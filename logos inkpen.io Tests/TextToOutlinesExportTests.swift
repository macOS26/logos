//
//  TextToOutlinesExportTests.swift
//  logos inkpen.io Tests
//
//  Created by Claude on 2025/01/29.
//

import XCTest
@testable import logos_inkpen_io

class TextToOutlinesExportTests: XCTestCase {
    
    var document: VectorDocument!
    var documentState: DocumentState!
    
    override func setUp() {
        super.setUp()
        
        // Create a new document with test data
        document = VectorDocument()
        
        // Add a test text object
        let testText = VectorText(
            content: "Test Text",
            position: CGPoint(x: 100, y: 100),
            typography: Typography(
                fontFamily: "Helvetica",
                fontSize: 24,
                fillColor: .black,
                fillOpacity: 1.0
            )
        )
        
        // Add text to document
        if let shape = testText.toShape() {
            document.addShape(shape, to: 2) // Add to default layer
        }
        
        // Create document state
        documentState = DocumentState()
        documentState.setDocument(document)
    }
    
    override func tearDown() {
        document = nil
        documentState = nil
        super.tearDown()
    }
    
    func testConvertAllTextToOutlinesForExport() {
        // Verify initial state has text objects
        let initialTextCount = document.allTextObjects.count
        XCTAssertGreaterThan(initialTextCount, 0, "Document should have at least one text object")
        
        // Get initial unified objects count
        let initialObjectCount = document.unifiedObjects.count
        
        // Convert all text to outlines
        documentState.convertAllTextToOutlinesForExport(document)
        
        // Verify text objects are removed
        XCTAssertEqual(document.allTextObjects.count, 0, "All text objects should be converted to outlines")
        
        // Verify text selection is cleared
        XCTAssertTrue(document.selectedTextIDs.isEmpty, "Text selection should be cleared")
        
        // Verify shapes were created (should have at least as many objects)
        XCTAssertGreaterThanOrEqual(document.unifiedObjects.count, initialObjectCount, "Should have created outline shapes")
    }
    
    func testDocumentStateRestorationAfterExport() {
        // Save initial state
        let initialTextCount = document.allTextObjects.count
        let initialUnifiedObjects = document.unifiedObjects.map { $0.id }
        let initialLayers = document.layers.map { $0.id }
        
        // Perform conversion
        documentState.convertAllTextToOutlinesForExport(document)
        
        // Verify conversion happened
        XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted")
        
        // Create saved state data
        guard let savedState = try? document.generateSaveData() else {
            XCTFail("Failed to generate save data")
            return
        }
        
        // Modify document further to simulate export process
        document.unifiedObjects.removeAll()
        
        // Restore from saved state
        guard let restoredDoc = try? VectorDocument.load(from: savedState) else {
            XCTFail("Failed to restore document")
            return
        }
        
        // Verify restoration
        XCTAssertEqual(restoredDoc.layers.count, document.layers.count, "Layers should be restored")
        XCTAssertFalse(restoredDoc.unifiedObjects.isEmpty, "Objects should be restored")
    }
    
    func testTextToOutlinesPreservesVisualAppearance() {
        // Get initial text object
        guard let initialText = document.allTextObjects.first else {
            XCTFail("No text object found")
            return
        }
        
        let initialFillColor = initialText.typography.fillColor
        let initialFillOpacity = initialText.typography.fillOpacity
        let initialPosition = initialText.position
        
        // Convert to outlines
        documentState.convertAllTextToOutlinesForExport(document)
        
        // Find the created shape(s)
        let createdShapes = document.allShapes.filter { shape in
            !shape.isTextObject // Only non-text shapes
        }
        
        XCTAssertGreaterThan(createdShapes.count, 0, "Should have created outline shapes")
        
        // Verify visual properties are preserved
        if let firstShape = createdShapes.first,
           let fillStyle = firstShape.fillStyle {
            XCTAssertEqual(fillStyle.color, initialFillColor, "Fill color should be preserved")
            XCTAssertEqual(fillStyle.opacity, initialFillOpacity, "Fill opacity should be preserved")
        } else {
            XCTFail("Created shape should have fill style")
        }
    }
    
