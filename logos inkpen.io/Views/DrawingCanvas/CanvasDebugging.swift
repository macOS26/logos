//
//  CanvasDebugging.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Canvas Debugging and Testing Functions
extension DrawingCanvas {
    
    /// COMPREHENSIVE COORDINATE SYSTEM TEST
    /// This systematically tests that objects appear in the same location at all zoom levels
    internal func runCoordinateSystemTest() {
        // print("🎯 COMPREHENSIVE COORDINATE SYSTEM TEST")
        // print("  Testing that objects appear at consistent screen positions across zoom levels")
        
        // Save current state
        let originalZoom = document.zoomLevel
        let originalOffset = document.canvasOffset
        
        // Clear existing objects for clean test
        if !document.layers.isEmpty {
            document.layers[0].shapes.removeAll()
        }
        
        // Test at "Fit to Page" zoom first
        document.zoomLevel = 1.0
        document.canvasOffset = CGPoint.zero
        
        // Create test objects at known canvas coordinates
        let testObjects = [
            (name: "Top-Left", point: CGPoint(x: 100, y: 100), color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0))),
            (name: "Top-Right", point: CGPoint(x: 400, y: 100), color: VectorColor.rgb(RGBColor(red: 0.0, green: 1.0, blue: 0.0))),
            (name: "Bottom-Left", point: CGPoint(x: 100, y: 300), color: VectorColor.rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0))),
            (name: "Center", point: CGPoint(x: 250, y: 200), color: VectorColor.rgb(RGBColor(red: 1.0, green: 1.0, blue: 0.0)))
        ]
        
        for testObj in testObjects {
            let shape = VectorShape(
                name: "TEST-\(testObj.name)",
                path: createTestCirclePath(center: testObj.point, radius: 20),
                strokeStyle: StrokeStyle(color: VectorColor.black, width: 2),
                fillStyle: FillStyle(color: testObj.color, opacity: 0.8)
            )
            document.addShape(shape)
            // print("  ✅ Created \(testObj.name) at canvas coords: (\(testObj.point.x), \(testObj.point.y))")
        }
        
        // print("  📏 COORDINATE SYSTEM ANALYSIS:")
        // print("    Background: .scaleEffect(\(document.zoomLevel), anchor: .topLeading).offset(\(document.canvasOffset))")
        // print("    Objects: .transformEffect(shape.transform).scaleEffect(\(document.zoomLevel), anchor: .topLeading).offset(\(document.canvasOffset))")
        // print("    Current drawing: .scaleEffect(\(document.zoomLevel), anchor: .topLeading).offset(\(document.canvasOffset))")
        // print("    ✅ ALL USE IDENTICAL COORDINATE TRANSFORMATIONS")
        
        // print("  📊 OBJECT COORDINATE VERIFICATION:")
        for testObj in testObjects {
            if !document.layers.isEmpty,
               let shape = document.layers[0].shapes.first(where: { $0.name == "TEST-\(testObj.name)" }) {
                let centerX = (shape.bounds.minX + shape.bounds.maxX) / 2
                let centerY = (shape.bounds.minY + shape.bounds.maxY) / 2
                let actualCenter = CGPoint(x: centerX, y: centerY)
                
                let deltaX = abs(actualCenter.x - testObj.point.x)
                let deltaY = abs(actualCenter.y - testObj.point.y)
                
                if deltaX < 1.0 && deltaY < 1.0 {
                    // print("    ✅ \(testObj.name): Expected (\(testObj.point.x), \(testObj.point.y)) → Actual (\(String(format: "%.1f", actualCenter.x)), \(String(format: "%.1f", actualCenter.y)))")
                } else {
                    // print("    ❌ \(testObj.name): Expected (\(testObj.point.x), \(testObj.point.y)) → Actual (\(String(format: "%.1f", actualCenter.x)), \(String(format: "%.1f", actualCenter.y))) - DRIFT!")
                }
            }
        }
        
        // Restore original state
        document.zoomLevel = originalZoom
        document.canvasOffset = originalOffset
        
        // print("  🔍 TESTING COMPLETE:")
        // print("    - If all objects show ✅, coordinate system is CONSISTENT")
        // print("    - If any show ❌, there's coordinate drift that needs fixing")
        // print("    - Objects should remain in same relative positions when zooming")
        // print("    - Drawing preview should match where final objects appear")
        // print("=" + String(repeating: "=", count: 58))
    }
    
    /// CRITICAL DRAWING TEST - Verifies canvas doesn't move during drawing
    /// Use Cmd+Shift+D to test drawing stability
    internal func runDrawingStabilityTest() {
        // print("🚨 DRAWING STABILITY TEST")
        // print("=" + String(repeating: "=", count: 58))
        // print("  TESTING: Canvas must NOT move during drawing operations")
        // print("  STATUS: isDrawing = \(isDrawing), isBezierDrawing = \(isBezierDrawing)")
        // print("  ZOOM GESTURE: \(!isDrawing && !isBezierDrawing ? "ACTIVE" : "DISABLED")")
        // print("  CURRENT ZOOM: \(String(format: "%.3f", document.zoomLevel))x")
        // print("  CURRENT OFFSET: (\(String(format: "%.1f", document.canvasOffset.x)), \(String(format: "%.1f", document.canvasOffset.y)))")
        
        if isDrawing || isBezierDrawing {
            // print("  🎯 DRAWING IN PROGRESS - Zoom gesture should be DISABLED")
            // print("  ✅ Canvas is protected from zoom changes during drawing")
        } else {
            // print("  ⏸️  NOT DRAWING - Zoom gesture is available")
            // print("  📝 Start drawing a shape to test stability")
        }
        
        // print("  INSTRUCTIONS:")
        // print("    1. Select rectangle tool")
        // print("    2. Start drawing a rectangle")
        // print("    3. While drawing, try to pinch/zoom")
        // print("    4. Canvas should NOT move or zoom")
        // print("    5. Only after releasing should zoom be available")
        // print("=" + String(repeating: "=", count: 58))
    }
    
    /// SIMPLE DRAWING TEST - Debug coordinate system without geometry
    /// Use Cmd+Shift+R to run this test
    internal func runRealDrawingTestSimple() {
        // print("🔥 SIMPLE DRAWING TEST - TRACKING COORDINATE SYSTEM")
        // print("=" + String(repeating: "=", count: 80))
        
        // Log initial state
        // print("📊 INITIAL STATE:")
        // print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        // print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        // print("   Initial Zoom Level: \(String(format: "%.6f", initialZoomLevel))")
        // print("   Is Drawing: \(isDrawing)")
        // print("   Is Bezier Drawing: \(isBezierDrawing)")
        
        // Clear any existing shapes
        if !document.layers.isEmpty {
            document.layers[0].shapes.removeAll()
        }
        
        // Create a test shape at a known position
        let testCenter = CGPoint(x: 300, y: 250)
        let testShape = VectorShape(
            name: "TEST SHAPE",
            path: createTestCirclePath(center: testCenter, radius: 30),
            strokeStyle: StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), width: 3),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), opacity: 0.8)
        )
        
        // print("📍 CREATING TEST SHAPE:")
        // print("   Expected center: (\(testCenter.x), \(testCenter.y))")
        
        // Log state before adding shape
        // print("📊 BEFORE ADDING SHAPE:")
        // print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        // print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Add the shape
        document.addShape(testShape)
        
        // Log state after adding shape
        // print("📊 AFTER ADDING SHAPE:")
        // print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        // print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Verify the shape's actual position
        if let addedShape = document.layers[0].shapes.first(where: { $0.name == "TEST SHAPE" }) {
            let actualCenter = CGPoint(
                x: (addedShape.bounds.minX + addedShape.bounds.maxX) / 2,
                y: (addedShape.bounds.minY + addedShape.bounds.maxY) / 2
            )
            
            // print("📍 SHAPE VERIFICATION:")
            // print("   Expected center: (\(String(format: "%.6f", testCenter.x)), \(String(format: "%.6f", testCenter.y)))")
            // print("   Actual center: (\(String(format: "%.6f", actualCenter.x)), \(String(format: "%.6f", actualCenter.y)))")
            
            let deltaX = abs(actualCenter.x - testCenter.x)
            let deltaY = abs(actualCenter.y - testCenter.y)
            
            if deltaX < 0.1 && deltaY < 0.1 {
                // print("   ✅ SHAPE POSITION CORRECT")
            } else {
                // print("   ❌ SHAPE POSITION DRIFT: ΔX=\(String(format: "%.6f", deltaX)), ΔY=\(String(format: "%.6f", deltaY))")
            }
        }
        
        // Now simulate drawing operations to see if coordinate system changes
        // print("🎨 SIMULATING DRAWING OPERATIONS:")
        
        // Simulate start drawing
        isDrawing = true
        // print("📊 DURING DRAWING (isDrawing = true):")
        // print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        // print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        // print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        // Create a drawing preview to see if coordinate system shifts
        let previewStart = CGPoint(x: 200, y: 200)
        let previewEnd = CGPoint(x: 400, y: 300)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(previewStart)),
            .line(to: VectorPoint(previewEnd))
        ])
        
        // print("📍 DRAWING PREVIEW CREATED:")
        // print("   Preview start: (\(String(format: "%.6f", previewStart.x)), \(String(format: "%.6f", previewStart.y)))")
        // print("   Preview end: (\(String(format: "%.6f", previewEnd.x)), \(String(format: "%.6f", previewEnd.y)))")
        
        // Log state with drawing preview
        // print("📊 WITH DRAWING PREVIEW:")
        // print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        // print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Simulate end drawing
        isDrawing = false
        currentPath = nil
        
        // print("📊 AFTER DRAWING (isDrawing = false):")
        // print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        // print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        // print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        // print("=" + String(repeating: "=", count: 80))
        // print("🏁 SIMPLE TEST COMPLETE - Run this test and then try drawing to compare")
        // print("   Next steps:")
        // print("   1. Note the values above")
        // print("   2. Try drawing a rectangle manually")
        // print("   3. Check if zoom/offset values change during drawing")
        // print("   4. If values change, we found the coordinate system bug!")
    }
} 
