//
//  PDFContent+PathBuilder.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

// MARK: - Helper Functions

/// Offset all points in a path by a given amount
private func offsetPath(_ path: VectorPath, by offset: CGPoint) -> VectorPath {
    let offsetElements = path.elements.map { element -> PathElement in
        switch element {
        case .move(let to):
            return .move(to: VectorPoint(to.x + offset.x, to.y + offset.y))
        case .line(let to):
            return .line(to: VectorPoint(to.x + offset.x, to.y + offset.y))
        case .quadCurve(let to, let control):
            return .quadCurve(
                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                control: VectorPoint(control.x + offset.x, control.y + offset.y)
            )
        case .cubicCurve(let to, let control1, let control2):
            return .cubicCurve(
                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                control1: VectorPoint(control1.x + offset.x, control1.y + offset.y),
                control2: VectorPoint(control2.x + offset.x, control2.y + offset.y)
            )
        case .close:
            return .close
        }
    }

    return VectorPath(elements: offsetElements, isClosed: path.isClosed)
}

// MARK: - PDF Vector Extraction using Working Parser
func extractPDFVectorContent(_ page: CGPDFPage) throws -> PDFContent {
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

                        // Parse XMP to extract inkpen:document element
                        if let range = xmpString.range(of: "<inkpen:document>"),
                           let endRange = xmpString.range(of: "</inkpen:document>") {
                            let startIndex = range.upperBound
                            let endIndex = endRange.lowerBound
                            // Don't trim - preserve exact base64 content
                            let base64Data = String(xmpString[startIndex..<endIndex])
                            inkpenMetadata = base64Data
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
    var shapes = parser.parseDocument(at: tempURL)

    // Apply mediaBox origin offset if needed
    // PDFs can have mediaBox with non-zero origin - we need to shift all shapes
    if mediaBox.origin != .zero {
        let offset = CGPoint(x: -mediaBox.origin.x, y: -mediaBox.origin.y)
        shapes = shapes.map { shape in
            var offsetShape = shape
            offsetShape.path = offsetPath(shape.path, by: offset)
            return offsetShape
        }
    }

    // Clean up temp file
    try? FileManager.default.removeItem(at: tempURL)

    return PDFContent(
        shapes: shapes,
        textCount: 0,
        creator: "PDF Vector Parser",
        version: "Individual Shapes",
        producer: inkpenMetadata  // Pass the XMP metadata directly without prefix
    )
}


