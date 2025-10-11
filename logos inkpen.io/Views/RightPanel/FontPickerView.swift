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
            Text("Font")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    if let selectedText = selectedText {
                        return selectedText.typography.fontFamily
                    }
                    return selectedTextTypography?.fontFamily ?? document.fontManager.selectedFontFamily
                },
                set: { newFamily in
                    document.fontManager.selectedFontFamily = newFamily
                    fontFamilyUpdateTrigger.toggle()

                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontFamilyDirect(id: textID, fontFamily: newFamily)
                    }

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

            Text("Weight")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    if let selectedText = selectedText {
                        if let variant = selectedText.typography.fontVariant,
                           availableFontVariantNames.contains(variant) {
                            return variant
                        }
                    }

                    return availableFontVariantNames.first ?? "Regular"
                },
                set: { newVariant in
                    document.fontManager.selectedFontVariant = newVariant

                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontVariantDirect(id: textID, fontVariant: newVariant)
                    }

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
