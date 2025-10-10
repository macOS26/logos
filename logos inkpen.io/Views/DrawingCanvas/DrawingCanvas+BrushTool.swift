//
//  DrawingCanvas+BrushTool.swift
//  logos inkpen.io
//
//  Variable brush stroke tool with parallel path generation
//

import SwiftUI
import SwiftUI

extension DrawingCanvas {
    
    
    
    /// Check if a CGRect has finite values (no infinity or NaN)
    func isPathBoundsFinite(_ rect: CGRect) -> Bool {
        return rect.origin.x.isFinite && rect.origin.y.isFinite && 
               rect.size.width.isFinite && rect.size.height.isFinite
    }
    // MARK: - Current Color Helpers (now using shared DrawingCanvasStyleHelpers)
    
    // MARK: - Brush Tool Management
    
    internal func cancelBrushDrawing() {
        brushPath = nil
        brushRawPoints.removeAll()
        brushSimplifiedPoints.removeAll()
        isBrushDrawing = false
        activeBrushShape = nil
    }
    
    internal func handleBrushDragStart(at location: CGPoint) {
        // Start new brush stroke with proper initialization
        guard !isBrushDrawing else { return }

        // Initialize brush drawing state
        isBrushDrawing = true
        brushRawPoints = [BrushPoint(location: location, pressure: 1.0)]
        brushSimplifiedPoints = []

        // Detect pressure input capability using PressureManager
        document.hasPressureInput = PressureManager.shared.hasRealPressureInput

        // Reset pressure manager for new drawing
        PressureManager.shared.resetForNewDrawing()

        // Create initial VectorPath for center line
        let startPoint = VectorPoint(location)
        brushPath = VectorPath(elements: [.move(to: startPoint)])

        // Create real VectorShape for brush stroke using current user settings
        let strokeStyle: StrokeStyle? = document.brushApplyNoStroke ? nil : StrokeStyle(
            color: getCurrentStrokeColor(), // Use whatever stroke color user has set
            width: getCurrentStrokeWidth(), // Use whatever stroke width user has set
            lineCap: document.defaultStrokeLineCap, // Use user's default line cap
            lineJoin: document.defaultStrokeLineJoin, // Use user's default line join
            miterLimit: document.defaultStrokeMiterLimit, // Use user's default miter limit
            opacity: getCurrentStrokeOpacity() // Use whatever stroke opacity user has set
        )
        let fillStyle = FillStyle(
            color: getCurrentFillColor(), // Use whatever fill color user has set
            opacity: getCurrentFillOpacity() // Use whatever fill opacity user has set
        )

        activeBrushShape = VectorShape(
            name: "Brush Stroke",
            path: brushPath!,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )

        // CRITICAL: Create initial preview immediately so it never shows nothing
        // This ensures something is always visible from the very first point
        let thickness = document.currentBrushThickness
        let initialPreview = VectorPath(elements: [
            .move(to: VectorPoint(location.x - thickness/2, location.y)),
            .line(to: VectorPoint(location.x + thickness/2, location.y)),
            .line(to: VectorPoint(location.x, location.y + thickness/2)),
            .close
        ])
        brushPreviewPath = initialPreview

        // VECTOR APP OPTIMIZATION: Don't add to document during drawing - use overlay system
        // Shape will be added only when drawing is complete

    }
    
