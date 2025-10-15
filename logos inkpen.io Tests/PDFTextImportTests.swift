import XCTest
@testable import logos_inkpen_io

class PDFTextImportTests: XCTestCase {

    func testBeginEndTextOperators() {
        let parser = PDFCommandParser()

        parser.handleBeginText()
        XCTAssertTrue(parser.isInTextObject, "BT should set isInTextObject to true")
        XCTAssertEqual(parser.currentTextMatrix, .identity, "BT should reset text matrix")
        XCTAssertEqual(parser.currentLineMatrix, .identity, "BT should reset line matrix")
        XCTAssertEqual(parser.currentTextContent, "", "BT should clear text content")

        parser.currentTextContent = "Test Text"

        parser.handleEndText()
        XCTAssertFalse(parser.isInTextObject, "ET should set isInTextObject to false")
        XCTAssertGreaterThan(parser.shapes.count, 0, "ET should create shape if text exists")

        if let shape = parser.shapes.first {
            XCTAssertTrue(shape.isTextObject, "Created shape should be marked as text object")
            XCTAssertEqual(shape.textContent, "Test Text", "Shape should contain the text content")
        }
    }

    func testFontSettingOperator() {
        let parser = PDFCommandParser()
        parser.currentFontName = "OldFont"
        parser.currentFontSize = 10.0

        parser.currentFontName = "Helvetica"
        parser.currentFontSize = 24.0

        XCTAssertEqual(parser.currentFontName, "Helvetica", "Font name should be updated")
        XCTAssertEqual(parser.currentFontSize, 24.0, "Font size should be updated")
    }

    func testTextSpacingOperators() {
        let parser = PDFCommandParser()

        parser.textCharacterSpacing = 2.0
        XCTAssertEqual(parser.textCharacterSpacing, 2.0, "Character spacing should be set")

        parser.textWordSpacing = 3.0
        XCTAssertEqual(parser.textWordSpacing, 3.0, "Word spacing should be set")

        parser.textHorizontalScaling = 150.0
        XCTAssertEqual(parser.textHorizontalScaling, 150.0, "Horizontal scaling should be set")

        parser.textLeading = 20.0
        XCTAssertEqual(parser.textLeading, 20.0, "Text leading should be set")

        parser.textRise = 5.0
        XCTAssertEqual(parser.textRise, 5.0, "Text rise should be set")
    }

    func testTextRenderingMode() {
        let parser = PDFCommandParser()

        let modes = [
            (0, "fill"),
            (1, "stroke"),
            (2, "fill+stroke"),
            (3, "invisible"),
            (4, "fill+clip"),
            (5, "stroke+clip"),
            (6, "fill+stroke+clip"),
            (7, "clip")
        ]

        for (mode, _) in modes {
            parser.textRenderingMode = mode
            XCTAssertEqual(parser.textRenderingMode, mode, "Rendering mode \(mode) should be set")
        }
    }

    func testTextMatrixOperations() {
        let parser = PDFCommandParser()

        let testMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 100, ty: 200)
        parser.currentTextMatrix = testMatrix
        parser.currentLineMatrix = testMatrix

