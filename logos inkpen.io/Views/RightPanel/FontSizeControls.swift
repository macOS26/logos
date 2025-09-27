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
                    Text("\(Int(previewFontSize ?? currentFontSize)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { previewFontSize ?? currentFontSize },
                    set: { newSize in
                        let rounded = CGFloat(Int(newSize.rounded()))
                        if isDraggingFontSize {
                            // Just update preview during drag - no document update!
                            previewFontSize = rounded
                        } else {
                            // Not dragging - update document
                            updateFontSize(rounded)
                        }
                    }
                ), in: 1...288, onEditingChanged: { editing in
                    isDraggingFontSize = editing
                    if !editing {
                        // Drag ended - commit the preview value to document
                        if let preview = previewFontSize {
                            updateFontSize(preview)
                        }
                        previewFontSize = nil
                    } else {
                        // Drag started - initialize preview
                        previewFontSize = currentFontSize
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
                    Text(spacing == 0 ? "0 pt" : "\(Int(spacing)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { previewLineSpacing ?? currentLineSpacing },
                    set: { newSpacing in
                        let rounded = CGFloat(Int(newSpacing.rounded()))
                        if isDraggingLineSpacing {
                            // Just update preview during drag - no document update!
                            previewLineSpacing = rounded
                        } else {
                            // Not dragging - update document
                            updateLineSpacing(rounded)
                        }
                    }
                ), in: 0...(currentFontSize / 2), onEditingChanged: { editing in
                    isDraggingLineSpacing = editing
                    if !editing {
                        // Drag ended - commit the preview value to document
                        if let preview = previewLineSpacing {
                            updateLineSpacing(preview)
                        }
                        previewLineSpacing = nil
                    } else {
                        // Drag started - initialize preview
                        previewLineSpacing = currentLineSpacing
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
                    Text("\(Int(previewLineHeight ?? currentLineHeight)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { previewLineHeight ?? currentLineHeight },
                    set: { newHeight in
                        let rounded = CGFloat(Int(newHeight.rounded()))
                        if isDraggingLineHeight {
                            // Just update preview during drag - no document update!
                            previewLineHeight = rounded
                        } else {
                            // Not dragging - update document
                            updateLineHeight(rounded)
                        }
                    }
                ), in: (currentFontSize / 2)...(currentFontSize * 2), onEditingChanged: { editing in
                    isDraggingLineHeight = editing
                    if !editing {
                        // Drag ended - commit the preview value to document
                        if let preview = previewLineHeight {
                            updateLineHeight(preview)
                        }
                        previewLineHeight = nil
                    } else {
                        // Drag started - initialize preview
                        previewLineHeight = currentLineHeight
                    }
                })
                .controlSize(.regular)
            }
        }
    }
    
    private func updateFontSize(_ newSize: CGFloat) {
        // ALWAYS update defaults first - NO RESTRICTIONS
        document.fontManager.selectedFontSize = newSize
        document.fontManager.selectedLineHeight = newSize
        document.objectWillChange.send() // Force UI update

        // Then update selected text if any
        if let textID = document.selectedTextIDs.first,
           let freshText = document.allTextObjects.first(where: { $0.id == textID }) {
            var updatedTypography = freshText.typography
            let oldFontSize = updatedTypography.fontSize
            let lineHeightRatio = updatedTypography.lineHeight / oldFontSize

            updatedTypography.fontSize = newSize
            updatedTypography.lineHeight = newSize * lineHeightRatio
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        }
    }
    
    private func updateLineSpacing(_ newSpacing: CGFloat) {
        // ALWAYS update defaults first - NO RESTRICTIONS
        document.fontManager.selectedLineSpacing = Double(newSpacing)
        document.objectWillChange.send() // Force UI update

        // Then update selected text if any
        if let textID = document.selectedTextIDs.first,
           let freshText = document.allTextObjects.first(where: { $0.id == textID }) {
            var updatedTypography = freshText.typography
            updatedTypography.lineSpacing = Double(newSpacing)
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        }
    }
    
    private func updateLineHeight(_ newHeight: CGFloat) {
        // ALWAYS update defaults first - NO RESTRICTIONS
        document.fontManager.selectedLineHeight = Double(newHeight)
        document.objectWillChange.send() // Force UI update

        // Then update selected text if any
        if let textID = document.selectedTextIDs.first,
           let freshText = document.allTextObjects.first(where: { $0.id == textID }) {
            var updatedTypography = freshText.typography
            updatedTypography.lineHeight = Double(newHeight)
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        }
    }
}