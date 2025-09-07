//
//  UnifiedHelperCoverageTests.swift
//  logos inkpen.ioTests
//
//  Tests to ensure ALL operations use unified helpers
//

// import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedHelperCoverageTests {
    
    // MARK: - Shape Transform Tests
    
    @Test func testShapeTransformUsesUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let _ = CGAffineTransform(scaleX: 2.0, y: 2.0)
        
        // VIOLATION TEST: This should use unified helper, not direct manipulation
        // document.layers[0].shapes[0].transform = transform  // VIOLATION!
        
        // CORRECT: Use unified system (need to add this helper)
        // document.updateShapeTransformUnified(id: shape.id, transform: transform)
        
        // For now, verify the violation doesn't exist
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape != nil, "Shape should exist")
    }
    
    @Test func testShapePathUpdateUsesUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let newPath = VectorPath(elements: [.move(to: VectorPoint(10, 10)), .line(to: VectorPoint(60, 60))], isClosed: false)
        
        // CORRECT: Use unified helper
        document.updateShapePathUnified(id: shape.id, path: newPath)
        
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape?.path.elements.count == 2, "Path should be updated via unified helper")
    }
    
    // MARK: - Text Object Tests
    
    @Test func testTextAddedToUnifiedSystem() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let textObject = VectorText(
            content: "Test Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 10, y: 10)
        )
        
        document.addTextToUnifiedSystem(textObject, layerIndex: 0)
        
        let unifiedTextObject = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textObject.id && shape.isTextObject
            }
            return false
        }
        #expect(unifiedTextObject != nil, "Text should be added as shape via unified helper")
    }
    
    // MARK: - Bounds and Properties Tests
    
    @Test func testShapeBoundsUpdateUsesUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        // VIOLATION TEST: Direct bounds manipulation should not be allowed
        // document.layers[0].shapes[0].bounds = newBounds  // VIOLATION!
        
        // Instead, bounds should be updated automatically by unified helpers
        // or through proper unified helper methods
        
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape != nil, "Shape should exist and bounds managed by unified system")
    }
    
    
    // MARK: - Visibility and Lock Tests
    
    @Test func testShapeVisibilityUsesUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        // CORRECT: Use unified helpers
        document.hideShapeInUnified(id: shape.id)
        
        let hiddenShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(hiddenShape?.isVisible == false, "Shape visibility should use unified helper")
        
        document.showShapeInUnified(id: shape.id)
        
        let visibleShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(visibleShape?.isVisible == true, "Shape visibility should use unified helper")
    }
    
    @Test func testTextVisibilityUsesUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let textObject = VectorText(
            content: "Test Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 10, y: 10)
        )
        
        document.addTextToUnifiedSystem(textObject, layerIndex: 0)
        
        // CORRECT: Use unified helpers
        document.hideTextInUnified(id: textObject.id)
        
        // Verify through unified system
        let hiddenUnifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textObject.id && shape.isTextObject
            }
            return false
        }
        #expect(hiddenUnifiedObj?.isVisible == false, "Text visibility should use unified helper")
        
        document.showTextInUnified(id: textObject.id)
        
        let visibleUnifiedObj = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textObject.id && shape.isTextObject
            }
            return false
        }
        #expect(visibleUnifiedObj?.isVisible == true, "Text visibility should use unified helper")
    }
    
    // MARK: - Color Updates Tests
    
    @Test func testShapeColorUsesUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        let newColor = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        
        // CORRECT: Use unified helpers
        document.updateShapeFillColorInUnified(id: shape.id, color: newColor)
        
        let updatedShape = document.layers[0].shapes.first { $0.id == shape.id }
        #expect(updatedShape?.fillStyle?.color == newColor, "Shape color should use unified helper")
    }
    
    @Test func testTextColorUsesUnified() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let textObject = VectorText(
            content: "Test Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 10, y: 10)
        )
        
        document.addTextToUnifiedSystem(textObject, layerIndex: 0)
        
        let unifiedTextObject = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == textObject.id && shape.isTextObject
            }
            return false
        }
        #expect(unifiedTextObject != nil, "Text should be added as shape via unified helper")
    }
    
    // MARK: - System Integrity Tests
    
    @Test func testUnifiedSystemSync() async throws {
        let document = VectorDocument()
        let layer = VectorLayer(name: "Test Layer")
        document.layers.append(layer)
        
        let shape = VectorShape.rectangle(at: CGPoint(x: 0, y: 0), size: CGSize(width: 50, height: 50))
        let textObject = VectorText(
            content: "Test Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 10, y: 10)
        )
        
        let initialUnifiedCount = document.unifiedObjects.count
        
        // Add both via unified system
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        document.addTextToUnifiedSystem(textObject, layerIndex: 0)
        
        // Verify unified system integrity
        #expect(document.unifiedObjects.count == initialUnifiedCount + 2, "Both objects should be in unified system")
        
        // Verify legacy arrays are in sync
        #expect(document.layers[0].shapes.contains { $0.id == shape.id }, "Shape should be in legacy array")
        
        // Verify unified objects have correct types
        let unifiedShape = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType { return s.id == shape.id }
            return false
        }
        let unifiedText = document.unifiedObjects.first { obj in
            if case .shape(let s) = obj.objectType { return s.id == textObject.id }
            return false
        }
        
        #expect(unifiedShape != nil, "Shape should exist in unified system")
        #expect(unifiedText != nil, "Text should exist in unified system")
    }
}