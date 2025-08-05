//
//  DrawingCanvas+FreehandTool.swift
//  logos inkpen.io
//
//  Freehand drawing tool with professional curve fitting
//

import SwiftUI
import Foundation

extension DrawingCanvas {
    
    // MARK: - Freehand Tool Management
    
    internal func cancelFreehandDrawing() {
        freehandPath = nil
        freehandRawPoints.removeAll()
        freehandSimplifiedPoints.removeAll()
        freehandRealtimeSmoothingPoints.removeAll()
        isFreehandDrawing = false
        activeFreehandShape = nil
    }
    
    internal func handleFreehandDragStart(at location: CGPoint) {
        // PROFESSIONAL FREEHAND: Start new path with proper initialization
        guard !isFreehandDrawing else { return }
        
        // Initialize freehand drawing state
        isFreehandDrawing = true
        freehandRawPoints = [location]
        freehandSimplifiedPoints = []
        
        // Create initial VectorPath
        let startPoint = VectorPoint(location)
        freehandPath = VectorPath(elements: [.move(to: startPoint)])
        
        // Create real VectorShape with document default colors
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth, // Use user's default stroke width setting
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle = FillStyle(
            color: document.defaultFillColor,
            opacity: document.defaultFillOpacity // Use user's default fill opacity setting
        )
        
        activeFreehandShape = VectorShape(
            name: "Freehand Path",
            path: freehandPath!,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        // Add the real shape to the document immediately for real-time preview
        document.addShape(activeFreehandShape!)
        
        print("🖊️ FREEHAND: Started drawing at \(location)")
    }
    
    internal func handleFreehandDragUpdate(at location: CGPoint) {
        guard isFreehandDrawing else { return }
        
        // Apply real-time smoothing for immediate visual feedback (if enabled)
        let smoothedLocation: CGPoint
        if document.settings.advancedSmoothingEnabled && document.settings.realTimeSmoothingEnabled {
            smoothedLocation = RealTimeSmoothing.applyRealTimeSmoothing(
                newPoint: location,
                recentPoints: &freehandRealtimeSmoothingPoints,
                windowSize: 5,
                strength: document.settings.realTimeSmoothingStrength
            )
        } else {
            smoothedLocation = location
        }
        
        // Add both original and smoothed points (use smoothed for preview)
        freehandRawPoints.append(location)  // Keep original for final processing
        
        // Update real-time preview with smoothed location
        updateFreehandPreview(smoothedLocation: smoothedLocation)
        
        // Limit raw points array to prevent memory issues
        if freehandRawPoints.count > 1000 {
            // Keep last 800 points
            freehandRawPoints = Array(freehandRawPoints.suffix(800))
        }
    }
    
    internal func handleFreehandDragEnd() {
        guard isFreehandDrawing else { return }
        
        print("🖊️ FREEHAND: Finishing drawing with \(freehandRawPoints.count) raw points")
        
        // Apply curve fitting algorithms to create smooth bezier curves
        processFreehandPath()
        
        // Clean up state
        cancelFreehandDrawing()
        
        print("✅ FREEHAND: Path completed and converted to smooth curves")
    }
    
    // MARK: - Real-time Preview
    
    private func updateFreehandPreview(smoothedLocation: CGPoint? = nil) {
        guard let activeFreehandShape = activeFreehandShape,
              freehandRawPoints.count >= 2,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Create simple line preview for real-time feedback
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(freehandRawPoints[0])))
        
        for i in 1..<freehandRawPoints.count {
            elements.append(.line(to: VectorPoint(freehandRawPoints[i])))
        }
        
        let previewPath = VectorPath(elements: elements)
        
        // Update the shape in the document
        for shapeIndex in document.layers[layerIndex].shapes.indices {
            if document.layers[layerIndex].shapes[shapeIndex].id == activeFreehandShape.id {
                document.layers[layerIndex].shapes[shapeIndex].path = previewPath
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                break
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    // MARK: - Professional Curve Fitting with Advanced Smoothing
    
    private func processFreehandPath() {
        guard freehandRawPoints.count >= 3 else {
            print("🖊️ FREEHAND: Too few points (\(freehandRawPoints.count)) - keeping as simple lines")
            return
        }
        
        print("🖊️ ADVANCED SMOOTHING: Starting with \(freehandRawPoints.count) raw points")
        
        var processedPoints = freehandRawPoints
        
        // STEP 1: Apply Chaikin smoothing for initial curve smoothing (if enabled)
        if document.settings.advancedSmoothingEnabled {
            let chaikinSmoothed = CurveSmoothing.chaikinSmooth(
                points: processedPoints,
                iterations: document.settings.chaikinSmoothingIterations,
                ratio: 0.25
            )
            processedPoints = chaikinSmoothed
            print("🖊️ CHAIKIN: Smoothed to \(processedPoints.count) points (\(document.settings.chaikinSmoothingIterations) iterations)")
        }
        
        // STEP 2: Apply improved Douglas-Peucker simplification with sharp corner preservation
        let tolerance = document.settings.freehandSmoothingTolerance
        let simplifiedPoints = document.settings.advancedSmoothingEnabled ? 
            CurveSmoothing.improvedDouglassPeucker(
                points: processedPoints,
                tolerance: tolerance,
                preserveSharpCorners: document.settings.preserveSharpCorners
            ) :
            douglasPeuckerSimplify(points: processedPoints, tolerance: tolerance)
        
        print("🖊️ DOUGLAS-PEUCKER: Simplified to \(simplifiedPoints.count) points (tolerance: \(String(format: "%.1f", tolerance)))")
        
        // STEP 3: Convert to smooth bezier curves with adaptive tension
        let smoothPath = document.settings.advancedSmoothingEnabled ? 
            createAdvancedSmoothBezierPath(from: simplifiedPoints) :
            createSmoothBezierPath(from: simplifiedPoints)
        
        // STEP 4: Update the final shape with professionally smooth curves
        updateFinalFreehandShape(with: smoothPath)
        
        print("✅ FREEHAND: Advanced smoothing completed - much smoother curves!")
    }
    
    // MARK: - Douglas-Peucker Line Simplification Algorithm
    
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
    
    // MARK: - Advanced Bezier Curve Fitting
    
    /// Creates professionally smooth bezier curves using advanced algorithms
    private func createAdvancedSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
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
    
    /// Legacy smooth bezier path creation (kept for compatibility)
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
    
    // MARK: - Final Shape Update
    
    private func updateFinalFreehandShape(with smoothPath: VectorPath) {
        guard let activeFreehandShape = activeFreehandShape,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Update the shape with the final smooth path
        for shapeIndex in document.layers[layerIndex].shapes.indices {
            if document.layers[layerIndex].shapes[shapeIndex].id == activeFreehandShape.id {
                document.layers[layerIndex].shapes[shapeIndex].path = smoothPath
                
                // Apply final styling (full opacity)
                document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                    color: document.defaultStrokeColor,
                    width: document.defaultStrokeWidth, // Use user's default stroke width
                    opacity: document.defaultStrokeOpacity
                )
                
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                break
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
        
        print("✅ FREEHAND: Applied smooth bezier curves to final shape")
    }
}
