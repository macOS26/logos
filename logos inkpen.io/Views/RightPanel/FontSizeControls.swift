import SwiftUI

struct FontSizeControls: View {
    let selectedObjectIDs: Set<UUID>
    let selectedFontSize: CGFloat
    let selectedLineSpacing: CGFloat
    let selectedLineHeight: CGFloat
    let document: VectorDocument
    let selectedText: VectorText?
    let editingText: VectorText?
    @Binding var fontSizeDelta: Double?

    @State private var isDraggingFontSize = false
    @State private var isDraggingLineSpacing = false
    @State private var isDraggingLineHeight = false
    @State private var previewFontSize: CGFloat? = nil
    @State private var previewLineSpacing: CGFloat? = nil
    @State private var previewLineHeight: CGFloat? = nil
    @State private var currentFontSizeState: CGFloat = 12.0
    @State private var currentLineSpacingState: CGFloat = 0.0
    @State private var currentLineHeightState: CGFloat = 12.0

    private var currentFontSize: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.fontSize
        } else if let editingText = editingText {
            return editingText.typography.fontSize
        } else {
            return selectedFontSize
        }
    }

    private var currentLineSpacing: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.lineSpacing
        } else if let editingText = editingText {
            return editingText.typography.lineSpacing
        } else {
            return selectedLineSpacing
        }
    }

    private var currentLineHeight: CGFloat {
        if let selectedText = selectedText {
            return selectedText.typography.lineHeight
        } else if let editingText = editingText {
            return editingText.typography.lineHeight
        } else {
            return selectedLineHeight
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
                        // During drag: ONLY update fontSizeDelta for live preview
                        fontSizeDelta = Double(rounded)
                    }
                ), in: 1...288, onEditingChanged: { editing in
                    isDraggingFontSize = editing
                    if !editing {
                        // Drag ended: clear delta and commit actual change
                        fontSizeDelta = nil
                        if let preview = previewFontSize {
                            updateFontSize(preview, isPreview: false)
                        }
                        previewFontSize = nil
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
                        if let textID = selectedObjectIDs.first {
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
                        if let textID = selectedObjectIDs.first {
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
//            // When editing ends (editingText becomes nil), apply the preview typography to document
//            if oldID != nil && newID == nil && previewTypography != nil, let textID = editingTextID {
//                // Editing finished - save preview to document
//                document.updateTextTypographyInUnified(id: textID, typography: previewTypography!)
//                // Clear preview state
//                previewTypography = nil
//                editingTextID = nil
//            }
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

        for textID in selectedObjectIDs {
            document.updateShapeByID(textID) { shape in
                var typography = shape.typography ?? TypographyProperties(
                    strokeColor: shape.strokeStyle?.color ?? .black,
                    fillColor: shape.fillStyle?.color ?? .black
                )
                let oldFontSize = typography.fontSize
                let lineHeightRatio = typography.lineHeight / oldFontSize
                typography.fontSize = newSize
                typography.lineHeight = newSize * lineHeightRatio
                shape.typography = typography
            }
        }

        document.fontManager.selectedFontSize = newSize
        document.fontManager.selectedLineHeight = newSize
    }

    private func updateLineSpacing(_ newSpacing: CGFloat, isPreview: Bool = false) {
        currentLineSpacingState = newSpacing

        for textID in selectedObjectIDs {
            document.updateShapeByID(textID) { shape in
                var typography = shape.typography ?? TypographyProperties(
                    strokeColor: shape.strokeStyle?.color ?? .black,
                    fillColor: shape.fillStyle?.color ?? .black
                )
                typography.lineSpacing = Double(newSpacing)
                shape.typography = typography
            }
        }

        document.fontManager.selectedLineSpacing = Double(newSpacing)
    }

    private func updateLineHeight(_ newHeight: CGFloat, isPreview: Bool = false) {
        currentLineHeightState = newHeight

        for textID in selectedObjectIDs {
            document.updateShapeByID(textID) { shape in
                var typography = shape.typography ?? TypographyProperties(
                    strokeColor: shape.strokeStyle?.color ?? .black,
                    fillColor: shape.fillStyle?.color ?? .black
                )
                typography.lineHeight = Double(newHeight)
                shape.typography = typography
            }
        }

        document.fontManager.selectedLineHeight = Double(newHeight)
    }
}
