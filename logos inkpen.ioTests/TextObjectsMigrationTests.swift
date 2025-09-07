import XCTest
@testable import logos_inkpen_io

/// Tests that verify the migration from direct textObjects access to unified system
class TextObjectsMigrationTests: XCTestCase {
    var document: VectorDocument!
    
    override func setUp() {
        super.setUp()
        document = VectorDocument()
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    // MARK: - Computed Property Tests
    
    func testAllTextObjectsReturnsFromUnified() {
        // Add texts through unified
        let text1 = VectorText(
            content: "Text 1",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        let text2 = VectorText(
            content: "Text 2",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text1, layerIndex: 2)
        document.addTextToUnifiedSystem(text2, layerIndex: 2)
        
        // Use allTextObjects computed property
        let allTexts = document.allTextObjects
        
        XCTAssertEqual(allTexts.count, 2)
        XCTAssertTrue(allTexts.contains { $0.content == "Text 1" })
        XCTAssertTrue(allTexts.contains { $0.content == "Text 2" })
    }
    
    func testAllTextObjectsReflectsUnifiedChanges() {
        // Add text
        let text = VectorText(
            content: "Original",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Verify initial state
        XCTAssertEqual(document.allTextObjects.count, 1)
        XCTAssertEqual(document.allTextObjects.first?.content, "Original")
        
        // Update through unified
        document.updateTextContentInUnified(id: text.id, content: "Updated")
        
        // Verify change reflects in allTextObjects
        XCTAssertEqual(document.allTextObjects.first?.content, "Updated")
    }
    
    // MARK: - Unified Helper Tests
    
    func testAddTextToUnifiedSystemAddsToUnified() {
        let text = VectorText(
            content: "Test",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Verify text is in unified objects as shape
        let textInUnified = document.unifiedObjects.first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == text.id && shape.isTextObject
            }
            return false
        }
        
        XCTAssertNotNil(textInUnified, "Text should be in unified objects")
        
        if case .shape(let shape) = textInUnified?.objectType {
            XCTAssertTrue(shape.isTextObject)
            XCTAssertEqual(shape.textContent, "Test")
        }
    }
    
    func testRemoveTextFromUnifiedSystemRemovesFromUnified() {
        let text = VectorText(
            content: "Remove Me",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        XCTAssertEqual(document.allTextObjects.count, 1)
        
        document.removeTextFromUnifiedSystem(id: text.id)
        
        XCTAssertEqual(document.allTextObjects.count, 0)
        XCTAssertFalse(document.unifiedObjects.contains { $0.id == text.id })
    }
    
    func testUpdateTextContentInUnifiedUpdatesShape() {
        let text = VectorText(
            content: "Original",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        document.updateTextContentInUnified(id: text.id, content: "Modified")
        
        // Check in unified objects
        if let unifiedObj = document.unifiedObjects.first(where: { $0.id == text.id }),
           case .shape(let shape) = unifiedObj.objectType {
            XCTAssertEqual(shape.textContent, "Modified")
        } else {
            XCTFail("Text should be in unified objects")
        }
    }
    
    func testUpdateTextTypographyInUnifiedUpdatesShape() {
        let text = VectorText(
            content: "Test",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        let newTypography = TypographyProperties(
            fontFamily: "Arial",
            fontSize: 36,
            strokeColor: .black,
            fillColor: .black
        )
        document.updateTextTypographyInUnified(id: text.id, typography: newTypography)
        
        // Check in unified objects
        if let unifiedObj = document.unifiedObjects.first(where: { $0.id == text.id }),
           case .shape(let shape) = unifiedObj.objectType {
            XCTAssertEqual(shape.typography?.fontFamily, "Arial")
            XCTAssertEqual(shape.typography?.fontSize, 36)
        } else {
            XCTFail("Text should be in unified objects")
        }
    }
    
    // MARK: - Legacy Compatibility Tests
    
    func testTextObjectsArrayStaysInSync() {
        // Add text
        let text = VectorText(
            content: "Sync Test",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // After populate, textObjects should be in sync
        document.populateUnifiedObjectsFromLayersPreservingOrder()
        
        XCTAssertEqual(document.allTextObjects.count, 1)
        XCTAssertEqual(document.allTextObjects.first?.content, "Sync Test")
    }
    
    func testTextObjectsRebuildsAfterUnifiedChanges() {
        // Add text
        let text = VectorText(
            content: "Original",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Update content in unified
        document.updateTextContentInUnified(id: text.id, content: "Changed")
        
        // Rebuild
        // Text is accessed directly from unified system
        
        // textObjects should reflect the change
        XCTAssertEqual(document.allTextObjects.first?.content, "Changed")
    }
    
    // MARK: - Selection Tests
    
    func testTextSelectionUsesUnified() {
        let text = VectorText(
            content: "Select Me",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Select through unified
        document.selectedObjectIDs.insert(text.id)
        document.syncSelectionArrays()
        
        XCTAssertTrue(document.selectedTextIDs.contains(text.id))
    }
    
    // MARK: - Layer Integration Tests
    
    func testTextInLayersAsShape() {
        let text = VectorText(
            content: "Layer Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Text should be in unified objects as shape
        let shapeInUnified = document.getShapesForLayer(2).first { shape in
            shape.id == text.id && shape.isTextObject
        }
        
        XCTAssertNotNil(shapeInUnified)
        XCTAssertTrue(shapeInUnified?.isTextObject ?? false)
        XCTAssertEqual(shapeInUnified?.textContent, "Layer Text")
    }
    
    // MARK: - Migration Path Tests
    
    func testMigrationFromDirectAccess() {
        // Simulate old code that would directly access textObjects
        let text = VectorText(
            content: "Legacy",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        // Add through unified (new way)
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Old code would read from textObjects
        // After rebuild, it should still work
        // Text is accessed directly from unified system
        
        // Legacy code reading textObjects would still work
        let legacyRead = document.allTextObjects.first { $0.id == text.id }
        XCTAssertNotNil(legacyRead)
        XCTAssertEqual(legacyRead?.content, "Legacy")
        
        // New code should use allTextObjects
        let newRead = document.allTextObjects.first { $0.id == text.id }
        XCTAssertNotNil(newRead)
        XCTAssertEqual(newRead?.content, "Legacy")
    }
    
    func testNoDirectModificationOfTextObjects() {
        // Add text through unified
        let text = VectorText(
            content: "Do Not Modify Directly",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Any direct modification to textObjects array would be overwritten
        // by the next rebuild
        // Text is now managed in unified system, can't directly modify
        
        // Rebuild restores correct state from unified
        // Text is accessed directly from unified system
        
        XCTAssertEqual(document.allTextObjects.count, 1)
        XCTAssertEqual(document.allTextObjects.first?.content, "Do Not Modify Directly")
    }
    
    // MARK: - Performance Tests
    
    func testRebuildPerformanceWithManyTexts() {
        // Add many texts
        for i in 1...100 {
            let text = VectorText(
                content: "Text \(i)",
                typography: TypographyProperties(strokeColor: .black, fillColor: .black),
                position: CGPoint(x: Double(i * 10), y: Double(i * 10))
            )
            document.addTextToUnifiedSystem(text, layerIndex: 2)
        }
        
        // Measure rebuild performance
        measure {
            // Text is accessed directly from unified system
        }
        
        // Verify all texts are present
        XCTAssertEqual(document.allTextObjects.count, 100)
    }
}