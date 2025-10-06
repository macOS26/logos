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
            Log.fileOperation("🔧 TYPE PANEL: Tool changed from \(oldTool.rawValue) to \(newTool.rawValue)", level: .info)
            // Log.info("🔒 PROTECTION: Type settings remain isolated per text box UUID - no syncing", category: .general)
            
            if let editingText = editingText {
                Log.fileOperation("🎯 EDITING UUID: \(editingText.id.uuidString.prefix(8)) - BLUE state maintained", level: .info)
            }
            if let selectedText = selectedText {
                Log.fileOperation("🎯 SELECTED UUID: \(selectedText.id.uuidString.prefix(8)) - GREEN state maintained", level: .info)
            }
            if selectedText == nil && editingText == nil {
                Log.fileOperation("🎯 NO TEXT SELECTED - showing document defaults for new text creation", level: .info)
            }
        }
        .onChange(of: document.selectedTextIDs) { oldIDs, newIDs in
            let removedIDs = oldIDs.subtracting(newIDs)
            let addedIDs = newIDs.subtracting(oldIDs)

            for removedID in removedIDs {
                Log.fileOperation("🎯 TEXT DESELECTED: \(removedID.uuidString.prefix(8)) - type settings preserved", level: .info)
            }
            for addedID in addedIDs {
                Log.fileOperation("🎯 TEXT SELECTED: \(addedID.uuidString.prefix(8)) - loading unique type settings", level: .info)
            }

            if let firstID = newIDs.first, let newSelectedText = document.findText(by: firstID) {
                if newSelectedText.id != lastLoggedSelection {
                    lastLoggedSelection = newSelectedText.id
                    Log.fileOperation("🎯 TYPE PANEL: Found selected text - UUID: \(newSelectedText.id.uuidString.prefix(8)), Line Spacing: \(newSelectedText.typography.lineSpacing)", level: .info)
                }
            } else {
                if lastLoggedSelection != nil {
                    lastLoggedSelection = nil
                    Log.fileOperation("🎯 TYPE PANEL: No selected text found - selectedTextIDs count: \(document.selectedTextIDs.count)", level: .info)
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
                    Log.fileOperation("🎯 TYPE PANEL: Found editing text - UUID: \(newEditingText.id.uuidString.prefix(8))", level: .info)
                }
            } else {
                if lastLoggedEditing != nil {
                    lastLoggedEditing = nil
                    Log.fileOperation("🎯 TYPE PANEL: No editing text found", level: .info)
                }
            }
        }
    }
}