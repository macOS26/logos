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
        print("🔥 REAL DRAWING TEST - TRACKING COORDINATE SYSTEM CHANGES")
        print("=" + String(repeating: "=", count: 80))
        
        // Log initial state
        print("📊 INITIAL STATE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Initial Zoom Level: \(String(format: "%.6f", initialZoomLevel))")
        print("   Is Drawing: \(isDrawing)")
        print("   Is Bezier Drawing: \(isBezierDrawing)")
        
        // Clear any existing shapes
        if !document.layers.isEmpty {
            document.layers[0].shapes.removeAll()
        }
        
        // Create a test shape at a known position
        let testCenter = CGPoint(x: 300, y: 250)
        let testShape = VectorShape(
            name: "TEST SHAPE",
            path: createCirclePath(center: testCenter, radius: 30),
            strokeStyle: StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), width: 3),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), opacity: 0.8)
        )
        
        print("📍 CREATING TEST SHAPE:")
        print("   Expected center: (\(testCenter.x), \(testCenter.y))")
        
        // Log state before adding shape
        print("📊 BEFORE ADDING SHAPE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Add the shape
        document.addShape(testShape)
        
        // Log state after adding shape
        print("📊 AFTER ADDING SHAPE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Verify the shape's actual position
        if let addedShape = document.layers[0].shapes.first(where: { $0.name == "TEST SHAPE" }) {
            let actualCenter = CGPoint(
                x: (addedShape.bounds.minX + addedShape.bounds.maxX) / 2,
                y: (addedShape.bounds.minY + addedShape.bounds.maxY) / 2
            )
            
            print("📍 SHAPE VERIFICATION:")
            print("   Expected center: (\(String(format: "%.6f", testCenter.x)), \(String(format: "%.6f", testCenter.y)))")
            print("   Actual center: (\(String(format: "%.6f", actualCenter.x)), \(String(format: "%.6f", actualCenter.y)))")
            
            let deltaX = abs(actualCenter.x - testCenter.x)
            let deltaY = abs(actualCenter.y - testCenter.y)
            
            if deltaX < 0.1 && deltaY < 0.1 {
                print("   ✅ SHAPE POSITION CORRECT")
            } else {
                print("   ❌ SHAPE POSITION DRIFT: ΔX=\(String(format: "%.6f", deltaX)), ΔY=\(String(format: "%.6f", deltaY))")
            }
        }
        
        // Now simulate drawing operations to see if coordinate system changes
        print("🎨 SIMULATING DRAWING OPERATIONS:")
        
        // Simulate start drawing
        isDrawing = true
        print("📊 DURING DRAWING (isDrawing = true):")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        // Create a drawing preview to see if coordinate system shifts
        let previewStart = CGPoint(x: 200, y: 200)
        let previewEnd = CGPoint(x: 400, y: 300)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(previewStart)),
            .line(to: VectorPoint(previewEnd))
        ])
        
        print("📍 DRAWING PREVIEW CREATED:")
        print("   Preview start: (\(String(format: "%.6f", previewStart.x)), \(String(format: "%.6f", previewStart.y)))")
        print("   Preview end: (\(String(format: "%.6f", previewEnd.x)), \(String(format: "%.6f", previewEnd.y)))")
        
        // Log state with drawing preview
        print("📊 WITH DRAWING PREVIEW:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Simulate end drawing
        isDrawing = false
        currentPath = nil
        
        print("📊 AFTER DRAWING (isDrawing = false):")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        // Test coordinate conversion consistency
        print("🔄 COORDINATE CONVERSION TEST:")
        let testCanvasPoint = CGPoint(x: 300, y: 200)
        let screenPoint = canvasToScreen(testCanvasPoint, geometry: geometry)
        let backToCanvas = screenToCanvas(screenPoint, geometry: geometry)
        
        print("   Canvas → Screen → Canvas:")
        print("   Original: (\(String(format: "%.6f", testCanvasPoint.x)), \(String(format: "%.6f", testCanvasPoint.y)))")
        print("   Screen: (\(String(format: "%.6f", screenPoint.x)), \(String(format: "%.6f", screenPoint.y)))")
        print("   Back to Canvas: (\(String(format: "%.6f", backToCanvas.x)), \(String(format: "%.6f", backToCanvas.y)))")
        
        let conversionDeltaX = abs(backToCanvas.x - testCanvasPoint.x)
        let conversionDeltaY = abs(backToCanvas.y - testCanvasPoint.y)
        
        if conversionDeltaX < 0.001 && conversionDeltaY < 0.001 {
            print("   ✅ COORDINATE CONVERSION ACCURATE")
        } else {
            print("   ❌ COORDINATE CONVERSION DRIFT: ΔX=\(String(format: "%.6f", conversionDeltaX)), ΔY=\(String(format: "%.6f", conversionDeltaY))")
        }
        
        print("=" + String(repeating: "=", count: 80))
        print("🏁 TEST COMPLETE - Check above for coordinate system issues")
    }
} 