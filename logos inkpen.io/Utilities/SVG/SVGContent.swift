//
//  SVGContent.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Parser Implementation Stubs
// These would be implemented with proper parsing libraries
struct SVGContent {
    let shapes: [VectorShape]
    let documentSize: CGSize
    let viewBoxSize: CGSize?  // Added to detect 96 DPI SVGs
    let colorSpace: String
    let units: VectorUnit
    let dpi: Double
    let missingFonts: [String]
    let creator: String?
    let version: String?
    let inkpenMetadata: String?  // Base64 encoded inkpen document
}

func parseSVGContent(_ data: Data, useExtremeValueHandling: Bool = false) throws -> SVGContent {
    // PROFESSIONAL SVG PARSER IMPLEMENTATION

    guard let xmlString = String(data: data, encoding: .utf8) else {
        throw VectorImportError.parsingError("Could not decode SVG as UTF-8", line: nil)
    }

    let parser = SVGParser()

    // Enable extreme value handling if requested
    if useExtremeValueHandling {
        parser.enableExtremeValueHandling()
    }

    let result = try parser.parse(xmlString)

    // CRITICAL FIX: Convert textObjects to VectorShapes (same as PDF import)
    var allShapes = result.shapes

    for textObject in result.textObjects {
        let textShape = textObject.toVectorShape()
        allShapes.append(textShape)
    }


    return SVGContent(
        shapes: allShapes,
        documentSize: result.documentSize,
        viewBoxSize: result.viewBoxSize,
        colorSpace: "RGB",
        units: .points,
        dpi: 72.0,
        missingFonts: [],
        creator: result.creator,
        version: result.version,
        inkpenMetadata: parser.inkpenMetadata
    )
}
