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

    // LOCAL @State variables for preview during editing
    @State private var currentFontFamilyState: String = "Helvetica"
    @State private var availableFontVariantNamesState: [String] = ["Regular"]
    @State private var currentFontVariantState: String = "Regular"
    @State private var previewTypography: TypographyProperties? = nil
    @State private var editingTextID: UUID? = nil

    private var currentFontFamily: String {
        // During editing, return the preview state
        if editingText != nil, previewTypography != nil {
            return currentFontFamilyState
        }

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
        // During editing, return the preview state
        if editingText != nil, previewTypography != nil {
            return currentFontVariantState
        }

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

                    let newVariants = document.fontManager.getAvailableVariantNames(for: newFamily)
                    availableFontVariantNamesState = newVariants

                    let defaultVariant = newVariants.first ?? "Regular"
                    currentFontVariantState = defaultVariant
                    document.fontManager.selectedFontVariant = defaultVariant

                    // Update LOCAL preview state only - do NOT update document
                    if let textID = document.selectedTextIDs.first,
                       let freshText = document.findText(by: textID) {
                        var updatedTypography = freshText.typography
                        updatedTypography.fontFamily = newFamily
                        updatedTypography.fontVariant = defaultVariant

                        // Store in @State for preview
                        previewTypography = updatedTypography
                        editingTextID = textID

                        // Send preview notification for live update
                        document.textPreviewTypography[textID] = updatedTypography
                        NotificationCenter.default.post(
                            name: Notification.Name("TextPreviewUpdate"),
                            object: nil,
                            userInfo: ["textID": textID, "typography": updatedTypography]
                        )

                        // Document will be updated when editing finishes
                    }
                }
            )) {
                ForEach(document.fontManager.availableFonts, id: \.self) { fontFamily in
                    Text(fontFamily)
                        .font(.custom(fontFamily, size: 12))
                        .tag(fontFamily)
                }
            }
            .fontPickerStyle()
            .id(fontFamilyUpdateTrigger)

            Text("Weight")
                .fontPickerLabel()
            
            Picker("", selection: Binding(
                get: {
                    currentFontVariantState
                },
                set: { newVariant in
                    currentFontVariantState = newVariant
                    document.fontManager.selectedFontVariant = newVariant

                    // Update LOCAL preview state only - do NOT update document
                    if let textID = document.selectedTextIDs.first,
                       let freshText = document.findText(by: textID) {
                        var updatedTypography = freshText.typography
                        updatedTypography.fontVariant = newVariant

                        // Store in @State for preview
                        previewTypography = updatedTypography
                        editingTextID = textID

                        // Send preview notification for live update
                        document.textPreviewTypography[textID] = updatedTypography
                        NotificationCenter.default.post(
                            name: Notification.Name("TextPreviewUpdate"),
                            object: nil,
                            userInfo: ["textID": textID, "typography": updatedTypography]
                        )

                        // Document will be updated when editing finishes
                    }
                }
            )) {
                ForEach(availableFontVariantNamesState, id: \.self) { variant in
                    Text(cleanVariantName(variant))
                        .font(getFontForVariant(family: currentFontFamilyState, variantName: variant))
                        .tag(variant)
                        .id("\(currentFontFamilyState)-\(variant)")
                }
            }
            .fontPickerStyle()
            .id("\(currentFontFamilyState)-\(fontFamilyUpdateTrigger)")
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
        .onChange(of: fontFamilyUpdateTrigger) { _, _ in
            syncFontStates()
        }
    }

    private func syncFontStates() {
        let family = currentFontFamily
        currentFontFamilyState = family

        let variants = document.fontManager.getAvailableVariantNames(for: family)
        availableFontVariantNamesState = variants

        print("📋 SYNCING FONT STATES FOR \(family)")
        print("   Variants in state: \(variants)")

        let variant = currentFontVariant
        if variants.contains(variant) {
            currentFontVariantState = variant
            print("   Current variant: \(variant) ✅")
        } else {
            currentFontVariantState = variants.first ?? "Regular"
            print("   Variant not found, using: \(currentFontVariantState) ⚠️")
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

    private func cleanVariantName(_ name: String) -> String {
        let weightMap: [String: String] = [
            "W0": "Ultra Light",
            "W1": "Light",
            "W2": "Thin",
            "W3": "Light",
            "W4": "Book",
            "W5": "Regular",
            "W6": "Medium",
            "W7": "Demibold",
            "W8": "Semibold",
            "W9": "Bold",
            "W10": "Extra Bold",
            "W11": "Heavy",
            "W12": "Black",
            "W13": "Ultra Black",
            "W14": "Extra Black",
            "W15": "Ultra Black"
        ]

        if let fullName = weightMap[name] {
            return fullName
        }

        for (code, fullWeight) in weightMap {
            if name.hasPrefix(code) {
                let remainder = name.dropFirst(code.count).trimmingCharacters(in: .whitespaces)
                if remainder.isEmpty {
                    return fullWeight
                } else {
                    return "\(fullWeight) \(remainder)"
                }
            }
        }

        return name
    }
}