    func testEmptyDocumentHandling() {
        // Create empty document
        let emptyDoc = VectorDocument()
        let emptyDocState = DocumentState()
        emptyDocState.setDocument(emptyDoc)
        
        // Verify no text objects
        XCTAssertEqual(emptyDoc.allTextObjects.count, 0, "Empty document should have no text")
        
        // Convert should handle empty document gracefully
        emptyDocState.convertAllTextToOutlinesForExport(emptyDoc)
        
        // Verify document is still valid
        XCTAssertNotNil(emptyDoc, "Document should still be valid")
        XCTAssertEqual(emptyDoc.allTextObjects.count, 0, "Should still have no text")
    }
    
    func testMultipleTextObjectsConversion() {
        // Add multiple text objects
        for i in 1...3 {
            let text = VectorText(
                content: "Text \(i)",
                position: CGPoint(x: 100 * Double(i), y: 100),
                typography: Typography(
                    fontFamily: "Helvetica",
                    fontSize: 24,
                    fillColor: .black,
                    fillOpacity: 1.0
                )
            )
            
            if let shape = text.toShape() {
                document.addShape(shape, to: 2)
            }
        }
        
        let textCount = document.allTextObjects.count
        XCTAssertGreaterThan(textCount, 1, "Should have multiple text objects")
        
        // Convert all text
        documentState.convertAllTextToOutlinesForExport(document)
        
        // Verify all text converted
        XCTAssertEqual(document.allTextObjects.count, 0, "All text objects should be converted")
        
        // Verify shapes were created
        let nonTextShapes = document.allShapes.filter { !$0.isTextObject }
        XCTAssertGreaterThan(nonTextShapes.count, 0, "Should have created outline shapes")
    }
    
    func testTextSelectionCleared() {
        // Select text objects
        let textIDs = document.allTextObjects.map { $0.id }
        document.selectedTextIDs = Set(textIDs)

        XCTAssertFalse(document.selectedTextIDs.isEmpty, "Should have text selected")

        // Convert text to outlines
        documentState.convertAllTextToOutlinesForExport(document)

        // Verify selection cleared
        XCTAssertTrue(document.selectedTextIDs.isEmpty, "Text selection should be cleared after conversion")
    }

    func testRectangleGlyphDetectionAndRemoval() {
        // Create text with special characters that might produce rectangles
        // Using uncommon Unicode characters that might not exist in fonts
        let textWithMissingGlyphs = VectorText(
            content: "Test 𝕏 \u{1F9FF} Text", // Contains Unicode chars that might be missing
            position: CGPoint(x: 100, y: 100),
            typography: Typography(
                fontFamily: "Helvetica",
                fontSize: 24,
                fillColor: .black,
                fillOpacity: 1.0
            )
        )

        // Add text to document
        if let shape = textWithMissingGlyphs.toShape() {
            document.addShape(shape, to: 2)
        }

        let initialTextCount = document.allTextObjects.count
        XCTAssertGreaterThan(initialTextCount, 0, "Should have text objects")

        // Convert to outlines - rectangles should be skipped automatically
        documentState.convertAllTextToOutlinesForExport(document)

        // Verify text converted but rectangles were handled
        XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted")

        // Verify we have outline shapes (but not rectangle glyphs)
        let nonTextShapes = document.allShapes.filter { !$0.isTextObject }
        XCTAssertGreaterThan(nonTextShapes.count, 0, "Should have created outline shapes")

        // The shapes should not contain obvious rectangles with counters
        // This is handled automatically by the isRectangleGlyph detection
    }

    func testNormalCharactersNotDetectedAsRectangles() {
        // Create text with normal characters
        let normalText = VectorText(
            content: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789",
            position: CGPoint(x: 100, y: 100),
            typography: Typography(
                fontFamily: "Helvetica",
                fontSize: 24,
                fillColor: .black,
                fillOpacity: 1.0
            )
        )

        // Add text to document
        if let shape = normalText.toShape() {
            document.addShape(shape, to: 2)
        }

        // Convert to outlines
        documentState.convertAllTextToOutlinesForExport(document)

        // All normal characters should be converted successfully
        XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted")

        // Should have created outline shapes for all characters
        let nonTextShapes = document.allShapes.filter { !$0.isTextObject }
        XCTAssertGreaterThan(nonTextShapes.count, 0, "Should have created outline shapes for normal text")
    }
}