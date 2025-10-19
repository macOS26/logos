import SwiftUI

struct FontPanel: View {
    @ObservedObject var document: VectorDocument
    @State private var lastLoggedSelection: UUID?
    @State private var lastLoggedEditing: UUID?
    @State private var fontFamilyUpdateTrigger: Bool = false

    private var selectedTextTypography: TypographyProperties? {
        guard !document.viewState.selectedObjectIDs.isEmpty,
              let textID = document.viewState.selectedObjectIDs.first else { return nil }

        if let unifiedObj = document.findObject(by: textID),
           case .text(let shape) = unifiedObj.objectType {
            if let typography = shape.typography {
                return typography
            } else {
                return TypographyProperties(
                    strokeColor: shape.strokeStyle?.color ?? .black,
                    fillColor: shape.fillStyle?.color ?? .black
                )
            }
        }
        return nil
    }

    private var selectedTextID: UUID? {
        return document.viewState.selectedObjectIDs.first
    }

    private var selectedTextContent: String? {
        guard let textID = selectedTextID else { return nil }

        if let unifiedObj = document.findObject(by: textID),
           case .text(let shape) = unifiedObj.objectType {
            return shape.textContent ?? shape.name.replacingOccurrences(of: "Text: ", with: "")
        }
        return nil
    }

    private var selectedText: VectorText? {
        guard let textID = selectedTextID,
              let typography = selectedTextTypography else { return nil }

        if let unifiedObj = document.findObject(by: textID),
           case .text(let shape) = unifiedObj.objectType {
            return VectorText.from(shape)
        }

        var text = VectorText(
            content: selectedTextContent ?? "",
            typography: typography,
            position: .zero
        )
        text.id = textID
        return text
    }

    private var editingText: VectorText? {
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .text(let shape) = obj.objectType {
                return shape.isEditing == true
            }
            return false
        }) {
            if case .text(let shape) = unifiedObj.objectType {
                return VectorText.from(shape)
            }
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    FontPanelHeader(
                        selectedText: selectedText,
                        editingText: editingText
                    )

                    VStack(spacing: 16) {
                        FontPickerView(
                            document: document,
                            selectedTextTypography: selectedTextTypography,
                            selectedText: selectedText,
                            editingText: editingText,
                            fontFamilyUpdateTrigger: $fontFamilyUpdateTrigger
                        )

                        FontSizeControls(
                            document: document,
                            selectedText: selectedText,
                            editingText: editingText
                        )

                        FontAlignmentControls(
                            document: document,
                            selectedText: selectedText,
                            editingText: editingText
                        )

                        ConvertToOutlinesButton(
                            document: document,
                            selectedText: selectedText
                        )
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(12)
                .padding(.horizontal, 12)

                Spacer()
            }
        }
        .onAppear {
        }
        .onChange(of: document.viewState.selectedObjectIDs) { oldIDs, newIDs in

            if let firstID = newIDs.first, let newSelectedText = document.findText(by: firstID) {
                if newSelectedText.id != lastLoggedSelection {
                    lastLoggedSelection = newSelectedText.id
                }
            } else {
                if lastLoggedSelection != nil {
                    lastLoggedSelection = nil
                }
            }
        }
        .onChange(of: document.changeNotifier.changeToken) { _, _ in
            let freshEditingText = document.unifiedObjects.first { obj in
                if case .text(let shape) = obj.objectType {
                    return shape.isEditing == true
                }
                return false
            }.flatMap { obj -> VectorText? in
                if case .text(let shape) = obj.objectType, var text = VectorText.from(shape) {
                    text.layerIndex = obj.layerIndex
                    return text
                }
                return nil
            }

            if let newEditingText = freshEditingText {
                if newEditingText.id != lastLoggedEditing {
                    lastLoggedEditing = newEditingText.id
                }
            } else {
                if lastLoggedEditing != nil {
                    lastLoggedEditing = nil
                }
            }
        }
    }
}
