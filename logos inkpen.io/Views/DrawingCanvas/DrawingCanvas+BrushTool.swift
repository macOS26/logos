//
//  DrawingCanvas+BrushTool.swift
//  logos inkpen.io
//
//  Variable brush stroke tool with parallel path generation
//

import SwiftUI
import Foundation

extension DrawingCanvas {
    
    // MARK: - Helper Functions
    
    /// Check if a CGRect has finite values (no infinity or NaN)
    func isPathBoundsFinite(_ rect: CGRect) -> Bool {
        return rect.origin.x.isFinite && rect.origin.y.isFinite && 
               rect.size.width.isFinite && rect.size.height.isFinite
    }
    
    // MARK: - Current Color Helpers (Same as other tools)
    
    /// Get the current fill color that the user has set (same logic as StrokeFillPanel)
    private func getCurrentFillColor() -> VectorColor {
        // PRIORITY 1: If text objects are selected, use their fill color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillColor
        }
        
        // PRIORITY 2: If shapes are selected, use their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let fillColor = shape.fillStyle?.color {
            return fillColor
        }
        
        // PRIORITY 3: Use default color for new shapes
        return document.defaultFillColor
    }
    
    /// Get the current fill opacity that the user has set (same logic as StrokeFillPanel)
    private func getCurrentFillOpacity() -> Double {
        // PRIORITY 1: If text objects are selected, use their fill opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.fillOpacity
        }
        
        // PRIORITY 2: If shapes are selected, use their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.fillStyle?.opacity {
            return opacity
        }
        
        // PRIORITY 3: Use default opacity for new shapes
        return document.defaultFillOpacity
    }
    
    /// Get the current stroke color that the user has set (same logic as StrokeFillPanel)
    private func getCurrentStrokeColor() -> VectorColor {
        // PRIORITY 1: If text objects are selected, use their stroke color
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeColor
        }
        
        // PRIORITY 2: If shapes are selected, use their color
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let strokeColor = shape.strokeStyle?.color {
            return strokeColor
        }
        
        // PRIORITY 3: Use default color for new shapes
        return document.defaultStrokeColor
    }
    
    /// Get the current stroke opacity that the user has set (same logic as StrokeFillPanel)
    private func getCurrentStrokeOpacity() -> Double {
        // PRIORITY 1: If text objects are selected, use their stroke opacity
        if let firstSelectedTextID = document.selectedTextIDs.first,
           let textObject = document.textObjects.first(where: { $0.id == firstSelectedTextID }) {
            return textObject.typography.strokeOpacity
        }
        
        // PRIORITY 2: If shapes are selected, use their opacity
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let opacity = shape.strokeStyle?.opacity {
            return opacity
        }
        
        // PRIORITY 3: Use default opacity for new shapes
        return document.defaultStrokeOpacity
    }
    
    /// Get the current stroke width that the user has set (same logic as StrokeFillPanel)
    private func getCurrentStrokeWidth() -> Double {
        // If shapes are selected, use their stroke width
        if let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
           let width = shape.strokeStyle?.width {
            return width
        }
        
        // Use default width for new shapes
        return document.defaultStrokeWidth
    }
    
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
        brushRawPoints = [BrushPoint(location: location, pressure: 1.0, timestamp: Date())]
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
        
        // Add the preview shape to the document immediately
        document.addShape(activeBrushShape!)
        
        print("🖌️ BRUSH: Started drawing at \(location)")
    }
    
    internal func handleBrushDragUpdate(at location: CGPoint) {
        guard isBrushDrawing else { return }
        
        // Get pressure using smart detection (real or simulated)
        let pressure = PressureManager.shared.getPressure(for: location, sensitivity: document.currentBrushPressureSensitivity)
        
        // Add point to raw path with pressure data
        let brushPoint = BrushPoint(location: location, pressure: pressure, timestamp: Date())
        brushRawPoints.append(brushPoint)
        
        // Update real-time preview
        updateBrushPreview()
        
        // Limit raw points array to prevent memory issues
        if brushRawPoints.count > 1000 {
            // Keep last 800 points
            brushRawPoints = Array(brushRawPoints.suffix(800))
        }
    }
    

    
    internal func handleBrushDragEnd() {
        guard isBrushDrawing else { return }
        
        print("🖌️ BRUSH: Finishing drawing with \(brushRawPoints.count) raw points")
        
        // Process brush stroke to create variable width path
        processBrushStroke()
        
        // Clean up state
        cancelBrushDrawing()
        
        // AUTO-DESELECT: Clear selection after completing brush stroke
        // This allows user to immediately change colors for the next stroke
        document.selectedShapeIDs.removeAll()
        print("🎨 BRUSH: Auto-deselected shape to enable color changes for next stroke")
        
        print("✅ BRUSH: Stroke completed and converted to variable width path")
    }
    
    // MARK: - Pressure Simulation
    
    private func calculateSimulatedPressure(at location: CGPoint) -> Double {
        // If pressure sensitivity is disabled, return constant pressure
        if !appState.pressureSensitivityEnabled {
            return 1.0
        }
        
        guard brushRawPoints.count > 1 else { return 1.0 }
        
        let lastPoint = brushRawPoints.last!.location
        let distance = sqrt(pow(location.x - lastPoint.x, 2) + pow(location.y - lastPoint.y, 2))
        
        // Simulate pressure based on drawing speed
        // Fast drawing = light pressure, slow drawing = heavy pressure
        let maxSpeed: Double = 100.0 // Maximum pixels per measurement
        let normalizedSpeed = min(distance / maxSpeed, 1.0)
        let basePressure = 1.0 - (normalizedSpeed * 0.5) // Reduce pressure with speed
        
        // Apply current brush sensitivity setting
        let sensitivity = document.currentBrushPressureSensitivity
        let pressureVariation = (basePressure - 0.5) * sensitivity
        
        return max(0.1, min(1.0, 0.5 + pressureVariation))
    }
    
    // MARK: - Real-time Preview
    
    private func updateBrushPreview() {
        guard let activeBrushShape = activeBrushShape,
              brushRawPoints.count >= 2,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // LIVE PREVIEW: Generate actual variable width brush stroke in real-time!
        let previewPath = generateLivePreviewPath()
        
        // Find and update the shape in the document with the REAL brush stroke preview
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeBrushShape.id }) {
            document.layers[layerIndex].shapes[shapeIndex].path = previewPath
            
            // Update stroke and fill using current user settings and toggles
            document.layers[layerIndex].shapes[shapeIndex].strokeStyle = document.brushApplyNoStroke ? nil : StrokeStyle(
                color: getCurrentStrokeColor(),
                width: getCurrentStrokeWidth(),
                opacity: getCurrentStrokeOpacity()
            )
            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
        }
    }
    
    /// Generate live preview of the variable width brush stroke as the user draws
    private func generateLivePreviewPath() -> VectorPath {
        guard brushRawPoints.count >= 2 else {
            // Fallback for insufficient points
            return VectorPath(elements: [.move(to: VectorPoint(brushRawPoints[0].location))])
        }
        
        // FIXED: Show the COMPLETE stroke, not just recent points!
        let rawPointLocations = brushRawPoints.map { $0.location }
        
        // PERFORMANCE OPTIMIZATION: Use a slightly higher tolerance for live preview to maintain smooth performance
        let previewSmoothingTolerance = document.currentBrushSmoothingTolerance * 1.25 // Slightly less detailed for speed
        let simplifiedPoints = douglasPeuckerSimplify(
            points: rawPointLocations,
            tolerance: previewSmoothingTolerance
        )
        
        // Generate variable width preview with proper pressure mapping for the FULL stroke
        if simplifiedPoints.count >= 2 {
            return generatePreviewVariableWidthPath(
                centerPoints: simplifiedPoints,
                recentRawPoints: brushRawPoints, // Pass ALL raw points for complete pressure mapping
                thickness: document.currentBrushThickness,
                pressureSensitivity: document.currentBrushPressureSensitivity,
                taper: document.currentBrushTaper
            )
        } else {
            // Fallback for single point
            return VectorPath(elements: [.move(to: VectorPoint(brushRawPoints[0].location))])
        }
    }
    
    // MARK: - Brush Stroke Processing
    
    private func processBrushStroke() {
        guard brushRawPoints.count >= 3,  // FIXED: Require at least 3 points like freehand
              let activeBrushShape = activeBrushShape,
              let layerIndex = document.selectedLayerIndex else { 
            print("🖌️ BRUSH: Too few points (\(brushRawPoints.count)) - keeping as simple shape")
            return 
        }
        
        // Step 1: Simplify the raw points using Douglas-Peucker algorithm (same as freehand)
        let smoothingTolerance = document.currentBrushSmoothingTolerance  // Use brush-specific smoothing tolerance
        brushSimplifiedPoints = douglasPeuckerSimplify(
            points: brushRawPoints.map { $0.location },
            tolerance: smoothingTolerance
        )
        
        // Step 2: Generate variable width brush stroke path using the SIMPLIFIED POINTS with pressure data
        // The smoothness comes from the final bezier path creation, not from over-sampling
        let brushStrokePath = generateSmoothVariableWidthPath(
            centerPoints: brushSimplifiedPoints,  // Use the clean simplified points!
            rawPoints: brushRawPoints,  // Pass raw points with pressure data
            thickness: document.currentBrushThickness,  // Use current tool settings
            pressureSensitivity: document.currentBrushPressureSensitivity,  // Use current tool settings
            taper: document.currentBrushTaper  // Use current tool settings
        )
        
        // Step 3: Replace the preview shape with the final brush stroke
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeBrushShape.id }) {
            // Update the shape with final brush stroke using current user settings and toggles
            var finalShape = document.layers[layerIndex].shapes[shapeIndex]
            finalShape.path = brushStrokePath
            finalShape.strokeStyle = document.brushApplyNoStroke ? nil : StrokeStyle(
                color: getCurrentStrokeColor(),
                width: getCurrentStrokeWidth(),
                opacity: getCurrentStrokeOpacity()
            )
            finalShape.fillStyle = FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
            
            document.layers[layerIndex].shapes[shapeIndex] = finalShape
            
            // Apply self-union operation if remove overlap is enabled
            if document.brushRemoveOverlap {
                print("🔍 MAIN DEBUG: === BRUSH REMOVE OVERLAP ENABLED ===")
                print("🔍 MAIN DEBUG: About to call applySelfUnionToBrushStroke with shapeIndex: \(shapeIndex)")
                print("🔍 MAIN DEBUG: Layer \(layerIndex) has \(document.layers[layerIndex].shapes.count) shapes BEFORE remove overlap")
                
                applySelfUnionToBrushStroke(shapeIndex: shapeIndex, layerIndex: layerIndex)
                
                print("🔍 MAIN DEBUG: Layer \(layerIndex) has \(document.layers[layerIndex].shapes.count) shapes AFTER remove overlap")
                print("🔍 MAIN DEBUG: === BRUSH REMOVE OVERLAP COMPLETED ===")
            }
        } else {
            print("🚨 BRUSH ERROR: Could not find activeBrushShape in layer! ID: \(activeBrushShape.id)")
        }
        
        print("🖌️ BRUSH: Generated variable width path with \(brushSimplifiedPoints.count) control points")
    }
    
    // MARK: - Remove Overlap Functionality
    
    /// Apply self-union operation to remove overlapping areas within the single brush stroke
    private func applySelfUnionToBrushStroke(shapeIndex: Int, layerIndex: Int) {
        print("🔍 REMOVE OVERLAP DEBUG: === STARTING SELF-UNION OPERATION ===")
        print("🔍 REMOVE OVERLAP DEBUG: Target shapeIndex: \(shapeIndex), layerIndex: \(layerIndex)")
        print("🔍 REMOVE OVERLAP DEBUG: BEFORE operation - Layer has \(document.layers[layerIndex].shapes.count) shapes:")
        for (i, shape) in document.layers[layerIndex].shapes.enumerated() {
            print("🔍 REMOVE OVERLAP DEBUG:   Shape \(i): '\(shape.name)' ID: \(shape.id)")
        }
        
        guard shapeIndex < document.layers[layerIndex].shapes.count else { 
            print("🚨 BRUSH ERROR: Shape index \(shapeIndex) out of bounds! Layer has \(document.layers[layerIndex].shapes.count) shapes")
            return 
        }
        
        let brushStroke = document.layers[layerIndex].shapes[shapeIndex]
        
        // VERIFY: Make sure we're operating on the correct shape
        guard brushStroke.id == activeBrushShape?.id else {
            print("🚨 BRUSH ERROR: Shape ID mismatch! Expected \(activeBrushShape?.id ?? UUID()), got \(brushStroke.id)")
            print("🚨 BRUSH ERROR: This would affect the WRONG shape - ABORTING self-union")
            return
        }
        
        print("🔍 REMOVE OVERLAP DEBUG: ✅ Verified correct shape - proceeding with self-union")
        
        // Convert VectorPath to CGPath for boolean operations
        let originalPath = brushStroke.path.cgPath
        
        // SAFETY CHECK: Ensure path is valid before union operation
        guard !originalPath.isEmpty else {
            print("🚨 BRUSH ERROR: Original path is empty - ABORTING self-union")
            return
        }
        
        // SAFETY CHECK: Verify path has valid bounds
        let pathBounds = originalPath.boundingBox
        guard isPathBoundsFinite(pathBounds) && !pathBounds.isNull else {
            print("🚨 BRUSH ERROR: Path has invalid bounds - ABORTING self-union")
            return
        }
        
        // Apply self-union to remove any self-intersections within the brush stroke
        // CRASH FIX: Use safe union operation with proper error handling
        if let cleanedPath = CoreGraphicsPathOperations.union(originalPath, originalPath) {
            // SAFETY CHECK: Verify the result path is valid
            guard !cleanedPath.isEmpty && isPathBoundsFinite(cleanedPath.boundingBox) else {
                print("🚨 BRUSH ERROR: Union operation produced invalid path - keeping original")
                return
            }
            
            let cleanedVectorPath = VectorPath(cgPath: cleanedPath)
            
            print("🔍 REMOVE OVERLAP DEBUG: About to update shape at index \(shapeIndex)")
            print("🔍 REMOVE OVERLAP DEBUG: Current shapes count: \(document.layers[layerIndex].shapes.count)")
            
            // Update the brush stroke with the cleaned path
            document.layers[layerIndex].shapes[shapeIndex].path = cleanedVectorPath
            
            print("🔍 REMOVE OVERLAP DEBUG: ✅ Updated path for shape at index \(shapeIndex)")
            print("🔍 REMOVE OVERLAP DEBUG: AFTER operation - Layer has \(document.layers[layerIndex].shapes.count) shapes:")
            for (i, shape) in document.layers[layerIndex].shapes.enumerated() {
                print("🔍 REMOVE OVERLAP DEBUG:   Shape \(i): '\(shape.name)' ID: \(shape.id)")
            }
            print("🔍 REMOVE OVERLAP DEBUG: === COMPLETED SELF-UNION OPERATION ===")
            
            print("🖌️ BRUSH: Applied self-union to remove overlapping areas within brush stroke")
        } else {
            print("🖌️ BRUSH: Self-union operation failed, keeping original path")
            print("🔍 REMOVE OVERLAP DEBUG: === ABORTED SELF-UNION OPERATION (union failed) ===")
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
        
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            
            // Apply tapering at start and end
            var finalThickness = thickness
            
            if progress < taper {
                // Taper from 0 to full thickness at start
                finalThickness *= (progress / taper)
            } else if progress > (1.0 - taper) {
                // Taper from full thickness to 0 at end
                let endProgress = (1.0 - progress) / taper
                finalThickness *= endProgress
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
                
                finalThickness *= closestPressure
            }
            
            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        
        // Generate left and right edge points with variable thickness
        let leftEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        
        // Create smooth bezier curves for BOTH edges (like freehand tool!)
        let leftEdgePath = createSmoothBezierPath(from: leftEdgePoints)
        let rightEdgePath = createSmoothBezierPath(from: rightEdgePoints.reversed()) // Reverse for proper winding
        
        // Combine into a filled shape with smooth bezier curves
        return createSmoothBrushOutline(leftEdgePath: leftEdgePath, rightEdgePath: rightEdgePath, startPoint: centerPoints.first!, endPoint: centerPoints.last!)
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
    
    // MARK: - Smooth Variable Width Path Generation (SAME APPROACH AS FREEHAND!)
    
    private func generateSmoothVariableWidthPath(centerPoints: [CGPoint], rawPoints: [BrushPoint], thickness: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point
            return VectorPath(elements: [.move(to: VectorPoint(rawPoints[0].location))])
        }
        
        // Calculate variable thickness at each simplified point with proper pressure interpolation
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []
        
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            
            // Apply tapering at start and end
            var finalThickness = thickness
            
            if progress < taper {
                // Taper from 0 to full thickness at start
                finalThickness *= (progress / taper)
            } else if progress > (1.0 - taper) {
                // Taper from full thickness to 0 at end
                let endProgress = (1.0 - progress) / taper
                finalThickness *= endProgress
            }
            
            // Interpolate pressure from raw points to simplified points
            let interpolatedPressure = interpolatePressureForPoint(point, from: rawPoints)
            
            // Apply pressure variation with sensitivity control
            let pressureMultiplier = 1.0 + (interpolatedPressure - 1.0) * pressureSensitivity
            finalThickness *= pressureMultiplier
            
            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        
        // Generate left and right edge points with variable thickness
        let leftEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        
        // Create smooth bezier curves for BOTH edges (like freehand tool!)
        let leftEdgePath = createSmoothBezierPath(from: leftEdgePoints)
        let rightEdgePath = createSmoothBezierPath(from: rightEdgePoints.reversed()) // Reverse for proper winding
        
        // Combine into a filled shape with smooth bezier curves
        return createSmoothBrushOutline(leftEdgePath: leftEdgePath, rightEdgePath: rightEdgePath, startPoint: centerPoints.first!, endPoint: centerPoints.last!)
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
        if !rightEdge.isEmpty {
            elements.append(.line(to: VectorPoint(rightEdge.last!)))
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
    private func createSmoothBrushOutline(leftEdgePath: VectorPath, rightEdgePath: VectorPath, startPoint: CGPoint, endPoint: CGPoint) -> VectorPath {
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
    
    // MARK: - Douglas-Peucker Line Simplification Algorithm (Shared with Freehand)
    
    private func douglasPeuckerSimplify(points: [CGPoint], tolerance: Double) -> [CGPoint] {
        guard points.count > 2 else { return points }
        
        return douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1)
    }
    
    private func douglasPeuckerRecursive(points: [CGPoint], tolerance: Double, startIndex: Int, endIndex: Int) -> [CGPoint] {
        guard endIndex - startIndex > 1 else {
            return [points[startIndex], points[endIndex]]
        }
        
        let startPoint = points[startIndex]
        let endPoint = points[endIndex]
        
        // Find the point with maximum distance from the line segment
        var maxDistance: Double = 0
        var maxIndex = startIndex
        
        for i in (startIndex + 1)..<endIndex {
            let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }
        
        // If the maximum distance is greater than tolerance, recursively simplify
        if maxDistance > tolerance {
            // Recursively simplify the two segments
            let leftSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: startIndex, endIndex: maxIndex)
            let rightSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: maxIndex, endIndex: endIndex)
            
            // Combine segments (remove duplicate point at the connection)
            return leftSegment + Array(rightSegment.dropFirst())
        } else {
            // All points between start and end are within tolerance - return only endpoints
            return [startPoint, endPoint]
        }
    }
    
    private func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let A = lineEnd.y - lineStart.y
        let B = lineStart.x - lineEnd.x
        let C = lineEnd.x * lineStart.y - lineStart.x * lineEnd.y
        
        let distance = abs(A * point.x + B * point.y + C) / sqrt(A * A + B * B)
        return distance
    }
    
    // MARK: - Smooth Bezier Curve Fitting (SAME AS FREEHAND TOOL)
    
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
            // Create smooth curves through all points
            let curveSegments = fitBezierCurves(through: points)
            elements.append(contentsOf: curveSegments)
        }
        
        return VectorPath(elements: elements)
    }
    
    private func fitBezierCurves(through points: [CGPoint]) -> [PathElement] {
        var elements: [PathElement] = []
        
        // Use a simple curve fitting approach that creates smooth C1 continuous curves
        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            
            // SURGICAL FIX: Make first and last segments lines (corner points) instead of curves
            let isFirstSegment = (i == 1)
            let isLastSegment = (i == points.count - 1)
            
            if isFirstSegment || isLastSegment {
                // Create corner points for start and end - no handles
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
    

}

