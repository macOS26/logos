//
//  FontSizeControls.swift
//  logos inkpen.io
//
//  Created by Claude on 2025/01/15.
//

import SwiftUI

struct FontSizeControls: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?
    
    @State private var isDraggingFontSize = false
    @State private var isDraggingLineSpacing = false
    @State private var isDraggingLineHeight = false
    
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
                    Text("\(String(format: "%.1f", currentFontSize)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { currentFontSize },
                    set: { newSize in
                        // Update dynamically while dragging for real-time feedback
                        updateFontSize(newSize)
                    }
                ), in: 1...288, onEditingChanged: { editing in
                    isDraggingFontSize = editing
                })
                .controlSize(.small)
            }
            
            // Line Spacing Control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Line Spacing")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(currentLineSpacing == 0 ? "0 pt" : "\(String(format: "%.0f", currentLineSpacing)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { currentLineSpacing },
                    set: { newSpacing in
                        // Update dynamically while dragging
                        updateLineSpacing(newSpacing)
                    }
                ), in: 0...(currentFontSize / 2), onEditingChanged: { editing in
                    isDraggingLineSpacing = editing
                })
                .controlSize(.small)
            }
            
            // Line Height Control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Line Height")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(String(format: "%.0f", currentLineHeight)) pt")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: Binding(
                    get: { currentLineHeight },
                    set: { newHeight in
                        // Update dynamically while dragging
                        updateLineHeight(newHeight)
                    }
                ), in: (currentFontSize / 2)...(currentFontSize * 2), onEditingChanged: { editing in
                    isDraggingLineHeight = editing
                })
                .controlSize(.small)
            }
        }
    }
    
    private func updateFontSize(_ newSize: CGFloat) {
        if let textID = document.selectedTextIDs.first,
           let freshText = document.allTextObjects.first(where: { $0.id == textID }) {
            var updatedTypography = freshText.typography
            let oldFontSize = updatedTypography.fontSize
            let lineHeightRatio = updatedTypography.lineHeight / oldFontSize
            
            updatedTypography.fontSize = newSize
            updatedTypography.lineHeight = newSize * lineHeightRatio
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        } else {
            document.fontManager.selectedFontSize = newSize
            document.fontManager.selectedLineHeight = newSize
        }
    }
    
    private func updateLineSpacing(_ newSpacing: CGFloat) {
        if let textID = document.selectedTextIDs.first,
           let freshText = document.allTextObjects.first(where: { $0.id == textID }) {
            var updatedTypography = freshText.typography
            updatedTypography.lineSpacing = Double(newSpacing)
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        } else {
            document.fontManager.selectedLineSpacing = Double(newSpacing)
        }
    }
    
    private func updateLineHeight(_ newHeight: CGFloat) {
        if let textID = document.selectedTextIDs.first,
           let freshText = document.allTextObjects.first(where: { $0.id == textID }) {
            var updatedTypography = freshText.typography
            updatedTypography.lineHeight = Double(newHeight)
            document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
        } else {
            document.fontManager.selectedLineHeight = Double(newHeight)
        }
    }
}