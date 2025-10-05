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
        
        // VECTOR APP OPTIMIZATION: Don't add to document during drawing - use overlay system
        // Shape will be added only when drawing is complete
        
        // Logging disabled in hot path to reduce CPU overhead
    }
    
    internal func handleBrushDragUpdate(at location: CGPoint) {
        guard isBrushDrawing else { return }

        // Only use pressure when BOTH enabled AND real pressure device detected
        let pressure: Double
        if appState.pressureSensitivityEnabled && PressureManager.shared.hasRealPressureInput {
            pressure = PressureManager.shared.getPressure(for: location, sensitivity: 0.5)
        } else {
            pressure = 1.0  // Constant pressure for mouse/trackpad
        }

        // Add point to raw path with pressure data
        let newPoint = BrushPoint(location: location, pressure: pressure)
        brushRawPoints.append(newPoint)
        
        // Update preview with new point
        updateBrushPreview()
    }
    

    
    internal func handleBrushDragEnd() {
        guard isBrushDrawing else { return }

        // Log the point count at drag end
        Log.info("🖌️ BRUSH DRAG END: \(brushRawPoints.count) points captured", category: .general)

        // For straight lines (only 2 points), add intermediate points to ensure proper leaf shape generation
        if brushRawPoints.count == 2 {
            Log.info("🖌️ BRUSH DRAG END: Interpolating 2-point line in handleBrushDragEnd", category: .general)
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
            Log.info("⚠️ BRUSH: No preview path, generating final path", category: .general)
            processBrushStroke()
        }
        
        // Clean up state including clearing preview path for overlay system
        brushPreviewPath = nil
        cancelBrushDrawing()
        
        // AUTO-DESELECT: Clear selection after completing brush stroke
        // This allows user to immediately change colors for the next stroke
        document.selectedShapeIDs.removeAll()
        // Logging disabled in hot path to reduce CPU overhead
        
        Log.info("✅ BRUSH: Stroke completed and converted to variable width path", category: .fileOperations)
    }
    
    // MARK: - Pressure Simulation
    
    private func calculateSimulatedPressure(at location: CGPoint) -> Double {
        // If pressure sensitivity is disabled, return constant pressure
        if !appState.pressureSensitivityEnabled {
            return 1.0
        }
        
        guard brushRawPoints.count > 1,
              let lastPointData = brushRawPoints.last else { return 1.0 }

        let lastPoint = lastPointData.location
        let distance = sqrt(pow(location.x - lastPoint.x, 2) + pow(location.y - lastPoint.y, 2))
        
        // Simulate pressure based on drawing speed
        // Fast drawing = light pressure, slow drawing = heavy pressure
        let maxSpeed: Double = 100.0 // Maximum pixels per measurement
        let normalizedSpeed = min(distance / maxSpeed, 1.0)
        let basePressure = 1.0 - (normalizedSpeed * 0.5) // Reduce pressure with speed
        
        // Apply fixed sensitivity for old code
        let sensitivity = 0.5
        let pressureVariation = (basePressure - 0.5) * sensitivity
        
        let finalPressure = max(0.1, min(1.0, 0.5 + pressureVariation))
        
        // Print pressure value during drawing
        // Logging disabled in hot path to reduce CPU overhead
        
        return finalPressure
    }
    
    // MARK: - Real-time Preview
    
    private func updateBrushPreview() {
        // VECTOR APP OPTIMIZATION: Direct overlay update - no throttling for 60fps
        guard brushRawPoints.count >= 2 else { return }
        
        // Generate preview path for overlay rendering - SwiftUI will handle 60fps updates
        let previewPath = generateLivePreviewPath()
        brushPreviewPath = previewPath
        
        // No document updates during drawing - overlay handles all preview rendering
    }
    
    /// Generate live preview path for overlay rendering
    private func generateLivePreviewPath() -> VectorPath {
        guard brushRawPoints.count >= 2 else {
            return VectorPath(elements: [.move(to: VectorPoint(brushRawPoints[0].location))])
        }

        // For very short strokes (2 points), add interpolation for smoother shape
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

                // Vary pressure for more natural tapering
                // Create a subtle "bulge" in the middle
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

        let simplifiedPoints: [CGPoint]

        // Only simplify if NOT using pressure device
        if appState.pressureSensitivityEnabled && PressureManager.shared.hasRealPressureInput {
            // PRESSURE DEVICE: Use all raw points, no simplification
            simplifiedPoints = rawPointLocations
        } else {
            // MOUSE/TRACKPAD: Apply liquid smoothing
            let liquidValue = document.currentBrushLiquid

            if abs(liquidValue - 50.0) < 0.01 {
                simplifiedPoints = rawPointLocations
            } else if liquidValue < 50.0 {
                let smoothFactor = (50.0 - liquidValue) / 50.0
                let tolerance = 0.5 + (2.0 * smoothFactor)
                simplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(
                    points: rawPointLocations,
                    tolerance: tolerance
                )
            } else {
                let smoothFactor = (liquidValue - 50.0) / 50.0
                let tolerance = 2.5 + (7.5 * smoothFactor)
                simplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(
                    points: rawPointLocations,
                    tolerance: tolerance
                )
            }

           // Log.info("🖌️ PREVIEW: Simplified from \(pointsToProcess.count) to \(simplifiedPoints.count) points", category: .general)
        }

        if simplifiedPoints.count >= 2 {
            return generatePreviewVariableWidthPath(
                centerPoints: (appState.pressureSensitivityEnabled && PressureManager.shared.hasRealPressureInput) ? rawPointLocations : simplifiedPoints,
                recentRawPoints: pointsToProcess,
                thickness: document.currentBrushThickness,
                pressureSensitivity: 0.5,
                taper: 0.5
            )
        } else {
            return VectorPath(elements: [.move(to: VectorPoint(pointsToProcess[0].location))])
        }
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
              let _ = activeBrushShape,
              let _ = document.selectedLayerIndex else {
            Log.info("🖌️ BRUSH: Too few points (\(brushRawPoints.count)) - keeping as simple shape", category: .general)
            return
        }
        
        let rawPointLocations = brushRawPoints.map { $0.location }
        // Logging disabled in hot path to reduce CPU overhead
        
        var processedPoints = rawPointLocations
        
        // Step 1: Apply Chaikin smoothing for initial curve smoothing (if enabled)
        if document.advancedSmoothingEnabled {
            // Prefer GPU Chaikin for large strokes; fall back to CPU
            if processedPoints.count >= 200 {
                let metalEngine = MetalComputeEngine.shared
                let gpuResult = metalEngine.chaikinSmoothingGPU(points: processedPoints, ratio: 0.25)
                switch gpuResult {
                case .success(let pts):
                    processedPoints = pts
                case .failure(_):
                    let chaikinSmoothed = CurveSmoothing.chaikinSmooth(
                        points: processedPoints,
                        iterations: document.chaikinSmoothingIterations,
                        ratio: 0.25
                    )
                    processedPoints = chaikinSmoothed
                }
            } else {
                let chaikinSmoothed = CurveSmoothing.chaikinSmooth(
                    points: processedPoints,
                    iterations: document.chaikinSmoothingIterations,
                    ratio: 0.25
                )
                processedPoints = chaikinSmoothed
            }
        }
        
        // Step 2: Apply improved Douglas-Peucker simplification with sharp corner preservation
        // Use extremely low tolerance to preserve almost all points for maximum smoothness
        let smoothingTolerance = document.currentBrushSmoothingTolerance * 0.01  // Keep 99% of points
        if processedPoints.count >= 200 {
            // Try GPU DP first; then apply CPU corner-preserving refinement if desired
            let metalEngine = MetalComputeEngine.shared
            let result = metalEngine.douglasPeuckerGPU(processedPoints, tolerance: Float(smoothingTolerance))
            switch result {
            case .success(let pts):
                if document.advancedSmoothingEnabled {
                    brushSimplifiedPoints = CurveSmoothing.improvedDouglassPeucker(
                        points: pts,
                        tolerance: smoothingTolerance,
                        preserveSharpCorners: document.preserveSharpCorners
                    )
                } else {
                    brushSimplifiedPoints = pts
                }
            case .failure(_):
                brushSimplifiedPoints = document.advancedSmoothingEnabled ?
                    CurveSmoothing.improvedDouglassPeucker(
                        points: processedPoints,
                        tolerance: smoothingTolerance,
                        preserveSharpCorners: document.preserveSharpCorners
                    ) :
                    DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: processedPoints, tolerance: smoothingTolerance)
            }
        } else {
            brushSimplifiedPoints = document.advancedSmoothingEnabled ?
                CurveSmoothing.improvedDouglassPeucker(
                    points: processedPoints,
                    tolerance: smoothingTolerance,
                    preserveSharpCorners: document.preserveSharpCorners
                ) :
                DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: processedPoints, tolerance: smoothingTolerance)
        }
        
        // CRITICAL: Ensure we have enough points for smooth tapers (matching marker tool)
        // Need MORE points when pressure sensitivity is off since taper is the only variation
        let minPoints = appState.pressureSensitivityEnabled ? 8 : 20
        if brushSimplifiedPoints.count < minPoints && processedPoints.count > 2 {
            // Try again with minimal tolerance
            let minTolerance = smoothingTolerance * 0.001
            brushSimplifiedPoints = DrawingCanvasPathHelpers.douglasPeuckerSimplify(points: processedPoints, tolerance: minTolerance)

            // If still too few, sample from processed points
            if brushSimplifiedPoints.count < minPoints {
                let stepSize = max(1, processedPoints.count / (minPoints + 10))
                brushSimplifiedPoints = []
                for i in Swift.stride(from: 0, to: processedPoints.count, by: stepSize) {
                    brushSimplifiedPoints.append(processedPoints[i])
                }
                if let last = processedPoints.last, brushSimplifiedPoints.last != last {
                    brushSimplifiedPoints.append(last)
                }
            }
        }

        Log.info("🖌️ PROCESS: Final simplified points: \(brushSimplifiedPoints.count)", category: .general)

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
                Log.info("🖌️ BRUSH: Removed self-overlap (normalize/union)", category: .general)
            } else {
                Log.info("🖌️ BRUSH: Overlap removal produced no change; keeping original", category: .general)
            }
        }
        
        // VECTOR APP OPTIMIZATION: Add shape only once at the end, not during drawing
        document.addShapeToFront(finalShape)
        
        // Logging disabled in hot path to reduce CPU overhead
    }

    // MARK: - Finalize From Preview (no recompute)
    private func finalizeFromPreview(_ preview: VectorPath) {
        guard document.selectedLayerIndex != nil else { return }
        let strokeStyle: StrokeStyle? = document.brushApplyNoStroke ? nil : StrokeStyle(
            color: getCurrentStrokeColor(),
            width: getCurrentStrokeWidth(),
            lineCap: document.defaultStrokeLineCap,
            lineJoin: document.defaultStrokeLineJoin,
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: getCurrentStrokeOpacity()
        )
        let fillStyle = FillStyle(color: getCurrentFillColor(), opacity: getCurrentFillOpacity())
        var finalPath = preview
        if document.brushRemoveOverlap {
            let cg = preview.cgPath
            var cleaned: CGPath? = nil
            cleaned = CoreGraphicsPathOperations.normalized(cg, using: .winding)
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.normalized(cg, using: .evenOdd) }
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .winding) }
            if cleaned == nil { cleaned = CoreGraphicsPathOperations.union(cg, cg, using: .evenOdd) }
            if let cleanedPath = cleaned, !cleanedPath.isEmpty, isPathBoundsFinite(cleanedPath.boundingBox) {
                finalPath = VectorPath(cgPath: cleanedPath)
                Log.info("🖌️ BRUSH: Removed self-overlap for preview bake", category: .general)
            } else {
                Log.info("🖌️ BRUSH: Overlap removal (preview bake) produced no change", category: .general)
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
            Log.fileOperation("🚨 BRUSH ERROR: Shape index \(shapeIndex) out of bounds! Layer has \(shapes.count) shapes", level: .info)
            return 
        }
        
        guard let brushStroke = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else {
            Log.fileOperation("🚨 BRUSH ERROR: Could not get shape at index \(shapeIndex)", level: .info)
            return
        }
        
        // VERIFY: Make sure we're operating on the correct shape
        guard brushStroke.id == activeBrushShape?.id else {
            Log.fileOperation("🚨 BRUSH ERROR: Shape ID mismatch! Expected \(activeBrushShape?.id ?? UUID()), got \(brushStroke.id)", level: .info)
            Log.fileOperation("🚨 BRUSH ERROR: This would affect the WRONG shape - ABORTING self-union", level: .info)
            return
        }
        

        
        // Convert VectorPath to CGPath for boolean operations
        let originalPath = brushStroke.path.cgPath
        
        // SAFETY CHECK: Ensure path is valid before union operation
        guard !originalPath.isEmpty else {
            Log.fileOperation("🚨 BRUSH ERROR: Original path is empty - ABORTING self-union", level: .info)
            return
        }
        
        // SAFETY CHECK: Verify path has valid bounds
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            Log.fileOperation("🚨 BRUSH ERROR: Path has invalid bounds - ABORTING self-union", level: .info)
            return
        }
        
        // Normalize the path to remove any self-intersections within the brush stroke
        // Using normalization is the correct way to resolve overlaps for a single path
        if let cleanedPath = CoreGraphicsPathOperations.normalized(originalPath) {
            // SAFETY CHECK: Verify the result path is valid
            guard !cleanedPath.isEmpty && isPathBoundsFinite(cleanedPath.boundingBox) else {
                Log.fileOperation("🚨 BRUSH ERROR: Union operation produced invalid path - keeping original", level: .info)
                return
            }
            
            let cleanedVectorPath = VectorPath(cgPath: cleanedPath)
            
            // Update the brush stroke with the cleaned path
            var updatedShape = brushStroke
            updatedShape.path = cleanedVectorPath
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            
            // CRITICAL FIX: Sync unified objects system to ensure the updated shape is rendered
            document.updateUnifiedObjectsOptimized()
            
            Log.info("🖌️ BRUSH: Applied self-union to remove overlapping areas within brush stroke", category: .general)
        } else {
            Log.info("🖌️ BRUSH: Self-union operation failed, keeping original path", category: .general)

        }
    }

    
    // MARK: - Live Preview Variable Width Path Generation
    
    /// Generate variable width path for live preview with proper pressure mapping
    private func generatePreviewVariableWidthPath(centerPoints: [CGPoint], recentRawPoints: [BrushPoint], thickness: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point
            return VectorPath(elements: [.move(to: VectorPoint(centerPoints[0]))])
        }

        // DETECT STRAIGHT LINES for special leaf shape treatment
        let isStraightLine = detectStraightLine(points: centerPoints)

        // Calculate variable thickness at each simplified point with proper pressure mapping
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []

        // ALWAYS ensure strong tapering for leaf shape
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)

            // Create leaf shape with smooth tapering
            var finalThickness = thickness

            // ENHANCED LEAF SHAPE - Better end tapering for proper leaf form
            // Creates characteristic leaf bulge at both start and end

            // Create leaf shape with asymmetric tapering for better end shape
            let distanceFromCenter = abs(progress - 0.5) * 2.0 // 0 at center, 1 at ends

            // Use sine-based curve for the main shape (smooth and natural)
            let sineShape = sin((1.0 - distanceFromCenter) * .pi * 0.5) // Half sine wave

            // Add subtle power curve to enhance the leaf bulge
            let powerShape = 1.0 - pow(distanceFromCenter, 2.0) // Quadratic for gentler curve

            // Blend for best of both - more sine for smoothness, some power for bulge
            let leafShape = sineShape * 0.7 + powerShape * 0.3

            // Apply thickness with good base scaling
            finalThickness = thickness * leafShape

            // SPECIAL TREATMENT FOR STRAIGHT LINES - Aggressive taper at end to avoid phallic shape
            if isStraightLine {
                // For straight lines, AGGRESSIVE TAPER at end - no bulge whatsoever
                if progress < 0.1 {
                    // Start: Quick taper from point
                    finalThickness *= pow(progress / 0.1, 2.0)
                } else if progress > 0.5 {
                    // END: Much more aggressive taper starting earlier
                    let endProgress = (progress - 0.5) / 0.5
                    // Use power of 3 for very aggressive thinning
                    // This creates a sharp point with no bulge
                    finalThickness *= pow(1.0 - endProgress, 3.0)
                }
            } else {
                // Normal curved strokes - Simple taper without bulges (like marker tool)
                if progress < 0.03 {
                    // START: Cut off very thin tails at beginning
                    finalThickness = 0  // Completely remove narrow tail
                } else if progress < 0.08 {
                    // Quick taper from zero
                    let startTaper = pow((progress - 0.03) / 0.05, 2.0)
                    finalThickness *= startTaper
                } else if progress > 0.88 && progress < 0.97 {
                    // Quick taper to zero
                    let endProgress = (progress - 0.88) / 0.09
                    let endTaper = 1.0 - pow(endProgress, 1.5)
                    finalThickness *= endTaper
                } else if progress >= 0.97 {
                    // END: Cut off very thin tails at end
                    finalThickness = 0  // Completely remove narrow tail
                }
            }

            // Ensure minimum thickness to avoid zero (unless explicitly set to 0 for tail removal)
            if finalThickness > 0 {
                finalThickness = max(finalThickness, 0.5)
            }
            
            // PROPER PRESSURE MAPPING: Find the closest raw point for pressure data
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

                // LOG CURVE DATA
                if index == 0 {
                    let curveStr = curve.map { "(\(String(format: "%.2f", $0.x)),\(String(format: "%.2f", $0.y)))" }.joined(separator: " ")
                    Log.info("📊 BRUSH CURVE: [\(curveStr)]", category: .pressure)
                }

                let mappedPressure = getThicknessFromPressureCurve(pressure: closestPressure, curve: curve)

                // LOG PRESSURE VALUES
                if index % 5 == 0 {  // Log every 5th point to reduce spam
                    Log.info("📊 BRUSH PRESSURE: raw=\(String(format: "%.3f", closestPressure)) → mapped=\(String(format: "%.3f", mappedPressure)) | thickness before=\(String(format: "%.2f", finalThickness)) after=\(String(format: "%.2f", finalThickness * mappedPressure))", category: .pressure)
                }

                finalThickness *= mappedPressure
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

        // Detect if this is a straight line
        let isStraightLine = detectStraightLine(points: centerPoints)

        // Calculate variable thickness at each simplified point with proper pressure interpolation
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []

        // ALWAYS ensure strong tapering for leaf shape
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)

            // ENHANCED LEAF SHAPE - matching preview generation
            var finalThickness = thickness

            // Consistent with preview generation
            let distanceFromCenter = abs(progress - 0.5) * 2.0
            let sineShape = sin((1.0 - distanceFromCenter) * .pi * 0.5)
            let powerShape = 1.0 - pow(distanceFromCenter, 2.0)
            let leafShape = sineShape * 0.7 + powerShape * 0.3
            finalThickness = thickness * leafShape

            // Special treatment for straight lines - aggressive taper to very thin end
            if isStraightLine {
                if progress < 0.1 {
                    finalThickness *= pow(progress / 0.1, 2.0)
                } else if progress > 0.5 {
                    let endProgress = (progress - 0.5) / 0.5
                    // Power of 3 for aggressive thinning
                    finalThickness *= pow(1.0 - endProgress, 3.0)
                }
            } else {
                // Simple taper for curved strokes without bulges
                if progress < 0.03 {
                    // START: Cut off very thin tails at beginning
                    finalThickness = 0  // Completely remove narrow tail
                } else if progress < 0.08 {
                    // Quick taper from zero
                    let startTaper = pow((progress - 0.03) / 0.05, 2.0)
                    finalThickness *= startTaper
                } else if progress > 0.88 && progress < 0.97 {
                    // Quick taper to zero
                    let endProgress = (progress - 0.88) / 0.09
                    let endTaper = 1.0 - pow(endProgress, 1.5)
                    finalThickness *= endTaper
                } else if progress >= 0.97 {
                    // END: Cut off very thin tails at end
                    finalThickness = 0  // Completely remove narrow tail
                }
            }

            // Ensure minimum thickness (unless explicitly set to 0 for tail removal)
            if finalThickness > 0 {
                finalThickness = max(finalThickness, 0.5)
            }
            
            // Interpolate pressure from raw points to simplified points
            let interpolatedPressure = interpolatePressureForPoint(point, from: rawPoints)

            // Apply pressure curve mapping like marker tool
            let curve = appState.pressureCurve

            // LOG CURVE DATA
            if index == 0 {
                let curveStr = curve.map { "(\(String(format: "%.2f", $0.x)),\(String(format: "%.2f", $0.y)))" }.joined(separator: " ")
                Log.info("📊 BRUSH SMOOTH CURVE: [\(curveStr)]", category: .pressure)
            }

            let mappedPressure = getThicknessFromPressureCurve(pressure: interpolatedPressure, curve: curve)

            // LOG PRESSURE VALUES
            if index % 5 == 0 {  // Log every 5th point to reduce spam
                Log.info("📊 BRUSH SMOOTH PRESSURE: raw=\(String(format: "%.3f", interpolatedPressure)) → mapped=\(String(format: "%.3f", mappedPressure)) | thickness before=\(String(format: "%.2f", finalThickness)) after=\(String(format: "%.2f", finalThickness * mappedPressure))", category: .pressure)
            }

            finalThickness *= mappedPressure
            
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

