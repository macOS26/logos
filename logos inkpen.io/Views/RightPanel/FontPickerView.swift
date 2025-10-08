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

    private var availableFontVariants: [(displayName: String, postScriptName: String)] {
        let family = currentFontFamily
        return document.fontManager.getAvailableVariants(for: family)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Font Family
            Text("Font")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    // First check if we have a selected text with typography
                    if let selectedText = selectedText {
                        return selectedText.typography.fontFamily
                    }
                    // Otherwise use the selected typography or document defaults
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

            // Font Variant (combines weight and style like Pages does)
            Text("Weight")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    // Get current variant from selected text or document defaults
                    var currentVariant = document.fontManager.selectedFontVariant

                    if let selectedText = selectedText {
                        // If variant is stored, use it
                        if let variant = selectedText.typography.fontVariant {
                            // Check if this is a PostScript name and convert to display name
                            let variants = availableFontVariants
                            if let matchingVariant = variants.first(where: {
                                $0.postScriptName == variant || $0.displayName == variant
                            }) {
                                currentVariant = matchingVariant.displayName
                            } else {
                                currentVariant = variant
                            }
                        } else {
                            // Otherwise, derive it from weight and style
                            if let derivedVariant = document.fontManager.getVariantName(
                                for: selectedText.typography.fontFamily,
                                weight: selectedText.typography.fontWeight,
                                style: selectedText.typography.fontStyle
                            ) {
                                currentVariant = derivedVariant
                            }
                        }
                    }

                    // CRITICAL: Ensure the variant exists in the available list
                    // If not, return the first available variant to avoid picker errors
                    let variants = availableFontVariants
                    if variants.contains(where: { $0.displayName == currentVariant }) {
                        return currentVariant
                    } else {
                        // Return first variant or "Regular" as fallback
                        return variants.first?.displayName ?? "Regular"
                    }
                },
                set: { newVariant in
                    // ALWAYS update defaults first - NO RESTRICTIONS
                    document.fontManager.selectedFontVariant = newVariant

                    // Also derive and set weight/style from the variant
                    let variants = document.fontManager.getAvailableVariants(for: currentFontFamily)
                    if variants.contains(where: { $0.displayName == newVariant }) {
                        // Get weight and style from this variant
                        let fontManager = NSFontManager.shared
                        let members = fontManager.availableMembers(ofFontFamily: currentFontFamily) ?? []
                        for member in members {
                            if let displayName = member[1] as? String,
                               displayName == newVariant,
                               let weightNumber = member[2] as? NSNumber,
                               let traits = member[3] as? NSNumber {

                                let weight = document.fontManager.mapNSWeightToFontWeight(weightNumber.intValue)
                                let traitMask = NSFontDescriptor.SymbolicTraits(rawValue: UInt32(traits.intValue))
                                let style: FontStyle = traitMask.contains(.italic) ? .italic : .normal

                                document.fontManager.selectedFontWeight = weight
                                document.fontManager.selectedFontStyle = style
                                break
                            }
                        }
                    }

                    // Then update selected text if any - with immediate update
                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontVariantDirect(id: textID, fontVariant: newVariant)
                    }

                    // Force UI update after the change
                    document.objectWillChange.send()
                }
            )) {
                ForEach(availableFontVariants, id: \.postScriptName) { variant in
                    Text(variant.displayName)
                        .font(.custom(variant.postScriptName, size: 12))
                        .tag(variant.displayName)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .id(fontFamilyUpdateTrigger)
        }
    }
}
