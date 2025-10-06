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
        
        // Log initial state
        Log.fileOperation("📊 INITIAL STATE:", level: .info)
        
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
        
        
        // Log state before adding shape
        Log.fileOperation("📊 BEFORE ADDING SHAPE:", level: .info)
        
        // Add the shape
        document.addShape(testShape)
        
        // Log state after adding shape
        Log.fileOperation("📊 AFTER ADDING SHAPE:", level: .info)
        
        // Verify the shape's actual position
        let shapes = document.getShapesForLayer(0)
        if let addedShape = shapes.first(where: { $0.name == "TEST SHAPE" }) {
            let actualCenter = CGPoint(
                x: (addedShape.bounds.minX + addedShape.bounds.maxX) / 2,
                y: (addedShape.bounds.minY + addedShape.bounds.maxY) / 2
            )
            
            
            let deltaX = abs(actualCenter.x - testCenter.x)
            let deltaY = abs(actualCenter.y - testCenter.y)
            
            if deltaX < 0.1 && deltaY < 0.1 {
            } else {
                Log.error("   ❌ SHAPE POSITION DRIFT: ΔX=\(String(format: "%.6f", deltaX)), ΔY=\(String(format: "%.6f", deltaY))", category: .error)
            }
        }
        
        // Now simulate drawing operations to see if coordinate system changes
        Log.fileOperation("🎨 SIMULATING DRAWING OPERATIONS:", level: .info)
        
        // Simulate start drawing
        isDrawing = true
        Log.fileOperation("📊 DURING DRAWING (isDrawing = true):", level: .info)
        
        // Create a drawing preview to see if coordinate system shifts
        let previewStart = CGPoint(x: 200, y: 200)
        let previewEnd = CGPoint(x: 400, y: 300)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(previewStart)),
            .line(to: VectorPoint(previewEnd))
        ])
        
        
        // Log state with drawing preview
        Log.fileOperation("📊 WITH DRAWING PREVIEW:", level: .info)
        
        // Simulate end drawing
        isDrawing = false
        currentPath = nil
        
        Log.fileOperation("📊 AFTER DRAWING (isDrawing = false):", level: .info)
        
        // Test coordinate conversion consistency
        Log.fileOperation("🔄 COORDINATE CONVERSION TEST:", level: .info)
        let testCanvasPoint = CGPoint(x: 300, y: 200)
        let screenPoint = canvasToScreen(testCanvasPoint, geometry: geometry)
        let backToCanvas = screenToCanvas(screenPoint, geometry: geometry)
        
        
        let conversionDeltaX = abs(backToCanvas.x - testCanvasPoint.x)
        let conversionDeltaY = abs(backToCanvas.y - testCanvasPoint.y)
        
        if conversionDeltaX < 0.001 && conversionDeltaY < 0.001 {
        } else {
            Log.error("   ❌ COORDINATE CONVERSION DRIFT: ΔX=\(String(format: "%.6f", conversionDeltaX)), ΔY=\(String(format: "%.6f", conversionDeltaY))", category: .error)
        }
        
    }
} 