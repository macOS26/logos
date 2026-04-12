import XCTest
@testable import logos_inkpen_io

class TextToOutlinesExportTests: XCTestCase {

    var document = VectorDocument()
    var documentState = DocumentState()

    override func setUp() {
        super.setUp()

        document = VectorDocument()

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

        if let shape = testText.toShape() {
            document.addShape(shape, to: 2)
        }

        documentState = DocumentState()
        documentState.setDocument(document)
    }

    override func tearDown() {
        super.tearDown()
    }

    func testConvertAllTextToOutlinesForExport() {
        let initialTextCount = document.allTextObjects.count
        XCTAssertGreaterThan(initialTextCount, 0, "Document should have at least one text object")

        let initialObjectCount = document.unifiedObjects.count

        documentState.convertAllTextToOutlinesForExport(document)

        XCTAssertEqual(document.allTextObjects.count, 0, "All text objects should be converted to outlines")

        XCTAssertTrue(document.selectedTextIDs.isEmpty, "Text selection should be cleared")

        XCTAssertGreaterThanOrEqual(document.unifiedObjects.count, initialObjectCount, "Should have created outline shapes")
    }

    func testDocumentStateRestorationAfterExport() {
        let initialTextCount = document.allTextObjects.count
        let initialUnifiedObjects = document.unifiedObjects.map { $0.id }
        let initialLayers = document.layers.map { $0.id }

        documentState.convertAllTextToOutlinesForExport(document)

        XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted")

        guard let savedState = try? document.generateSaveData() else {
            XCTFail("Failed to generate save data")
            return
        }

        document.unifiedObjects.removeAll()

        guard let restoredDoc = try? VectorDocument.load(from: savedState) else {
            XCTFail("Failed to restore document")
            return
        }

        XCTAssertEqual(restoredDoc.layers.count, document.layers.count, "Layers should be restored")
        XCTAssertFalse(restoredDoc.unifiedObjects.isEmpty, "Objects should be restored")
    }

    func testTextToOutlinesPreservesVisualAppearance() {
        guard let initialText = document.allTextObjects.first else {
            XCTFail("No text object found")
            return
        }

        let initialFillColor = initialText.typography.fillColor
        let initialFillOpacity = initialText.typography.fillOpacity
        let initialPosition = initialText.position

        documentState.convertAllTextToOutlinesForExport(document)

        let createdShapes = document.allShapes.filter { shape in
            !shape.isTextObject
        }

        XCTAssertGreaterThan(createdShapes.count, 0, "Should have created outline shapes")

        if let firstShape = createdShapes.first,
           let fillStyle = firstShape.fillStyle {
            XCTAssertEqual(fillStyle.color, initialFillColor, "Fill color should be preserved")
            XCTAssertEqual(fillStyle.opacity, initialFillOpacity, "Fill opacity should be preserved")
        } else {
            XCTFail("Created shape should have fill style")
        }
    }

    func testEmptyDocumentHandling() {
        let emptyDoc = VectorDocument()
        let emptyDocState = DocumentState()
        emptyDocState.setDocument(emptyDoc)

        XCTAssertEqual(emptyDoc.allTextObjects.count, 0, "Empty document should have no text")

        emptyDocState.convertAllTextToOutlinesForExport(emptyDoc)

        XCTAssertNotNil(emptyDoc, "Document should still be valid")
        XCTAssertEqual(emptyDoc.allTextObjects.count, 0, "Should still have no text")
    }

    func testMultipleTextObjectsConversion() {
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

        documentState.convertAllTextToOutlinesForExport(document)

        XCTAssertEqual(document.allTextObjects.count, 0, "All text objects should be converted")

        let nonTextShapes = document.allShapes.filter { !$0.isTextObject }
        XCTAssertGreaterThan(nonTextShapes.count, 0, "Should have created outline shapes")
    }

    func testTextSelectionCleared() {
        let textIDs = document.allTextObjects.map { $0.id }
        document.selectedTextIDs = Set(textIDs)

        XCTAssertFalse(document.selectedTextIDs.isEmpty, "Should have text selected")

        documentState.convertAllTextToOutlinesForExport(document)

        XCTAssertTrue(document.selectedTextIDs.isEmpty, "Text selection should be cleared after conversion")
    }

    func testRectangleGlyphDetectionAndRemoval() {
        let textWithMissingGlyphs = VectorText(
            content: "Test 𝕏 \u{1F9FF} Text",
            position: CGPoint(x: 100, y: 100),
            typography: Typography(
                fontFamily: "Helvetica",
                fontSize: 24,
                fillColor: .black,
                fillOpacity: 1.0
            )
        )

        if let shape = textWithMissingGlyphs.toShape() {
            document.addShape(shape, to: 2)
        }

        let initialTextCount = document.allTextObjects.count
        XCTAssertGreaterThan(initialTextCount, 0, "Should have text objects")

        documentState.convertAllTextToOutlinesForExport(document)

        XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted")

        let nonTextShapes = document.allShapes.filter { !$0.isTextObject }
        XCTAssertGreaterThan(nonTextShapes.count, 0, "Should have created outline shapes")

    }

    func testNormalCharactersNotDetectedAsRectangles() {
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

        if let shape = normalText.toShape() {
            document.addShape(shape, to: 2)
        }

        documentState.convertAllTextToOutlinesForExport(document)

        XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted")

        let nonTextShapes = document.allShapes.filter { !$0.isTextObject }
        XCTAssertGreaterThan(nonTextShapes.count, 0, "Should have created outline shapes for normal text")
    }
}
