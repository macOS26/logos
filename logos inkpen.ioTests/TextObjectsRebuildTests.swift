import XCTest
@testable import logos_inkpen_io

/// Tests that verify text objects are properly managed in the unified system
class TextObjectsRebuildTests: XCTestCase {
    var document: VectorDocument!
    
    override func setUp() {
        super.setUp()
        document = VectorDocument()
    }
    
    override func tearDown() {
        document = nil
        super.tearDown()
    }
    
    // MARK: - Basic Rebuild Tests
    
    func testUnifiedSystemPreservesTextContent() {
        // Add text through unified system
        let text1 = VectorText(
            content: "First Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 100, y: 100)
        )
        let text2 = VectorText(
            content: "Second Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 200, y: 200)
        )
        
        document.addTextToUnifiedSystem(text1, layerIndex: 2)
        document.addTextToUnifiedSystem(text2, layerIndex: 2)
        
        // Verify text is accessible from unified system
        XCTAssertEqual(document.allTextObjects.count, 2, "Should have 2 text objects in unified")
        XCTAssertTrue(document.allTextObjects.contains { $0.content == "First Text" }, "First text should be present")
        XCTAssertTrue(document.allTextObjects.contains { $0.content == "Second Text" }, "Second text should be present")
    }
    
    func testRebuildPreservesTextIDs() {
        // Add text with specific IDs
        let id1 = UUID()
        let id2 = UUID()
        
        var text1 = VectorText(
            content: "Text 1",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        text1.id = id1
        
        var text2 = VectorText(
            content: "Text 2",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        text2.id = id2
        
        document.addTextToUnifiedSystem(text1, layerIndex: 2)
        document.addTextToUnifiedSystem(text2, layerIndex: 2)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify IDs are preserved
        XCTAssertTrue(document.allTextObjects.contains { $0.id == id1 }, "ID1 should be preserved")
        XCTAssertTrue(document.allTextObjects.contains { $0.id == id2 }, "ID2 should be preserved")
    }
    
    func testRebuildPreservesTypography() {
        // Add text with custom typography
        let text = VectorText(
            content: "Styled Text",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontWeight: .bold,
                fontSize: 36,
                alignment: .center,
                strokeColor: .rgb(RGBColor(red: 1, green: 0, blue: 0)),
                fillColor: .rgb(RGBColor(red: 0, green: 0, blue: 1))
            ),
            position: CGPoint(x: 100, y: 100)
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify typography is preserved
        if let rebuiltText = document.allTextObjects.first {
            XCTAssertEqual(rebuiltText.typography.fontFamily, "Helvetica")
            XCTAssertEqual(rebuiltText.typography.fontWeight, .bold)
            XCTAssertEqual(rebuiltText.typography.fontSize, 36)
            XCTAssertEqual(rebuiltText.typography.alignment, .center)
        } else {
            XCTFail("Text should exist after rebuild")
        }
    }
    
    func testRebuildPreservesPosition() {
        // Add text at specific positions
        let text1 = VectorText(
            content: "Text 1",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 123, y: 456)
        )
        let text2 = VectorText(
            content: "Text 2",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: CGPoint(x: 789, y: 321)
        )
        
        document.addTextToUnifiedSystem(text1, layerIndex: 2)
        document.addTextToUnifiedSystem(text2, layerIndex: 2)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify positions are preserved
        if let rebuiltText1 = document.allTextObjects.first(where: { $0.content == "Text 1" }) {
            XCTAssertEqual(rebuiltText1.position, CGPoint(x: 123, y: 456))
        } else {
            XCTFail("Text 1 should exist")
        }
        
        if let rebuiltText2 = document.allTextObjects.first(where: { $0.content == "Text 2" }) {
            XCTAssertEqual(rebuiltText2.position, CGPoint(x: 789, y: 321))
        } else {
            XCTFail("Text 2 should exist")
        }
    }
    
    func testRebuildPreservesEditingState() {
        // Add text and set editing state
        let text = VectorText(
            content: "Editing Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        document.setTextEditingInUnified(id: text.id, isEditing: true)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify editing state is preserved
        if let rebuiltText = document.allTextObjects.first {
            XCTAssertTrue(rebuiltText.isEditing, "Editing state should be preserved")
        } else {
            XCTFail("Text should exist")
        }
    }
    
    func testRebuildPreservesAreaSize() {
        // Add text with area size
        var text = VectorText(
            content: "Box Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        text.areaSize = CGSize(width: 300, height: 200)
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify area size is preserved
        if let rebuiltText = document.allTextObjects.first {
            XCTAssertEqual(rebuiltText.areaSize, CGSize(width: 300, height: 200))
        } else {
            XCTFail("Text should exist")
        }
    }
    
    // MARK: - Order Preservation Tests
    
    func testRebuildPreservesOrder() {
        // Add multiple texts
        let texts = (1...5).map { i in
            VectorText(
                content: "Text \(i)",
                typography: TypographyProperties(strokeColor: .black, fillColor: .black),
                position: CGPoint(x: Double(i * 100), y: 100)
            )
        }
        
        for text in texts {
            document.addTextToUnifiedSystem(text, layerIndex: 2)
        }
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify order is preserved
        XCTAssertEqual(document.allTextObjects.count, 5)
        for (index, text) in document.allTextObjects.enumerated() {
            XCTAssertEqual(text.content, "Text \(index + 1)", "Order should be preserved")
        }
    }
    
    func testRebuildHandlesMixedLayerTexts() {
        // Add texts to different layers
        let text1 = VectorText(
            content: "Layer 2 Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        let text2 = VectorText(
            content: "Layer 3 Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text1, layerIndex: 2)
        document.addTextToUnifiedSystem(text2, layerIndex: 3)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify both texts are present with correct layer indices
        XCTAssertEqual(document.allTextObjects.count, 2)
        
        if let layer2Text = document.allTextObjects.first(where: { $0.content == "Layer 2 Text" }) {
            XCTAssertEqual(layer2Text.layerIndex, 2)
        } else {
            XCTFail("Layer 2 text should exist")
        }
        
        if let layer3Text = document.allTextObjects.first(where: { $0.content == "Layer 3 Text" }) {
            XCTAssertEqual(layer3Text.layerIndex, 3)
        } else {
            XCTFail("Layer 3 text should exist")
        }
    }
    
    // MARK: - Update and Rebuild Tests
    
    func testTypographyUpdateReflectsInRebuild() {
        // Add text
        let text = VectorText(
            content: "Test Text",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Update typography
        let newTypography = TypographyProperties(
            fontFamily: "Times New Roman",
            fontSize: 48,
            strokeColor: .black,
            fillColor: .black
        )
        document.updateTextTypographyInUnified(id: text.id, typography: newTypography)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify update is reflected
        if let rebuiltText = document.allTextObjects.first {
            XCTAssertEqual(rebuiltText.typography.fontFamily, "Times New Roman")
            XCTAssertEqual(rebuiltText.typography.fontSize, 48)
        } else {
            XCTFail("Text should exist")
        }
    }
    
    func testContentUpdateReflectsInRebuild() {
        // Add text
        let text = VectorText(
            content: "Original",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Update content
        document.updateTextContentInUnified(id: text.id, content: "Modified")
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify update is reflected
        if let rebuiltText = document.allTextObjects.first {
            XCTAssertEqual(rebuiltText.content, "Modified")
        } else {
            XCTFail("Text should exist")
        }
    }
    
    func testDeletedTextNotInRebuild() {
        // Add texts
        let text1 = VectorText(
            content: "Keep This",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        let text2 = VectorText(
            content: "Delete This",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text1, layerIndex: 2)
        document.addTextToUnifiedSystem(text2, layerIndex: 2)
        
        // Delete one text
        document.removeTextFromUnifiedSystem(id: text2.id)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify only kept text is present
        XCTAssertEqual(document.allTextObjects.count, 1)
        XCTAssertEqual(document.allTextObjects.first?.content, "Keep This")
        XCTAssertFalse(document.allTextObjects.contains { $0.content == "Delete This" })
    }
    
    // MARK: - Edge Case Tests
    
    func testRebuildWithNoTexts() {
        // Ensure no texts exist
        document.removeAllText()
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify empty array
        XCTAssertEqual(document.allTextObjects.count, 0)
    }
    
    func testRebuildAfterPopulateUnifiedObjects() {
        // Add text
        let text = VectorText(
            content: "Test",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Populate unified objects (this should trigger rebuild)
        document.populateUnifiedObjectsFromLayersPreservingOrder()
        
        // Verify text is in textObjects
        XCTAssertEqual(document.allTextObjects.count, 1)
        XCTAssertEqual(document.allTextObjects.first?.content, "Test")
    }
    
    func testRebuildPreservesVisibilityAndLockState() {
        // Add text
        let text = VectorText(
            content: "Test",
            typography: TypographyProperties(strokeColor: .black, fillColor: .black),
            position: .zero
        )
        
        document.addTextToUnifiedSystem(text, layerIndex: 2)
        
        // Set visibility and lock state
        document.hideTextInUnified(id: text.id)
        document.lockTextInUnified(id: text.id)
        
        // Rebuild
        // Text is now accessed directly from unified system
        
        // Verify states are preserved
        if let rebuiltText = document.allTextObjects.first {
            XCTAssertFalse(rebuiltText.isVisible, "Should be hidden")
            XCTAssertTrue(rebuiltText.isLocked, "Should be locked")
        } else {
            XCTFail("Text should exist")
        }
    }
}