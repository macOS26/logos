//
//  UnifiedSelectionTapMigrationTests.swift
//  logos inkpen.ioTests
//
//  Created by Todd Bruss on 12/4/24.
//

// import Testing
import Foundation
@testable import logos_inkpen_io

struct UnifiedSelectionTapMigrationTests {
    
    @Test func testShapeSelectionUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        document.createCanvasAndWorkingLayers()
        
        // Create a test shape
        let shape = VectorShape.rectangle(at: CGPoint(x: 50, y: 50), size: CGSize(width: 100, height: 100))
        let layerIndex = 2 // Working layer
        document.addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        
        // Initially no selection
        #expect(document.selectedObjectIDs.isEmpty)
        #expect(document.selectedShapeIDs.isEmpty)
        
        // Test: Selecting a shape should use unified system
        // Simulate shape selection logic
        document.selectedTextIDs.removeAll()
        document.selectedShapeIDs = [shape.id]
        document.syncUnifiedSelectionFromLegacy()
        
        // Verify unified system is updated
        #expect(document.selectedObjectIDs.count == 1)
        
        // Find the unified object for this shape
        let unifiedObject = document.unifiedObjects.first { obj in
            if case .shape(let shapeInObj) = obj.objectType {
                return shapeInObj.id == shape.id
            }
            return false
        }
        
        #expect(unifiedObject != nil)
        #expect(document.selectedObjectIDs.contains(unifiedObject!.id))
        
        // Verify legacy arrays are synced
        #expect(document.selectedShapeIDs.contains(shape.id))
    }
    
    @Test func testShiftClickAdditiveSelectionUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        document.createCanvasAndWorkingLayers()
        
        // Create two test shapes
        let shape1 = VectorShape.rectangle(at: CGPoint(x: 50, y: 50), size: CGSize(width: 50, height: 50))
        let shape2 = VectorShape.rectangle(at: CGPoint(x: 150, y: 150), size: CGSize(width: 50, height: 50))
        let layerIndex = 2
        
        document.addShapeToUnifiedSystem(shape1, layerIndex: layerIndex)
        document.addShapeToUnifiedSystem(shape2, layerIndex: layerIndex)
        
        // Select first shape
        document.selectedShapeIDs = [shape1.id]
        document.syncUnifiedSelectionFromLegacy()
        
        // Test: Shift+click to add second shape
        document.selectedShapeIDs.insert(shape2.id)  // This simulates shift+click additive selection
        document.syncUnifiedSelectionFromLegacy()
        
        // Verify both shapes are selected in unified system
        #expect(document.selectedObjectIDs.count == 2)
        #expect(document.selectedShapeIDs.count == 2)
        #expect(document.selectedShapeIDs.contains(shape1.id))
        #expect(document.selectedShapeIDs.contains(shape2.id))
        
        // Verify unified objects exist for both shapes
        let unifiedObjects = document.unifiedObjects.filter { obj in
            if case .shape(let shapeInObj) = obj.objectType {
                return shapeInObj.id == shape1.id || shapeInObj.id == shape2.id
            }
            return false
        }
        
        #expect(unifiedObjects.count == 2)
        for unifiedObj in unifiedObjects {
            #expect(document.selectedObjectIDs.contains(unifiedObj.id))
        }
    }
    
    @Test func testShapeAlreadySelectedDetectionUsesUnifiedSystem() async throws {
        let document = VectorDocument()
        document.createCanvasAndWorkingLayers()
        
        // Create a test shape
        let shape = VectorShape.rectangle(at: CGPoint(x: 50, y: 50), size: CGSize(width: 100, height: 100))
        let layerIndex = 2
        document.addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        
        // Select the shape
        document.selectedShapeIDs = [shape.id]
        document.syncUnifiedSelectionFromLegacy()
        
        // Test: Check if shape is already selected (used in command+click logic)
        let isAlreadySelected = document.selectedShapeIDs.contains(shape.id)
        #expect(isAlreadySelected == true)
        
        // Verify unified system consistency
        let unifiedObject = document.unifiedObjects.first { obj in
            if case .shape(let shapeInObj) = obj.objectType {
                return shapeInObj.id == shape.id
            }
            return false
        }
        
        #expect(unifiedObject != nil)
        #expect(document.selectedObjectIDs.contains(unifiedObject!.id))
    }
    
    @Test func testClearTextSelectionWhenSelectingShape() async throws {
        let document = VectorDocument()
        document.createCanvasAndWorkingLayers()
        
        // Create a text object and a shape
        let textObj = VectorText(
            content: "Test Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 100, y: 100)
        )
        let shape = VectorShape.rectangle(at: CGPoint(x: 200, y: 200), size: CGSize(width: 100, height: 100))
        let layerIndex = 2
        
        document.addTextToUnifiedSystem(textObj, layerIndex: layerIndex)
        document.addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        
        // Initially select the text
        document.selectedTextIDs = [textObj.id]
        document.syncUnifiedSelectionFromLegacy()
        
        // Verify text is selected
        #expect(document.selectedTextIDs.contains(textObj.id))
        #expect(document.selectedObjectIDs.count == 1)
        
        // Test: When selecting shape, text selection should be cleared
        document.selectedTextIDs.removeAll()  // This is what happens in the selection tap code
        document.selectedShapeIDs = [shape.id]
        document.syncUnifiedSelectionFromLegacy()
        
        // Verify text is no longer selected and shape is selected
        #expect(document.selectedTextIDs.isEmpty)
        #expect(document.selectedShapeIDs.contains(shape.id))
        #expect(document.selectedObjectIDs.count == 1)
        
        // Verify the selected object is the shape
        let selectedUnifiedObj = document.unifiedObjects.first { document.selectedObjectIDs.contains($0.id) }
        #expect(selectedUnifiedObj != nil)
        
        if case .shape(let selectedShape) = selectedUnifiedObj!.objectType {
            #expect(selectedShape.id == shape.id)
            #expect(selectedShape.isTextObject == false)
        } else {
            #expect(Bool(false), "Selected object should be a shape")
        }
    }
}