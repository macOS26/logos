//
//  DrawingCanvas+BlobBrush.swift
//  logos inkpen.io
//
//  Blob brush tool - creates filled shapes that merge overlapping areas
//  Based on Adobe Illustrator, Macromedia Freehand, CorelDraw, and Inkscape blob brush tools
//

import SwiftUI
import Foundation

extension DrawingCanvas {
    
    // MARK: - Blob Brush Tool Management
    
    internal func cancelBlobBrushDrawing() {
        blobBrushPath = nil
        blobBrushRawPoints.removeAll()
        blobBrushSimplifiedPoints.removeAll()
        isBlobBrushDrawing = false
        activeBlobBrushShape = nil
    }
    
    internal func handleBlobBrushDragStart(at location: CGPoint) {
        // Start new blob brush stroke with proper initialization
        guard !isBlobBrushDrawing else { return }
        
        // Initialize blob brush drawing state
        isBlobBrushDrawing = true
        blobBrushRawPoints = [BlobBrushPoint(location: location, pressure: 1.0, timestamp: Date())]
        blobBrushSimplifiedPoints = []
        
        // Create initial VectorPath for center line
        let startPoint = VectorPoint(location)
        blobBrushPath = VectorPath(elements: [.move(to: startPoint)])
        
        // Create real VectorShape for blob brush stroke using current user settings
        // BLOB BRUSH SPECIFIC: Always filled shapes, no stroke by default
        let fillStyle = FillStyle(
            color: getCurrentFillColor(), // Use whatever fill color user has set
            opacity: getCurrentFillOpacity() // Use whatever fill opacity user has set
        )
        
        activeBlobBrushShape = VectorShape(
            name: "Blob Brush Shape",
            path: blobBrushPath!,
            strokeStyle: nil, // Blob brush typically has no stroke
            fillStyle: fillStyle
        )
        
        // Add the preview shape to the document immediately
        document.addShape(activeBlobBrushShape!)
        
        print("🟡 BLOB BRUSH: Started drawing at \(location)")
    }
    
    internal func handleBlobBrushDragUpdate(at location: CGPoint) {
        guard isBlobBrushDrawing else { return }
        
        // Calculate pressure simulation (same as brush tool)
        let pressure = calculateBlobBrushPressure(at: location)
        
        // Add point to raw path with pressure data
        let blobPoint = BlobBrushPoint(location: location, pressure: pressure, timestamp: Date())
        blobBrushRawPoints.append(blobPoint)
        
        // Update real-time preview
        updateBlobBrushPreview()
        
        // Limit raw points array to prevent memory issues
        if blobBrushRawPoints.count > 1000 {
            // Keep last 800 points
            blobBrushRawPoints = Array(blobBrushRawPoints.suffix(800))
        }
    }
    
    internal func handleBlobBrushDragEnd() {
        guard isBlobBrushDrawing else { return }
        
        print("🟡 BLOB BRUSH: Finishing drawing with \(blobBrushRawPoints.count) raw points")
        
        // Process blob brush stroke to create variable width filled shape
        processBlobBrushStroke()
        
        // Clean up state
        cancelBlobBrushDrawing()
        
        // AUTO-DESELECT: Clear selection after completing blob brush stroke
        // This allows user to immediately change colors for the next stroke
        document.selectedShapeIDs.removeAll()
        print("🎨 BLOB BRUSH: Auto-deselected shape to enable color changes for next stroke")
        
        print("✅ BLOB BRUSH: Stroke completed and converted to filled shape")
    }
    
    // MARK: - Pressure Simulation (Same as Brush Tool)
    
    private func calculateBlobBrushPressure(at location: CGPoint) -> Double {
        guard blobBrushRawPoints.count > 1 else { return 1.0 }
        
        let lastPoint = blobBrushRawPoints.last!.location
        let distance = sqrt(pow(location.x - lastPoint.x, 2) + pow(location.y - lastPoint.y, 2))
        
        // Simulate pressure based on drawing speed
        // Fast drawing = light pressure, slow drawing = heavy pressure
        let maxSpeed: Double = 100.0 // Maximum pixels per measurement
        let normalizedSpeed = min(distance / maxSpeed, 1.0)
        let basePressure = 1.0 - (normalizedSpeed * 0.5) // Reduce pressure with speed
        
        // Apply current blob brush sensitivity setting (use brush settings for now)
        let sensitivity = document.currentBrushPressureSensitivity
        let pressureVariation = (basePressure - 0.5) * sensitivity
        
        return max(0.1, min(1.0, 0.5 + pressureVariation))
    }
    
    // MARK: - Real-time Preview
    
