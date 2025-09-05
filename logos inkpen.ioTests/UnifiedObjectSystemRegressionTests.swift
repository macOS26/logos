//
//  UnifiedObjectSystemRegressionTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemRegressionTests {
    
    // MARK: - CRITICAL REGRESSION PREVENTION TESTS
    
    @Test func testTextBoxDragPositionPersistence() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let initialPosition = CGPoint(x: 100, y: 200)
        let textObject = VectorText(
            content: "Drag Test",
            typography: initialTypography,
            position: initialPosition
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.selectedObjectIDs.insert(textObject.id)
        
        // Simulate drag operation - update position in textObjects array
        let newPosition = CGPoint(x: 300, y: 400)
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].position = newPosition
        }
        
        // Simulate what happens after drag - sync unified objects from textObjects
        if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if let updatedText = document.textObjects.first(where: { $0.id == textObject.id }) {
                let updatedShape = VectorShape.from(updatedText)
                document.unifiedObjects[objectIndex] = VectorObject(
                    shape: updatedShape,
                    layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                    orderID: document.unifiedObjects[objectIndex].orderID
                )
            }
        }
        
        // CRITICAL TEST: Position must persist after sync
        let finalText = document.textObjects.first { $0.id == textObject.id }
        #expect(finalText?.position.x == newPosition.x)
        #expect(finalText?.position.y == newPosition.y)
        
        // Verify unified object also has correct position
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObj.objectType {
                #expect(shape.transform.tx == newPosition.x)
                #expect(shape.transform.ty == newPosition.y)
            }
        }
    }
    
    @Test func testColorUpdatesPreservePosition() async throws {
        let document = VectorDocument()
        
        // Create text object at specific position
        let initialPosition = CGPoint(x: 150, y: 250)
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "Position Test",
            typography: initialTypography,
            position: initialPosition
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.selectedObjectIDs.insert(textObject.id)
        
        // Update fill color using unified helper
        let newFillColor = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
        document.updateTextFillColorInUnified(id: textObject.id, color: newFillColor)
        
        // CRITICAL TEST: Position must be preserved after color update
        let updatedText = document.textObjects.first { $0.id == textObject.id }
        #expect(updatedText?.position.x == initialPosition.x)
        #expect(updatedText?.position.y == initialPosition.y)
        #expect(updatedText?.typography.fillColor == newFillColor)
        
        // Update stroke color using unified helper
        let newStrokeColor = VectorColor.rgb(RGBColor(red: 0, green: 1, blue: 0))
        document.updateTextStrokeColorInUnified(id: textObject.id, color: newStrokeColor)
        
        // CRITICAL TEST: Position must still be preserved after stroke color update
        let finalText = document.textObjects.first { $0.id == textObject.id }
        #expect(finalText?.position.x == initialPosition.x)
        #expect(finalText?.position.y == initialPosition.y)
        #expect(finalText?.typography.strokeColor == newStrokeColor)
        #expect(finalText?.typography.hasStroke == true)
    }
    
    @Test func testUnifiedObjectSyncDirection() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica", 
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let initialPosition = CGPoint(x: 50, y: 75)
        let textObject = VectorText(
            content: "Sync Test",
            typography: initialTypography,
            position: initialPosition
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        
        // Move text object in textObjects array (simulating drag)
        let draggedPosition = CGPoint(x: 200, y: 300)
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].position = draggedPosition
        }
        
        // Get initial unified object position (should be old position)
        var unifiedPosition: CGPoint?
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObj.objectType {
                unifiedPosition = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            }
        }
        
        // BEFORE sync: unified object should have old position, textObject should have new position
        #expect(unifiedPosition?.x == initialPosition.x)
        #expect(unifiedPosition?.y == initialPosition.y)
        let textBeforeSync = document.textObjects.first { $0.id == textObject.id }
        #expect(textBeforeSync?.position.x == draggedPosition.x)
        #expect(textBeforeSync?.position.y == draggedPosition.y)
        
        // Now sync unified object FROM textObjects (correct direction)
        if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if let updatedText = document.textObjects.first(where: { $0.id == textObject.id }) {
                let updatedShape = VectorShape.from(updatedText)
                document.unifiedObjects[objectIndex] = VectorObject(
                    shape: updatedShape,
                    layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                    orderID: document.unifiedObjects[objectIndex].orderID
                )
            }
        }
        
        // AFTER sync: both should have new position
        let finalText = document.textObjects.first { $0.id == textObject.id }
        #expect(finalText?.position.x == draggedPosition.x)
        #expect(finalText?.position.y == draggedPosition.y)
        
        if let finalUnifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(let shape) = finalUnifiedObj.objectType {
                #expect(shape.transform.tx == draggedPosition.x)
                #expect(shape.transform.ty == draggedPosition.y)
            }
        }
    }
    
    @Test func testMultipleDragOperationsPositionPersistence() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "Multiple Drag Test",
            typography: initialTypography,
            position: CGPoint(x: 0, y: 0)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.selectedObjectIDs.insert(textObject.id)
        
        let positions = [
            CGPoint(x: 100, y: 100),
            CGPoint(x: 200, y: 150),
            CGPoint(x: 50, y: 300),
            CGPoint(x: 400, y: 50)
        ]
        
        // Simulate multiple drag operations
        for newPosition in positions {
            // Update position in textObjects (drag operation)
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                document.textObjects[textIndex].position = newPosition
            }
            
            // Sync unified object FROM textObjects (correct direction)
            if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && shape.id == textObject.id
                }
                return false
            }) {
                if let updatedText = document.textObjects.first(where: { $0.id == textObject.id }) {
                    let updatedShape = VectorShape.from(updatedText)
                    document.unifiedObjects[objectIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                        orderID: document.unifiedObjects[objectIndex].orderID
                    )
                }
            }
            
            // CRITICAL TEST: Position must persist after each operation
            let currentText = document.textObjects.first { $0.id == textObject.id }
            #expect(currentText?.position.x == newPosition.x)
            #expect(currentText?.position.y == newPosition.y)
        }
        
        // Final position should be the last drag position
        let finalPosition = positions.last!
        let finalText = document.textObjects.first { $0.id == textObject.id }
        #expect(finalText?.position.x == finalPosition.x)
        #expect(finalText?.position.y == finalPosition.y)
    }
}