    internal func handleBrushDragUpdate(at location: CGPoint, pressure: Double? = nil) {
        guard isBrushDrawing else { return }

        // Use pressure passed directly from event, or fall back to PressureManager current value (NO SIMULATION)
        let actualPressure = pressure ?? PressureManager.shared.currentPressure

        // DISTANCE-BASED FILTERING: Only add point if it's far enough from the last point
        // This prevents excessive point density and duplicate points
        if let lastPoint = brushRawPoints.last {
            let distance = hypot(location.x - lastPoint.location.x, location.y - lastPoint.location.y)
            let minDistance: Double = 1.0 // Minimum 1.0 pixel between points - deduplication happens at the end

            // Skip this point if too close to previous point
            if distance < minDistance {
                return
            }
        }

        // DEBUG: Log pressure values every 10 points
        if brushRawPoints.count % 10 == 0 {
            print("🔴 PRESSURE: \(String(format: "%.2f", actualPressure)) | Sensitivity: \(appState.pressureSensitivityEnabled) | HasReal: \(PressureManager.shared.hasRealPressureInput)")
        }

        // Add point to raw path with RAW pressure data (no speed-based simulation)
        let newPoint = BrushPoint(location: location, pressure: actualPressure)
        brushRawPoints.append(newPoint)

        // Update preview on every point (same as marker tool for responsive drawing)
        updateBrushPreview()
    }
    

    
    internal func handleBrushDragEnd() {
        guard isBrushDrawing else { return }

        // For straight lines (only 2 points), add intermediate points to ensure proper leaf shape generation
        if brushRawPoints.count == 2 {
            let startPoint = brushRawPoints[0]
            let endPoint = brushRawPoints[1]

            // Add intermediate points along the line for proper variable width calculation
            var interpolatedPoints: [BrushPoint] = [startPoint]

            // Add 3-5 intermediate points for smooth leaf shape
            let numIntermediatePoints = 4
            for i in 1...numIntermediatePoints {
                let t = Double(i) / Double(numIntermediatePoints + 1)
                let interpolatedLocation = CGPoint(
                    x: startPoint.location.x + (endPoint.location.x - startPoint.location.x) * t,
                    y: startPoint.location.y + (endPoint.location.y - startPoint.location.y) * t
                )
                // Interpolate pressure as well
                let interpolatedPressure = startPoint.pressure + (endPoint.pressure - startPoint.pressure) * t
                interpolatedPoints.append(BrushPoint(
                    location: interpolatedLocation,
                    pressure: interpolatedPressure
                ))
            }

            interpolatedPoints.append(endPoint)
            brushRawPoints = interpolatedPoints
        }

        // ALWAYS use the preview path as final - it's already calculated correctly
        if let preview = brushPreviewPath {
            // Use the exact preview path as final
            finalizeFromPreview(preview)
        } else {
            // Fallback: generate the path if no preview exists (shouldn't happen)
            processBrushStroke()
        }
        
        // Clean up state including clearing preview path for overlay system
        brushPreviewPath = nil
        cancelBrushDrawing()

        // AUTO-DESELECT: Clear all selections after completing brush stroke
        // This allows user to immediately change colors for the next stroke
        document.selectedShapeIDs.removeAll()
        document.selectedObjectIDs.removeAll()
        document.selectedTextIDs.removeAll()
    }

    // MARK: - Real-time Preview
    
    private func updateBrushPreview() {
        // Generate preview - same simple approach as marker tool (no validation)
        guard brushRawPoints.count >= 2 else { return }

        let newPreviewPath = generateLivePreviewPath()
        print("🔵 BRUSH UPDATE: \(brushRawPoints.count) points -> \(newPreviewPath.elements.count) elements")
        brushPreviewPath = newPreviewPath
    }
    
