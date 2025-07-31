//
//  DrawingCanvas+BrushTool.swift
//  logos inkpen.io
//
//  Variable brush stroke tool with parallel path generation
//

import SwiftUI
import Foundation

extension DrawingCanvas {
    
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
        
        // Detect pressure input capability (for now, we use simulated pressure)
        // TODO: Implement real pressure detection when available
        document.hasPressureInput = false
        
        // Create initial VectorPath for center line
        let startPoint = VectorPoint(location)
        brushPath = VectorPath(elements: [.move(to: startPoint)])
        
        // Create real VectorShape for brush stroke with proper preview styling
        let strokeStyle = StrokeStyle(
            color: VectorColor.clear, // No stroke outline for brush preview
            width: 0.0,
            opacity: 0.0
        )
        let fillStyle = FillStyle(
            color: document.defaultStrokeColor, // Brush uses stroke color as fill
            opacity: document.defaultFillOpacity
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
        
        // Calculate pressure simulation (can be enhanced with real pressure data)
        let pressure = calculateSimulatedPressure(at: location)
        
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
        
        print("✅ BRUSH: Stroke completed and converted to variable width path")
    }
    
    // MARK: - Pressure Simulation
    
    private func calculateSimulatedPressure(at location: CGPoint) -> Double {
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
            
            // Update stroke and fill to show the actual brush appearance
            document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: VectorColor.clear, width: 0) // No stroke outline
            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                color: document.defaultStrokeColor, // Use stroke color as fill
                opacity: document.defaultFillOpacity
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
        
        // Step 2: Generate variable width brush stroke path using the SIMPLIFIED POINTS (like freehand!)
        // The smoothness comes from the final bezier path creation, not from over-sampling
        let brushStrokePath = generateSmoothVariableWidthPath(
            centerPoints: brushSimplifiedPoints,  // Use the clean simplified points!
            thickness: document.currentBrushThickness,  // Use current tool settings
            pressureSensitivity: document.currentBrushPressureSensitivity,  // Use current tool settings
            taper: document.currentBrushTaper  // Use current tool settings
        )
        
        // Step 3: Replace the preview shape with the final brush stroke
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeBrushShape.id }) {
            // Update the shape with filled brush stroke
            var finalShape = document.layers[layerIndex].shapes[shapeIndex]
            finalShape.path = brushStrokePath
            finalShape.strokeStyle = StrokeStyle(color: VectorColor.clear, width: 0) // No stroke
            finalShape.fillStyle = FillStyle(
                color: document.defaultStrokeColor,
                opacity: document.defaultFillOpacity
            )
            
            document.layers[layerIndex].shapes[shapeIndex] = finalShape
        }
        
        print("🖌️ BRUSH: Generated variable width path with \(brushSimplifiedPoints.count) control points")
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
    
    // MARK: - Smooth Variable Width Path Generation (SAME APPROACH AS FREEHAND!)
    
    private func generateSmoothVariableWidthPath(centerPoints: [CGPoint], thickness: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point
            return VectorPath(elements: [.move(to: VectorPoint(brushRawPoints[0].location))])
        }
        
        // Calculate variable thickness at each simplified point (NOT millions of points!)
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
            
            // Apply pressure variation if we have pressure data (map to simplified points)
            if index < brushRawPoints.count {
                finalThickness *= brushRawPoints[index].pressure
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
            case .move(let point), .line(let point), .curve(let point, _, _), .quadCurve(let point, _):
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

// MARK: - Brush Point Data Structure

struct BrushPoint {
    let location: CGPoint
    let pressure: Double // 0.0 to 1.0
    let timestamp: Date
    
    init(location: CGPoint, pressure: Double = 1.0, timestamp: Date = Date()) {
        self.location = location
        self.pressure = max(0.0, min(1.0, pressure)) // Clamp between 0 and 1
        self.timestamp = timestamp
    }
}

