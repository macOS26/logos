//
//  FileOperations+SVG.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

extension FileOperations {
    /// Export VectorDocument to SVG format
    static func exportToSVG(_ document: VectorDocument, url: URL, includeBackground: Bool = true, convertTextToOutlines: Bool = false) throws {
        Log.fileOperation("🎨 Exporting document to SVG: \(url.path)", level: .info)

        // If converting text to outlines, save state, convert, then restore after export
        if convertTextToOutlines && !document.allTextObjects.isEmpty {
            Log.info("📝 Converting text to outlines for SVG export", category: .general)

            // Save current state
            document.saveToUndoStack()

            // Select all text objects
            document.selectedTextIDs = Set(document.allTextObjects.map { $0.id })
            document.selectedObjectIDs = Set(document.allTextObjects.map { $0.id })

            // Convert text to outlines
            document.convertSelectedTextToOutlines()
        }

        do {
            // Use the proper SVG exporter (pass flag to skip text objects since they're now shapes)
            let svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: includeBackground, textConverted: convertTextToOutlines)
            try svgContent.write(to: url, atomically: true, encoding: .utf8)

            // If we converted text to outlines, undo to restore original text
            if convertTextToOutlines && !document.undoStack.isEmpty {
                document.undo()
                Log.info("📝 Restored original text after SVG export", category: .general)
            }

            Log.info("✅ Successfully exported SVG document", category: .fileOperations)
        } catch {
            // Make sure to restore if there was an error
            if convertTextToOutlines && !document.undoStack.isEmpty {
                document.undo()
            }

            Log.error("❌ SVG export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export SVG: \(error.localizedDescription)", line: nil)
        }
    }
}