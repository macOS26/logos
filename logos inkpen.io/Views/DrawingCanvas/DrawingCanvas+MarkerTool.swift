//
//  DrawingCanvas+MarkerTool.swift
//  logos inkpen.io
//
//  Marker tool - creates smooth strokes with circular felt-tip marker
//  Based on Sharpie, Rapidograph, and other felt-tip markers
//

import SwiftUI

// MARK: - Marker Point Data Structure
struct MarkerPoint {
    let location: CGPoint
    let pressure: Double // RAW 0.0 to 1.0 - NO CLAMPING

    init(location: CGPoint, pressure: Double = 1.0) {
        self.location = location
        self.pressure = pressure // Use raw pressure value directly
    }
}

extension DrawingCanvas {
    
    // MARK: - Marker Tool Management
    
    internal func cancelMarkerDrawing() {
        markerPath = nil
        markerRawPoints.removeAll()
        markerSimplifiedPoints.removeAll()
        isMarkerDrawing = false
        activeMarkerShape = nil
    }
    
    internal func handleMarkerDragStart(at location: CGPoint) {
        // Start new marker stroke with proper initialization
        guard !isMarkerDrawing else { return }

        // Save undo state BEFORE starting drawing
        document.saveToUndoStack()

        // Initialize marker drawing state
        isMarkerDrawing = true
        markerRawPoints = [MarkerPoint(location: location, pressure: 1.0)]
        markerSimplifiedPoints = []
        
        // Reset pressure manager for new drawing
        PressureManager.shared.resetForNewDrawing()
        
        // Create initial VectorPath for center line
        let startPoint = VectorPoint(location)
        markerPath = VectorPath(elements: [.move(to: startPoint)])
        
        // Create real VectorShape for marker stroke using current user settings
        // MARKER SPECIFIC: Creates variable width filled shapes instead of strokes
        let strokeColor = document.markerApplyNoStroke ? nil : getCurrentStrokeColor()
        let strokeWidth = getCurrentStrokeWidth() // Use stroke weight from fill/stroke tool
        
        // For marker tool: if "Use Fill as Stroke" is enabled, use fill color for both fill and stroke
        // Otherwise, use stroke color for both fill and stroke
        let markerFillColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerStrokeColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        
        // Use dedicated marker opacity for both stroke and fill to honor Marker Settings
        let markerOpacity = document.currentMarkerOpacity
        let strokeStyle = strokeColor != nil ? StrokeStyle(
            color: markerStrokeColor,
            width: strokeWidth,
            placement: document.defaultStrokePlacement,
            lineCap: .round,
            lineJoin: .round,
            opacity: markerOpacity
        ) : nil
        
        let fillStyle = FillStyle(
            color: markerFillColor,
            opacity: markerOpacity
        )
        
        guard let path = markerPath else { return }
        activeMarkerShape = VectorShape(
            name: "Marker Stroke",
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        // VECTOR APP OPTIMIZATION: Don't add to document during drawing - use overlay system
        // Shape will be added only when drawing is complete
        
        Log.fileOperation("🖊️ MARKER: Started drawing at \(location)", level: .info)
    }
    
    internal func handleMarkerDragUpdate(at location: CGPoint, pressure: Double? = nil) {
        guard isMarkerDrawing else { return }

        // Use pressure passed directly from event, or fall back to PressureManager
        let actualPressure = pressure ?? PressureManager.shared.currentPressure

        // Logging disabled in hot path to reduce CPU overhead

        // Add point to raw path with RAW pressure data (0.0-1.0)
        let markerPoint = MarkerPoint(location: location, pressure: actualPressure)
        // Logging disabled in hot path to reduce CPU overhead

        markerRawPoints.append(markerPoint)
        // Logging disabled in hot path to reduce CPU overhead

        // Update real-time preview
        updateMarkerPreview()

        // Limit raw points array to prevent memory issues
        if markerRawPoints.count > 1000 {
            // Keep last 800 points
            markerRawPoints = Array(markerRawPoints.suffix(800))
        }
    }
    
    internal func handleMarkerDragEnd() {
        guard isMarkerDrawing else { return }

        Log.fileOperation("🖊️ MARKER: Finishing drawing with \(markerRawPoints.count) raw points", level: .info)

        // Use the EXACT preview path as final - no recomputation
        if let preview = markerPreviewPath {
            finalizeMarkerFromPreview(preview)
        } else {
            // Fallback: generate if no preview exists
            processMarkerStroke()
        }

        // Clean up state including clearing preview path for overlay system
        markerPreviewPath = nil
        cancelMarkerDrawing()

        // AUTO-DESELECT: Clear selection AFTER shape is added
        // MUST happen after processMarkerStroke since that selects the shape
        document.selectedShapeIDs.removeAll()
        document.selectedObjectIDs.removeAll()
        Log.fileOperation("🎨 MARKER: Auto-deselected shape to enable color changes for next stroke", level: .info)
        
        Log.info("✅ MARKER: Stroke completed and converted to smooth felt-tip stroke", category: .fileOperations)
    }
    
    // MARK: - Pressure Simulation for Felt-Tip Marker
    
    private func calculateMarkerPressure(at location: CGPoint) -> Double {
        // If pressure sensitivity is disabled, return constant pressure
        if !appState.pressureSensitivityEnabled {
            return 1.0
        }
        
        guard markerRawPoints.count > 1,
              let lastPointData = markerRawPoints.last else { return 1.0 }

        let lastPoint = lastPointData.location
        let distance = sqrt(pow(location.x - lastPoint.x, 2) + pow(location.y - lastPoint.y, 2))
        
        // Simulate pressure based on drawing speed for felt-tip marker
        // Fast drawing = light pressure (thin line), slow drawing = heavy pressure (thick line)
        let maxSpeed: Double = 100.0 // Maximum pixels per measurement
        let normalizedSpeed = min(distance / maxSpeed, 1.0)
        let basePressure = 1.0 - (normalizedSpeed * 0.5) // Reduce pressure with speed

        // Apply fixed sensitivity for simulated pressure
        let sensitivity = 0.5 // Fixed sensitivity when simulating
        let pressureVariation = (basePressure - 0.5) * sensitivity

        let finalPressure = max(0.1, min(1.0, 0.5 + pressureVariation))
        
        // Reduced logging frequency for performance
        if markerRawPoints.count % 20 == 0 {
            Log.info("Marker pressure: \(String(format: "%.2f", finalPressure)) [speed: \(String(format: "%.1f", normalizedSpeed * 100))%]", category: .pressure)
        }
        
        return finalPressure
    }
    
    // MARK: - Real-time Preview
    
    private func updateMarkerPreview() {
        // VECTOR APP OPTIMIZATION: Direct overlay update - no throttling for 60fps
        guard markerRawPoints.count >= 2 else { return }
        
        // Generate preview path for overlay rendering - SwiftUI will handle 60fps updates
        let previewPath = generateMarkerLivePreviewPath()
        markerPreviewPath = previewPath
        
        // No document updates during drawing - overlay handles all preview rendering
    }
    
    /// Generate live preview of the felt-tip marker stroke as the user draws
    private func generateMarkerLivePreviewPath() -> VectorPath {
        guard markerRawPoints.count >= 2 else {
            // Fallback for insufficient points
            return VectorPath(elements: [.move(to: VectorPoint(markerRawPoints[0].location))])
        }

        // LIVE PREVIEW: Use raw points directly with their captured pressure - NO SIMPLIFICATION
        // This ensures real-time pressure response during drawing
        let rawPointLocations = markerRawPoints.map { $0.location }

        // Generate smooth felt-tip marker stroke with real-time pressure
        return createSmoothMarkerStroke(
            centerPoints: rawPointLocations,
            recentRawPoints: markerRawPoints
        )
    }
    
    // MARK: - Marker Stroke Processing
    
    private func processMarkerStroke() {
        guard markerRawPoints.count >= 2,
              let _ = activeMarkerShape,
              document.selectedLayerIndex != nil else {
            Log.fileOperation("🖊️ MARKER: Too few points (\(markerRawPoints.count)) - keeping as simple stroke", level: .info)
            return
        }

        // We'll detect straight lines AFTER simplification, like brush tool does
        
        let rawPointLocations = markerRawPoints.map { $0.location }
        Log.fileOperation("🖊️ ADVANCED SMOOTHING: Starting with \(rawPointLocations.count) raw marker points", level: .info)
        
        var processedPoints = rawPointLocations
        
        // Step 1: Apply Chaikin smoothing for initial curve smoothing (if enabled)
        if document.advancedSmoothingEnabled {
            let chaikinSmoothed = CurveSmoothing.chaikinSmooth(
                points: processedPoints,
                iterations: document.chaikinSmoothingIterations,
                ratio: 0.25
            )
            processedPoints = chaikinSmoothed
            Log.fileOperation("🖊️ CHAIKIN: Smoothed to \(processedPoints.count) points (\(document.chaikinSmoothingIterations) iterations)", level: .info)
        }
        
        // Step 2: Apply improved Douglas-Peucker simplification with sharp corner preservation
        // Reduce tolerance to preserve more points for proper leaf shapes
        let smoothingTolerance = document.currentMarkerSmoothingTolerance * 0.3  // Less aggressive for leaf shapes
        markerSimplifiedPoints = document.advancedSmoothingEnabled ?
            CurveSmoothing.improvedDouglassPeucker(
                points: processedPoints,
                tolerance: smoothingTolerance,
                preserveSharpCorners: document.preserveSharpCorners
            ) :
            DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: processedPoints, tolerance: smoothingTolerance)

        Log.info("Douglas-Peucker: Simplified to \(markerSimplifiedPoints.count) points", category: .general)

        // CRITICAL: Ensure we have enough points for smooth tapers
        // Need MORE points when pressure sensitivity is off since taper is the only variation
        let minPoints = appState.pressureSensitivityEnabled ? 8 : 20
        if markerSimplifiedPoints.count < minPoints && processedPoints.count > 2 {
            // Try again with much less tolerance
            let minTolerance = smoothingTolerance * 0.05
            markerSimplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: processedPoints, tolerance: minTolerance)

            // If still too few, sample from processed points
            if markerSimplifiedPoints.count < minPoints {
                let stepSize = max(1, processedPoints.count / (minPoints + 10))
                markerSimplifiedPoints = []
                for i in Swift.stride(from: 0, to: processedPoints.count, by: stepSize) {
                    markerSimplifiedPoints.append(processedPoints[i])
                }
                if let last = processedPoints.last, markerSimplifiedPoints.last != last {
                    markerSimplifiedPoints.append(last)
                }
            }
        }
        
