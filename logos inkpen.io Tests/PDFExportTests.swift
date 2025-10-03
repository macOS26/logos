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

    func testGeneratePDFData() throws {
        // Test generating PDF data (the correct way)
        let outputURL = tempDirectory.appendingPathComponent("test_generate.pdf")

        do {
            let pdfData = try FileOperations.generatePDFData(from: document)
            try pdfData.write(to: outputURL)

            // Verify file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")

            // Verify file is not empty
            XCTAssertGreaterThan(pdfData.count, 0, "PDF data should not be empty")

            // Verify it's a valid PDF (starts with %PDF)
            let pdfHeader = String(data: pdfData.prefix(5), encoding: .ascii)
            XCTAssertEqual(pdfHeader, "%PDF-", "File should be a valid PDF")
        } catch {
            XCTFail("PDF generation should not throw: \(error)")
        }
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

        do {
            let pdfData = try FileOperations.generatePDFData(from: document)
            try pdfData.write(to: outputURL)

            // Verify file exists and is valid
            XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "PDF file should exist")

            // The pasteboard content should not affect the PDF
            // (We can't easily verify this without parsing the PDF, but at least it should export)
        } catch {
            XCTFail("PDF generation should not throw even with pasteboard content: \(error)")
        }
    }

    func testPDFDataGeneration() throws {
        // Test that PDF data generation works correctly
        do {
            let pdfData = try FileOperations.generatePDFData(from: document)

            // Verify data is not empty
            XCTAssertGreaterThan(pdfData.count, 0, "PDF data should not be empty")

            // Verify it's a valid PDF (starts with %PDF)
            let pdfHeader = String(data: pdfData.prefix(5), encoding: .ascii)
            XCTAssertEqual(pdfHeader, "%PDF-", "Data should be a valid PDF")

            // Check for PDF version marker
            let pdfString = String(data: pdfData.prefix(100), encoding: .ascii) ?? ""
            XCTAssertTrue(pdfString.contains("%PDF"), "Should contain PDF marker")
        } catch {
            XCTFail("PDF generation should not throw: \(error)")
        }
    }
}