        XCTAssertEqual(parser.currentTextMatrix, testMatrix, "Text matrix should be set")
        XCTAssertEqual(parser.currentLineMatrix, testMatrix, "Line matrix should match text matrix")
    }

    func testVectorTextCreationFromPDF() {
        let parser = PDFCommandParser()

        parser.isInTextObject = true
        parser.currentFontName = "Helvetica"
        parser.currentFontSize = 24.0
        parser.textCharacterSpacing = 1.0
        parser.textLeading = 30.0
        parser.currentTextContent = "Sample PDF Text"
        parser.currentFillColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        parser.textRenderingMode = 0

        parser.handleEndText()

        XCTAssertEqual(parser.shapes.count, 1, "Should create one shape")

        if let shape = parser.shapes.first {
            XCTAssertTrue(shape.isTextObject, "Shape should be text object")
            XCTAssertEqual(shape.textContent, "Sample PDF Text", "Text content should match")

            XCTAssertEqual(shape.metadata["fontFamily"], "Helvetica", "Font family should be stored")
            XCTAssertEqual(shape.metadata["fontSize"], "24.0", "Font size should be stored")
            XCTAssertEqual(shape.metadata["letterSpacing"], "1.0", "Letter spacing should be stored")
            XCTAssertEqual(shape.metadata["lineSpacing"], "30.0", "Line spacing should be stored")

            XCTAssertNotNil(shape.fillStyle, "Should have fill style")
            if let fillStyle = shape.fillStyle {
                XCTAssertEqual(fillStyle.opacity, 1.0, "Fill opacity should be 1.0")
            }
        }
    }

    func testVectorTextReconstructionFromMetadata() {
        var shape = VectorShape(
            name: "Text: Test",
            path: VectorPath(elements: [])
        )

        shape.isTextObject = true
        shape.textContent = "Reconstructed Text"
        shape.textPosition = CGPoint(x: 100, y: 200)
        shape.metadata = [
            "fontFamily": "Arial",
            "fontSize": "18.0",
            "letterSpacing": "2.0",
            "wordSpacing": "5.0",
            "lineSpacing": "25.0"
        ]

        let vectorText = VectorText.from(shape)

        XCTAssertNotNil(vectorText, "Should create VectorText from shape")

        if let text = vectorText {
            XCTAssertEqual(text.content, "Reconstructed Text", "Content should match")
            XCTAssertEqual(text.position, CGPoint(x: 100, y: 200), "Position should match")
            XCTAssertEqual(text.typography.fontFamily, "Arial", "Font family should match")
            XCTAssertEqual(text.typography.fontSize, 18.0, "Font size should match")
            XCTAssertEqual(text.typography.letterSpacing, 2.0, "Letter spacing should match")
            XCTAssertEqual(text.typography.lineSpacing, 25.0, "Line spacing should match")
        }
    }

    func testPDFFontMapping() {
        let fontMappings = [
            ("Times-Roman", "Times New Roman"),
            ("Helvetica", "Helvetica"),
            ("Courier", "Courier"),
            ("ArialMT", "Arial"),
            ("Arial-BoldMT", "Arial-Bold")
        ]

        for (pdfFont, systemFont) in fontMappings {
            XCTAssertNotNil(pdfFont, "PDF font name should exist")
            XCTAssertNotNil(systemFont, "System font name should exist")
        }
    }

    func testTextEncodingExtraction() {
        let utf8Text = "UTF-8 Text: 你好"
        let asciiText = "ASCII Text"
        let macRomanText = "MacRoman: Café"

        if let utf8Data = utf8Text.data(using: .utf8),
           let utf8Recovered = String(data: utf8Data, encoding: .utf8) {
            XCTAssertEqual(utf8Recovered, utf8Text, "UTF-8 should round-trip")
        }

        if let asciiData = asciiText.data(using: .ascii),
           let asciiRecovered = String(data: asciiData, encoding: .ascii) {
            XCTAssertEqual(asciiRecovered, asciiText, "ASCII should round-trip")
        }

        if let macRomanData = macRomanText.data(using: .macOSRoman),
           let macRomanRecovered = String(data: macRomanData, encoding: .macOSRoman) {
            XCTAssertEqual(macRomanRecovered, macRomanText, "MacRoman should round-trip")
        }
    }

    func testTextRenderingModeConversion() {
        let parser = PDFCommandParser()

        parser.textRenderingMode = 0
        parser.currentFillColor = CGColor(red: 1, green: 0, blue: 0, alpha: 1)
        parser.currentFillOpacity = 0.8
        parser.isInTextObject = true
        parser.currentTextContent = "Fill Text"
        parser.handleEndText()

        if let shape = parser.shapes.last {
            XCTAssertNotNil(shape.fillStyle, "Fill mode should create fill style")
            XCTAssertNil(shape.strokeStyle, "Fill mode should not create stroke style")
        }

        parser.shapes.removeAll()
        parser.textRenderingMode = 1
        parser.currentStrokeColor = CGColor(red: 0, green: 1, blue: 0, alpha: 1)
        parser.currentStrokeOpacity = 0.6
        parser.currentLineWidth = 2.0
        parser.isInTextObject = true
        parser.currentTextContent = "Stroke Text"
        parser.handleEndText()

        if let shape = parser.shapes.last {
            XCTAssertNotNil(shape.strokeStyle, "Stroke mode should create stroke style")
            if let strokeStyle = shape.strokeStyle {
                XCTAssertEqual(strokeStyle.width, 2.0, "Stroke width should match")
                XCTAssertEqual(strokeStyle.opacity, 0.6, "Stroke opacity should match")
            }
        }

        parser.shapes.removeAll()
        parser.textRenderingMode = 2
        parser.isInTextObject = true
        parser.currentTextContent = "Fill+Stroke Text"
        parser.handleEndText()

        if let shape = parser.shapes.last {
            XCTAssertNotNil(shape.fillStyle, "Fill+stroke mode should create fill style")
            XCTAssertNotNil(shape.strokeStyle, "Fill+stroke mode should create stroke style")
        }
    }

    func testMultiLineTextHandling() {
        let parser = PDFCommandParser()

        parser.isInTextObject = true
        parser.currentTextContent = "Line 1\nLine 2\nLine 3"
        parser.textLeading = 20.0
        parser.handleEndText()

        if let shape = parser.shapes.first {
            XCTAssertTrue(shape.textContent?.contains("\n") ?? false, "Should preserve newlines")

            let lines = shape.textContent?.components(separatedBy: "\n") ?? []
            XCTAssertEqual(lines.count, 3, "Should have 3 lines")
        }
    }

    func testFullPDFTextRoundTrip() {
        let originalText = VectorText(
            content: "Round Trip Test",
            typography: TypographyProperties(
                fontFamily: "Helvetica",
                fontSize: 24,
                strokeColor: .black,
                fillColor: .black
            ),
            position: CGPoint(x: 100, y: 200)
        )

        let shape = originalText.toVectorShape()

        XCTAssertTrue(shape.isTextObject, "Shape should be text object")
        XCTAssertEqual(shape.textContent, "Round Trip Test", "Content should match")
        XCTAssertNotNil(shape.metadata["fontFamily"], "Should have font metadata")

        let reconstructedText = VectorText.from(shape)

        XCTAssertNotNil(reconstructedText, "Should reconstruct VectorText")

        if let text = reconstructedText {
            XCTAssertEqual(text.content, originalText.content, "Content should match")
            XCTAssertEqual(text.typography.fontFamily, originalText.typography.fontFamily, "Font should match")
            XCTAssertEqual(text.typography.fontSize, originalText.typography.fontSize, "Font size should match")
            XCTAssertEqual(text.position, originalText.position, "Position should match")
        }
    }
}
