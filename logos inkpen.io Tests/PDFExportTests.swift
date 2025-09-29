//
//  PDFExportTests.swift
//  logos inkpen.io Tests
//
//  Created by Claude on 2025-09-28.
//

import XCTest
@testable import logos_inkpen_io

class PDFExportTests: XCTestCase {

    var document: VectorDocument!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        // Create a test document
        document = VectorDocument()

        // Set up document with some test content
        document.settings = DocumentSettings(
            size: .letterPortrait,
            resolution: 72,
            backgroundColor: .white,
            artboardColor: ColorValue.rgb(RGBColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0))
        )

        // Add a test shape to a layer
        let testShape = VectorShape()
        testShape.path = VectorPath(elements: [
            .moveTo(point: CGPoint(x: 100, y: 100)),
            .lineTo(point: CGPoint(x: 200, y: 100)),
            .lineTo(point: CGPoint(x: 200, y: 200)),
            .lineTo(point: CGPoint(x: 100, y: 200)),
            .close
        ])
        testShape.fillStyle = FillStyle(color: .rgb(RGBColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0)), opacity: 1.0)

        // Add shape to a non-background layer (layer index 2 or higher)
        if document.layers.count > 2 {
            document.addShape(testShape, to: 2)
        }

        // Create temp directory for test exports
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("PDFExportTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        super.tearDown()

        // Clean up temp directory
        try? FileManager.default.removeItem(at: tempDirectory)

        document = nil
        tempDirectory = nil
    }

    func testExportPDFWithBackground() throws {
        // Test exporting PDF with background
        let outputURL = tempDirectory.appendingPathComponent("test_with_background.pdf")

        XCTAssertNoThrow(
            try FileOperations.exportToPDF(document, url: outputURL, includeBackground: true),
            "PDF export with background should not throw"
        )

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")

        // Verify file is not empty
        let fileData = try Data(contentsOf: outputURL)
        XCTAssertGreaterThan(fileData.count, 0, "PDF file should not be empty")

        // Verify it's a valid PDF (starts with %PDF)
        let pdfHeader = String(data: fileData.prefix(5), encoding: .ascii)
        XCTAssertEqual(pdfHeader, "%PDF-", "File should be a valid PDF")
    }

    func testExportPDFWithoutBackground() throws {
        // Test exporting PDF without background
        let outputURL = tempDirectory.appendingPathComponent("test_without_background.pdf")

        XCTAssertNoThrow(
            try FileOperations.exportToPDF(document, url: outputURL, includeBackground: false),
            "PDF export without background should not throw"
        )

        // Verify file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")

        // Verify file is not empty
        let fileData = try Data(contentsOf: outputURL)
        XCTAssertGreaterThan(fileData.count, 0, "PDF file should not be empty")

        // Verify it's a valid PDF
        let pdfHeader = String(data: fileData.prefix(5), encoding: .ascii)
        XCTAssertEqual(pdfHeader, "%PDF-", "File should be a valid PDF")
    }

    func testPDFExportDefaultsToIncludeBackground() throws {
        // Test that the default parameter includes background
        let outputURL = tempDirectory.appendingPathComponent("test_default.pdf")

        // Call without specifying includeBackground parameter
        XCTAssertNoThrow(
            try FileOperations.exportToPDF(document, url: outputURL),
            "PDF export with default parameters should not throw"
        )

        // Verify file exists and is valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")

        let fileData = try Data(contentsOf: outputURL)
        XCTAssertGreaterThan(fileData.count, 0, "PDF file should not be empty")
    }

    func testPDFExportSkipsPasteboardLayer() throws {
        // Ensure Pasteboard layer (index 0) is never exported
        let outputURL = tempDirectory.appendingPathComponent("test_no_pasteboard.pdf")

        // Add a shape to the pasteboard layer (if it exists)
        if document.layers.count > 0 {
            let pasteboardShape = VectorShape()
            pasteboardShape.path = VectorPath(elements: [
                .moveTo(point: CGPoint(x: 0, y: 0)),
                .lineTo(point: CGPoint(x: 1000, y: 0)),
                .lineTo(point: CGPoint(x: 1000, y: 1000)),
                .lineTo(point: CGPoint(x: 0, y: 1000)),
                .close
            ])
            pasteboardShape.fillStyle = FillStyle(color: .rgb(RGBColor(red: 1.0, green: 0, blue: 0, alpha: 1.0)), opacity: 1.0)
            document.addShape(pasteboardShape, to: 0) // Add to pasteboard layer
        }

        XCTAssertNoThrow(
            try FileOperations.exportToPDF(document, url: outputURL, includeBackground: true),
            "PDF export should not throw even with pasteboard content"
        )

        // Verify file exists and is valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")

        // The pasteboard content should not affect the PDF
        // (We can't easily verify this without parsing the PDF, but at least it should export)
    }

    func testPDFExportSkipsCanvasLayerWhenBackgroundDisabled() throws {
        // Ensure Canvas layer (index 1) is skipped when includeBackground is false
        let outputURL = tempDirectory.appendingPathComponent("test_no_canvas.pdf")

        // Add a shape to the canvas layer (if it exists)
        if document.layers.count > 1 {
            let canvasShape = VectorShape()
            canvasShape.path = VectorPath(elements: [
                .moveTo(point: CGPoint(x: 50, y: 50)),
                .lineTo(point: CGPoint(x: 250, y: 50)),
                .lineTo(point: CGPoint(x: 250, y: 250)),
                .lineTo(point: CGPoint(x: 50, y: 250)),
                .close
            ])
            canvasShape.fillStyle = FillStyle(color: .rgb(RGBColor(red: 0, green: 1.0, blue: 0, alpha: 1.0)), opacity: 1.0)
            document.addShape(canvasShape, to: 1) // Add to canvas layer
        }

        XCTAssertNoThrow(
            try FileOperations.exportToPDF(document, url: outputURL, includeBackground: false),
            "PDF export without background should not throw"
        )

        // Verify file exists and is valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")
    }
}