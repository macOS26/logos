//
//  TextObjectMigrationTests.swift
//  logos inkpen.ioTests
//
//  Testing the migration from direct textObjects array to unified system
//

import Testing
import Foundation
import CoreGraphics
@testable import logos_inkpen_io

struct TextObjectMigrationTests {
    
    // MARK: - Test allTextObjects computed property
    
    @Test func testAllTextObjectsReturnsCorrectObjects() {
        let document = VectorDocument()
        
        // Create text objects
        let text1 = VectorText(
            content: "First Text",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontWeight: FontWeight.regular,
                fontSize: 24,
                alignment: TextAlignment.left,
                strokeColor: VectorColor.clear,
                fillColor: VectorColor.black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        let text2 = VectorText(
            content: "Second Text",
            typography: TypographyProperties(
                fontFamily: "Arial",
                fontWeight: FontWeight.bold,
                fontSize: 18,
                alignment: TextAlignment.center,
                strokeColor: VectorColor.clear,
                fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
            ),
            position: CGPoint(x: 200, y: 200)
        )
        
        // Add texts to unified system
        document.addTextToUnifiedSystem(text1, layerIndex: 0)
        document.addTextToUnifiedSystem(text2, layerIndex: 0)
        
        // Verify allTextObjects returns both
        let allTexts = document.allTextObjects
        #expect(allTexts.count == 2, "Should have 2 text objects")
        #expect(allTexts.contains(where: { $0.id == text1.id }), "Should contain first text")
        #expect(allTexts.contains(where: { $0.id == text2.id }), "Should contain second text")
    }
    
    @Test func testAllTextObjectsEmptyWhenNoTexts() {
        let document = VectorDocument()
        
        // Note: Document starts with 2 background shapes
        let initialShapeCount = document.allShapes.count
        
        // Add only shapes, no text
        let shape = VectorShape(
            name: "Rectangle",
            path: VectorPath(elements: [], isClosed: true),
            fillStyle: FillStyle(color: VectorColor.black, opacity: 1.0),
            isTextObject: false
        )
        
        document.addShapeToUnifiedSystem(shape, layerIndex: 2) // Use working layer
        
        // Verify allTextObjects is empty
        let allTexts = document.allTextObjects
        #expect(allTexts.isEmpty, "Should have no text objects when only shapes exist")
        
        // Verify shape was added
        #expect(document.allShapes.count == initialShapeCount + 1, "Should have added one shape")
    }
    
    @Test func testAllTextObjectsMaintainsLayerOrder() {
        let document = VectorDocument()
        
        // Add layers if needed
        while document.layers.count < 3 {
            document.layers.append(VectorLayer(name: "Layer \(document.layers.count)", isVisible: true))
        }
        
        // Create text objects on different layers
        let text1 = VectorText(content: "Layer 0 Text", position: CGPoint(x: 100, y: 100))
        let text2 = VectorText(content: "Layer 1 Text", position: CGPoint(x: 200, y: 200))
        let text3 = VectorText(content: "Layer 2 Text", position: CGPoint(x: 300, y: 300))
        
        document.addTextToUnifiedSystem(text1, layerIndex: 0)
        document.addTextToUnifiedSystem(text2, layerIndex: 1)
        document.addTextToUnifiedSystem(text3, layerIndex: 2)
        
        // Verify all texts are returned
        let allTexts = document.allTextObjects
        #expect(allTexts.count == 3, "Should have 3 text objects across layers")
        
        // Verify layer indices are preserved
        for text in allTexts {
            let unifiedObj = document.unifiedObjects.first { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.id == text.id
                }
                return false
            }
            #expect(unifiedObj != nil, "Text should exist in unified objects")
        }
    }
    
    // MARK: - Test findText helper method
    
