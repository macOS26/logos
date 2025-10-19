import SwiftUI
import Combine

struct FontSizeControls: View {
    @ObservedObject var document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?

    // LOCAL @State variables for preview during editing
    @State private var isDraggingFontSize = false
    @State private var isDraggingLineSpacing = false
    @State private var isDraggingLineHeight = false
    @State private var previewFontSize: CGFloat? = nil
    @State private var previewLineSpacing: CGFloat? = nil
    @State private var previewLineHeight: CGFloat? = nil
    @State private var currentFontSizeState: CGFloat = 12.0
    @State private var currentLineSpacingState: CGFloat = 0.0
    @State private var currentLineHeightState: CGFloat = 12.0
    @State private var previewTypography: TypographyProperties? = nil
    @State private var editingTextID: UUID? = nil

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
                    Text(String(format: "%.1f pt", previewFontSize ?? currentFontSizeState))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { previewFontSize ?? currentFontSizeState },
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
                    let spacing = previewLineSpacing ?? currentLineSpacingState
                    Text(spacing == 0 ? "0 pt" : String(format: "%.1f pt", spacing))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { previewLineSpacing ?? currentLineSpacingState },
                    set: { newSpacing in
                        let rounded = (newSpacing * 10).rounded() / 10
                        previewLineSpacing = rounded
                        updateLineSpacing(rounded, isPreview: isDraggingLineSpacing)
                    }
                ), in: 0...(currentFontSizeState / 2), onEditingChanged: { editing in
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
                    Text(String(format: "%.1f pt", previewLineHeight ?? currentLineHeightState))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { previewLineHeight ?? currentLineHeightState },
                    set: { newHeight in
                        let rounded = (newHeight * 10).rounded() / 10
                        previewLineHeight = rounded
                        updateLineHeight(rounded, isPreview: isDraggingLineHeight)
                    }
                ), in: (currentFontSizeState / 2)...(currentFontSizeState * 2), onEditingChanged: { editing in
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
        .onAppear {
            syncFontStates()
        }
        .onChange(of: selectedText?.id) { _, _ in
            syncFontStates()
        }
        .onChange(of: editingText?.id) { oldID, newID in
            // When editing ends (editingText becomes nil), apply the preview typography to document
            if oldID != nil && newID == nil && previewTypography != nil, let textID = editingTextID {
                // Editing finished - save preview to document
                document.updateTextTypographyInUnified(id: textID, typography: previewTypography!)
                // Clear preview state
                previewTypography = nil
                editingTextID = nil
            }
            syncFontStates()
        }
    }

    private func syncFontStates() {
        currentFontSizeState = currentFontSize
        currentLineSpacingState = currentLineSpacing
        currentLineHeightState = currentLineHeight
    }

    private func updateFontSize(_ newSize: CGFloat, isPreview: Bool = false) {
        currentFontSizeState = newSize
        currentLineHeightState = newSize

        if let textID = document.selectedTextIDs.first {
            // Initialize previewTypography once if not already set
            if previewTypography == nil, let freshText = document.findText(by: textID) {
                previewTypography = freshText.typography
                editingTextID = textID
            }

            // Use cached previewTypography for updates
            if var updatedTypography = previewTypography {
                let oldFontSize = updatedTypography.fontSize

                if abs(oldFontSize - newSize) > 0.01 {
                    let lineHeightRatio = updatedTypography.lineHeight / oldFontSize
                    updatedTypography.fontSize = newSize
                    updatedTypography.lineHeight = newSize * lineHeightRatio

                    // Update cached preview
                    previewTypography = updatedTypography

                    // Always post notification for live preview
                    document.updateTextFontSizePreviewDirect(id: textID, typography: updatedTypography)

                    // Only update fontManager and document when dragging ends
                    if !isPreview {
                        document.fontManager.selectedFontSize = newSize
                        document.fontManager.selectedLineHeight = newSize
                        document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                        previewTypography = nil
                        editingTextID = nil
                    }
                }
            }
        }
    }

    private func updateLineSpacing(_ newSpacing: CGFloat, isPreview: Bool = false) {
        currentLineSpacingState = newSpacing

        if let textID = document.selectedTextIDs.first {
            // Initialize previewTypography once if not already set
            if previewTypography == nil, let freshText = document.findText(by: textID) {
                previewTypography = freshText.typography
                editingTextID = textID
            }

            // Use cached previewTypography for updates
            if var updatedTypography = previewTypography {
                if abs(updatedTypography.lineSpacing - Double(newSpacing)) > 0.01 {
                    updatedTypography.lineSpacing = Double(newSpacing)

                    // Update cached preview
                    previewTypography = updatedTypography

                    // Always post notification for live preview
                    document.updateTextLineSpacingPreviewDirect(id: textID, typography: updatedTypography)

                    // Only update fontManager and document when dragging ends
                    if !isPreview {
                        document.fontManager.selectedLineSpacing = Double(newSpacing)
                        document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                        previewTypography = nil
                        editingTextID = nil
                    }
                }
            }
        }
    }

    private func updateLineHeight(_ newHeight: CGFloat, isPreview: Bool = false) {
        currentLineHeightState = newHeight

        if let textID = document.selectedTextIDs.first {
            // Initialize previewTypography once if not already set
            if previewTypography == nil, let freshText = document.findText(by: textID) {
                previewTypography = freshText.typography
                editingTextID = textID
            }

            // Use cached previewTypography for updates
            if var updatedTypography = previewTypography {
                if abs(updatedTypography.lineHeight - Double(newHeight)) > 0.01 {
                    updatedTypography.lineHeight = Double(newHeight)

                    // Update cached preview
                    previewTypography = updatedTypography

                    // Always post notification for live preview
                    document.updateTextLineHeightPreviewDirect(id: textID, typography: updatedTypography)

                    // Only update fontManager and document when dragging ends
                    if !isPreview {
                        document.fontManager.selectedLineHeight = Double(newHeight)
                        document.updateTextTypographyInUnified(id: textID, typography: updatedTypography)
                        previewTypography = nil
                        editingTextID = nil
                    }
                }
            }
        }
    }
}
