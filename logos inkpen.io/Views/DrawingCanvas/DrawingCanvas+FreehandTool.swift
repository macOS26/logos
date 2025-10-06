//
//  DrawingCanvas+FreehandTool.swift
//  logos inkpen.io
//
//  Freehand drawing tool with professional curve fitting
//

import SwiftUI
import SwiftUI

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
        
        // Create real VectorShape using CURRENT stroke/fill settings (not defaults!)
        let strokeStyle = StrokeStyle(
            color: getCurrentStrokeColor(), // Use current stroke color from UI
            width: getCurrentStrokeWidth(), // Use current stroke width from UI
            lineCap: .round, // Always use round caps for freehand
            lineJoin: .round, // Always use round joins for freehand
            miterLimit: document.defaultStrokeMiterLimit, // Use user's default miter limit
            opacity: getCurrentStrokeOpacity() // Use current stroke opacity from UI
        )
        // Use fill mode setting to determine fill style
        let fillStyle: FillStyle? = document.freehandFillMode == .fill
            ? FillStyle(color: getCurrentFillColor(), opacity: getCurrentFillOpacity())
            : nil

        activeFreehandShape = VectorShape(
            name: "Freehand Path",
            path: freehandPath!,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        // VECTOR APP OPTIMIZATION: Don't add to document during drawing - use overlay system
        // Shape will be added only when drawing is complete
        
    }
    
    internal func handleFreehandDragUpdate(at location: CGPoint) {
        guard isFreehandDrawing else { return }
        
        // 🚀 OPTIMIZED: Track drawing performance
        MetalDrawingOptimizer.shared.trackDrawingStart()
        
        // Apply real-time smoothing for immediate visual feedback (if enabled)
        let smoothedLocation: CGPoint
        if document.advancedSmoothingEnabled && document.realTimeSmoothingEnabled {
            smoothedLocation = RealTimeSmoothing.applyRealTimeSmoothing(
                newPoint: location,
                recentPoints: &freehandRealtimeSmoothingPoints,
                windowSize: 5,
                strength: document.realTimeSmoothingStrength
            )
        } else {
            smoothedLocation = location
        }
        
        // Add both original and smoothed points (use smoothed for preview)
        freehandRawPoints.append(location)  // Keep original for final processing
        
        // 🚀 OPTIMIZED: Prevent memory bloat and CPU overload
        MetalDrawingOptimizer.shared.optimizePointCollection(&freehandRawPoints, maxPoints: 500)
        
        // Update real-time preview with smoothed location
        updateFreehandPreview(smoothedLocation: smoothedLocation)
    }
    
    internal func handleFreehandDragEnd() {
        guard isFreehandDrawing else { return }


        // Apply curve fitting algorithms to create smooth bezier curves
        processFreehandPath()

        // Clean up state including clearing preview path for overlay system
        freehandPreviewPath = nil
        cancelFreehandDrawing()

        // AUTO-DESELECT: Clear selection AFTER shape is added
        // MUST happen after processFreehandPath since that selects the shape
        document.selectedShapeIDs.removeAll()
        document.selectedObjectIDs.removeAll()

    }
    
    // MARK: - Real-time Preview
    
    private func updateFreehandPreview(smoothedLocation: CGPoint? = nil) {
        // VECTOR APP OPTIMIZATION: Direct overlay update - no throttling for 60fps
        guard freehandRawPoints.count >= 2 else { return }
        
        // Create simple line preview for real-time feedback
        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(freehandRawPoints[0])))
        
        for i in 1..<freehandRawPoints.count {
            elements.append(.line(to: VectorPoint(freehandRawPoints[i])))
        }
        
        let previewPath = VectorPath(elements: elements)
        freehandPreviewPath = previewPath
        
        // No document updates during drawing - overlay handles all preview rendering
    }
    
    // MARK: - Professional Curve Fitting with Advanced Smoothing
    
    private func processFreehandPath() {
        guard freehandRawPoints.count >= 3 else {
            return
        }
        
        
        var processedPoints = freehandRawPoints
        
        // STEP 1: Apply Chaikin smoothing for initial curve smoothing (if enabled)
        if document.advancedSmoothingEnabled {
            let chaikinSmoothed = CurveSmoothing.chaikinSmooth(
                points: processedPoints,
                iterations: document.chaikinSmoothingIterations,
                ratio: 0.25
            )
            processedPoints = chaikinSmoothed
        }
        
        // STEP 2: 🚀 OPTIMIZED Douglas-Peucker simplification (Metal-accelerated when possible)
        let tolerance = document.freehandSmoothingTolerance
        let cgPoints = processedPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let optimizedCGPoints = MetalDrawingOptimizer.shared.optimizeFreehandDrawing(points: cgPoints, tolerance: tolerance)
        let simplifiedPoints = optimizedCGPoints.map { VectorPoint($0) }
        
        
        // STEP 3: Convert to smooth bezier curves with adaptive tension
        let finalCGPoints = simplifiedPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let smoothPath = document.advancedSmoothingEnabled ?
            createAdvancedSmoothBezierPath(from: finalCGPoints) :
            DrawingCanvasPathHelpers.createSmoothBezierPath(from: finalCGPoints)
        
        // STEP 4: Update the final shape with professionally smooth curves
        updateFinalFreehandShape(with: smoothPath)
        
    }
    
    // MARK: - Douglas-Peucker Line Simplification Algorithm
    // These functions have been moved to DrawingCanvasPathHelpers
    
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

        // Close path if option is enabled
        if document.freehandClosePath {
            elements.append(.close)
        }

        return VectorPath(elements: elements)
    }
    
    /// Legacy smooth bezier path creation (kept for compatibility)
    private func createSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
        return DrawingCanvasPathHelpers.createSmoothBezierPath(from: points)
    }
    
    // MARK: - Final Shape Update
    
    private func updateFinalFreehandShape(with smoothPath: VectorPath) {
        // Get current colors
        var strokeColor = getCurrentStrokeColor()
        var fillColor = getCurrentFillColor()

        // Apply freehand-specific color rules:
        // If stroke is none/clear, use fill color for stroke
        if strokeColor == .clear {
            strokeColor = fillColor
        }

        // If fill is none/clear, use red (5th color = index 4) for fill and blue (4th color = index 3) for stroke
        if fillColor == .clear {
            // Use RGB swatches: index 4 is red, index 3 is blue
            let rgbSwatches = ColorManager.shared.colorDefaults.rgbSwatches
            if rgbSwatches.count > 4 {
                fillColor = rgbSwatches[4] // Red (5th swatch)
                strokeColor = rgbSwatches[3] // Blue (4th swatch)
            }
        }

        // Create and add the final freehand shape using adjusted colors
        let strokeStyle = StrokeStyle(
            color: strokeColor,
            width: getCurrentStrokeWidth(), // Use current stroke width from UI
            lineCap: .round, // Always use round caps for freehand
            lineJoin: .round, // Always use round joins for freehand
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: getCurrentStrokeOpacity() // Use current stroke opacity from UI
        )

        // Use fill mode setting to determine fill style
        let fillStyle: FillStyle? = document.freehandFillMode == .fill
            ? FillStyle(color: fillColor, opacity: getCurrentFillOpacity())
            : nil

        // Check if we need to expand stroke to outline
        if document.freehandExpandStroke {
            // Convert stroke to filled outline path
            if let expandedPath = PathOperations.outlineStroke(
                path: smoothPath.cgPath,
                strokeStyle: strokeStyle
            ) {
                // Create shape with expanded path as fill, no stroke
                let expandedShape = VectorShape(
                    name: "Freehand Path",
                    path: VectorPath(cgPath: expandedPath),
                    strokeStyle: nil, // No stroke since it's now a filled outline
                    fillStyle: FillStyle(
                        color: strokeStyle.color,
                        opacity: strokeStyle.opacity
                    )
                )
                document.addShapeToFront(expandedShape)
            } else {
                // Fallback to regular shape if expansion fails
                let finalShape = VectorShape(
                    name: "Freehand Path",
                    path: smoothPath,
                    strokeStyle: strokeStyle,
                    fillStyle: fillStyle
                )
                document.addShapeToFront(finalShape)
            }
        } else {
            // Regular shape without expansion
            let finalShape = VectorShape(
                name: "Freehand Path",
                path: smoothPath,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            document.addShapeToFront(finalShape)
        }
        
    }
}
