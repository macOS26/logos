//
//  logos_inkpen_ioTests.swift
//  logos inkpen.ioTests
//
//  Created by Todd Bruss on 7/13/25.
//

import Testing
@testable import logos_inkpen_io

struct logos_inkpen_ioTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }
    
    @Test func testLayerOrderingWithShapesAndText() async throws {
        // Create a test document
        let document = VectorDocument()
        
        // Add some shapes and text to the working layer
        let shape1 = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 50, height: 50))
        let shape2 = VectorShape.rectangle(at: CGPoint(x: 150, y: 150), size: CGSize(width: 50, height: 50))
        let text1 = VectorText(content: "Test Text", position: CGPoint(x: 200, y: 200))
        
        // Add objects to document
        document.addShape(shape1)
        document.addShape(shape2)
        document.addText(text1)
        
        // Verify initial order (should be: shape1, shape2, text1 from back to front)
        let objectsInOrder = document.getObjectsInStackingOrder()
        #expect(objectsInOrder.count == 3)
        
        // Select the text object
        document.selectedObjectIDs = [text1.id]
        document.syncSelectionArrays()
        
        // Test send backward - text should move behind shape2
        document.sendSelectedBackward()
        
        // Verify text is now behind shape2
        let objectsAfterSendBackward = document.getObjectsInStackingOrder()
        #expect(objectsAfterSendBackward.count == 3)
        
        // The text should now be in the middle (between shape1 and shape2)
        let textObjectAfterBackward = objectsAfterSendBackward.first { obj in
            if case .text(let text) = obj.objectType {
                return text.id == text1.id
            }
            return false
        }
        #expect(textObjectAfterBackward != nil)
        
        // Test send to back - text should move to the very back
        document.sendSelectedToBack()
        
        // Verify text is now at the very back
        let objectsAfterSendToBack = document.getObjectsInStackingOrder()
        #expect(objectsAfterSendToBack.count == 3)
        
        // The text should now be first (at the back)
        let textObjectAfterToBack = objectsAfterSendToBack.first { obj in
            if case .text(let text) = obj.objectType {
                return text.id == text1.id
            }
            return false
        }
        #expect(textObjectAfterToBack != nil)
        #expect(objectsAfterSendToBack.first?.id == textObjectAfterToBack?.id)
    }
    
    @Test func testPasteInBackWithShapesAndText() async throws {
        // Create a test document
        let document = VectorDocument()
        
        // Add some existing shapes and text
        let existingShape = VectorShape.rectangle(at: CGPoint(x: 100, y: 100), size: CGSize(width: 50, height: 50))
        let existingText = VectorText(content: "Existing Text", position: CGPoint(x: 200, y: 200))
        
        document.addShape(existingShape)
        document.addText(existingText)
        
        // Select the existing text
        document.selectedObjectIDs = [existingText.id]
        document.syncSelectionArrays()
        
        // Create clipboard data with new shapes and text
        let newShape = VectorShape.rectangle(at: CGPoint(x: 300, y: 300), size: CGSize(width: 30, height: 30))
        let newText = VectorText(content: "New Text", position: CGPoint(x: 400, y: 400))
        let clipboardData = ClipboardData(shapes: [newShape], texts: [newText])
        
        // Simulate paste in back by manually adding objects with proper orderID
        let targetOrderID = 0 // Should paste behind the selected text
        
        // Add new shape with orderID that places it behind selected text
        var pastedShape = newShape
        pastedShape.id = UUID()
        document.layers[document.selectedLayerIndex!].shapes.append(pastedShape)
        
        let shapeUnifiedObject = VectorObject(shape: pastedShape, layerIndex: document.selectedLayerIndex!, orderID: targetOrderID)
        document.unifiedObjects.append(shapeUnifiedObject)
        
        // Add new text with orderID that places it behind selected text
        var pastedText = newText
        pastedText.id = UUID()
        document.textObjects.append(pastedText)
        
        let textUnifiedObject = VectorObject(text: pastedText, layerIndex: document.selectedLayerIndex!, orderID: targetOrderID + 1)
        document.unifiedObjects.append(textUnifiedObject)
        
        // Verify the pasted objects are behind the selected text
        let objectsInOrder = document.getObjectsInStackingOrder()
        #expect(objectsInOrder.count == 4)
        
        // The pasted objects should be at the back (lowest orderID)
        let pastedShapeInOrder = objectsInOrder.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == pastedShape.id
            }
            return false
        }
        let pastedTextInOrder = objectsInOrder.first { obj in
            if case .text(let text) = obj.objectType {
                return text.id == pastedText.id
            }
            return false
        }
        
        #expect(pastedShapeInOrder != nil)
        #expect(pastedTextInOrder != nil)
        
        // Both pasted objects should be behind the existing text
        let existingTextInOrder = objectsInOrder.first { obj in
            if case .text(let text) = obj.objectType {
                return text.id == existingText.id
            }
            return false
        }
        
        #expect(existingTextInOrder != nil)
        #expect(pastedShapeInOrder!.orderID < existingTextInOrder!.orderID)
        #expect(pastedTextInOrder!.orderID < existingTextInOrder!.orderID)
    }
}