    private func updateBlobBrushPreview() {
        guard let activeBlobBrushShape = activeBlobBrushShape,
              blobBrushRawPoints.count >= 2,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // LIVE PREVIEW: Generate actual variable width blob brush shape in real-time!
        let previewPath = generateBlobBrushLivePreviewPath()
        
        // Find and update the shape in the document with the REAL blob brush preview
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeBlobBrushShape.id }) {
            document.layers[layerIndex].shapes[shapeIndex].path = previewPath
            
            // Update fill using current user settings (blob brush is always filled)
            document.layers[layerIndex].shapes[shapeIndex].strokeStyle = nil // No stroke
            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
        }
    }
    
    /// Generate live preview of the blob brush shape as the user draws
    private func generateBlobBrushLivePreviewPath() -> VectorPath {
        guard blobBrushRawPoints.count >= 2 else {
            // Fallback for insufficient points
            return VectorPath(elements: [.move(to: VectorPoint(blobBrushRawPoints[0].location))])
        }
        
        // Show the COMPLETE stroke, not just recent points
        let rawPointLocations = blobBrushRawPoints.map { $0.location }
        
        // PERFORMANCE OPTIMIZATION: Use a slightly higher tolerance for live preview
        let previewSmoothingTolerance = document.currentBrushSmoothingTolerance * 1.25
        let simplifiedPoints = douglasPeuckerSimplify(
            points: rawPointLocations,
            tolerance: previewSmoothingTolerance
        )
        
        // Generate blob brush shape with circular brush tip
        if simplifiedPoints.count >= 2 {
            return generateBlobBrushVariableWidthPath(
                centerPoints: simplifiedPoints,
                recentRawPoints: blobBrushRawPoints,
                brushSize: document.currentBrushThickness, // Use brush thickness setting
                pressureSensitivity: document.currentBrushPressureSensitivity,
                taper: document.currentBrushTaper
            )
        } else {
            // Fallback for single point - create a small circle
            return createBlobBrushCircle(at: blobBrushRawPoints[0].location, size: document.currentBrushThickness)
        }
    }
    
    // MARK: - Blob Brush Stroke Processing
    
    private func processBlobBrushStroke() {
        guard blobBrushRawPoints.count >= 3,
              let activeBlobBrushShape = activeBlobBrushShape,
              let layerIndex = document.selectedLayerIndex else { 
            print("🟡 BLOB BRUSH: Too few points (\(blobBrushRawPoints.count)) - keeping as simple shape")
            return 
        }
        
        // Step 1: Simplify the raw points using Douglas-Peucker algorithm (same as freehand/brush)
        let smoothingTolerance = document.currentBrushSmoothingTolerance
        blobBrushSimplifiedPoints = douglasPeuckerSimplify(
            points: blobBrushRawPoints.map { $0.location },
            tolerance: smoothingTolerance
        )
        
        // Step 2: Generate blob brush shape path with circular brush tips
        let blobBrushPath = generateFinalBlobBrushPath(
            centerPoints: blobBrushSimplifiedPoints,
            brushSize: document.currentBrushThickness,
            pressureSensitivity: document.currentBrushPressureSensitivity,
            taper: document.currentBrushTaper
        )
        
        // Step 3: Replace the preview shape with the final blob brush shape
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeBlobBrushShape.id }) {
            // Update the shape with final blob brush stroke
            var finalShape = document.layers[layerIndex].shapes[shapeIndex]
            finalShape.path = blobBrushPath
            finalShape.strokeStyle = nil // Blob brush has no stroke
            finalShape.fillStyle = FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
            
            document.layers[layerIndex].shapes[shapeIndex] = finalShape
            
            // BLOB BRUSH SPECIFIC: Apply automatic merging with overlapping shapes
            if shouldMergeBlobBrushShapes() {
                applyBlobBrushMerging(shapeIndex: shapeIndex, layerIndex: layerIndex)
            }
        } else {
            print("🚨 BLOB BRUSH ERROR: Could not find activeBlobBrushShape in layer! ID: \(activeBlobBrushShape.id)")
        }
        
        print("🟡 BLOB BRUSH: Generated filled shape with \(blobBrushSimplifiedPoints.count) control points")
    }
    
    // MARK: - Blob Brush Path Generation
    
    /// Generate blob brush shape with circular brush tip
    private func generateBlobBrushVariableWidthPath(centerPoints: [CGPoint], recentRawPoints: [BlobBrushPoint], brushSize: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point - create a circle
            return createBlobBrushCircle(at: centerPoints[0], size: brushSize)
        }
        
        // Calculate variable thickness at each simplified point with pressure mapping
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []
        
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            
            // Apply tapering at start and end
            var finalThickness = brushSize
            
            if progress < taper {
                // Taper from 0 to full thickness at start
                finalThickness *= (progress / taper)
            } else if progress > (1.0 - taper) {
                // Taper from full thickness to 0 at end
                let endProgress = (1.0 - progress) / taper
                finalThickness *= endProgress
            }
            
            // Find the closest raw point for pressure data
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
        
        // Generate smooth outline for blob brush shape
        return createBlobBrushOutlinePath(thicknessPoints: thicknessPoints)
    }
    
    /// Generate final blob brush path
    private func generateFinalBlobBrushPath(centerPoints: [CGPoint], brushSize: Double, pressureSensitivity: Double, taper: Double) -> VectorPath {
        guard centerPoints.count >= 2 else {
            // Fallback for single point - create a circle
            return createBlobBrushCircle(at: centerPoints[0], size: brushSize)
        }
        
        // Calculate variable thickness at each simplified point
        var thicknessPoints: [(location: CGPoint, thickness: Double)] = []
        
        for (index, point) in centerPoints.enumerated() {
            let progress = Double(index) / Double(centerPoints.count - 1)
            
            // Apply tapering at start and end
            var finalThickness = brushSize
            
            if progress < taper {
                // Taper from 0 to full thickness at start
                finalThickness *= (progress / taper)
            } else if progress > (1.0 - taper) {
                // Taper from full thickness to 0 at end
                let endProgress = (1.0 - progress) / taper
                finalThickness *= endProgress
            }
            
            // Apply pressure variation if we have pressure data
            if index < blobBrushRawPoints.count {
                finalThickness *= blobBrushRawPoints[index].pressure
            }
            
            thicknessPoints.append((location: point, thickness: finalThickness))
        }
        
        // Generate smooth outline for blob brush shape
        return createBlobBrushOutlinePath(thicknessPoints: thicknessPoints)
    }
    
    /// Create blob brush outline path with smooth curves
    private func createBlobBrushOutlinePath(thicknessPoints: [(location: CGPoint, thickness: Double)]) -> VectorPath {
        // Generate left and right edge points with variable thickness (same as brush tool)
        let leftEdgePoints = generateBlobBrushOffsetPoints(centerPoints: thicknessPoints, isLeftSide: true)
        let rightEdgePoints = generateBlobBrushOffsetPoints(centerPoints: thicknessPoints, isLeftSide: false)
        
        // Create smooth bezier curves for BOTH edges (like freehand/brush tools)
        let leftEdgePath = createSmoothBezierPath(from: leftEdgePoints)
        let rightEdgePath = createSmoothBezierPath(from: rightEdgePoints.reversed()) // Reverse for proper winding
        
        // Combine into a filled shape with smooth bezier curves
        return createSmoothBlobBrushOutline(leftEdgePath: leftEdgePath, rightEdgePath: rightEdgePath, startPoint: thicknessPoints.first!.location, endPoint: thicknessPoints.last!.location)
    }
    
    /// Create a circular blob brush shape for single points
    private func createBlobBrushCircle(at center: CGPoint, size: Double) -> VectorPath {
        let radius = size / 2.0
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
    
    /// Generate offset points for blob brush (same logic as brush tool)
    private func generateBlobBrushOffsetPoints(centerPoints: [(location: CGPoint, thickness: Double)], isLeftSide: Bool) -> [CGPoint] {
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
    
    /// Combine two smooth bezier edge paths into a closed blob brush outline
    private func createSmoothBlobBrushOutline(leftEdgePath: VectorPath, rightEdgePath: VectorPath, startPoint: CGPoint, endPoint: CGPoint) -> VectorPath {
        var elements: [PathElement] = []
        
        // Start with the left edge path (gives us smooth bezier curves)
        elements.append(contentsOf: leftEdgePath.elements)
        
        // Connect to the right edge at the end
        if let lastLeftPoint = leftEdgePath.elements.last {
            switch lastLeftPoint {
            case .move(let _), .line(let _), .curve(let _, _, _), .quadCurve(let _, _):
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
        
        // Close the path to complete the blob brush shape
        elements.append(.close)
        
        return VectorPath(elements: elements)
    }
    
    // MARK: - Blob Brush Merging (Key Feature)
    
    /// Check if blob brush shapes should merge
    private func shouldMergeBlobBrushShapes() -> Bool {
        // For now, always attempt merging - this is the key feature of blob brush
        // Later we can add user preferences for this
        return true
    }
    
    /// Apply automatic merging with overlapping shapes of the same color
    private func applyBlobBrushMerging(shapeIndex: Int, layerIndex: Int) {
        print("🟡 BLOB BRUSH: Starting automatic merging process...")
        
        // TODO: Implement blob brush merging logic
        // This is where the blob brush differs from regular brush - it merges overlapping areas
        // For now, just log that we would apply merging here
        
        print("🟡 BLOB BRUSH: Merging logic will be implemented next")
    }
    
    // MARK: - Helper Functions (Shared with Brush Tool)
    
    /// Get the current fill color that the user has set
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
    
    /// Get the current fill opacity that the user has set
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
    
    // MARK: - Shared Algorithm Functions (Same as Freehand/Brush Tools)
    
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
            
            // Make first and last segments lines (corner points) instead of curves
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

// MARK: - Blob Brush Point Data Structure

struct BlobBrushPoint {
    let location: CGPoint
    let pressure: Double // 0.0 to 1.0
    let timestamp: Date
    
    init(location: CGPoint, pressure: Double = 1.0, timestamp: Date = Date()) {
        self.location = location
        self.pressure = max(0.0, min(1.0, pressure)) // Clamp between 0 and 1
        self.timestamp = timestamp
    }
}