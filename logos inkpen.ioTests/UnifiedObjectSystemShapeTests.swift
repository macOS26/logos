//
//  UnifiedObjectSystemShapeTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

// import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemShapeTests {
    
    // MARK: - SHAPE UNIFIED HELPER TESTS
    
    @Test func testSyncLayerShapesFromUnified() async throws {
        let document = VectorDocument()
        
        // Add layers
        document.layers = [
            VectorLayer(name: "Layer 0"),
            VectorLayer(name: "Layer 1")
        ]
        
        // Create shapes directly in unified system
        let shape1 = VectorShape(name: "Shape 1", path: VectorPath(elements: [], isClosed: false))
        let shape2 = VectorShape(name: "Shape 2", path: VectorPath(elements: [], isClosed: false))
        
        document.unifiedObjects = [
            VectorObject(shape: shape1, layerIndex: 0, orderID: 0),
            VectorObject(shape: shape2, layerIndex: 1, orderID: 0)
        ]
        
        // Sync layers from unified using updateUnifiedObjectsOptimized
        document.updateUnifiedObjectsOptimized()
        
        // Verify sync worked
        #expect(document.layers[0].shapes.count == 1)
        #expect(document.layers[0].shapes[0].id == shape1.id)
        #expect(document.layers[1].shapes.count == 1)
        #expect(document.layers[1].shapes[0].id == shape2.id)
    }
    
    @Test func testUpdateShapeFillColorInUnified() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        // Create a test shape
        let testShape = VectorShape(
            name: "Test Shape",
            path: VectorPath(elements: [], isClosed: false),
            fillStyle: FillStyle(color: VectorColor.black, opacity: 1.0)
        )
        
        // Add shape to document
        document.addShapeToUnifiedSystem(testShape, layerIndex: 0)
        
        // Verify initial fill color
        let initialShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(initialShape?.fillStyle?.color == VectorColor.black, "Initial fill color not set correctly")
        
        // Use unified helper to update fill color
        let newColor = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        document.updateShapeFillColorInUnified(id: testShape.id, color: newColor)
        
        // Verify legacy array updated
        let updatedShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(updatedShape?.fillStyle?.color == newColor, "Legacy shapes fill color not updated")
        
        // Verify unified system knows about the shape
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == testShape.id
            }
            return false
        }
        #expect(unifiedExists, "Shape not found in unified system")
    }
    
    @Test func testLockShapeInUnified() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        // Create a test shape
        let testShape = VectorShape(
            name: "Test Shape",
            path: VectorPath(elements: [], isClosed: false),
            isLocked: false
        )
        
        // Add shape to document
        document.addShapeToUnifiedSystem(testShape, layerIndex: 0)
        
        // Verify initial lock state
        let initialShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(initialShape?.isLocked == false, "Initial lock state not set correctly")
        
        // Use unified helper to lock shape
        document.lockShapeInUnified(id: testShape.id)
        
        // Verify legacy array updated
        let lockedShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(lockedShape?.isLocked == true, "Legacy shapes lock state not updated")
        
        // Test unlock
        document.unlockShapeInUnified(id: testShape.id)
        let unlockedShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(unlockedShape?.isLocked == false, "Legacy shapes unlock state not updated")
    }
    
    @Test func testHideShowShapeInUnified() async throws {
        let document = VectorDocument()
        
        // Add a layer first
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        // Create a test shape
        let testShape = VectorShape(
            name: "Test Shape",
            path: VectorPath(elements: [], isClosed: false),
            isVisible: true
        )
        
        // Add shape to document
        document.addShapeToUnifiedSystem(testShape, layerIndex: 0)
        
        // Verify initial visibility state
        let initialShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(initialShape?.isVisible == true, "Initial visibility state not set correctly")
        
        // Use unified helper to hide shape
        document.hideShapeInUnified(id: testShape.id)
        
        // Verify legacy array updated
        let hiddenShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(hiddenShape?.isVisible == false, "Legacy shapes visibility state not updated")
        
        // Test show
        document.showShapeInUnified(id: testShape.id)
        let visibleShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(visibleShape?.isVisible == true, "Legacy shapes show state not updated")
    }
    
    @Test func testCreateFillStyleInUnified() async throws {
        let document = VectorDocument()
        
        let testShape = VectorShape(
            name: "Test Shape",
            path: VectorPath(elements: [], isClosed: false)
        )
        
        // Add shape to document
        document.addShapeToUnifiedSystem(testShape, layerIndex: 0)
        
        // Verify initial fill style is nil
        let initialShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(initialShape?.fillStyle == nil, "Initial fill style should be nil")
        
        // Use unified helper to create fill style
        let testColor = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        let testOpacity = 0.7
        document.createFillStyleInUnified(id: testShape.id, color: testColor, opacity: testOpacity)
        
        // Verify legacy array updated
        let updatedShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(updatedShape?.fillStyle?.color == testColor, "Legacy shapes fill color not updated")
        #expect(updatedShape?.fillStyle?.opacity == testOpacity, "Legacy shapes fill opacity not updated")
        
        // Verify unified system knows about the shape
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == testShape.id
            }
            return false
        }
        #expect(unifiedExists, "Shape not found in unified system")
    }
    
    @Test func testCreateStrokeStyleInUnified() async throws {
        let document = VectorDocument()
        
        let testShape = VectorShape(
            name: "Test Shape",
            path: VectorPath(elements: [], isClosed: false)
        )
        
        // Add shape to document
        document.addShapeToUnifiedSystem(testShape, layerIndex: 0)
        
        // Verify initial stroke style is nil
        let initialShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(initialShape?.strokeStyle == nil, "Initial stroke style should be nil")
        
        // Use unified helper to create stroke style
        let testColor = VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1))
        let testWidth = 3.0
        let testPlacement = StrokePlacement.center
        let testLineCap = CGLineCap.round
        let testLineJoin = CGLineJoin.round
        let testMiterLimit: Double = 10.0
        let testOpacity = 0.8
        
        document.createStrokeStyleInUnified(
            id: testShape.id,
            color: testColor,
            width: testWidth,
            placement: testPlacement,
            lineCap: testLineCap,
            lineJoin: testLineJoin,
            miterLimit: testMiterLimit,
            opacity: testOpacity
        )
        
        // Verify legacy array updated
        let updatedShape = document.layers[0].shapes.first { $0.id == testShape.id }
        #expect(updatedShape?.strokeStyle?.color == testColor, "Legacy shapes stroke color not updated")
        #expect(updatedShape?.strokeStyle?.width == testWidth, "Legacy shapes stroke width not updated")
        #expect(updatedShape?.strokeStyle?.placement == testPlacement, "Legacy shapes stroke placement not updated")
        #expect(updatedShape?.strokeStyle?.lineCap == testLineCap, "Legacy shapes stroke lineCap not updated")
        #expect(updatedShape?.strokeStyle?.lineJoin == testLineJoin, "Legacy shapes stroke lineJoin not updated")
        #expect(updatedShape?.strokeStyle?.miterLimit == testMiterLimit, "Legacy shapes stroke miterLimit not updated")
        #expect(updatedShape?.strokeStyle?.opacity == testOpacity, "Legacy shapes stroke opacity not updated")
        
        // Verify unified system knows about the shape
        let unifiedExists = document.unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.isTextObject && shape.id == testShape.id
            }
            return false
        }
        #expect(unifiedExists, "Shape not found in unified system")
    }
}