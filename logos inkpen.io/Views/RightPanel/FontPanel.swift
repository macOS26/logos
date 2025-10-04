//
//  FontPanel.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct FontPanel: View {
    @ObservedObject var document: VectorDocument
    
    @State private var lastLoggedSelection: UUID?
    @State private var lastLoggedEditing: UUID?
    @State private var fontFamilyUpdateTrigger: Bool = false

    private var selectedTextTypography: TypographyProperties? {
        guard !document.selectedTextIDs.isEmpty,
              let textID = document.selectedTextIDs.first else { return nil }

        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObj = document.findObject(by: textID),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject {
            // CRITICAL FIX: If typography is nil, create it from the shape's stroke/fill styles
            // This handles the case when text is restored from undo but typography wasn't preserved
            if let typography = shape.typography {
                return typography
            } else {
                // Fallback: create typography from shape properties
                return TypographyProperties(
                    strokeColor: shape.strokeStyle?.color ?? .black,
                    fillColor: shape.fillStyle?.color ?? .black
                )
            }
        }
        return nil
    }

    private var selectedTextID: UUID? {
        return document.selectedTextIDs.first
    }

    private var selectedTextContent: String? {
        guard let textID = selectedTextID else { return nil }

        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObj = document.findObject(by: textID),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject {
            // CRITICAL FIX: Use textContent if available, otherwise parse from name
            return shape.textContent ?? shape.name.replacingOccurrences(of: "Text: ", with: "")
        }
        return nil
    }

    private var selectedText: VectorText? {
        guard let textID = selectedTextID,
              let typography = selectedTextTypography else { return nil }

        // CRITICAL FIX: Try to get the actual VectorText from the shape first
        // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
        if let unifiedObj = document.findObject(by: textID),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject {
            // Use VectorText.from to properly reconstruct the text object
            return VectorText.from(shape)
        }

        // Fallback to creating a minimal VectorText
        var text = VectorText(
            content: selectedTextContent ?? "",
            typography: typography,
            position: .zero
        )
        text.id = textID
        return text
    }

    private var editingText: VectorText? {
        // NOTE: This O(N) loop is intentional - we need to find ANY text object in editing mode
        // Cannot use UUID lookup since we don't know which text is being edited
        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && (shape.isEditing == true)
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObj.objectType {
                return VectorText.from(shape)
            }
        }
        return nil
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Component
                    FontPanelHeader(
                        selectedText: selectedText,
                        editingText: editingText
                    )
                    
                    VStack(spacing: 16) {
                        // Font Picker Component
                        FontPickerView(
                            document: document,
                            selectedTextTypography: selectedTextTypography,
                            selectedText: selectedText,
                            editingText: editingText,
                            fontFamilyUpdateTrigger: $fontFamilyUpdateTrigger
                        )
                        
                        // Font Size Controls Component
                        FontSizeControls(
                            document: document,
                            selectedText: selectedText,
                            editingText: editingText
                        )
                        
                        // Alignment Controls Component
                        FontAlignmentControls(
                            document: document,
                            selectedText: selectedText,
                            editingText: editingText
                        )

                        // Convert to Outlines Component
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
            // NO CACHE - always use fresh data
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
        }
        .onChange(of: document.selectedTextIDs) { _, newIDs in
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
        .onChange(of: document.unifiedObjects.map { $0.id }) { _, _ in
            let freshEditingText = document.unifiedObjects.first { obj in
                if case .shape(let shape) = obj.objectType, shape.isTextObject {
                    return shape.isEditing == true
                }
                return false
            }.flatMap { obj -> VectorText? in
                if case .shape(let shape) = obj.objectType, var text = VectorText.from(shape) {
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
