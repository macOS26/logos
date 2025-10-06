//
//  FileOperations+SVG.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

extension FileOperations {
    /// Export VectorDocument to SVG format
    static func exportToSVG(_ document: VectorDocument, url: URL, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs) throws {

        do {
            // Use the proper SVG exporter with text rendering mode
            let svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: includeBackground, textRenderingMode: textRenderingMode)
            try svgContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            Log.error("❌ SVG export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export SVG: \(error.localizedDescription)", line: nil)
        }
    }
}