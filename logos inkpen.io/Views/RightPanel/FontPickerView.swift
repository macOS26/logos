import SwiftUI
import AppKit
import Combine

struct FontPickerLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

struct FontPickerPickerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
    }
}

extension View {
    func fontPickerLabel() -> some View {
        modifier(FontPickerLabelStyle())
    }
    
    func fontPickerStyle() -> some View {
        modifier(FontPickerPickerStyle())
    }
}

struct FontPickerView: View {
    @ObservedObject var document: VectorDocument
    let selectedTextTypography: TypographyProperties?
    let selectedText: VectorText?
    let editingText: VectorText?
    @Binding var fontFamilyUpdateTrigger: Bool

    @State private var currentFontFamilyState: String = "Helvetica"
    @State private var availableFontVariantNamesState: [String] = ["Regular"]
    @State private var currentFontVariantState: String = "Regular"
    @State private var cachedAvailableFonts: [String] = []

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

    private var currentFontVariant: String {
        if let selectedText = selectedText {
            if let variant = selectedText.typography.fontVariant,
               !variant.isEmpty {
                return variant
            }
        } else if let editingText = editingText {
            if let variant = editingText.typography.fontVariant,
               !variant.isEmpty {
                return variant
            }
        }
        return document.fontManager.selectedFontVariant
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font")
                .fontPickerLabel()
            
            Picker("", selection: Binding(
                get: {
                    currentFontFamilyState
                },
                set: { newFamily in
                    currentFontFamilyState = newFamily
                    document.fontManager.selectedFontFamily = newFamily
                    fontFamilyUpdateTrigger.toggle()

                    // Update available variants for new family
                    let newVariants = document.fontManager.getAvailableVariantNames(for: newFamily)
                    availableFontVariantNamesState = newVariants

                    // Reset to first available variant (usually Regular)
                    let defaultVariant = newVariants.first ?? "Regular"
                    currentFontVariantState = defaultVariant
                    document.fontManager.selectedFontVariant = defaultVariant

                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontFamilyDirect(id: textID, fontFamily: newFamily)
                        document.updateTextFontVariantDirect(id: textID, fontVariant: defaultVariant)
                    }
                }
            )) {
                ForEach(cachedAvailableFonts, id: \.self) { fontFamily in
                    Text(fontFamily)
                        .tag(fontFamily)
                }
            }
            .fontPickerStyle()

            Text("Weight")
                .fontPickerLabel()
            
            Picker("", selection: Binding(
                get: {
                    currentFontVariantState
                },
                set: { newVariant in
                    currentFontVariantState = newVariant
                    document.fontManager.selectedFontVariant = newVariant

                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontVariantDirect(id: textID, fontVariant: newVariant)
                    }
                }
            )) {
                ForEach(availableFontVariantNamesState, id: \.self) { variant in
                    Text(variant)
                        .tag(variant)
                }
            }
            .fontPickerStyle()
        }
        .onAppear {
            cachedAvailableFonts = document.fontManager.availableFonts
            syncFontStates()
        }
        .onChange(of: selectedText?.id) { _, _ in
            syncFontStates()
        }
        .onChange(of: editingText?.id) { _, _ in
            syncFontStates()
        }
        .onChange(of: fontFamilyUpdateTrigger) { _, _ in
            syncFontStates()
        }
    }

    private func syncFontStates() {
        let family = currentFontFamily
        currentFontFamilyState = family

        let variants = document.fontManager.getAvailableVariantNames(for: family)
        availableFontVariantNamesState = variants

        let variant = currentFontVariant
        // Make sure the current variant is valid for the available variants
        if variants.contains(variant) {
            currentFontVariantState = variant
        } else {
            currentFontVariantState = variants.first ?? "Regular"
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
