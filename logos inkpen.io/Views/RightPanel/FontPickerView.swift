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

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Font")
                .fontPickerLabel()
            
            Picker("", selection: Binding(
                get: {
                    if let textID = document.viewState.selectedObjectIDs.first,
                       let freshText = document.findText(by: textID) {
                        return freshText.typography.fontFamily
                    }
                    return document.fontManager.selectedFontFamily
                },
                set: { newFamily in
                    document.fontManager.selectedFontFamily = newFamily
                    let defaultVariant = document.fontManager.getAvailableVariantNames(for: newFamily).first ?? "Regular"
                    document.fontManager.selectedFontVariant = defaultVariant

                    if let textID = document.viewState.selectedObjectIDs.first,
                       let freshText = document.findText(by: textID) {
                        var updatedTypography = freshText.typography
                        updatedTypography.fontFamily = newFamily
                        updatedTypography.fontVariant = defaultVariant

                        // Use command system for undo/redo
                        let command = TextTypographyCommand(
                            textID: textID,
                            oldTypography: freshText.typography,
                            newTypography: updatedTypography
                        )
                        document.commandManager.execute(command)

                        // Send preview notification so text view updates immediately
                        NotificationCenter.default.post(
                            name: Notification.Name("TextPreviewUpdate"),
                            object: nil,
                            userInfo: ["textID": textID, "typography": updatedTypography]
                        )
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

            Text("Weight")
                .fontPickerLabel()
            
            Picker("", selection: Binding(
                get: {
                    if let textID = document.viewState.selectedObjectIDs.first,
                       let freshText = document.findText(by: textID),
                       let variant = freshText.typography.fontVariant,
                       !variant.isEmpty {
                        return variant
                    }
                    return document.fontManager.selectedFontVariant
                },
                set: { newVariant in
                    document.fontManager.selectedFontVariant = newVariant

                    if let textID = document.viewState.selectedObjectIDs.first,
                       let freshText = document.findText(by: textID) {
                        var updatedTypography = freshText.typography
                        updatedTypography.fontVariant = newVariant

                        // Use command system for undo/redo
                        let command = TextTypographyCommand(
                            textID: textID,
                            oldTypography: freshText.typography,
                            newTypography: updatedTypography
                        )
                        document.commandManager.execute(command)

                        // Send preview notification so text view updates immediately
                        NotificationCenter.default.post(
                            name: Notification.Name("TextPreviewUpdate"),
                            object: nil,
                            userInfo: ["textID": textID, "typography": updatedTypography]
                        )
                    }
                }
            )) {
                let currentFamily = {
                    if let textID = document.viewState.selectedObjectIDs.first,
                       let freshText = document.findText(by: textID) {
                        return freshText.typography.fontFamily
                    }
                    return document.fontManager.selectedFontFamily
                }()

                ForEach(document.fontManager.getAvailableVariantNames(for: currentFamily), id: \.self) { variant in
                    Text(cleanVariantName(variant))
                        .font(getFontForVariant(family: currentFamily, variantName: variant))
                        .tag(variant)
                        .id("\(currentFamily)-\(variant)")
                }
            }
            .fontPickerStyle()
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
