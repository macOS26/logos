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

        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObj.objectType {
                return shape.typography
            }
        }
        return nil
    }

    private var selectedTextID: UUID? {
        return document.selectedTextIDs.first
    }

    private var selectedTextContent: String? {
        guard let textID = selectedTextID else { return nil }

        if let unifiedObj = document.unifiedObjects.first(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == textID
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObj.objectType {
                return shape.name.replacingOccurrences(of: "Text: ", with: "")
            }
        }
        return nil
    }

    private var selectedText: VectorText? {
        guard let textID = selectedTextID,
              let typography = selectedTextTypography else { return nil }

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
                        
                        // Color Display Component
                        FontColorDisplay(selectedText: selectedText)
                        
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
            Log.fileOperation("🔧 FONT PANEL: Tool changed from \(oldTool.rawValue) to \(newTool.rawValue)", level: .info)
            Log.info("🔒 PROTECTION: Font settings remain isolated per text box UUID - no syncing", category: .general)
            
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
                Log.fileOperation("🎯 TEXT DESELECTED: \(removedID.uuidString.prefix(8)) - font settings preserved", level: .info)
            }
            for addedID in addedIDs {
                Log.fileOperation("🎯 TEXT SELECTED: \(addedID.uuidString.prefix(8)) - loading unique font settings", level: .info)
            }

            if let newSelectedText = document.allTextObjects.first(where: { newIDs.contains($0.id) }) {
                if newSelectedText.id != lastLoggedSelection {
                    lastLoggedSelection = newSelectedText.id
                    Log.fileOperation("🎯 FONT PANEL: Found selected text - UUID: \(newSelectedText.id.uuidString.prefix(8)), Line Spacing: \(newSelectedText.typography.lineSpacing)", level: .info)
                }
            } else {
                if lastLoggedSelection != nil {
                    lastLoggedSelection = nil
                    Log.fileOperation("🎯 FONT PANEL: No selected text found - selectedTextIDs count: \(document.selectedTextIDs.count)", level: .info)
                }
            }
        }
        .onChange(of: document.unifiedObjects.map { $0.id }) { _, _ in
            let freshEditingText = document.allTextObjects.first { $0.isEditing }

            if let newEditingText = freshEditingText {
                if newEditingText.id != lastLoggedEditing {
                    lastLoggedEditing = newEditingText.id
                    Log.fileOperation("🎯 FONT PANEL: Found editing text - UUID: \(newEditingText.id.uuidString.prefix(8))", level: .info)
                }
            } else {
                if lastLoggedEditing != nil {
                    lastLoggedEditing = nil
                    Log.fileOperation("🎯 FONT PANEL: No editing text found", level: .info)
                }
            }
        }
    }
}
