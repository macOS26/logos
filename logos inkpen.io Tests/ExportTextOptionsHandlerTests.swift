
import XCTest
import AppKit
@testable import logos_inkpen_io

final class ExportTextOptionsHandlerTests: XCTestCase {

    func testTextOptionsHandlerToggle() {
        let checkbox = NSButton()
        let label = NSTextField()
        let glyphsRadio = NSButton()
        let linesRadio = NSButton()

        let handler = ExportTextOptionsHandler(
            textToOutlinesCheckbox: checkbox,
            textModeLabel: label,
            glyphsRadio: glyphsRadio,
            linesRadio: linesRadio
        )

        checkbox.state = .on
        handler.toggleTextOptions(checkbox)

        XCTAssertTrue(label.isHidden)
        XCTAssertTrue(glyphsRadio.isHidden)
        XCTAssertTrue(linesRadio.isHidden)

        checkbox.state = .off
        handler.toggleTextOptions(checkbox)

        XCTAssertFalse(label.isHidden)
        XCTAssertFalse(glyphsRadio.isHidden)
        XCTAssertFalse(linesRadio.isHidden)
    }

    func testGlyphsSelection() {
        let checkbox = NSButton()
        let label = NSTextField()
        let glyphsRadio = NSButton()
        let linesRadio = NSButton()

        let handler = ExportTextOptionsHandler(
            textToOutlinesCheckbox: checkbox,
            textModeLabel: label,
            glyphsRadio: glyphsRadio,
            linesRadio: linesRadio
        )

        handler.selectGlyphs(glyphsRadio)

        XCTAssertEqual(glyphsRadio.state, .on)
        XCTAssertEqual(linesRadio.state, .off)
    }

    func testLinesSelection() {
        let checkbox = NSButton()
        let label = NSTextField()
        let glyphsRadio = NSButton()
        let linesRadio = NSButton()

        let handler = ExportTextOptionsHandler(
            textToOutlinesCheckbox: checkbox,
            textModeLabel: label,
            glyphsRadio: glyphsRadio,
            linesRadio: linesRadio
        )

        handler.selectLines(linesRadio)

        XCTAssertEqual(glyphsRadio.state, .off)
        XCTAssertEqual(linesRadio.state, .on)
    }

    func testUICreationHelpers() {
        let checkbox = ExportTextRenderingUI.createTextToOutlinesCheckbox(y: 100, defaultState: .on)
        XCTAssertEqual(checkbox.title, "Convert text to outlines")
        XCTAssertEqual(checkbox.state, .on)
        XCTAssertEqual(checkbox.frame.origin.y, 100)

        let label = ExportTextRenderingUI.createTextModeLabel(y: 50, text: "Test Label")
        XCTAssertEqual(label.stringValue, "Test Label")
        XCTAssertEqual(label.frame.origin.y, 50)

        AppState.shared.svgTextRenderingMode = .glyphs
        let glyphsRadio = ExportTextRenderingUI.createGlyphsRadioButton(y: 30, mode: AppState.shared.svgTextRenderingMode)
        XCTAssertEqual(glyphsRadio.state, .on)

        AppState.shared.pdfTextRenderingMode = .lines
        let linesRadio = ExportTextRenderingUI.createLinesRadioButton(y: 20, mode: AppState.shared.pdfTextRenderingMode)
        XCTAssertEqual(linesRadio.state, .on)
    }

    func testExportWithTextToOutlines() async throws {
        let document = TemplateManager.shared.createBlankDocument()
        let textObj = VectorShape.createTextShape(
            text: "Test Text",
            position: CGPoint(x: 100, y: 100),
            fontSize: 24,
            fontName: "Helvetica"
        )

        guard let layerIndex = document.selectedLayerIndex else {
            XCTFail("No selected layer")
            return
        }

        document.addShape(textObj, to: layerIndex)

        XCTAssertEqual(document.allTextObjects.count, 1)

        let data = try await DocumentState.exportWithTextToOutlines(document) {
            XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted to outlines")
            return Data("test".utf8)
        }

        XCTAssertEqual(document.allTextObjects.count, 1, "Text should be restored")
        XCTAssertEqual(data, Data("test".utf8))
    }
}