    /// Generate live preview path for overlay rendering
    private func generateLivePreviewPath() -> VectorPath {
        guard brushRawPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(brushRawPoints[0].location))])
        }

        // ALWAYS use ALL points - no deduplication during preview for performance
        var pointsToProcess = brushRawPoints
        if brushRawPoints.count == 2 {
            let startPoint = brushRawPoints[0]
            let endPoint = brushRawPoints[1]

            var interpolatedPoints: [BrushPoint] = [startPoint]

            // Calculate perpendicular direction for jitter
            let dx = endPoint.location.x - startPoint.location.x
            let dy = endPoint.location.y - startPoint.location.y
            let lineLength = sqrt(dx * dx + dy * dy)

            // Perpendicular vector (normalized) - handle zero-length lines
            let perpX = lineLength > 0 ? -dy / lineLength : 0
            let perpY = lineLength > 0 ? dx / lineLength : 0

            // Add intermediate points with subtle jitter for natural brush look
            let numIntermediatePoints = 5
            for i in 1...numIntermediatePoints {
                let t = Double(i) / Double(numIntermediatePoints + 1)

                // Add subtle perpendicular jitter for organic feel
                // Use sine wave for smooth variation
                let jitterAmount = sin(t * .pi) * 2.0 // Max 2 pixels offset at middle

                let interpolatedLocation = CGPoint(
                    x: startPoint.location.x + (endPoint.location.x - startPoint.location.x) * t + perpX * jitterAmount,
                    y: startPoint.location.y + (endPoint.location.y - startPoint.location.y) * t + perpY * jitterAmount
                )

                // Linear pressure interpolation (no artificial bulge)
                let interpolatedPressure = startPoint.pressure + (endPoint.pressure - startPoint.pressure) * t

                interpolatedPoints.append(BrushPoint(
                    location: interpolatedLocation,
                    pressure: interpolatedPressure
                ))
            }

            interpolatedPoints.append(endPoint)
            pointsToProcess = interpolatedPoints
        }

        let rawPointLocations = pointsToProcess.map { $0.location }

        // CRITICAL FIX: Use raw points directly like marker tool - NO SIMPLIFICATION during preview
        // Simplification causes the path geometry to change dramatically between updates -> flicker
        // The marker tool doesn't simplify and it doesn't flicker!
        if rawPointLocations.count >= 2 {
            let newPath = generatePreviewVariableWidthPath(
                centerPoints: rawPointLocations,  // Use ALL raw points - no simplification!
                recentRawPoints: pointsToProcess,
                thickness: document.currentBrushThickness,
                pressureSensitivity: 0.5,
                taper: 0.5
            )
            return newPath
        }

        // Fallback for not enough points
        return VectorPath(elements: [.move(to: VectorPoint(rawPointLocations[0]))])
    }
    
    /// Generate live preview of the variable width brush stroke as the user draws
    private func generateLivePreviewPathOffMain(
        rawPoints: [BrushPoint],
        thickness: Double,
        pressureSensitivity: Double,
        taper: Double,
        previewTolerance: Double
    ) -> VectorPath {
        guard rawPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(rawPoints[0].location))])
        }

        // For straight lines (only 2 points), interpolate for proper leaf shape
        var pointsToProcess = rawPoints
        if rawPoints.count == 2 {
            let startPoint = rawPoints[0]
            let endPoint = rawPoints[1]

            var interpolatedPoints: [BrushPoint] = [startPoint]

            // Calculate perpendicular direction for jitter
            let dx = endPoint.location.x - startPoint.location.x
            let dy = endPoint.location.y - startPoint.location.y
            let lineLength = sqrt(dx * dx + dy * dy)

            // Perpendicular vector (normalized) - handle zero-length lines
            let perpX = lineLength > 0 ? -dy / lineLength : 0
            let perpY = lineLength > 0 ? dx / lineLength : 0

            // Add intermediate points with subtle jitter
            let numIntermediatePoints = 5
            for i in 1...numIntermediatePoints {
                let t = Double(i) / Double(numIntermediatePoints + 1)

                // Add subtle perpendicular jitter for organic feel
                let jitterAmount = sin(t * .pi) * 2.0 // Max 2 pixels offset at middle

                let interpolatedLocation = CGPoint(
                    x: startPoint.location.x + (endPoint.location.x - startPoint.location.x) * t + perpX * jitterAmount,
                    y: startPoint.location.y + (endPoint.location.y - startPoint.location.y) * t + perpY * jitterAmount
                )

                // Vary pressure for more natural tapering
                let basePressure = startPoint.pressure + (endPoint.pressure - startPoint.pressure) * t
                let pressureVariation = sin(t * .pi) * 0.15 // Add up to 15% variation
                let interpolatedPressure = min(1.0, basePressure * (1.0 + pressureVariation))

                interpolatedPoints.append(BrushPoint(
                    location: interpolatedLocation,
                    pressure: interpolatedPressure
                ))
            }

            interpolatedPoints.append(endPoint)
            pointsToProcess = interpolatedPoints
        }

        let rawPointLocations = pointsToProcess.map { $0.location }
        // Use extremely low tolerance for maximum smoothness
        var simplifiedPoints: [CGPoint] = DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: rawPointLocations, tolerance: previewTolerance * 0.01)

        // Ensure many points for smooth curves
        if simplifiedPoints.count < 30 && rawPointLocations.count > 2 {
            simplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: rawPointLocations, tolerance: previewTolerance * 0.001)
            if simplifiedPoints.count < 30 {
                // Sample densely from raw points
                let stepSize = max(1, rawPointLocations.count / 50)  // Keep up to 50 points
                simplifiedPoints = []
                for i in Swift.stride(from: 0, to: rawPointLocations.count, by: stepSize) {
                    simplifiedPoints.append(rawPointLocations[i])
                }
                if let last = rawPointLocations.last, simplifiedPoints.last != last {
                    simplifiedPoints.append(last)
                }
            }
        }

        if simplifiedPoints.count >= 2 {
            return generatePreviewVariableWidthPath(
                centerPoints: simplifiedPoints,
                recentRawPoints: pointsToProcess,
                thickness: thickness,
                pressureSensitivity: pressureSensitivity,
                taper: taper
            )
        } else {
            return VectorPath(elements: [.move(to: VectorPoint(pointsToProcess[0].location))])
        }
    }
    
    // MARK: - Brush Stroke Processing
    
    private func processBrushStroke() {
        guard brushRawPoints.count >= 2,  // Allow 2 points for straight lines
              activeBrushShape != nil,
              document.selectedLayerIndex != nil else {
            return
        }

        // SPECIAL CASE: For 4 points or less (straight lines that auto-close), skip - they're invalid
        if brushRawPoints.count <= 4 {
            return
        }

        // USE RAW POINTS DIRECTLY - NO SIMPLIFICATION OR SMOOTHING
        // Accept the curve exactly as drawn by the user
        brushSimplifiedPoints = brushRawPoints.map { $0.location }

        // Step 3: Generate variable width brush stroke path using the SIMPLIFIED POINTS with pressure data
        // The smoothness comes from the final bezier path creation, not from over-sampling
        let brushStrokePath = generateSmoothVariableWidthPath(
            centerPoints: brushSimplifiedPoints,  // Use the clean simplified points!
            rawPoints: brushRawPoints,  // Pass raw points with pressure data
            thickness: document.currentBrushThickness,  // Use current tool settings
            pressureSensitivity: 0.5,  // Fixed sensitivity
            taper: 0.5  // Fixed taper
        )

        // Step 3: Create and add the final brush stroke to the document
        var finalShape = VectorShape(
            name: "Brush Stroke",
            path: brushStrokePath,
            strokeStyle: document.brushApplyNoStroke ? nil : StrokeStyle(
                color: getCurrentStrokeColor(),
                width: getCurrentStrokeWidth(),
                opacity: getCurrentStrokeOpacity()
            ),
            fillStyle: FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
        )
        
        // Apply overlap removal inline before adding to document
        if document.brushRemoveOverlap {
            let cg = finalShape.path.cgPath
            var cleaned: CGPath? = nil
            // Try normalization (winding)
            cleaned = CoreGraphicsPathOperations.normalized(cg, using: .winding)
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.normalized(cg, using: .evenOdd) }
            // Fall back to self-union if normalization yields nil
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .winding) }
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .evenOdd) }
            if let cleanedPath = cleaned, !cleanedPath.isEmpty, isPathBoundsFinite(cleanedPath.boundingBox) {
                finalShape.path = VectorPath(cgPath: cleanedPath)
            }
        }
        
        // VECTOR APP OPTIMIZATION: Add shape only once at the end, not during drawing
        document.addShapeToFront(finalShape)
        
    }

    // MARK: - Finalize From Preview (with point reduction)
    private func finalizeFromPreview(_ preview: VectorPath) {
        guard document.selectedLayerIndex != nil else { return }

        // DEDUPLICATION ON FINAL: Remove duplicate/near-duplicate points from raw points
        // Use the smoothness slider value as the deduplication threshold (0.5-10 pixels)
        var dedupedPoints: [BrushPoint] = []
        let dupThreshold = document.currentBrushSmoothingTolerance

        for point in brushRawPoints {
            if let lastPoint = dedupedPoints.last {
                let distance = hypot(point.location.x - lastPoint.location.x,
                                   point.location.y - lastPoint.location.y)
                if distance < dupThreshold {
                    continue // Skip duplicate points
                }
            }
            dedupedPoints.append(point)
        }

        // Regenerate path with deduplicated points for final stroke
        let dedupedLocations = dedupedPoints.map { $0.location }
        var finalPath: VectorPath

        if dedupedLocations.count >= 2 {
            finalPath = generatePreviewVariableWidthPath(
                centerPoints: dedupedLocations,
                recentRawPoints: dedupedPoints,
                thickness: document.currentBrushThickness,
                pressureSensitivity: 0.5,
                taper: 0.5
            )
        } else {
            finalPath = preview
        }

        let strokeStyle: StrokeStyle? = document.brushApplyNoStroke ? nil : StrokeStyle(
            color: getCurrentStrokeColor(),
            width: getCurrentStrokeWidth(),
            lineCap: document.defaultStrokeLineCap,
            lineJoin: document.defaultStrokeLineJoin,
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: getCurrentStrokeOpacity()
        )
        let fillStyle = FillStyle(color: getCurrentFillColor(), opacity: getCurrentFillOpacity())

        // CRITICAL: Brush has NO STROKE - only fill. Use WINDING rule to prevent reversed holes.
        if document.brushRemoveOverlap {
            let currentPath = finalPath.cgPath

            // Use WINDING fill rule to prevent even-odd reversed holes on self-overlap
            var cleaned: CGPath? = nil
            cleaned = CoreGraphicsPathOperations.union(currentPath, currentPath, using: .winding)
            if cleaned == nil {
                cleaned = CoreGraphicsPathOperations.normalized(currentPath, using: .winding)
            }

            if let cleanedPath = cleaned, !cleanedPath.isEmpty, isPathBoundsFinite(cleanedPath.boundingBox) {
                finalPath = VectorPath(cgPath: cleanedPath, fillRule: .winding)
            }
        }
        let shape = VectorShape(name: "Brush Stroke", path: finalPath, strokeStyle: strokeStyle, fillStyle: fillStyle)
        document.addShape(shape)
    }
    
    // MARK: - Remove Overlap Functionality
    
    /// Apply self-union operation to remove overlapping areas within the single brush stroke
    private func applySelfUnionToBrushStroke(shapeIndex: Int, layerIndex: Int) {
        
        let shapes = document.getShapesForLayer(layerIndex)
        guard shapeIndex < shapes.count else { 
            return 
        }
        
        guard let brushStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            return
        }
        
        // VERIFY: Make sure we're operating on the correct shape
        guard brushStroke.id == activeBrushShape?.id else {
            return
        }
        

        
        // Convert VectorPath to CGPath for boolean operations
        let originalPath = brushStroke.path.cgPath
        
        // SAFETY CHECK: Ensure path is valid before union operation
        guard !originalPath.isEmpty else {
            return
        }
        
        // SAFETY CHECK: Verify path has valid bounds
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            return
        }
        
        // Normalize the path to remove any self-intersections within the brush stroke
        // Using normalization is the correct way to resolve overlaps for a single path
        if let cleanedPath = CoreGraphicsPathOperations.normalized(originalPath) {
            // SAFETY CHECK: Verify the result path is valid
            guard !cleanedPath.isEmpty && isPathBoundsFinite(cleanedPath.boundingBox) else {
                return
            }
            
            let cleanedVectorPath = VectorPath(cgPath: cleanedPath)
            
            // Update the brush stroke with the cleaned path
            var updatedShape = brushStroke
            updatedShape.path = cleanedVectorPath
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // CRITICAL FIX: Sync unified objects system to ensure the updated shape is rendered
            document.updateUnifiedObjectsOptimized()
        } else {

        }
    }

    
    // MARK: - Live Preview Variable Width Path Generation
    
    /// Generate variable width path for live preview with proper pressure mapping
    private func generatePreviewVariableWidthPath(centerPoints: [CGPoint], recentRawPoints: [BrushPoint], thickness: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point
            return VectorPath(elements: [.move(to: VectorPoint(centerPoints[0]))])
        }

        // Calculate variable thickness at each simplified point with proper pressure mapping
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []

        // ALWAYS ensure strong tapering for leaf shape
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)

            // Base thickness from brush settings (like marker tool)
            var finalThickness = thickness

            // PROPER PRESSURE MAPPING: Find the closest raw point for pressure data
            var mappedPressure = 1.0
            if !recentRawPoints.isEmpty {
                var closestDistance = Double.infinity
                var closestPressure = 1.0

                for rawPoint in recentRawPoints {
                    let distance = sqrt(pow(point.x - rawPoint.location.x, 2) + pow(point.y - rawPoint.location.y, 2))
                    if distance < closestDistance {
                        closestDistance = distance
                        closestPressure = rawPoint.pressure
                    }
                }

                // Apply pressure curve mapping like marker tool
                let curve = appState.pressureCurve

                mappedPressure = getThicknessFromPressureCurve(pressure: closestPressure, curve: curve)

                // DEBUG: Log pressure mapping for first few points
                if index < 5 {
                    print("🟡 PRESSURE MAP [\(index)]: raw=\(String(format: "%.2f", closestPressure)) -> mapped=\(String(format: "%.2f", mappedPressure))")
                }
            }

            // Apply taper to ends - BLEND with pressure for smoother transitions
            let taperZone = 0.15 // Taper over first/last 15% of stroke
            var taperMultiplier = 1.0

            if progress < taperZone {
                // Start taper: use smoother curve that blends with pressure
                let t = progress / taperZone
                taperMultiplier = pow(t, 1.5) // Gentler curve for better blending
            } else if progress > (1.0 - taperZone) {
                // End taper: use smoother curve that blends with pressure
                let t = (1.0 - progress) / taperZone
                taperMultiplier = pow(t, 1.5) // Gentler curve for better blending
            }

            // Blend taper and pressure together for smooth transitions
            finalThickness *= (taperMultiplier * mappedPressure)

            // Ensure minimum thickness AFTER all multipliers (taper + pressure)
            let minThickness = document.currentBrushMinTaperThickness
            if finalThickness > 0 {
                finalThickness = max(finalThickness, minThickness)
            }

            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        
        // Generate left and right edge points with variable thickness
        let leftEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        
        // Create smooth bezier curves for BOTH edges (like freehand tool!)
        let leftEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: leftEdgePoints)
        let rightEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: rightEdgePoints.reversed()) // Reverse for proper winding
        
        // Combine into a filled shape with smooth bezier curves
        return createSmoothBrushOutline(leftEdgePath: leftEdgePath, rightEdgePath: rightEdgePath)
    }
    
    // MARK: - Pressure Interpolation
    
    /// Interpolates pressure value for a simplified point based on nearby raw points
    private func interpolatePressureForPoint(_ targetPoint: CGPoint, from rawPoints: [BrushPoint]) -> Double {
        guard !rawPoints.isEmpty else { return 1.0 }
        
        // For better interpolation, find the two closest points and interpolate between them
        var firstClosest: (distance: Double, pressure: Double) = (Double.infinity, 1.0)
        var secondClosest: (distance: Double, pressure: Double) = (Double.infinity, 1.0)
        
        for rawPoint in rawPoints {
            let distance = hypot(
                targetPoint.x - rawPoint.location.x,
                targetPoint.y - rawPoint.location.y
            )
            
            if distance < firstClosest.distance {
                // New closest point, move current closest to second
                secondClosest = firstClosest
                firstClosest = (distance, rawPoint.pressure)
            } else if distance < secondClosest.distance {
                // New second closest point
                secondClosest = (distance, rawPoint.pressure)
            }
        }
        
        // If we have two close points, interpolate between them
        if secondClosest.distance != Double.infinity && firstClosest.distance > 0 {
            let totalDistance = firstClosest.distance + secondClosest.distance
            if totalDistance > 0 {
                let weight1 = secondClosest.distance / totalDistance
                let weight2 = firstClosest.distance / totalDistance
                
                return weight1 * firstClosest.pressure + weight2 * secondClosest.pressure
            }
        }
        
        // Otherwise, just use the closest point
        return firstClosest.pressure
    }
    
    // MARK: - Straight Line Detection

    private func detectStraightLine(points: [CGPoint]) -> Bool {
        guard points.count >= 2 else { return false }

        // Calculate the direct line from start to end
        guard let start = points.first, let end = points.last else {
            return false
        }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lineLength = sqrt(dx * dx + dy * dy)

        // Check if very short line (likely straight)
        if lineLength < 50 { return true }

        // Check deviation of all points from the straight line
        var maxDeviation: Double = 0
        for point in points {
            // Calculate perpendicular distance to line
            let deviation = abs((dy * point.x - dx * point.y + end.x * start.y - end.y * start.x) / lineLength)
            maxDeviation = max(maxDeviation, deviation)
        }

        // If max deviation is less than 5% of line length, it's straight
        return maxDeviation < lineLength * 0.05
    }

    // MARK: - Smooth Variable Width Path Generation (SAME APPROACH AS FREEHAND!)

    private func generateSmoothVariableWidthPath(centerPoints: [CGPoint], rawPoints: [BrushPoint], thickness: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point
            return VectorPath(elements: [.move(to: VectorPoint(rawPoints[0].location))])
        }

        // Calculate variable thickness at each simplified point with proper pressure interpolation
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []

        // ALWAYS ensure strong tapering for leaf shape
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)

            // Base thickness from brush settings (like marker tool)
            var finalThickness = thickness

            // Interpolate pressure from raw points to simplified points
            let interpolatedPressure = interpolatePressureForPoint(point, from: rawPoints)

            // Apply pressure curve mapping like marker tool
            let curve = appState.pressureCurve

            let mappedPressure = getThicknessFromPressureCurve(pressure: interpolatedPressure, curve: curve)

            // Apply taper to ends - BLEND with pressure for smoother transitions
            let taperZone = 0.15 // Taper over first/last 15% of stroke
            var taperMultiplier = 1.0

            if progress < taperZone {
                // Start taper: use smoother curve that blends with pressure
                let t = progress / taperZone
                taperMultiplier = pow(t, 1.5) // Gentler curve for better blending
            } else if progress > (1.0 - taperZone) {
                // End taper: use smoother curve that blends with pressure
                let t = (1.0 - progress) / taperZone
                taperMultiplier = pow(t, 1.5) // Gentler curve for better blending
            }

            // Blend taper and pressure together for smooth transitions
            finalThickness *= (taperMultiplier * mappedPressure)

            // Ensure minimum thickness AFTER all multipliers (taper + pressure)
            let minThickness = document.currentBrushMinTaperThickness
            if finalThickness > 0 {
                finalThickness = max(finalThickness, minThickness)
            }

            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        
        // Generate left and right edge points with variable thickness
        let leftEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        
        // Create smooth bezier curves for BOTH edges (like freehand tool!)
        let leftEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: leftEdgePoints)
        let rightEdgePath = DrawingCanvasPathHelpers.createSmoothBezierPath(from: rightEdgePoints.reversed()) // Reverse for proper winding
        
        // Combine into a filled shape with smooth bezier curves
        return createSmoothBrushOutline(leftEdgePath: leftEdgePath, rightEdgePath: rightEdgePath)
    }
    
    private func generateOffsetPoints(centerPoints: [(location: CGPoint, thickness: Double)], isLeftSide: Bool) -> [CGPoint] {
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
                // Use average of incoming and outgoing directions
                let prevPoint = centerPoints[i - 1].location
                let nextPoint = centerPoints[i + 1].location
                
                let incomingDir = CGPoint(x: point.location.x - prevPoint.x, y: point.location.y - prevPoint.y)
                let outgoingDir = CGPoint(x: nextPoint.x - point.location.x, y: nextPoint.y - point.location.y)
                
                let avgDirection = CGPoint(
                    x: (incomingDir.x + outgoingDir.x) / 2,
                    y: (incomingDir.y + outgoingDir.y) / 2
                )
                
                perpendicular = CGPoint(x: -avgDirection.y, y: avgDirection.x)
            }
            
            // Normalize perpendicular vector
            let length = sqrt(perpendicular.x * perpendicular.x + perpendicular.y * perpendicular.y)
            if length > 0 {
                perpendicular.x /= length
                perpendicular.y /= length
            }
            
            // Apply offset distance (half thickness) in appropriate direction
            let offsetDistance = thickness / 2.0
            let multiplier = isLeftSide ? 1.0 : -1.0
            
            let offsetPoint = CGPoint(
                x: point.location.x + perpendicular.x * offsetDistance * multiplier,
                y: point.location.y + perpendicular.y * offsetDistance * multiplier
            )
            
            offsetPoints.append(offsetPoint)
        }
        
        return offsetPoints
    }
    
    private func createBrushStrokeOutline(leftEdge: [CGPoint], rightEdge: [CGPoint]) -> VectorPath {
        var elements: [PathElement] = []
        
        guard !leftEdge.isEmpty && !rightEdge.isEmpty else {
            return VectorPath(elements: elements)
        }
        
        // Start at first point of left edge
        elements.append(.move(to: VectorPoint(leftEdge[0])))
        
        // Draw along left edge
        for i in 1..<leftEdge.count {
            elements.append(.line(to: VectorPoint(leftEdge[i])))
        }
        
        // Connect to right edge at the end
        if let lastRightEdge = rightEdge.last {
            elements.append(.line(to: VectorPoint(lastRightEdge)))
        }
        
        // Draw back along right edge (in reverse)
        for i in stride(from: rightEdge.count - 2, through: 0, by: -1) {
            elements.append(.line(to: VectorPoint(rightEdge[i])))
        }
        
        // Close the path
        elements.append(.close)
        
        return VectorPath(elements: elements)
    }
    
    /// Combine two smooth bezier edge paths into a closed brush stroke outline
    private func createSmoothBrushOutline(leftEdgePath: VectorPath, rightEdgePath: VectorPath) -> VectorPath {
        var elements: [PathElement] = []
        
        // Start with the left edge path (this gives us smooth bezier curves!)
        elements.append(contentsOf: leftEdgePath.elements)
        
        // Connect to the right edge at the end
        if let lastLeftPoint = leftEdgePath.elements.last {
            switch lastLeftPoint {
            case .move(_), .line(_), .curve(_, _, _), .quadCurve(_, _):
                // Connect to start of right edge path
                if let firstRightElement = rightEdgePath.elements.first {
                    switch firstRightElement {
                    case .move(let rightPoint), .line(let rightPoint), .curve(let rightPoint, _, _), .quadCurve(let rightPoint, _):
                        elements.append(.line(to: rightPoint))
                    case .close:
                        break
                    }
                }
            case .close:
                break
            }
        }
        
        // Add the right edge path elements (already reversed, so this traces back)
        // Skip the first move element since we already connected
        let rightElements = rightEdgePath.elements.dropFirst()
        elements.append(contentsOf: rightElements)
        
        // Close the path to complete the brush stroke
        elements.append(.close)
        
        return VectorPath(elements: elements)
    }
    
    // MARK: - Path Simplification and Bezier Fitting
    // These functions have been moved to DrawingCanvasPathHelpers
    

}

