//
//  FontSizeControls.swift
//  logos inkpen.io
//
//  Created by Claude on 2025/01/15.
//

import SwiftUI
import Combine

struct FontSizeControls: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?
    
    @State private var isDraggingFontSize = false
    @State private var isDraggingLineSpacing = false
    @State private var isDraggingLineHeight = false

    // Preview values for immediate UI feedback without document updates
    @State private var previewFontSize: CGFloat? = nil
    @State private var previewLineSpacing: CGFloat? = nil
    @State private var previewLineHeight: CGFloat? = nil

    private var currentFontSize: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.fontSize
        } else if let editingText = editingText {
            return editingText.typography.fontSize
        } else {
            return document.fontManager.selectedFontSize
        }
    }
    
    private var currentLineSpacing: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.lineSpacing
        } else if let editingText = editingText {
            return editingText.typography.lineSpacing
        } else {
            return document.fontManager.selectedLineSpacing
        }
    }
    
    private var currentLineHeight: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.lineHeight
        } else if let editingText = editingText {
            return editingText.typography.lineHeight
        } else {
            return document.fontManager.selectedLineHeight
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Font Size Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Font Size")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f pt", previewFontSize ?? currentFontSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { previewFontSize ?? currentFontSize },
                    set: { newSize in
                        let rounded = (newSize * 10).rounded() / 10 // Round to 0.1 precision
                        previewFontSize = rounded
                        // Live update during drag AND on direct value changes
                        updateFontSize(rounded, isPreview: isDraggingFontSize)
                    }
                ), in: 1...288, onEditingChanged: { editing in
                    isDraggingFontSize = editing
                    if !editing {
                        // Drag ended - ensure final value is committed
                        if let preview = previewFontSize {
                            updateFontSize(preview, isPreview: false)
                        }
                        previewFontSize = nil
                        // Clear preview typography
                        if let textID = document.selectedTextIDs.first {
                            document.clearTextPreviewTypography(id: textID)
                        }
                    }
                })
                .controlSize(.regular)
            }
            
            // Line Spacing Control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Line Spacing")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    let spacing = previewLineSpacing ?? currentLineSpacing
                    Text(spacing == 0 ? "0 pt" : String(format: "%.1f pt", spacing))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { previewLineSpacing ?? currentLineSpacing },
                    set: { newSpacing in
                        let rounded = (newSpacing * 10).rounded() / 10 // Round to 0.1 precision
                        previewLineSpacing = rounded
                        // Live update during drag AND on direct value changes
                        updateLineSpacing(rounded, isPreview: isDraggingLineSpacing)
                    }
                ), in: 0...(currentFontSize / 2), onEditingChanged: { editing in
                    isDraggingLineSpacing = editing
                    if !editing {
                        // Drag ended - ensure final value is committed
                        if let preview = previewLineSpacing {
                            updateLineSpacing(preview, isPreview: false)
                        }
                        previewLineSpacing = nil
                        // Clear preview typography
                        if let textID = document.selectedTextIDs.first {
                            document.clearTextPreviewTypography(id: textID)
                        }
                    }
                })
                .controlSize(.regular)
            }
            
            // Line Height Control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Line Height")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.1f pt", previewLineHeight ?? currentLineHeight))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { previewLineHeight ?? currentLineHeight },
                    set: { newHeight in
                        let rounded = (newHeight * 10).rounded() / 10 // Round to 0.1 precision
                        previewLineHeight = rounded
                        // Live update during drag AND on direct value changes
                        updateLineHeight(rounded, isPreview: isDraggingLineHeight)
                    }
                ), in: (currentFontSize / 2)...(currentFontSize * 2), onEditingChanged: { editing in
                    isDraggingLineHeight = editing
                    if !editing {
                        // Drag ended - ensure final value is committed
                        if let preview = previewLineHeight {
                            updateLineHeight(preview, isPreview: false)
                        }
                        previewLineHeight = nil
                        // Clear preview typography
                        if let textID = document.selectedTextIDs.first {
                            document.clearTextPreviewTypography(id: textID)
                        }
                    }
                })
                .controlSize(.regular)
            }
        }
    }
    
    private func updateFontSize(_ newSize: CGFloat, isPreview: Bool = false) {
        // ALWAYS update defaults first - NO RESTRICTIONS
        document.fontManager.selectedFontSize = newSize
        document.fontManager.selectedLineHeight = newSize

        if isPreview {
            // For preview, use the lightweight preview update
            if let textID = document.selectedTextIDs.first {
                document.updateTextFontSizePreview(id: textID, fontSize: newSize)
            }
        } else {
            // Full update when not previewing - commit to unified objects
            document.objectWillChange.send() // Force UI update

            // Then update selected text if any
            if let textID = document.selectedTextIDs.first,
               let unifiedObj = document.unifiedObjects.first(where: { $0.id == textID }),
               case .shape(let shape) = unifiedObj.objectType,
               shape.isTextObject,
               var freshText = VectorText.from(shape) {
                freshText.layerIndex = unifiedObj.layerIndex
                var updatedTypography = freshText.typography
                let oldFontSize = updatedTypography.fontSize

                // Check if font size actually changed
                if abs(oldFontSize - newSize) > 0.01 {
                    let lineHeightRatio = updatedTypography.lineHeight / oldFontSize
                    updatedTypography.fontSize = newSize
                    updatedTypography.lineHeight = newSize * lineHeightRatio
                    document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                }
            }
        }
    }
    
    private func updateLineSpacing(_ newSpacing: CGFloat, isPreview: Bool = false) {
        // ALWAYS update defaults first - NO RESTRICTIONS
        document.fontManager.selectedLineSpacing = Double(newSpacing)

        if isPreview {
            // For preview, use the lightweight preview update
            if let textID = document.selectedTextIDs.first {
                document.updateTextLineSpacingPreview(id: textID, lineSpacing: Double(newSpacing))
            }
        } else {
            // Full update when not previewing - commit to unified objects
            document.objectWillChange.send() // Force UI update

            // Then update selected text if any
            if let textID = document.selectedTextIDs.first,
               let unifiedObj = document.unifiedObjects.first(where: { $0.id == textID }),
               case .shape(let shape) = unifiedObj.objectType,
               shape.isTextObject,
               var freshText = VectorText.from(shape) {
                freshText.layerIndex = unifiedObj.layerIndex
                var updatedTypography = freshText.typography

                // Check if line spacing actually changed
                if abs(updatedTypography.lineSpacing - Double(newSpacing)) > 0.01 {
                    updatedTypography.lineSpacing = Double(newSpacing)
                    document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                }
            }
        }
    }
    
    private func updateLineHeight(_ newHeight: CGFloat, isPreview: Bool = false) {
        // ALWAYS update defaults first - NO RESTRICTIONS
        document.fontManager.selectedLineHeight = Double(newHeight)

        if isPreview {
            // For preview, use the lightweight preview update
            if let textID = document.selectedTextIDs.first {
                document.updateTextLineHeightPreview(id: textID, lineHeight: Double(newHeight))
            }
        } else {
            // Full update when not previewing - commit to unified objects
            document.objectWillChange.send() // Force UI update

            // Then update selected text if any
            if let textID = document.selectedTextIDs.first,
               let unifiedObj = document.unifiedObjects.first(where: { $0.id == textID }),
               case .shape(let shape) = unifiedObj.objectType,
               shape.isTextObject,
               var freshText = VectorText.from(shape) {
                freshText.layerIndex = unifiedObj.layerIndex
                var updatedTypography = freshText.typography

                // Check if line height actually changed
                if abs(updatedTypography.lineHeight - Double(newHeight)) > 0.01 {
                    updatedTypography.lineHeight = Double(newHeight)
                    document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                }
            }
        }
    }
}