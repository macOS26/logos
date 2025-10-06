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
            Log.fileOperation("🔧 Implementing professional SVG parser...", level: .info)

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

    // CRITICAL: Apply uniform width to all text objects (widest + 2 chars)
    let maxWidth = parser.maxTextWidth

    // Reverse text objects to fix stacking order (last letter should be last, not first)
    for var textObject in result.textObjects.reversed() {
        // Update text object to use maximum width for consistency
        if maxWidth > 0 {
            let height = textObject.areaSize?.height ?? CGFloat(textObject.typography.lineHeight)
            textObject.areaSize = CGSize(width: maxWidth, height: height)
            textObject.bounds = CGRect(
                x: textObject.bounds.origin.x,
                y: textObject.bounds.origin.y,
                width: maxWidth,
                height: textObject.bounds.height
            )
        }
        let textShape = textObject.toVectorShape()
        allShapes.append(textShape)
        Log.fileOperation("📝 Converted SVG text to shape: '\(textObject.content.prefix(30))...' (id: \(textShape.id)), width: \(maxWidth)", level: .debug)
    }

    Log.fileOperation("✅ SVG parsing complete: \(result.shapes.count) shapes + \(result.textObjects.count) text objects = \(allShapes.count) total, max text width: \(maxWidth)", level: .info)

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
