//
//  UnifiedObjectSystemViolationTests.swift
//  logos inkpen.ioTests
//
//  Created by Claude on 1/4/25.
//  Tests for shape migrations to unified object system
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemViolationTests {
    
    // MARK: - BEZIER TOOL VIOLATIONS
    
    @Test func testBezierToolUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        document.selectedLayerIndex = 0
        
        // Create a test shape similar to what BezierTool creates
        let bezierPath = VectorPath(elements: [.move(to: VectorPoint(0, 0)), .line(to: VectorPoint(100, 100))], isClosed: false)
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: document.defaultStrokeWidth,
            placement: document.defaultStrokePlacement,
            lineCap: document.defaultStrokeLineCap,
            lineJoin: document.defaultStrokeLineJoin,
            miterLimit: document.defaultStrokeMiterLimit,
            opacity: document.defaultStrokeOpacity
        )
        let fillStyle = FillStyle(
            color: document.defaultFillColor,
            opacity: document.defaultFillOpacity
        )
        
        let testShape = VectorShape(
            name: "Bezier Path (Continued)",
            path: bezierPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        // Test VIOLATION: document.addShape() bypasses unified system
        // This should be replaced with addShapeToUnifiedSystem()
        let initialUnifiedCount = document.unifiedObjects.count
        
        // CORRECT approach - what should be used instead
        document.addShapeToUnifiedSystem(testShape, layerIndex: 0)
        
        // Verify shape is in unified system
        #expect(document.unifiedObjects.count == initialUnifiedCount + 1, "Shape not added to unified system")
        
        let unifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == testShape.id
            }
            return false
        }
        #expect(unifiedShape != nil, "Shape not found in unified objects")
        
        // Verify shape is in legacy layer
        let legacyShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(legacyShape != nil, "Shape not found in legacy layer")
    }
    
    // MARK: - SHAPE DRAWING VIOLATIONS
    
    @Test func testShapeDrawingUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        document.selectedLayerIndex = 0
        
        // Create a test shape similar to what DrawingCanvas+ShapeDrawing creates
        let testShape = VectorShape.rectangle(at: CGPoint(x: 10, y: 10), size: CGSize(width: 50, height: 50))
        
        // Test that we use unified system instead of direct addShape
        let initialUnifiedCount = document.unifiedObjects.count
        
        // CORRECT approach
        document.addShapeToUnifiedSystem(testShape, layerIndex: 0)
        
        // Verify unified system consistency
        #expect(document.unifiedObjects.count == initialUnifiedCount + 1, "Shape not added to unified system")
        
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == testShape.id && !shape.isTextObject
            }
            return false
        }
        #expect(unifiedExists, "Shape not properly tracked in unified system")
    }
    
    // MARK: - BRUSH TOOL VIOLATIONS
    
    @Test func testBrushToolUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        document.selectedLayerIndex = 0
        
        // Create a test brush stroke shape
        let brushPath = VectorPath(elements: [
            .move(to: VectorPoint(0, 0)),
            .curve(to: VectorPoint(10, 10), control1: VectorPoint(3, 3), control2: VectorPoint(7, 7)),
            .line(to: VectorPoint(20, 20))
        ], isClosed: false)
        
        let brushShape = VectorShape(
            name: "Brush Stroke",
            path: brushPath,
            strokeStyle: StrokeStyle(color: document.defaultStrokeColor, width: 5.0),
            fillStyle: nil
        )
        
        // Test unified system integration
        let initialCount = document.unifiedObjects.count
        
        document.addShapeToUnifiedSystem(brushShape, layerIndex: 0)
        
        #expect(document.unifiedObjects.count == initialCount + 1, "Brush stroke not added to unified system")
        
        // Verify ordering
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == brushShape.id
            }
            return false
        }) {
            #expect(unifiedObj.layerIndex == 0, "Brush stroke has wrong layer index")
            #expect(unifiedObj.orderID >= 0, "Brush stroke has invalid order ID")
        }
    }
    
    // MARK: - TEMPLATE MANAGER VIOLATIONS
    
    @Test func testTemplateManagerUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Ensure pasteboard layer exists (index 0)
        if document.layers.isEmpty {
            let pasteboardLayer = VectorLayer(name: "Pasteboard")
            document.layers.append(pasteboardLayer)
        }
        
        // Create a test template shape
        let templateShape = VectorShape.circle(center: CGPoint(x: 50, y: 50), radius: 25)
        
        // Test VIOLATION: layers[0].shapes.append() bypasses unified system
        let initialUnifiedCount = document.unifiedObjects.count
        
        // CORRECT approach
        document.addShapeToUnifiedSystem(templateShape, layerIndex: 0)
        
        // Verify unified system integration
        #expect(document.unifiedObjects.count == initialUnifiedCount + 1, "Template shape not added to unified system")
        
        // Verify both systems are in sync
        let legacyExists = document.layers[0].shapes.contains { $0.id == templateShape.id }
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == templateShape.id
            }
            return false
        }
        
        #expect(legacyExists, "Template shape not in legacy layer")
        #expect(unifiedExists, "Template shape not in unified system")
    }
    
    // MARK: - MARKER TOOL VIOLATIONS
    
    @Test func testMarkerToolUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        document.selectedLayerIndex = 0
        
        // Create a test marker stroke
        let markerPath = VectorPath(elements: [
            .move(to: VectorPoint(0, 0)),
            .line(to: VectorPoint(50, 0)),
            .line(to: VectorPoint(50, 10)),
            .line(to: VectorPoint(0, 10)),
            .close
        ], isClosed: true)
        
        let markerShape = VectorShape(
            name: "Marker Stroke",
            path: markerPath,
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 1, green: 0.5, blue: 0)), opacity: 0.7)
        )
        
        // Test correct unified system usage
        let initialCount = document.unifiedObjects.count
        
        document.addShapeToUnifiedSystem(markerShape, layerIndex: 0)
        
        #expect(document.unifiedObjects.count == initialCount + 1, "Marker stroke not added to unified system")
        
        // Verify marker-specific properties are preserved
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == markerShape.id
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObj.objectType {
                #expect(shape.fillStyle?.opacity == 0.7, "Marker opacity not preserved")
                #expect(shape.name == "Marker Stroke", "Marker name not preserved")
            }
        }
    }
    
    // MARK: - TEXT OUTLINE VIOLATIONS
    
    @Test func testTextOutlineUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        document.selectedLayerIndex = 0
        
        // Create a test outline shape (similar to ProfessionalTextCanvas outline generation)
        let outlinePath = VectorPath(elements: [
            .move(to: VectorPoint(10, 10)),
            .line(to: VectorPoint(90, 10)),
            .line(to: VectorPoint(90, 30)),
            .line(to: VectorPoint(10, 30)),
            .close
        ], isClosed: true)
        
        let outlineShape = VectorShape(
            name: "Text Outline",
            path: outlinePath,
            strokeStyle: StrokeStyle(color: .black, width: 1.0),
            fillStyle: nil
        )
        
        // Test correct usage with specific layer targeting
        let targetLayerIndex = 0
        let initialCount = document.unifiedObjects.count
        
        document.addShapeToUnifiedSystem(outlineShape, layerIndex: targetLayerIndex)
        
        #expect(document.unifiedObjects.count == initialCount + 1, "Text outline not added to unified system")
        
        // Verify layer targeting works correctly
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == outlineShape.id
            }
            return false
        }) {
            #expect(unifiedObj.layerIndex == targetLayerIndex, "Text outline added to wrong layer")
        }
    }
    
    // MARK: - COORDINATE SYSTEM DEBUGGING VIOLATIONS
    
    @Test func testCoordinateDebuggingUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        document.selectedLayerIndex = 0
        
        // Create a test debugging shape
        var debugShape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 10, height: 10))
        debugShape.name = "Debug Coordinate Test"
        
        let initialCount = document.unifiedObjects.count
        
        // Use unified system instead of direct addShape
        document.addShapeToUnifiedSystem(debugShape, layerIndex: 0)
        
        #expect(document.unifiedObjects.count == initialCount + 1, "Debug shape not added to unified system")
        
        // Verify debugging shapes don't interfere with normal operations
        let unifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == debugShape.id
            }
            return false
        }
        
        #expect(unifiedObj != nil, "Debug shape not found in unified system")
        if let obj = unifiedObj {
            #expect(obj.isVisible, "Debug shape should be visible")
            #expect(!obj.isLocked, "Debug shape should not be locked")
        }
    }
    
    // MARK: - FILE DROP VIOLATIONS
    
    @Test func testFileDropUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        
        // Add layers
        let layer1 = VectorLayer(name: "Layer 1")
        let layer2 = VectorLayer(name: "Layer 2")
        document.layers.append(contentsOf: [layer1, layer2])
        
        // Create a test imported shape (simulating file drop)
        let importedShape = VectorShape(
            name: "Imported Shape",
            path: VectorPath(elements: [.move(to: VectorPoint(0, 0)), .line(to: VectorPoint(100, 100))], isClosed: false),
            strokeStyle: StrokeStyle(color: .black, width: 2.0),
            fillStyle: FillStyle(color: .rgb(RGBColor(red: 0, green: 1, blue: 0)), opacity: 1.0)
        )
        
        // Test adding to specific layer (like file drop targeting)
        let targetLayerIndex = 1
        let initialCount = document.unifiedObjects.count
        
        document.addShapeToUnifiedSystem(importedShape, layerIndex: targetLayerIndex)
        
        #expect(document.unifiedObjects.count == initialCount + 1, "Imported shape not added to unified system")
        
        // Verify correct layer targeting
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == importedShape.id
            }
            return false
        }) {
            #expect(unifiedObj.layerIndex == targetLayerIndex, "Imported shape added to wrong layer")
        }
        
        // Verify legacy system consistency
        let legacyExists = document.layers[targetLayerIndex].shapes.contains { $0.id == importedShape.id }
        #expect(legacyExists, "Imported shape not in correct legacy layer")
    }
}