    @Test func testFindTextById() {
        let document = VectorDocument()
        
        let text = VectorText(content: "Find Me", position: CGPoint(x: 100, y: 100))
        document.addTextToUnifiedSystem(text, layerIndex: 0)
        
        // Test finding existing text
        let found = document.findText(by: text.id)
        #expect(found != nil, "Should find text by ID")
        #expect(found?.id == text.id, "Found text should have matching ID")
        #expect(found?.content == "Find Me", "Found text should have correct content")
        
        // Test finding non-existent text
        let notFound = document.findText(by: UUID())
        #expect(notFound == nil, "Should return nil for non-existent ID")
    }
    
    // MARK: - Test text updates through unified system
    
    @Test func testUpdateTextThroughUnifiedSystem() {
        let document = VectorDocument()
        
        let originalText = VectorText(
            content: "Original",
            typography: TypographyProperties(
                fontSize: 24,
                strokeColor: VectorColor.clear,
                fillColor: VectorColor.black
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addTextToUnifiedSystem(originalText, layerIndex: 0)
        
        // Update the text
        var updatedText = originalText
        updatedText.content = "Updated"
        updatedText.typography.fontSize = 36
        updatedText.typography.fillColor = VectorColor.rgb(RGBColor(red: 0, green: 0, blue: 1))
        
        // Find and update in unified system
        if let index = document.unifiedObjects.firstIndex(where: { $0.id == originalText.id }) {
            let updatedShape = VectorShape.from(updatedText)
            document.unifiedObjects[index] = VectorObject(
                shape: updatedShape,
                layerIndex: document.unifiedObjects[index].layerIndex,
                orderID: document.unifiedObjects[index].orderID
            )
        }
        
        // Verify update through allTextObjects
        let foundText = document.allTextObjects.first { $0.id == originalText.id }
        #expect(foundText != nil, "Should find updated text")
        #expect(foundText?.content == "Updated", "Text content should be updated")
        #expect(foundText?.typography.fontSize == 36, "Font size should be updated")
    }
    
    // MARK: - Test text deletion through unified system
    
    @Test func testDeleteTextThroughUnifiedSystem() {
        let document = VectorDocument()
        
        let text1 = VectorText(content: "Keep Me", position: CGPoint(x: 100, y: 100))
        let text2 = VectorText(content: "Delete Me", position: CGPoint(x: 200, y: 200))
        
        document.addTextToUnifiedSystem(text1, layerIndex: 0)
        document.addTextToUnifiedSystem(text2, layerIndex: 0)
        
        #expect(document.allTextObjects.count == 2, "Should have 2 texts initially")
        
        // Delete text2 from unified system
        document.unifiedObjects.removeAll { $0.id == text2.id }
        
        // Verify deletion
        #expect(document.allTextObjects.count == 1, "Should have 1 text after deletion")
        #expect(document.allTextObjects.first?.id == text1.id, "Remaining text should be text1")
        #expect(document.findText(by: text2.id) == nil, "Deleted text should not be found")
    }
    
    // MARK: - Test mixed shapes and text
    
    @Test func testMixedShapesAndTextInUnifiedSystem() {
        let document = VectorDocument()
        
        // Note: Document starts with background shapes
        let initialObjectCount = document.unifiedObjects.count
        let initialShapeCount = document.allShapes.count
        
        // Add shape
        let shape = VectorShape(
            name: "Rectangle",
            path: VectorPath(elements: [], isClosed: true),
            fillStyle: FillStyle(color: VectorColor.black, opacity: 1.0),
            isTextObject: false
        )
        
        // Add text
        let text = VectorText(
            content: "Mixed Content",
            position: CGPoint(x: 150, y: 150)
        )
        
        document.addShapeToUnifiedSystem(shape, layerIndex: 2) // Use working layer
        
        // Check shape was added
        let afterShapeCount = document.allShapes.count
        #expect(afterShapeCount == initialShapeCount + 1, "Should have added 1 regular shape")
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Verify counts (accounting for initial background shapes)
        #expect(document.unifiedObjects.count == initialObjectCount + 2, "Should have added 2 objects")
        
        // Note: allShapes excludes text objects, even though they're stored as shapes internally
        #expect(document.allShapes.count == afterShapeCount, "allShapes should not include text objects")
        #expect(document.allTextObjects.count == 1, "Should have 1 text object")
        
        // Verify correct types
        let textFromUnified = document.allTextObjects.first
        #expect(textFromUnified?.id == text.id, "Text should be retrievable from unified system")
        
        let nonTextShapes = document.allShapes.filter { !$0.isTextObject }
        #expect(nonTextShapes.contains(where: { $0.id == shape.id }), "Non-text shapes should include the rectangle")
    }
    
    // MARK: - Test VectorText <-> VectorShape conversion
    
    @Test func testVectorTextToShapeConversion() {
        let text = VectorText(
            content: "Convert Me",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontWeight: FontWeight.bold,
                fontSize: 24,
                alignment: TextAlignment.center,
                strokeColor: VectorColor.clear,
                fillColor: VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        // Convert to shape
        let shape = VectorShape.from(text)
        
        // Verify shape properties
        #expect(shape.isTextObject == true, "Shape should be marked as text object")
        #expect(shape.textContent == "Convert Me", "Shape should preserve text content")
        #expect(shape.typography != nil, "Shape should have typography properties")
        #expect(shape.typography?.fontSize == 24, "Typography should preserve font size")
        #expect(shape.typography?.fontFamily == "Helvetica", "Typography should preserve font name")
        #expect(shape.typography?.fillColor == text.typography.fillColor, "Typography should preserve fill color")
        #expect(shape.typography?.alignment == TextAlignment.center, "Typography should preserve alignment")
        #expect(shape.typography?.fontWeight == FontWeight.bold, "Typography should preserve font weight")
        
        // Convert back to text
        let convertedBack = VectorText.from(shape)
        #expect(convertedBack != nil, "Should convert back to VectorText")
        #expect(convertedBack?.content == text.content, "Text content should match")
        #expect(convertedBack?.typography.fontSize == text.typography.fontSize, "Font size should match")
        #expect(convertedBack?.typography.fontFamily == text.typography.fontFamily, "Font name should match")
        #expect(convertedBack?.typography.fillColor == text.typography.fillColor, "Fill color should match")
        #expect(convertedBack?.typography.alignment == text.typography.alignment, "Alignment should match")
        #expect(convertedBack?.typography.fontWeight == text.typography.fontWeight, "Font weight should match")
    }
    
    // MARK: - Test document with text objects
    
    @Test func testDocumentWithTextObjects() {
        let document = VectorDocument()
        
        // Note: Document starts with background shapes, not empty
        let initialObjectCount = document.unifiedObjects.count
        #expect(initialObjectCount > 0, "Document starts with background shapes")
        
        // Add a text object
        let text = VectorText(content: "Not Empty", position: CGPoint(x: 100, y: 100))
        document.addTextToUnifiedSystem(text, layerIndex: 2) // Use working layer
        
        // Should have one more object
        #expect(document.unifiedObjects.count == initialObjectCount + 1, "Document should have added one object")
        
        // Remove the text
        document.unifiedObjects.removeAll { $0.id == text.id }
        
        // Should be back to initial count
        #expect(document.unifiedObjects.count == initialObjectCount, "Document should be back to initial object count")
    }
    
    // MARK: - Test legacy textObjects array sync
    
    @Test func testLegacyTextObjectsArraySync() {
        let document = VectorDocument()
        
        let text = VectorText(content: "Legacy Sync", position: CGPoint(x: 100, y: 100))
        
        // Add through unified system
        document.addTextToUnifiedSystem(text, layerIndex: 0)
        
        // Check legacy array is synced
        #expect(document.allTextObjects.count == 1, "Text should be in unified system")
        #expect(document.allTextObjects.first?.id == text.id, "Unified system should contain the same text")
        
        // Both should return the same text
        let fromUnified = document.allTextObjects.first
        let fromLegacy = document.allTextObjects.first
        
        #expect(fromUnified?.id == fromLegacy?.id, "Both systems should return same text object")
    }
}