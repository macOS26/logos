//
//  PDFContent+PathBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI
import PDFKit

// MARK: - PDF Vector Extraction using Working Parser
func extractPDFVectorContent(_ page: CGPDFPage) throws -> PDFContent {
    Log.fileOperation("🔧 Extracting PDF vector content using working parser...", level: .info)

    // Extract inkpen metadata from PDF content
    var inkpenMetadata: String? = nil

    // Extract text content from the PDF page to look for embedded inkpen data
    if let pageContent = extractTextFromPDFPage(page) {
        // Look for our markers in the text
        if let startRange = pageContent.range(of: "INKPEN_METADATA_START"),
           let endRange = pageContent.range(of: "INKPEN_METADATA_END") {
            // Extract the base64 data between the markers
            let startIndex = pageContent.index(after: startRange.upperBound)
            let endIndex = endRange.lowerBound
            if startIndex < endIndex {
                let base64Data = String(pageContent[startIndex..<endIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !base64Data.isEmpty {
                    inkpenMetadata = base64Data
                    Log.info("📦 Found inkpen metadata embedded in PDF content (\(base64Data.count) chars)", category: .fileOperations)
                }
            }
        }
    }

    // Create a temporary file URL from the page
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_pdf_page.pdf")

    // Create a PDF context to write the single page
    var mediaBox = page.getBoxRect(.mediaBox)
    guard let context = CGContext(tempURL as CFURL, mediaBox: &mediaBox, nil) else {
        throw VectorImportError.parsingError("Cannot create PDF context", line: nil)
    }

    context.beginPDFPage(nil)
    context.drawPDFPage(page)
    context.endPDFPage()
    context.closePDF()

    // Now parse with the working parser
    let parser = PDFCommandParser()
    let shapes = parser.parseDocument(at: tempURL)

    Log.info("✅ Extracted \(shapes.count) vector shapes with individual colors", category: .fileOperations)

    // Clean up temp file
    try? FileManager.default.removeItem(at: tempURL)

    return PDFContent(
        shapes: shapes,
        textCount: 0,
        creator: "PDF Vector Parser",
        version: "Individual Shapes",
        producer: inkpenMetadata != nil ? "INKPEN_DATA:" + inkpenMetadata! : nil
    )
}

// Helper function to extract text from PDF page
func extractTextFromPDFPage(_ page: CGPDFPage) -> String? {
    // Create a temporary PDF file with just this page to extract text
    let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_text_extract.pdf")

    // Create a PDF context to write the single page
    var mediaBox = page.getBoxRect(.mediaBox)
    guard let context = CGContext(tempURL as CFURL, mediaBox: &mediaBox, nil) else {
        return nil
    }

    context.beginPDFPage(nil)
    context.drawPDFPage(page)
    context.endPDFPage()
    context.closePDF()

    // Now use PDFKit to extract text
    defer { try? FileManager.default.removeItem(at: tempURL) }

    if let pdfDocument = PDFDocument(url: tempURL),
       let pdfPage = pdfDocument.page(at: 0) {
        return pdfPage.string
    }

    return nil
}


