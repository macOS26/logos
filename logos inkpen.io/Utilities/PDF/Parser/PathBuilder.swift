//
//  PDFContent+PathBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

// MARK: - PDF Vector Extraction using Working Parser
func extractPDFVectorContent(_ page: CGPDFPage) throws -> PDFContent {
    Log.fileOperation("🔧 Extracting PDF vector content using working parser...", level: .info)

    // Extract inkpen metadata from PDF info dictionary
    var inkpenMetadata: String? = nil

    if let pdfDoc = page.document,
       let info = pdfDoc.info {
        // Try to get XInfo field which contains our inkpen data
        var pdfString: CGPDFStringRef?
        if CGPDFDictionaryGetString(info, "XInfo", &pdfString),
           let xInfoString = CGPDFStringCopyTextString(pdfString!) as String? {
            inkpenMetadata = xInfoString
            Log.info("📦 Found inkpen metadata in PDF XInfo field (\(xInfoString.count) chars)", category: .fileOperations)
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


