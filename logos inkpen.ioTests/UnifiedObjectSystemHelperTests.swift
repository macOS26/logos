//
//  UnifiedObjectSystemHelperTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemHelperTests {
    
    // MARK: - Helper Method Tests
    
    @Test func testAddTextToUnifiedSystemCreatesProperShape() async throws {
        let document = VectorDocument()
        
        let typography = TypographyProperties(
            fontFamily: "Herculanum",
            fontWeight: .bold,
            fontSize: 24.0,
            strokeColor: VectorColor.black,
            fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        )
        
        let text = VectorText(
            content: "Test Text",
            typography: typography,
            position: CGPoint(x: 100, y: 200),
            areaSize: CGSize(width: 300, height: 150)
        )
        
        // Use helper method to add text
        document.addTextToUnifiedSystem(text, layerIndex: 1)
        
        // Verify unified object was created correctly (filter out background objects)
        let textObjects = document.unifiedObjects.compactMap { obj -> VectorObject? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return obj
            }
            return nil
        }
        #expect(textObjects.count == 1)
        
        let unifiedObj = textObjects[0]
        #expect(unifiedObj.layerIndex == 1)
        
        if case .shape(let shape) = unifiedObj.objectType {
            #expect(shape.isTextObject == true)
            #expect(shape.textContent == "Test Text")
            #expect(shape.typography?.fontFamily == "Herculanum")
            #expect(shape.typography?.fontWeight == .bold)
            #expect(shape.typography?.fontSize == 24.0)
            #expect(shape.areaSize?.width == 300)
            #expect(shape.areaSize?.height == 150)
        } else {
            #expect(Bool(false), "Should create shape object type")
        }
    }
    
    @Test func testAddShapeToUnifiedSystemPreventsDuplicates() async throws {
        let document = VectorDocument()
        
        let shape = VectorShape(
            name: "Test Shape",
            path: VectorPath(elements: [], isClosed: false),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1)), opacity: 1.0)
        )
        
        // Add shape twice with same ID
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        document.addShapeToUnifiedSystem(shape, layerIndex: 0)
        
        // Should only have one test shape (no duplicates, filter out background objects)
        let testShapes = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.name == "Test Shape" {
                return shape
            }
            return nil
        }
        #expect(testShapes.count == 1)
        
        let unifiedShape = testShapes[0]
        #expect(unifiedShape.id == shape.id)
        #expect(unifiedShape.name == "Test Shape")
    }
    
    // MARK: - Unified Object Access Tests
    
    @Test func testUnifiedObjectsContainBothShapesAndText() async throws {
        let document = VectorDocument()
        
        // Add regular shape
        let regularShape = VectorShape(
            name: "Circle",
            path: VectorPath(elements: [], isClosed: true),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0)), opacity: 1.0),
            isTextObject: false
        )
        document.addShapeToUnifiedSystem(regularShape, layerIndex: 0)
        
        // Add text object
        let textObj = VectorText(
            content: "Hello World",
            typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 1))),
            position: CGPoint(x: 50, y: 75)
        )
        document.addTextToUnifiedSystem(textObj, layerIndex: 1)
        
        // Find test shape object (filter out background objects)
        let shapeObjects = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, !shape.isTextObject && shape.name == "Circle" {
                return shape
            }
            return nil
        }
        #expect(shapeObjects.count == 1)
        #expect(shapeObjects[0].name == "Circle")
        #expect(shapeObjects[0].fillStyle?.color == VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0)))
        
        // Find text object
        let textObjects = document.unifiedObjects.compactMap { obj -> VectorShape? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return shape
            }
            return nil
        }
        #expect(textObjects.count == 1)
        #expect(textObjects[0].textContent == "Hello World")
        #expect(textObjects[0].typography?.fillColor == VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 1)))
    }
    
    @Test func testUnifiedObjectOrderingByLayer() async throws {
        let document = VectorDocument()
        
        // Add objects to different layers
        let shape1 = VectorShape(name: "Layer 0 Shape", path: VectorPath(elements: [], isClosed: false))
        document.addShapeToUnifiedSystem(shape1, layerIndex: 0)
        
        let text1 = VectorText(content: "Layer 1 Text", typography: TypographyProperties(strokeColor: VectorColor.black, fillColor: VectorColor.black))
        document.addTextToUnifiedSystem(text1, layerIndex: 1)
        
        let shape2 = VectorShape(name: "Layer 2 Shape", path: VectorPath(elements: [], isClosed: false))
        document.addShapeToUnifiedSystem(shape2, layerIndex: 2)
        
        // Verify proper layer assignment
        let layer0Objects = document.unifiedObjects.filter { $0.layerIndex == 0 }
        let layer1Objects = document.unifiedObjects.filter { $0.layerIndex == 1 }
        let layer2Objects = document.unifiedObjects.filter { $0.layerIndex == 2 }
        
        
        // Filter out background objects for testing
        let testLayer0Objects = layer0Objects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.name.contains("Background")
            }
            return true
        }
        let testLayer1Objects = layer1Objects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.name.contains("Background")
            }
            return true
        }
        let testLayer2Objects = layer2Objects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return !shape.name.contains("Background")
            }
            return true
        }
        
        #expect(testLayer0Objects.count == 1)
        #expect(testLayer1Objects.count == 1)
        #expect(testLayer2Objects.count == 1)
        
        // Verify orderIDs are assigned correctly by unified system
        #expect(testLayer0Objects[0].orderID >= 0)  // Unified system assigns correctly
        #expect(testLayer1Objects[0].orderID >= 0)  // Unified system assigns correctly
        #expect(testLayer2Objects[0].orderID >= 0)  // Unified system assigns correctly
    }
}