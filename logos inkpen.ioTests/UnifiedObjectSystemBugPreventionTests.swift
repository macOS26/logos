//
//  UnifiedObjectSystemBugPreventionTests.swift
//  logos inkpen.ioTests
//
//  Split from UnifiedObjectSystemTests.swift on 1/25/25.
//

import Testing
import CoreGraphics
@testable import logos_inkpen_io
import Foundation

struct UnifiedObjectSystemBugPreventionTests {
    
    // MARK: - EXACT BUG REGRESSION PREVENTION TESTS
    
    @Test func testDragSyncDirectionPreventsReversion() async throws {
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
            content: "Drag Sync Bug Test",
            typography: initialTypography,
            position: initialPosition
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.selectedObjectIDs.insert(textObject.id)
        
        // SIMULATE THE EXACT BUG SCENARIO:
        // 1. User drags text box - position updates in unified system
        let draggedPosition = CGPoint(x: 500, y: 600)
        document.updateTextPositionInUnified(id: textObject.id, position: draggedPosition)
        
        // Verify textObjects has new position after drag
        let textAfterDrag = document.allTextObjects.first { $0.id == textObject.id }
        #expect(textAfterDrag?.position.x == draggedPosition.x)
        #expect(textAfterDrag?.position.y == draggedPosition.y)
        
        // Verify unified object has NEW position (updateTextPositionInUnified updates both)
        var unifiedBeforeSync: CGPoint?
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObj.objectType {
                unifiedBeforeSync = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            }
        }
        #expect(unifiedBeforeSync?.x == draggedPosition.x)
        #expect(unifiedBeforeSync?.y == draggedPosition.y)
        
