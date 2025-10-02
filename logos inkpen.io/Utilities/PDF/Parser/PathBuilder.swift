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

    // Extract inkpen metadata from PDF XMP metadata stream
    var inkpenMetadata: String? = nil

    if let pdfDoc = page.document {
        // Try to get XMP metadata from the catalog
        if let catalog = pdfDoc.catalog {
            var metadataRef: CGPDFStreamRef?

            // Try to get the Metadata stream from the catalog
            if CGPDFDictionaryGetStream(catalog, "Metadata", &metadataRef),
               let metadataStream = metadataRef {

                var format: CGPDFDataFormat = .raw
                if let data = CGPDFStreamCopyData(metadataStream, &format) {
                    if let xmpString = String(data: data as Data, encoding: .utf8) {
                        Log.info("📦 Found XMP metadata in PDF (\(xmpString.count) chars)", category: .fileOperations)

                        // Parse XMP to extract inkpen:document element
                        if let range = xmpString.range(of: "<inkpen:document>"),
                           let endRange = xmpString.range(of: "</inkpen:document>") {
                            let start = xmpString.index(after: range.upperBound)
                            let end = endRange.lowerBound
                            let base64Data = String(xmpString[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                            inkpenMetadata = base64Data
                            Log.info("✅ Extracted inkpen document from XMP metadata (\(base64Data.count) base64 chars)", category: .fileOperations)
                        }
                    }
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


