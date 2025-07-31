//
//  DrawingCanvas+BlobBrushTool.swift
//  logos inkpen.io
//
//  Blob brush tool - creates filled shapes with variable circular points
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
        blobBrushRawPoints = [BlobPoint(location: location, size: document.currentBlobBrushSize, timestamp: Date())]
        blobBrushSimplifiedPoints = []
        
        // Create initial circular blob at starting point
        let startCircle = createCircularBlob(at: location, size: document.currentBlobBrushSize)
        blobBrushPath = startCircle
        
        // Create real VectorShape for blob brush using current user settings
        let fillStyle = FillStyle(
            color: getCurrentFillColor(), // Blob brush is primarily fill-based
            opacity: getCurrentFillOpacity()
        )
        
        activeBlobBrushShape = VectorShape(
            name: "Blob Brush",
            path: blobBrushPath!,
            strokeStyle: nil, // No stroke for blob brush
            fillStyle: fillStyle
        )
        
        // Add the preview shape to the document immediately
        document.addShape(activeBlobBrushShape!)
        
        print("🔵 BLOB BRUSH: Started drawing at \(location) with size \(document.currentBlobBrushSize)")
    }
    
    internal func handleBlobBrushDragUpdate(at location: CGPoint) {
        guard isBlobBrushDrawing else { return }
        
        // Calculate dynamic size variation based on drawing speed and user settings
        let currentSize = calculateDynamicBlobSize(at: location)
        
        // Add point to raw path with size data
        let blobPoint = BlobPoint(location: location, size: currentSize, timestamp: Date())
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
        
        print("🔵 BLOB BRUSH: Finishing drawing with \(blobBrushRawPoints.count) raw points")
        
        // Process blob brush stroke to create final blob shape
        processBlobBrushStroke()
        
        // Clean up state
        cancelBlobBrushDrawing()
        
        // AUTO-DESELECT: Clear selection after completing blob brush stroke
        // This allows user to immediately change colors for the next stroke
        document.selectedShapeIDs.removeAll()
        print("🎨 BLOB BRUSH: Auto-deselected shape to enable color changes for next stroke")
        
        print("✅ BLOB BRUSH: Stroke completed and converted to blob shape")
    }
    
    // MARK: - Dynamic Size Calculation
    
    private func calculateDynamicBlobSize(at location: CGPoint) -> Double {
        guard blobBrushRawPoints.count > 1 else { return document.currentBlobBrushSize }
        
        let lastPoint = blobBrushRawPoints.last!.location
        let distance = sqrt(pow(location.x - lastPoint.x, 2) + pow(location.y - lastPoint.y, 2))
        
        // Simulate size variation based on drawing speed
        // Fast drawing = smaller size, slow drawing = larger size
        let maxSpeed: Double = 100.0 // Maximum pixels per measurement
        let normalizedSpeed = min(distance / maxSpeed, 1.0)
        let baseSize = document.currentBlobBrushSize
        
        // Apply size variation based on speed
        let speedVariation = 1.0 - (normalizedSpeed * document.currentBlobBrushSizeVariation)
        
        return max(baseSize * 0.1, baseSize * speedVariation)
    }
    
    // MARK: - Real-time Preview
    
    private func updateBlobBrushPreview() {
        guard let activeBlobBrushShape = activeBlobBrushShape,
              blobBrushRawPoints.count >= 2,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Generate real-time blob shape preview
        let previewPath = generateLiveBlobPreview()
        
        // Find and update the shape in the document with the blob preview
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeBlobBrushShape.id }) {
            document.layers[layerIndex].shapes[shapeIndex].path = previewPath
            
            // Update fill using current user settings
            document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
        }
    }
    
    /// Generate live preview of the blob brush shape as the user draws
    private func generateLiveBlobPreview() -> VectorPath {
        guard blobBrushRawPoints.count >= 2 else {
            // Fallback for insufficient points
            return createCircularBlob(at: blobBrushRawPoints[0].location, size: blobBrushRawPoints[0].size)
        }
        
        // PERFORMANCE OPTIMIZATION: Use simplified points for live preview
        let rawPointLocations = blobBrushRawPoints.map { $0.location }
        let previewTolerance = document.currentBlobBrushSmoothingTolerance * 1.25 // Less detailed for speed
        let simplifiedPoints = douglasPeuckerSimplify(
            points: rawPointLocations,
            tolerance: previewTolerance
        )
        
        // Generate blob shape from simplified points
        if simplifiedPoints.count >= 2 {
            return generateBlobShape(from: simplifiedPoints, rawPoints: blobBrushRawPoints)
        } else {
            // Fallback for single point
            return createCircularBlob(at: blobBrushRawPoints[0].location, size: blobBrushRawPoints[0].size)
        }
    }
    
    // MARK: - Blob Shape Processing
    
    private func processBlobBrushStroke() {
        guard blobBrushRawPoints.count >= 2,  // Require at least 2 points for blob
              let activeBlobBrushShape = activeBlobBrushShape,
              let layerIndex = document.selectedLayerIndex else { 
            print("🔵 BLOB BRUSH: Too few points (\(blobBrushRawPoints.count)) - keeping as simple circle")
            return 
        }
        
        // Step 1: Simplify the raw points using Douglas-Peucker algorithm
        let smoothingTolerance = document.currentBlobBrushSmoothingTolerance
        blobBrushSimplifiedPoints = douglasPeuckerSimplify(
            points: blobBrushRawPoints.map { $0.location },
            tolerance: smoothingTolerance
        )
        
        // Step 2: Generate final blob shape using simplified points
        let blobShapePath = generateFinalBlobShape(
            centerPoints: blobBrushSimplifiedPoints,
            rawPoints: blobBrushRawPoints
        )
        
        // Step 3: Replace the preview shape with the final blob shape
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == activeBlobBrushShape.id }) {
            // Update the shape with final blob shape
            var finalShape = document.layers[layerIndex].shapes[shapeIndex]
            finalShape.path = blobShapePath
            finalShape.strokeStyle = nil // No stroke for blob brush
            finalShape.fillStyle = FillStyle(
                color: getCurrentFillColor(),
                opacity: getCurrentFillOpacity()
            )
            
            document.layers[layerIndex].shapes[shapeIndex] = finalShape
        } else {
            print("🚨 BLOB BRUSH ERROR: Could not find activeBlobBrushShape in layer! ID: \(activeBlobBrushShape.id)")
        }
        
        print("🔵 BLOB BRUSH: Generated blob shape with \(blobBrushSimplifiedPoints.count) control points")
    }
    
    // MARK: - Blob Shape Generation
    
    /// Create a circular blob at a specific location and size
    private func createCircularBlob(at location: CGPoint, size: Double) -> VectorPath {
        let radius = size / 2.0
        let rect = CGRect(
            x: location.x - radius,
            y: location.y - radius,
            width: size,
            height: size
        )
        
        // Create a perfect circle using bezier curves
        let elements: [PathElement] = [
            .move(to: VectorPoint(rect.midX, rect.minY)),
            .curve(
                to: VectorPoint(rect.maxX, rect.midY),
                control1: VectorPoint(rect.midX + radius * 0.552, rect.minY),
                control2: VectorPoint(rect.maxX, rect.midY - radius * 0.552)
            ),
            .curve(
                to: VectorPoint(rect.midX, rect.maxY),
                control1: VectorPoint(rect.maxX, rect.midY + radius * 0.552),
                control2: VectorPoint(rect.midX + radius * 0.552, rect.maxY)
            ),
            .curve(
                to: VectorPoint(rect.minX, rect.midY),
                control1: VectorPoint(rect.midX - radius * 0.552, rect.maxY),
                control2: VectorPoint(rect.minX, rect.midY + radius * 0.552)
            ),
            .curve(
                to: VectorPoint(rect.midX, rect.minY),
                control1: VectorPoint(rect.minX, rect.midY - radius * 0.552),
                control2: VectorPoint(rect.midX - radius * 0.552, rect.minY)
            ),
            .close
        ]
        
        return VectorPath(elements: elements)
    }
    
    /// Generate blob shape from simplified points with size variation
    private func generateBlobShape(from points: [CGPoint], rawPoints: [BlobPoint]) -> VectorPath {
        guard points.count >= 2 else {
            return createCircularBlob(at: points[0], size: document.currentBlobBrushSize)
        }
        
        // Create a union of overlapping circles at each point
        var combinedPath: VectorPath?
        
        for (_, point) in points.enumerated() {
            // Find corresponding size from raw points
            let size = findSizeForPoint(point, in: rawPoints)
            let circlePath = createCircularBlob(at: point, size: size)
            
            if combinedPath == nil {
                combinedPath = circlePath
            } else {
                // Union the new circle with the existing path
                combinedPath = unionPaths(combinedPath!, circlePath)
            }
        }
        
        return combinedPath ?? createCircularBlob(at: points[0], size: document.currentBlobBrushSize)
    }
    
    /// Generate final blob shape with smooth curves
    private func generateFinalBlobShape(centerPoints: [CGPoint], rawPoints: [BlobPoint]) -> VectorPath {
        guard centerPoints.count >= 2 else {
            let size = rawPoints.isEmpty ? document.currentBlobBrushSize : rawPoints[0].size
            return createCircularBlob(at: centerPoints[0], size: size)
        }
        
        // For final shape, create smooth blob using existing algorithms
        return generateBlobShape(from: centerPoints, rawPoints: rawPoints)
    }
    
    // MARK: - Helper Functions
    
    /// Find the size for a simplified point by finding the closest raw point
    private func findSizeForPoint(_ point: CGPoint, in rawPoints: [BlobPoint]) -> Double {
        guard !rawPoints.isEmpty else { return document.currentBlobBrushSize }
        
        var closestDistance = Double.infinity
        var closestSize = document.currentBlobBrushSize
        
        for rawPoint in rawPoints {
            let distance = sqrt(pow(point.x - rawPoint.location.x, 2) + pow(point.y - rawPoint.location.y, 2))
            if distance < closestDistance {
                closestDistance = distance
                closestSize = rawPoint.size
            }
        }
        
        return closestSize
    }
    
    /// Union two VectorPaths (simplified version for blob brush)
    private func unionPaths(_ path1: VectorPath, _ path2: VectorPath) -> VectorPath {
        // For now, use a simple approach - this can be enhanced with CoreGraphics boolean operations
        // Create a smooth hull around both paths
        return path1 // Placeholder - will be enhanced in later steps
    }
    
    /// Get current fill color for blob brush
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
    
    /// Get current fill opacity for blob brush
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
    
    // MARK: - Douglas-Peucker Line Simplification Algorithm (Shared)
    
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
}

// MARK: - Blob Point Data Structure

struct BlobPoint {
    let location: CGPoint
    let size: Double // Circular blob size at this point
    let timestamp: Date
    
    init(location: CGPoint, size: Double, timestamp: Date = Date()) {
        self.location = location
        self.size = max(1.0, size) // Ensure minimum size
        self.timestamp = timestamp
    }
}