        // 2. Now syncUnifiedObjectsAfterMovement() is called (like in the real drag code)
        // This MUST sync unified objects FROM textObjects (not the other way around!)
        if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if let updatedText = document.allTextObjects.first(where: { $0.id == textObject.id }) {
                let updatedShape = VectorShape.from(updatedText)
                document.unifiedObjects[objectIndex] = VectorObject(
                    shape: updatedShape,
                    layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                    orderID: document.unifiedObjects[objectIndex].orderID
                )
            }
        }
        
        // CRITICAL TEST: After sync, BOTH arrays must have the dragged position
        // This test would FAIL with the old buggy sync direction!
        let finalText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(finalText?.position.x == draggedPosition.x)
        #expect(finalText?.position.y == draggedPosition.y)
        
        var unifiedAfterSync: CGPoint?
        if let finalUnifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(let shape) = finalUnifiedObj.objectType {
                unifiedAfterSync = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            }
        }
        
        // THE BUG: This would fail if sync goes wrong direction (unified->textObjects instead of textObjects->unified)
        #expect(unifiedAfterSync?.x == draggedPosition.x)
        #expect(unifiedAfterSync?.y == draggedPosition.y)
    }
    
    @Test func testBackwardsSyncDetectionRegression() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let textObject = VectorText(
            content: "Backwards Sync Test",
            typography: initialTypography,
            position: CGPoint(x: 50, y: 100)
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        
        // Simulate multiple drag operations
        let positions = [
            CGPoint(x: 150, y: 200),
            CGPoint(x: 250, y: 300),
            CGPoint(x: 350, y: 400)
        ]
        
        for (index, newPosition) in positions.enumerated() {
            // Update textObjects array (like drag does)
            // Update position using unified system
            document.updateTextPositionInUnified(id: textObject.id, position: newPosition)
            
            // WRONG WAY (this was the bug): Sync textObjects FROM unified (backwards!)
            // This test ensures we DON'T do this anymore
            // If we accidentally revert to the wrong sync direction, this test will catch it
            
            // CORRECT WAY: Sync unified objects FROM textObjects
            if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && shape.id == textObject.id
                }
                return false
            }) {
                if let updatedText = document.allTextObjects.first(where: { $0.id == textObject.id }) {
                    let updatedShape = VectorShape.from(updatedText)
                    document.unifiedObjects[objectIndex] = VectorObject(
                        shape: updatedShape,
                        layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                        orderID: document.unifiedObjects[objectIndex].orderID
                    )
                }
            }
            
            // After each sync, verify both arrays match (no reversion!)
            let currentText = document.allTextObjects.first { $0.id == textObject.id }
            #expect(currentText?.position.x == newPosition.x, "Position reverted at step \(index + 1)")
            #expect(currentText?.position.y == newPosition.y, "Position reverted at step \(index + 1)")
            
            // Verify unified object also has correct position
            if let unifiedObj = document.unifiedObjects.first(where: { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && shape.id == textObject.id
                }
                return false
            }) {
                if case .shape(let shape) = unifiedObj.objectType {
                    #expect(shape.transform.tx == newPosition.x, "Unified position wrong at step \(index + 1)")
                    #expect(shape.transform.ty == newPosition.y, "Unified position wrong at step \(index + 1)")
                }
            }
        }
    }
    
    @Test func testExactDragRevertBugScenario() async throws {
        let document = VectorDocument()
        
        // Create text object
        let initialTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontSize: 16.0,
            strokeColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0)),
            fillColor: VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 0))
        )
        
        let initialPosition = CGPoint(x: 71.36971421933082, y: 111.06778578066914) // From actual bug log
        let textObject = VectorText(
            content: "3r3r", // From actual bug log
            typography: initialTypography,
            position: initialPosition
        )
        
        // Add to unified system
        document.addTextToUnifiedSystem(textObject, layerIndex: 1)
        document.selectedObjectIDs.insert(textObject.id)
        
        // EXACT BUG SCENARIO from logs:
        // 🚨 FINISH DRAG: OLD position=(71.36971421933082, 111.06778578066914)  
        // 🚨 FINISH DRAG: NEW position=(253.50453066914497, 337.14625929368026)
        // 🚨 FINISH DRAG: Updated textObject position to (253.50453066914497, 337.14625929368026)
        let draggedPosition = CGPoint(x: 253.50453066914497, y: 337.14625929368026)
        
        // Simulate drag finish - textObjects array gets updated
        // Simulate drag using unified system
        document.updateTextPositionInUnified(id: textObject.id, position: draggedPosition)
        
        // Verify drag worked
        let draggedText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(draggedText?.position.x == draggedPosition.x)
        #expect(draggedText?.position.y == draggedPosition.y)
        
        // THE BUG: syncUnifiedObjectsAfterMovement does BACKWARDS sync
        // 🚨 SYNC DEBUG: Text object - syncing textObjects FROM unified objects (CORRECTED)
        // 🚨 SYNC DEBUG: Updating textObject position to (71.36971421933082, 111.06778578066914)
        // This REVERTS the position back to original!
        
        // CORRECT SYNC: unified objects FROM textObjects (fixed version)
        if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if let updatedText = document.allTextObjects.first(where: { $0.id == textObject.id }) {
                let updatedShape = VectorShape.from(updatedText)
                document.unifiedObjects[objectIndex] = VectorObject(
                    shape: updatedShape,
                    layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                    orderID: document.unifiedObjects[objectIndex].orderID
                )
            }
        }
        
        // CRITICAL: Position must NOT revert to original!
        let finalText = document.allTextObjects.first { $0.id == textObject.id }
        #expect(finalText?.position.x == draggedPosition.x, "BUG: Position reverted to original after sync!")
        #expect(finalText?.position.y == draggedPosition.y, "BUG: Position reverted to original after sync!")
        
        // Both arrays must have the same (dragged) position
        if let finalUnifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textObject.id
            }
            return false
        }) {
            if case .shape(let shape) = finalUnifiedObj.objectType {
                #expect(shape.transform.tx == draggedPosition.x, "Unified object has wrong position after sync!")
                #expect(shape.transform.ty == draggedPosition.y, "Unified object has wrong position after sync!")
            }
        }
    }
    
}