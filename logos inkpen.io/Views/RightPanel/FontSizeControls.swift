
import SwiftUI
import Combine

struct FontSizeControls: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?

    @State private var isDraggingFontSize = false
    @State private var isDraggingLineSpacing = false
    @State private var isDraggingLineHeight = false

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
                        let rounded = (newSize * 10).rounded() / 10
                        previewFontSize = rounded
                        updateFontSize(rounded, isPreview: isDraggingFontSize)
                    }
                ), in: 1...288, onEditingChanged: { editing in
                    isDraggingFontSize = editing
                    if !editing {
                        if let preview = previewFontSize {
                            updateFontSize(preview, isPreview: false)
                        }
                        previewFontSize = nil
                        if let textID = document.selectedTextIDs.first {
                            document.clearTextPreviewTypography(id: textID)
                        }
                    }
                })
                .controlSize(.regular)
            }

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
                        let rounded = (newSpacing * 10).rounded() / 10
                        previewLineSpacing = rounded
                        updateLineSpacing(rounded, isPreview: isDraggingLineSpacing)
                    }
                ), in: 0...(currentFontSize / 2), onEditingChanged: { editing in
                    isDraggingLineSpacing = editing
                    if !editing {
                        if let preview = previewLineSpacing {
                            updateLineSpacing(preview, isPreview: false)
                        }
                        previewLineSpacing = nil
                        if let textID = document.selectedTextIDs.first {
                            document.clearTextPreviewTypography(id: textID)
                        }
                    }
                })
                .controlSize(.regular)
            }

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
                        let rounded = (newHeight * 10).rounded() / 10
                        previewLineHeight = rounded
                        updateLineHeight(rounded, isPreview: isDraggingLineHeight)
                    }
                ), in: (currentFontSize / 2)...(currentFontSize * 2), onEditingChanged: { editing in
                    isDraggingLineHeight = editing
                    if !editing {
                        if let preview = previewLineHeight {
                            updateLineHeight(preview, isPreview: false)
                        }
                        previewLineHeight = nil
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
        document.fontManager.selectedFontSize = newSize
        document.fontManager.selectedLineHeight = newSize

        if isPreview {
            if let textID = document.selectedTextIDs.first {
                document.updateTextFontSizePreview(id: textID, fontSize: newSize)
            }
        } else {
            document.objectWillChange.send()

            if let textID = document.selectedTextIDs.first,
               let freshText = document.findText(by: textID) {
                var updatedTypography = freshText.typography
                let oldFontSize = updatedTypography.fontSize

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
        document.fontManager.selectedLineSpacing = Double(newSpacing)

        if isPreview {
            if let textID = document.selectedTextIDs.first {
                document.updateTextLineSpacingPreview(id: textID, lineSpacing: Double(newSpacing))
            }
        } else {
            document.objectWillChange.send()

            if let textID = document.selectedTextIDs.first,
               let freshText = document.findText(by: textID) {
                var updatedTypography = freshText.typography

                if abs(updatedTypography.lineSpacing - Double(newSpacing)) > 0.01 {
                    updatedTypography.lineSpacing = Double(newSpacing)
                    document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                }
            }
        }
    }

    private func updateLineHeight(_ newHeight: CGFloat, isPreview: Bool = false) {
        document.fontManager.selectedLineHeight = Double(newHeight)

        if isPreview {
            if let textID = document.selectedTextIDs.first {
                document.updateTextLineHeightPreview(id: textID, lineHeight: Double(newHeight))
            }
        } else {
            document.objectWillChange.send()

            if let textID = document.selectedTextIDs.first,
               let freshText = document.findText(by: textID) {
                var updatedTypography = freshText.typography

                if abs(updatedTypography.lineHeight - Double(newHeight)) > 0.01 {
                    updatedTypography.lineHeight = Double(newHeight)
                    document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                }
            }
        }
    }
}