        // Step 2: Generate smooth felt-tip marker stroke
        let markerStrokePath = createFinalMarkerStroke(
            centerPoints: markerSimplifiedPoints,
            recentRawPoints: markerRawPoints
        )
        
        // Step 3: Create and add the final marker stroke to the document
        let strokeColor = document.markerApplyNoStroke ? nil : getCurrentStrokeColor()
        let strokeWidth = getCurrentStrokeWidth()
        
        // For marker tool: if "Use Fill Color for Stroke" is enabled, use fill color for both fill and stroke
        // Otherwise, use stroke color for both fill and stroke
        let markerFillColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerStrokeColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        
        // Apply marker-specific opacity for finalized shape
        let markerOpacity = document.currentMarkerOpacity
        let strokeStyle = strokeColor != nil ? StrokeStyle(
            color: markerStrokeColor,
            width: strokeWidth,
            placement: document.defaultStrokePlacement,
            lineCap: .round,
            lineJoin: .round,
            opacity: markerOpacity
        ) : nil
        
        let fillStyle = FillStyle(
            color: markerFillColor,
            opacity: markerOpacity
        )
        
        var finalShape = VectorShape(
            name: "Marker Stroke",
            path: markerStrokePath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        // Apply expand stroke and union if remove overlap is enabled
        if document.markerRemoveOverlap {
            var currentPath = finalShape.path.cgPath

            // Step 1: FIRST remove overlap from the fill path to avoid artifacts
            var cleanedFillPath: CGPath? = nil
            cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .winding)
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .evenOdd) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .winding) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .evenOdd) }

            if let cleaned = cleanedFillPath, !cleaned.isEmpty, isPathBoundsFinite(cleaned.boundingBox) {
                currentPath = cleaned
                finalShape.path = VectorPath(cgPath: cleaned)
                Log.info("🖊️ MARKER: Removed fill path overlap first", category: .general)
            }

            // Step 2: Expand the stroke outline if stroke exists and union with cleaned fill
            if let stroke = finalShape.strokeStyle, stroke.width > 0 {
                if let expandedStroke = PathOperations.outlineStroke(path: currentPath, strokeStyle: stroke) {
                    // Step 3: Union the expanded stroke with itself to remove internal overlaps
                    var unionedStroke: CGPath? = nil
                    unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding)
                    if unionedStroke == nil {
                        unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .evenOdd)
                    }

                    // Step 4: Union the expanded stroke with the cleaned fill path
                    let strokeToMerge = unionedStroke ?? expandedStroke
                    var merged: CGPath? = nil
                    merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .winding)
                    if merged == nil {
                        merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .evenOdd)
                    }

                    if let mergedPath = merged, !mergedPath.isEmpty, isPathBoundsFinite(mergedPath.boundingBox) {
                        finalShape.path = VectorPath(cgPath: mergedPath)
                        finalShape.strokeStyle = nil // Convert to fill-only shape
                        Log.info("🖊️ MARKER: Expanded stroke and unioned with cleaned fill", category: .general)
                    }
                }
            }
        }
        
        // VECTOR APP OPTIMIZATION: Add shape only once at the end, not during drawing
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.addShapeToFrontOfUnifiedSystem(finalShape, layerIndex: layerIndex)

        Log.fileOperation("🖊️ MARKER: Generated smooth felt-tip stroke with \(markerSimplifiedPoints.count) control points", level: .info)
    }

    /// Finalize marker stroke from preview path (no recomputation)
    private func finalizeMarkerFromPreview(_ preview: VectorPath) {
        guard document.selectedLayerIndex != nil else { return }

        // Use current marker settings
        let strokeColor = document.markerApplyNoStroke ? nil : getCurrentStrokeColor()
        let strokeWidth = getCurrentStrokeWidth()

        let markerFillColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerStrokeColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
        let markerOpacity = document.currentMarkerOpacity

        let strokeStyle = strokeColor != nil ? StrokeStyle(
            color: markerStrokeColor,
            width: strokeWidth,
            placement: document.defaultStrokePlacement,
            lineCap: .round,
            lineJoin: .round,
            opacity: markerOpacity
        ) : nil

        let fillStyle = FillStyle(
            color: markerFillColor,
            opacity: markerOpacity
        )

        var finalPath = preview
        var finalStrokeStyle = strokeStyle

        // Apply remove overlap if enabled
        if document.markerRemoveOverlap {
            var currentPath = preview.cgPath

            // Step 1: FIRST remove overlap from the fill path to avoid artifacts
            var cleanedFillPath: CGPath? = nil
            cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .winding)
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.normalized(currentPath, using: .evenOdd) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .winding) }
            if cleanedFillPath == nil { cleanedFillPath = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .evenOdd) }

            if let cleaned = cleanedFillPath, !cleaned.isEmpty, isPathBoundsFinite(cleaned.boundingBox) {
                currentPath = cleaned
                finalPath = VectorPath(cgPath: cleaned)
                Log.info("🖊️ MARKER: Removed fill path overlap first (preview)", category: .general)
            }

            // Step 2: Expand the stroke outline if stroke exists and union with cleaned fill
            if let stroke = strokeStyle, stroke.width > 0 {
                if let expandedStroke = PathOperations.outlineStroke(path: currentPath, strokeStyle: stroke) {
                    // Step 3: Union the expanded stroke with itself to remove internal overlaps
                    var unionedStroke: CGPath? = nil
                    unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding)
                    if unionedStroke == nil {
                        unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .evenOdd)
                    }

                    // Step 4: Union the expanded stroke with the cleaned fill path
                    let strokeToMerge = unionedStroke ?? expandedStroke
                    var merged: CGPath? = nil
                    merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .winding)
                    if merged == nil {
                        merged = CoreGraphicsPathOperations.union(currentPath, strokeToMerge, using: .evenOdd)
                    }

                    if let mergedPath = merged, !mergedPath.isEmpty, isPathBoundsFinite(mergedPath.boundingBox) {
                        finalPath = VectorPath(cgPath: mergedPath)
                        finalStrokeStyle = nil // Convert to fill-only shape
                        Log.info("🖊️ MARKER: Expanded stroke and unioned with cleaned fill (preview)", category: .general)
                    }
                }
            }
        }

        let shape = VectorShape(name: "Marker Stroke", path: finalPath, strokeStyle: finalStrokeStyle, fillStyle: fillStyle)
        guard let layerIndex = document.selectedLayerIndex else { return }
        document.addShapeToFrontOfUnifiedSystem(shape, layerIndex: layerIndex)
    }


    // MARK: - Marker Stroke Generation
    
    /// Generate smooth felt-tip marker stroke with variable width
    private func createSmoothMarkerStroke(centerPoints: [CGPoint], recentRawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point - create a dot
            return createMarkerDot(at: centerPoints[0])
        }
        
        // Create variable-width felt-tip marker stroke
        return createVariableWidthMarkerStroke(centerPoints: centerPoints, rawPoints: recentRawPoints)
    }
    
    /// Create final marker stroke with proper smoothing
    private func createFinalMarkerStroke(centerPoints: [CGPoint], recentRawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point - create a dot
            return createMarkerDot(at: centerPoints[0])
        }
        
        // Create variable-width felt-tip marker stroke
        return createVariableWidthMarkerStroke(centerPoints: centerPoints, rawPoints: recentRawPoints)
    }
    
    /// Create variable-width felt-tip marker stroke with realistic pressure simulation and SMOOTH BEZIER CURVES
    private func createVariableWidthMarkerStroke(centerPoints: [CGPoint], rawPoints: [MarkerPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            return createMarkerDot(at: centerPoints[0])
        }

        // Markers don't need special straight line handling - they should look consistent

        // Calculate variable thickness at each simplified point with pressure and tapering
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []
        
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)

            // Get pressure at this point
            let pressure = getPressureAtPoint(point, rawPoints: rawPoints)

            // Base thickness from marker settings
            var finalThickness = document.currentMarkerTipSize

            // MARKER-SPECIFIC THICKNESS PROFILE (consistent felt-tip appearance)
            // For very short strokes, use minimal tapering to maintain marker appearance
            let strokeLength = Double(centerPoints.count)
            let isShortStroke = strokeLength < 5

            if isShortStroke {
                // Very short strokes: Sharp taper from thin point to thick and back to thin point
                if progress < 0.3 {
                    finalThickness *= pow(progress / 0.3, 1.5)
                } else if progress > 0.7 {
                    let endProgress = (1.0 - progress) / 0.3
                    finalThickness *= pow(endProgress, 1.5)
                }
            } else {
                // Longer strokes: Sharp marker tapering (thin points at start and end)
                // Increased minimum taper amount to make taper start sooner
                let startTaper = max(0.25, document.currentMarkerTaperStart)
                let endTaper = max(0.25, document.currentMarkerTaperEnd)

                if progress < startTaper {
                    finalThickness *= pow(progress / startTaper, 1.5)
                } else if progress > (1.0 - endTaper) {
                    let endProgress = (1.0 - progress) / endTaper
                    finalThickness *= pow(endProgress, 1.5)
                }
            }

            // Apply feathering effect for felt-tip appearance
            let feathering = document.currentMarkerFeathering
            if isShortStroke {
                finalThickness *= (1.0 - feathering * 0.15)
            } else {
                finalThickness *= (1.0 - feathering * 0.2)
            }

            // Apply pressure curve mapping - READ DIRECTLY FROM USERDEFAULTS
            if appState.pressureSensitivityEnabled {
                // Read curve from UserDefaults EVERY TIME
                var curve: [CGPoint] = []
                if let data = UserDefaults.standard.array(forKey: "pressureCurve") {
                    curve = data.compactMap { item -> CGPoint? in
                        if let dict = item as? [String: Any],
                           let x = dict["x"] as? Double,
                           let y = dict["y"] as? Double {
                            return CGPoint(x: x, y: y)
                        } else if let dict = item as? [String: Double],
                                  let x = dict["x"],
                                  let y = dict["y"] {
                            return CGPoint(x: x, y: y)
                        }
                        return nil
                    }
                }

                // Fallback to linear if no curve
                if curve.count < 2 {
                    curve = [
                        CGPoint(x: 0.0, y: 0.0),
                        CGPoint(x: 0.25, y: 0.25),
                        CGPoint(x: 0.5, y: 0.5),
                        CGPoint(x: 0.75, y: 0.75),
                        CGPoint(x: 1.0, y: 1.0)
                    ]
                }

                // LOG CURVE DATA
                if index == 0 {
                    let curveStr = curve.map { "(\(String(format: "%.2f", $0.x)),\(String(format: "%.2f", $0.y)))" }.joined(separator: " ")
                    Log.info("📊 MARKER CURVE: [\(curveStr)]", category: .pressure)
                }

                let mappedPressure = getThicknessFromPressureCurve(pressure: pressure, curve: curve)

                // LOG PRESSURE VALUES
                if index % 5 == 0 {  // Log every 5th point to reduce spam
                    Log.info("📊 MARKER PRESSURE: raw=\(String(format: "%.3f", pressure)) → mapped=\(String(format: "%.3f", mappedPressure)) | thickness before=\(String(format: "%.2f", finalThickness)) after=\(String(format: "%.2f", finalThickness * mappedPressure))", category: .pressure)
                }

                finalThickness *= mappedPressure
            }

            // Ensure minimum thickness AFTER all multipliers (taper + pressure)
            let minThickness = document.currentMarkerMinTaperThickness
            if finalThickness > 0 {
                finalThickness = max(finalThickness, minThickness)
            }

            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        
        // Generate left and right edge points with variable thickness
        let leftEdgePoints = generateMarkerOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateMarkerOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        
        // Create simple filled outline like brush tool - NO COMPLEX CAPS!
        return createSimpleMarkerOutline(leftEdgePoints: leftEdgePoints, rightEdgePoints: rightEdgePoints)
    }
    
    /// Get pressure at a specific point by interpolating from raw points
    private func getPressureAtPoint(_ point: CGPoint, rawPoints: [MarkerPoint]) -> Double {
        guard rawPoints.count > 0 else {
            // Logging disabled in hot path to reduce CPU overhead
            return 1.0
        }

        // Find the TWO closest raw points and interpolate between them
        var closestDistance1 = Double.infinity
        var closestDistance2 = Double.infinity
        var closestPressure1: Double = 1.0
        var closestPressure2: Double = 1.0

        for rawPoint in rawPoints {
            let distance = sqrt(pow(point.x - rawPoint.location.x, 2) + pow(point.y - rawPoint.location.y, 2))

            if distance < closestDistance1 {
                // New closest point
                closestDistance2 = closestDistance1
                closestPressure2 = closestPressure1
                closestDistance1 = distance
                closestPressure1 = rawPoint.pressure
            } else if distance < closestDistance2 {
                // New second closest
                closestDistance2 = distance
                closestPressure2 = rawPoint.pressure
            }
        }

        // If we found two points, interpolate between them
        if closestDistance1 < Double.infinity && closestDistance2 < Double.infinity {
            let totalDistance = closestDistance1 + closestDistance2
            if totalDistance > 0 {
                // Weight by inverse distance
                let weight1 = closestDistance2 / totalDistance
                let weight2 = closestDistance1 / totalDistance
                let interpolatedPressure = closestPressure1 * weight1 + closestPressure2 * weight2
                // Logging disabled in hot path to reduce CPU overhead
                return interpolatedPressure
            }
        }

        // Logging disabled in hot path to reduce CPU overhead
        return closestPressure1
    }
    
    /// Generate offset points for marker edges with variable thickness
    private func generateMarkerOffsetPoints(centerPoints: [(location: CGPoint, thickness: Double)], isLeftSide: Bool) -> [CGPoint] {
        var offsetPoints: [CGPoint] = []
        
        for i in 0..<centerPoints.count {
            let point = centerPoints[i]
            let thickness = point.thickness
            
            // Calculate perpendicular direction for offset
            var perpendicular: CGPoint
            
            if i == 0 {
                // Use direction to next point
                if i + 1 < centerPoints.count {
                    let nextPoint = centerPoints[i + 1].location
                    let direction = CGPoint(x: nextPoint.x - point.location.x, y: nextPoint.y - point.location.y)
                    perpendicular = CGPoint(x: -direction.y, y: direction.x)
                } else {
                    perpendicular = CGPoint(x: 0, y: 1) // Default vertical
                }
            } else if i == centerPoints.count - 1 {
                // Use direction from previous point
                let prevPoint = centerPoints[i - 1].location
                let direction = CGPoint(x: point.location.x - prevPoint.x, y: point.location.y - prevPoint.y)
                perpendicular = CGPoint(x: -direction.y, y: direction.x)
            } else {
                // Use average direction from previous and next points
                let prevPoint = centerPoints[i - 1].location
                let nextPoint = centerPoints[i + 1].location
                let direction = CGPoint(x: nextPoint.x - prevPoint.x, y: nextPoint.y - prevPoint.y)
                perpendicular = CGPoint(x: -direction.y, y: direction.x)
            }
            
            // Normalize perpendicular vector
            let length = sqrt(perpendicular.x * perpendicular.x + perpendicular.y * perpendicular.y)
            if length > 0 {
                perpendicular = CGPoint(x: perpendicular.x / length, y: perpendicular.y / length)
            }
            
            // Calculate offset distance (half thickness on each side)
            let offsetDistance = thickness / 2.0
            let multiplier: Double = isLeftSide ? 1.0 : -1.0
            
            let offsetPoint = CGPoint(
                x: point.location.x + perpendicular.x * offsetDistance * multiplier,
                y: point.location.y + perpendicular.y * offsetDistance * multiplier
            )
            
            offsetPoints.append(offsetPoint)
        }
        
        return offsetPoints
    }
    
    /// Create advanced smooth bezier path from points using professional algorithms
    private func createSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
        guard points.count >= 2 else {
            return VectorPath(elements: [])
        }
        
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))
        
        if points.count == 2 {
            // Simple line for two points
            elements.append(.line(to: VectorPoint(points[1])))
        } else {
            // Use advanced adaptive curve fitting with centripetal Catmull-Rom
            let curveSegments = CurveSmoothing.adaptiveCurveFitting(
                points: points,
                adaptiveTension: true,
                baseTension: 0.3
            )
            elements.append(contentsOf: curveSegments)
        }
        
        return VectorPath(elements: elements)
    }
    
    /// Create simple marker outline like brush tool - just a filled stroke shape
    private func createSimpleMarkerOutline(leftEdgePoints: [CGPoint], rightEdgePoints: [CGPoint]) -> VectorPath {
        guard leftEdgePoints.count >= 2 && rightEdgePoints.count >= 2 else {
            // Fallback for insufficient points
            if let firstPoint = leftEdgePoints.first {
                return VectorPath(elements: [.move(to: VectorPoint(firstPoint))])
            }
            return VectorPath(elements: [])
        }
        
        var elements: [PathElement] = []
        
        // Start at first left point
        elements.append(.move(to: VectorPoint(leftEdgePoints[0])))
        
        // Create smooth bezier curves along left edge
        if leftEdgePoints.count == 2 {
            elements.append(.line(to: VectorPoint(leftEdgePoints[1])))
        } else {
            let leftCurves = fitBezierCurves(through: leftEdgePoints)
            elements.append(contentsOf: leftCurves)
        }
        
        // Connect to right edge at end (smooth transition)
        if let lastRightEdge = rightEdgePoints.last {
            elements.append(.line(to: VectorPoint(lastRightEdge)))
        }
        
        // Create smooth bezier curves along right edge (in reverse)
        let reversedRightPoints = rightEdgePoints.reversed()
        if reversedRightPoints.count == 2 {
            elements.append(.line(to: VectorPoint(Array(reversedRightPoints)[1])))
        } else {
            let rightCurves = fitBezierCurves(through: Array(reversedRightPoints))
            elements.append(contentsOf: rightCurves)
        }
        
        // Close back to start
        elements.append(.close)
        
        return VectorPath(elements: elements)
    }
    
    /// Create a small dot for single marker points
    private func createMarkerDot(at center: CGPoint) -> VectorPath {
        // Create a small circle for single points using marker settings
        let radius = document.currentMarkerTipSize / 2.0
        var elements: [PathElement] = []
        
        // Create a circle using bezier curves (4 curve segments)
        let controlPointDistance = radius * 0.552284749831 // Magic number for circle approximation
        
        // Start at right point
        elements.append(.move(to: VectorPoint(center.x + radius, center.y)))
        
        // Top curve
        elements.append(.curve(
            to: VectorPoint(center.x, center.y + radius),
            control1: VectorPoint(center.x + radius, center.y + controlPointDistance),
            control2: VectorPoint(center.x + controlPointDistance, center.y + radius)
        ))
        
        // Left curve
        elements.append(.curve(
            to: VectorPoint(center.x - radius, center.y),
            control1: VectorPoint(center.x - controlPointDistance, center.y + radius),
            control2: VectorPoint(center.x - radius, center.y + controlPointDistance)
        ))
        
        // Bottom curve
        elements.append(.curve(
            to: VectorPoint(center.x, center.y - radius),
            control1: VectorPoint(center.x - radius, center.y - controlPointDistance),
            control2: VectorPoint(center.x - controlPointDistance, center.y - radius)
        ))
        
        // Right curve (back to start)
        elements.append(.curve(
            to: VectorPoint(center.x + radius, center.y),
            control1: VectorPoint(center.x + controlPointDistance, center.y - radius),
            control2: VectorPoint(center.x + radius, center.y - controlPointDistance)
        ))
        
        elements.append(.close)
        
        return VectorPath(elements: elements)
    }
    
    // MARK: - Shared Algorithm Functions (Same as Freehand/Brush Tools)
    
    // douglasPeuckerSimplify moved to DrawingCanvasPathHelpers
    
    // douglasPeuckerRecursive moved to DrawingCanvasPathHelpers
    
    // perpendicularDistance moved to DrawingCanvasPathHelpers
    
    private func fitBezierCurves(through points: [CGPoint]) -> [PathElement] {
        var elements: [PathElement] = []
        
        // Use a simple curve fitting approach that creates smooth C1 continuous curves
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            
            // MARKER SPECIFIC: Make only first and last segments lines (corner points)
            // The second and second-last points should be smooth for better marker appearance
            let isFirstSegment = (i == 1)
            let isLastSegment = (i == points.count - 1)
            
            if isFirstSegment || isLastSegment {
                // Create corner points only for start and end - no handles
                elements.append(.line(to: VectorPoint(p1)))
            } else {
                // Calculate control points for smooth curves (middle segments only)
                let tension: Double = 0.25 // Curve tension factor
                let distance = sqrt(pow(p1.x - p0.x, 2) + pow(p1.y - p0.y, 2))
                
                // Calculate tangent directions
                let prevTangent = i > 1 ? calculateTangent(p0: points[i - 2], p1: p0, p2: p1) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let nextTangent = i < points.count - 1 ? calculateTangent(p0: p0, p1: p1, p2: points[i + 1]) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                
                // Create control points
                let controlLength = distance * tension
                
                let control1 = CGPoint(
                    x: p0.x + prevTangent.x * controlLength,
                    y: p0.y + prevTangent.y * controlLength
                )
                
                let control2 = CGPoint(
                    x: p1.x - nextTangent.x * controlLength,
                    y: p1.y - nextTangent.y * controlLength
                )
                
                elements.append(.curve(
                    to: VectorPoint(p1),
                    control1: VectorPoint(control1),
                    control2: VectorPoint(control2)
                ))
            }
        }
        
        return elements
    }
    
    private func calculateTangent(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        // Calculate normalized tangent direction at p1
        let dx1 = p1.x - p0.x
        let dy1 = p1.y - p0.y
        let dx2 = p2.x - p1.x
        let dy2 = p2.y - p1.y
        
        // Average the two segments
        let avgDx = (dx1 + dx2) / 2
        let avgDy = (dy1 + dy2) / 2
        
        // Normalize
        let length = sqrt(avgDx * avgDx + avgDy * avgDy)
        if length > 0 {
            return CGPoint(x: avgDx / length, y: avgDy / length)
        } else {
            return CGPoint(x: 1, y: 0)
        }
    }
    
    // MARK: - Remove Overlap Functionality
    
    /// Apply self-union operation to remove overlapping areas within the single marker stroke
    private func applySelfUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        
        let shapes = document.getShapesForLayer(layerIndex)
        guard shapeIndex < shapes.count else { 
            Log.fileOperation("🚨 MARKER ERROR: Shape index \(shapeIndex) out of bounds! Layer has \(shapes.count) shapes", level: .info)
            return 
        }
        
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            Log.fileOperation("🚨 MARKER ERROR: Could not get shape at index \(shapeIndex)", level: .info)
            return
        }
        
        // VERIFY: Make sure we're operating on the correct shape
        guard markerStroke.id == activeMarkerShape?.id else {
            Log.fileOperation("🚨 MARKER ERROR: Shape ID mismatch! Expected \(activeMarkerShape?.id ?? UUID()), got \(markerStroke.id)", level: .info)
            Log.fileOperation("🚨 MARKER ERROR: This would affect the WRONG shape - ABORTING self-union", level: .info)
            return
        }
        

        
        // Handle different behaviors based on stroke/fill color matching
        let hasStroke = markerStroke.strokeStyle != nil
        let hasFill = markerStroke.fillStyle != nil
        
        if hasStroke && hasFill,
           let strokeColor = markerStroke.strokeStyle?.color,
           let fillColor = markerStroke.fillStyle?.color {

            if strokeColor == fillColor {
                // Same color: expand stroke and combine with fill as one shape
                applyExpandedStrokeUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            } else {
                // Different colors: union stroke separately, union fill separately
                applyDualUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            }
        } else {
            // Only stroke or only fill: simple union
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }
    
    /// Apply union operation for markers with same stroke/fill color or single color
    private func applySingleUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            Log.fileOperation("🚨 MARKER ERROR: Could not get shape at index \(shapeIndex)", level: .info)
            return
        }
        
        // Convert VectorPath to CGPath for boolean operations
        let originalPath = markerStroke.path.cgPath
        
        // SAFETY CHECK: Ensure path is valid before union operation
        guard !originalPath.isEmpty else {
            Log.fileOperation("🚨 MARKER ERROR: Original path is empty - ABORTING self-union", level: .info)
            return
        }
        
        // SAFETY CHECK: Verify path has valid bounds
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            Log.fileOperation("🚨 MARKER ERROR: Path has invalid bounds - ABORTING self-union", level: .info)
            return
        }
        
        // Apply self-union to remove any self-intersections within the marker stroke
        if let cleanedPath = CoreGraphicsPathOperations.union(originalPath, originalPath) {
            // SAFETY CHECK: Verify the result path is valid
            guard !cleanedPath.isEmpty && isPathBoundsFinite(cleanedPath.boundingBox) else {
                Log.fileOperation("🚨 MARKER ERROR: Union operation produced invalid path - keeping original", level: .info)
                return
            }
            
            let cleanedVectorPath = VectorPath(cgPath: cleanedPath)
            
            // Update the marker stroke with the cleaned path
            var updatedShape = markerStroke
            updatedShape.path = cleanedVectorPath
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // CRITICAL FIX: Sync unified objects system to ensure the updated shape is rendered
            document.updateUnifiedObjectsOptimized()
            
            Log.fileOperation("🖊️ MARKER: Applied self-union to remove overlapping areas within marker stroke", level: .info)
        } else {
            Log.fileOperation("🖊️ MARKER: Self-union operation failed, keeping original path", level: .info)
        }
    }
    
    /// Apply expanded stroke union for markers with same stroke/fill color
    private func applyExpandedStrokeUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            Log.fileOperation("🚨 MARKER ERROR: Could not get shape at index \(shapeIndex)", level: .info)
            return
        }
        
        // Convert VectorPath to CGPath for boolean operations
        let originalPath = markerStroke.path.cgPath
        
        // SAFETY CHECK: Ensure path is valid before union operation
        guard !originalPath.isEmpty else {
            Log.fileOperation("🚨 MARKER ERROR: Original path is empty - ABORTING expanded stroke union", level: .info)
            return
        }
        
        // SAFETY CHECK: Verify path has valid bounds
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            Log.fileOperation("🚨 MARKER ERROR: Path has invalid bounds - ABORTING expanded stroke union", level: .info)
            return
        }
        
        // Step 1: Expand the stroke of the original path
        if let strokeStyle = markerStroke.strokeStyle,
           let expandedStroke = PathOperations.outlineStroke(path: originalPath, strokeStyle: strokeStyle) {
            
            // Step 2: Union the expanded stroke with itself to remove overlaps
            if let unionedExpandedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding) {
                
                // Step 3: Union the expanded stroke with the original fill path
                if let finalPath = CoreGraphicsPathOperations.union(originalPath, unionedExpandedStroke, using: .winding) {
                    
                    // SAFETY CHECK: Verify the result path is valid
                    guard !finalPath.isEmpty && isPathBoundsFinite(finalPath.boundingBox) else {
                        Log.fileOperation("🚨 MARKER ERROR: Final union operation produced invalid path - keeping original", level: .info)
                        return
                    }
                    
                    let finalVectorPath = VectorPath(cgPath: finalPath)
                    
                    // Update the marker stroke with the combined path and remove the stroke style
                    var updatedShape = markerStroke
                    updatedShape.path = finalVectorPath
                    updatedShape.strokeStyle = nil // Remove stroke since it's now part of the fill
                    updatedShape.fillStyle = FillStyle(
                        color: markerStroke.strokeStyle?.color ?? .black, // Use stroke color for the combined fill
                        opacity: markerStroke.strokeStyle?.opacity ?? 1.0
                    )
                    
                    // Use unified helper to update shape
                    document.updateEntireShapeInUnified(id: updatedShape.id) { shape in
                        shape.path = updatedShape.path
                        shape.fillStyle = updatedShape.fillStyle
                    }
                    
                    // CRITICAL FIX: Sync unified objects system to ensure the updated shape is rendered
                    document.updateUnifiedObjectsOptimized()
                    
                    Log.fileOperation("🖊️ MARKER: Applied expanded stroke union - stroke and fill combined as single shape", level: .info)
                } else {
                    Log.fileOperation("🖊️ MARKER: Final union operation failed, keeping original path", level: .info)
                }
            } else {
                Log.fileOperation("🖊️ MARKER: Expanded stroke union operation failed, keeping original path", level: .info)
            }
        } else {
            Log.fileOperation("🖊️ MARKER: Stroke expansion failed, falling back to simple union", level: .info)
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }
    
    /// Apply separate union operations for markers with different stroke/fill colors
    private func applyDualUnionToMarkerStroke(shapeIndex: Int, layerIndex: Int) {
        guard let markerStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            Log.fileOperation("🚨 MARKER ERROR: Could not get shape at index \(shapeIndex)", level: .info)
            return
        }
        
        // For different colors, we need to expand the stroke and union separately
        if let strokeStyle = markerStroke.strokeStyle {
            // Expand the stroke of the original path
            if let expandedStroke = PathOperations.outlineStroke(path: markerStroke.path.cgPath, strokeStyle: strokeStyle) {
                // Union the expanded stroke with itself
                if let unionedStroke = CoreGraphicsPathOperations.union(expandedStroke, expandedStroke, using: .winding) {
                    // Create a new shape for the unioned stroke
                    let strokeVectorPath = VectorPath(cgPath: unionedStroke)
                    let strokeShape = VectorShape(
                        name: "Marker Stroke (Outline)",
                        path: strokeVectorPath,
                        strokeStyle: nil, // Convert to fill
                        fillStyle: FillStyle(color: strokeStyle.color, opacity: strokeStyle.opacity)
                    )
                    
                    // Replace the original shape's stroke with no stroke and union the fill separately
                    var originalShape = markerStroke
                    originalShape.strokeStyle = nil // Remove stroke since we created separate stroke shape
                    
                    // Union the fill path with itself
                    if let cleanedFillPath = CoreGraphicsPathOperations.union(markerStroke.path.cgPath, markerStroke.path.cgPath) {
                        originalShape.path = VectorPath(cgPath: cleanedFillPath)
                    }
                    
                    // Use unified helper to update the original shape (now fill-only)
                    document.updateShapePathUnified(id: originalShape.id, path: originalShape.path)
                    
                    // Add the stroke shape using unified system
                    document.addShapeToUnifiedSystem(strokeShape, layerIndex: layerIndex)
                    
                    Log.fileOperation("🖊️ MARKER: Applied dual union - separated stroke and fill with different colors", level: .info)
                } else {
                    Log.fileOperation("🖊️ MARKER: Stroke union operation failed", level: .info)
                    applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
                }
            } else {
                Log.fileOperation("🖊️ MARKER: Stroke expansion failed", level: .info)
                applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
            }
        } else {
            // No stroke, just union the fill
            applySingleUnionToMarkerStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
        }
    }
    
    // MARK: - Helper Functions (Same as Brush Tool)

    // Color helper functions are now provided by DrawingCanvasStyleHelpers extension
} 
