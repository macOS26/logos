//
//  ExportTextOptionsHandlerTests.swift
//  logos inkpen.io Tests
//
//  Tests for the consolidated export text options handler
//

import XCTest
import AppKit
@testable import logos_inkpen_io

final class ExportTextOptionsHandlerTests: XCTestCase {

    func testTextOptionsHandlerToggle() {
        // Create UI controls
        let checkbox = NSButton()
        let label = NSTextField()
        let glyphsRadio = NSButton()
        let linesRadio = NSButton()

        // Create handler
        let handler = ExportTextOptionsHandler(
            textToOutlinesCheckbox: checkbox,
            textModeLabel: label,
            glyphsRadio: glyphsRadio,
            linesRadio: linesRadio
        )

        // Test toggle when checkbox is ON (should hide text options)
        checkbox.state = .on
        handler.toggleTextOptions(checkbox)

        XCTAssertTrue(label.isHidden)
        XCTAssertTrue(glyphsRadio.isHidden)
        XCTAssertTrue(linesRadio.isHidden)

        // Test toggle when checkbox is OFF (should show text options)
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

        // Select glyphs
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

        // Select lines
        handler.selectLines(linesRadio)

        XCTAssertEqual(glyphsRadio.state, .off)
        XCTAssertEqual(linesRadio.state, .on)
    }

    func testUICreationHelpers() {
        // Test checkbox creation
        let checkbox = ExportTextRenderingUI.createTextToOutlinesCheckbox(y: 100, defaultState: .on)
        XCTAssertEqual(checkbox.title, "Convert text to outlines")
        XCTAssertEqual(checkbox.state, .on)
        XCTAssertEqual(checkbox.frame.origin.y, 100)

        // Test label creation
        let label = ExportTextRenderingUI.createTextModeLabel(y: 50, text: "Test Label")
        XCTAssertEqual(label.stringValue, "Test Label")
        XCTAssertEqual(label.frame.origin.y, 50)

        // Test glyphs radio with SVG mode
        AppState.shared.svgTextRenderingMode = .glyphs
        let glyphsRadio = ExportTextRenderingUI.createGlyphsRadioButton(y: 30, mode: AppState.shared.svgTextRenderingMode)
        XCTAssertEqual(glyphsRadio.state, .on)

        // Test lines radio with PDF mode
        AppState.shared.pdfTextRenderingMode = .lines
        let linesRadio = ExportTextRenderingUI.createLinesRadioButton(y: 20, mode: AppState.shared.pdfTextRenderingMode)
        XCTAssertEqual(linesRadio.state, .on)
    }

    func testExportWithTextToOutlines() async throws {
        // Create test document
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

        // Initial state check
        XCTAssertEqual(document.allTextObjects.count, 1)

        // Export with text to outlines
        let data = try await DocumentState.exportWithTextToOutlines(document) {
            // Simulate export - text should be converted at this point
            XCTAssertEqual(document.allTextObjects.count, 0, "Text should be converted to outlines")
            return Data("test".utf8)
        }

        // After export, text should be restored
        XCTAssertEqual(document.allTextObjects.count, 1, "Text should be restored")
        XCTAssertEqual(data, Data("test".utf8))
    }
}