//
//  FontPickerView.swift
//  logos inkpen.io
//
//  Created by Claude on 2025/01/15.
//

import SwiftUI
import AppKit
import Combine

struct FontPickerView: View {
    @ObservedObject var document: VectorDocument
    let selectedTextTypography: TypographyProperties?
    let selectedText: VectorText?
    let editingText: VectorText?
    @Binding var fontFamilyUpdateTrigger: Bool
    
    private var currentFontFamily: String {
        if let selectedText = selectedText {
            return selectedText.typography.fontFamily
        } else if let editingText = editingText {
            return editingText.typography.fontFamily
        } else {
            return document.fontManager.selectedFontFamily
        }
    }
    
    private var availableFontVariantNames: [String] {
        let family = currentFontFamily
        return document.fontManager.getAvailableVariantNames(for: family)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Font Family
            Text("Font")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    // Use selectedText first if available
                    if let selectedText = selectedText {
                        return selectedText.typography.fontFamily
                    }
                    return selectedTextTypography?.fontFamily ?? document.fontManager.selectedFontFamily
                },
                set: { newFamily in
                    // ALWAYS update defaults first - NO RESTRICTIONS
                    document.fontManager.selectedFontFamily = newFamily
                    fontFamilyUpdateTrigger.toggle()

                    // Then update selected text if any - with immediate update
                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontFamilyDirect(id: textID, fontFamily: newFamily)
                    }

                    // Force UI update after the change
                    document.objectWillChange.send()
                }
            )) {
                ForEach(document.fontManager.availableFonts, id: \.self) { fontFamily in
                    Text(fontFamily)
                        .font(.custom(fontFamily, size: 12))
                        .tag(fontFamily)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .id(fontFamilyUpdateTrigger)

            // Font Weight (shows all variants)
            Text("Weight")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    // Get current variant name
                    if let selectedText = selectedText {
                        // Check if variant is stored (migration ensures this is populated)
                        if let variant = selectedText.typography.fontVariant,
                           availableFontVariantNames.contains(variant) {
                            return variant
                        }
                    }

                    // Default to Regular or first available
                    return availableFontVariantNames.first ?? "Regular"
                },
                set: { newVariant in
                    // ALWAYS update defaults first
                    document.fontManager.selectedFontVariant = newVariant

                    // Then update selected text if any
                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontVariantDirect(id: textID, fontVariant: newVariant)
                    }

                    // Force UI update after the change
                    document.objectWillChange.send()
                }
            )) {
                ForEach(availableFontVariantNames, id: \.self) { variant in
                    Text(variant)
                        .font(getFontForVariant(family: currentFontFamily, variantName: variant))
                        .tag(variant)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .id(fontFamilyUpdateTrigger)

            // Font Style - DEPRECATED: All variants are now in Weight picker
            // Keeping this hidden as style is now included in the variant selection
        }
    }

    private func getFontForVariant(family: String, variantName: String) -> Font {
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []

        for member in members {
            if let postScriptName = member[0] as? String,
               let displayName = member[1] as? String,
               displayName == variantName {
                return Font.custom(postScriptName, size: 12)
            }
        }

        return Font.system(size: 12)
    }
}
