//
//  ExportTextOptionsHandler.swift
//  logos inkpen.io
//
//  Created to consolidate duplicated text options handling code
//

import AppKit
import Combine

/// Shared handler for text rendering options in export dialogs
/// Eliminates duplication between SVG, PDF, and AutoDesk export dialogs
class ExportTextOptionsHandler: NSObject {
    let textToOutlinesCheckbox: NSButton
    let textModeLabel: NSTextField
    let glyphsRadio: NSButton
    let linesRadio: NSButton

    init(textToOutlinesCheckbox: NSButton,
         textModeLabel: NSTextField,
         glyphsRadio: NSButton,
         linesRadio: NSButton) {
        self.textToOutlinesCheckbox = textToOutlinesCheckbox
        self.textModeLabel = textModeLabel
        self.glyphsRadio = glyphsRadio
        self.linesRadio = linesRadio
    }

    @objc func toggleTextOptions(_ sender: NSButton) {
        let shouldHide = sender.state == .on
        textModeLabel.isHidden = shouldHide
        glyphsRadio.isHidden = shouldHide
        linesRadio.isHidden = shouldHide
    }

    @objc func selectGlyphs(_ sender: NSButton) {
        glyphsRadio.state = .on
        linesRadio.state = .off
    }

    @objc func selectLines(_ sender: NSButton) {
        glyphsRadio.state = .off
        linesRadio.state = .on
    }
}

/// Helper to export with text converted to outlines
/// Eliminates duplication of save/convert/restore pattern
extension DocumentState {
    @discardableResult
    static func exportWithTextToOutlines(
        _ document: VectorDocument,
        exportHandler: () throws -> Data
    ) async throws -> Data {
        // Save current document state
        let savedData = try JSONEncoder().encode(document)
        let savedState = try JSONDecoder().decode(VectorDocument.self, from: savedData)

        // Convert all text to outlines
        await MainActor.run {
            DocumentState.convertAllTextToOutlinesForExport(document)
        }

        // Export with converted text
        let exportData = try exportHandler()

        // Restore original document state
        await MainActor.run {
            document.unifiedObjects = savedState.unifiedObjects
            document.layers = savedState.layers
            document.selectedObjectIDs = savedState.selectedObjectIDs
            document.selectedTextIDs = savedState.selectedTextIDs
            document.selectedShapeIDs = savedState.selectedShapeIDs
            document.objectWillChange.send()
        }

        return exportData
    }

    /// Helper to export SVG with text converted to outlines
    static func exportSVGWithTextToOutlines(
        _ document: VectorDocument,
        includeBackground: Bool,
        textRenderingMode: AppState.SVGTextRenderingMode,
        includeInkpenData: Bool,
        isAutoDesk: Bool = false
    ) async throws -> String {
        // Save current document state
        let savedData = try JSONEncoder().encode(document)
        let savedState = try JSONDecoder().decode(VectorDocument.self, from: savedData)

        // Convert all text to outlines
        await MainActor.run {
            DocumentState.convertAllTextToOutlinesForExport(document)
        }

        // Generate SVG with outlined text
        let svgContent: String
        if isAutoDesk {
            svgContent = try SVGExporter.shared.exportToAutoDeskSVG(
                document,
                includeBackground: includeBackground,
                textRenderingMode: textRenderingMode
            )
        } else {
            svgContent = try SVGExporter.shared.exportToSVG(
                document,
                includeBackground: includeBackground,
                textRenderingMode: textRenderingMode,
                includeInkpenData: includeInkpenData
            )
        }

        // Restore original document state
        await MainActor.run {
            document.unifiedObjects = savedState.unifiedObjects
            document.layers = savedState.layers
            document.selectedObjectIDs = savedState.selectedObjectIDs
            document.selectedTextIDs = savedState.selectedTextIDs
            document.selectedShapeIDs = savedState.selectedShapeIDs
            document.objectWillChange.send()
        }

        return svgContent
    }
}
