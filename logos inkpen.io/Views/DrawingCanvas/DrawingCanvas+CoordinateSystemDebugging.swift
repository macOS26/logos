//
//  DrawingCanvas+CoordinateSystemDebugging.swift
//  logos inkpen.io
//
//  Coordinate system debugging functionality
//

import SwiftUI

extension DrawingCanvas {
    // MARK: - COORDINATE SYSTEM DEBUGGING AND TESTING
    // Use Cmd+Shift+T to analyze coordinate system consistency
    
    /// COMPREHENSIVE DRAWING TEST - Run this to debug coordinate system issues
    /// Use Cmd+Shift+R to run this test
    internal func runRealDrawingTest(geometry: GeometryProxy) {
        Log.fileOperation("🔥 REAL DRAWING TEST - TRACKING COORDINATE SYSTEM CHANGES", level: .info)
        Log.info("=" + String(repeating: "=", count: 80), category: .general)
        
        // Log initial state
        Log.fileOperation("📊 INITIAL STATE:", level: .info)
        Log.info("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))", category: .general)
        Log.info("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))", category: .general)
        Log.info("   Initial Zoom Level: \(String(format: "%.6f", initialZoomLevel))", category: .general)
        Log.info("   Is Drawing: \(isDrawing)", category: .general)
        Log.info("   Is Bezier Drawing: \(isBezierDrawing)", category: .general)
        
        // Clear any existing shapes
        if !document.layers.isEmpty {
            document.removeShapesUnified(layerIndex: 0, where: { _ in true })
        }
        
        // Create a test shape at a known position
        let testCenter = CGPoint(x: 300, y: 250)
        let testShape = VectorShape(
            name: "TEST SHAPE",
            path: createCirclePath(center: testCenter, radius: 30),
            strokeStyle: StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), width: 3, placement: .center),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), opacity: 0.8)
        )
        
        Log.info("📍 CREATING TEST SHAPE:", category: .general)
        Log.info("   Expected center: (\(testCenter.x), \(testCenter.y))", category: .general)
        
        // Log state before adding shape
        Log.fileOperation("📊 BEFORE ADDING SHAPE:", level: .info)
        Log.info("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))", category: .general)
        Log.info("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))", category: .general)
        
        // Add the shape
        document.addShape(testShape)
        
        // Log state after adding shape
        Log.fileOperation("📊 AFTER ADDING SHAPE:", level: .info)
        Log.info("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))", category: .general)
        Log.info("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))", category: .general)
        
        // Verify the shape's actual position
        let shapes = document.getShapesForLayer(0)
        if let addedShape = shapes.first(where: { $0.name == "TEST SHAPE" }) {
            let actualCenter = CGPoint(
                x: (addedShape.bounds.minX + addedShape.bounds.maxX) / 2,
                y: (addedShape.bounds.minY + addedShape.bounds.maxY) / 2
            )
            
            Log.info("📍 SHAPE VERIFICATION:", category: .general)
            Log.info("   Expected center: (\(String(format: "%.6f", testCenter.x)), \(String(format: "%.6f", testCenter.y)))", category: .general)
            Log.info("   Actual center: (\(String(format: "%.6f", actualCenter.x)), \(String(format: "%.6f", actualCenter.y)))", category: .general)
            
            let deltaX = abs(actualCenter.x - testCenter.x)
            let deltaY = abs(actualCenter.y - testCenter.y)
            
            if deltaX < 0.1 && deltaY < 0.1 {
                Log.info("   ✅ SHAPE POSITION CORRECT", category: .general)
            } else {
                Log.error("   ❌ SHAPE POSITION DRIFT: ΔX=\(String(format: "%.6f", deltaX)), ΔY=\(String(format: "%.6f", deltaY))", category: .error)
            }
        }
        
        // Now simulate drawing operations to see if coordinate system changes
        Log.fileOperation("🎨 SIMULATING DRAWING OPERATIONS:", level: .info)
        
        // Simulate start drawing
        isDrawing = true
        Log.fileOperation("📊 DURING DRAWING (isDrawing = true):", level: .info)
        Log.info("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))", category: .general)
        Log.info("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))", category: .general)
        Log.info("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)", category: .general)
        
        // Create a drawing preview to see if coordinate system shifts
        let previewStart = CGPoint(x: 200, y: 200)
        let previewEnd = CGPoint(x: 400, y: 300)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(previewStart)),
            .line(to: VectorPoint(previewEnd))
        ])
        
        Log.info("📍 DRAWING PREVIEW CREATED:", category: .general)
        Log.info("   Preview start: (\(String(format: "%.6f", previewStart.x)), \(String(format: "%.6f", previewStart.y)))", category: .general)
        Log.info("   Preview end: (\(String(format: "%.6f", previewEnd.x)), \(String(format: "%.6f", previewEnd.y)))", category: .general)
        
        // Log state with drawing preview
        Log.fileOperation("📊 WITH DRAWING PREVIEW:", level: .info)
        Log.info("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))", category: .general)
        Log.info("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))", category: .general)
        
        // Simulate end drawing
        isDrawing = false
        currentPath = nil
        
        Log.fileOperation("📊 AFTER DRAWING (isDrawing = false):", level: .info)
        Log.info("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))", category: .general)
        Log.info("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))", category: .general)
        Log.info("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)", category: .general)
        
        // Test coordinate conversion consistency
        Log.fileOperation("🔄 COORDINATE CONVERSION TEST:", level: .info)
        let testCanvasPoint = CGPoint(x: 300, y: 200)
        let screenPoint = canvasToScreen(testCanvasPoint, geometry: geometry)
        let backToCanvas = screenToCanvas(screenPoint, geometry: geometry)
        
        Log.info("   Canvas → Screen → Canvas:", category: .general)
        Log.info("   Original: (\(String(format: "%.6f", testCanvasPoint.x)), \(String(format: "%.6f", testCanvasPoint.y)))", category: .general)
        Log.info("   Screen: (\(String(format: "%.6f", screenPoint.x)), \(String(format: "%.6f", screenPoint.y)))", category: .general)
        Log.info("   Back to Canvas: (\(String(format: "%.6f", backToCanvas.x)), \(String(format: "%.6f", backToCanvas.y)))", category: .general)
        
        let conversionDeltaX = abs(backToCanvas.x - testCanvasPoint.x)
        let conversionDeltaY = abs(backToCanvas.y - testCanvasPoint.y)
        
        if conversionDeltaX < 0.001 && conversionDeltaY < 0.001 {
            Log.info("   ✅ COORDINATE CONVERSION ACCURATE", category: .general)
        } else {
            Log.error("   ❌ COORDINATE CONVERSION DRIFT: ΔX=\(String(format: "%.6f", conversionDeltaX)), ΔY=\(String(format: "%.6f", conversionDeltaY))", category: .error)
        }
        
        Log.info("=" + String(repeating: "=", count: 80), category: .general)
        Log.info("🏁 TEST COMPLETE - Check above for coordinate system issues", category: .general)
    }
} 