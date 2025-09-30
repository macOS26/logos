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
    
    private var availableFontWeights: [FontWeight] {
        let family = currentFontFamily
        return document.fontManager.getAvailableWeights(for: family)
    }
    
    private var availableFontStyles: [FontStyle] {
        let family = currentFontFamily
        return document.fontManager.getAvailableStyles(for: family)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Font Family
            Text("Font")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
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

            // Font Weight
            Text("Weight")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    guard let selectedText = selectedText else {
                        return availableFontWeights.contains(document.fontManager.selectedFontWeight) ? document.fontManager.selectedFontWeight : availableFontWeights.first ?? .regular
                    }
                    return availableFontWeights.contains(selectedText.typography.fontWeight) ? selectedText.typography.fontWeight : availableFontWeights.first ?? .regular
                },
                set: { newWeight in
                    // ALWAYS update defaults first - NO RESTRICTIONS
                    document.fontManager.selectedFontWeight = newWeight

                    // Then update selected text if any - with immediate update
                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontWeightDirect(id: textID, fontWeight: newWeight)
                    }

                    // Force UI update after the change
                    document.objectWillChange.send()
                }
            )) {
                ForEach(availableFontWeights, id: \.self) { weight in
                    Text(weight.rawValue)
                        .font(createPreviewFont(family: currentFontFamily, weight: weight, style: selectedText?.typography.fontStyle ?? document.fontManager.selectedFontStyle))
                        .tag(weight)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .id(fontFamilyUpdateTrigger)

            // Font Style
            Text("Style")
                .font(.caption)
                .foregroundColor(.secondary)
            Picker("", selection: Binding(
                get: {
                    guard let selectedText = selectedText else {
                        return availableFontStyles.contains(document.fontManager.selectedFontStyle) ? document.fontManager.selectedFontStyle : availableFontStyles.first ?? .normal
                    }
                    return availableFontStyles.contains(selectedText.typography.fontStyle) ? selectedText.typography.fontStyle : availableFontStyles.first ?? .normal
                },
                set: { newStyle in
                    // ALWAYS update defaults first - NO RESTRICTIONS
                    document.fontManager.selectedFontStyle = newStyle

                    // Then update selected text if any - with immediate update
                    if let textID = document.selectedTextIDs.first {
                        document.updateTextFontStyleDirect(id: textID, fontStyle: newStyle)
                    }

                    // Force UI update after the change
                    document.objectWillChange.send()
                }
            )) {
                ForEach(availableFontStyles, id: \.self) { style in
                    Text(style.rawValue)
                        .font(createPreviewFont(family: currentFontFamily, weight: selectedText?.typography.fontWeight ?? document.fontManager.selectedFontWeight, style: style))
                        .tag(style)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .id(fontFamilyUpdateTrigger)
        }
    }
    
    private func createPreviewFont(family: String, weight: FontWeight, style: FontStyle) -> Font {
        let fontManager = NSFontManager.shared
        let members = fontManager.availableMembers(ofFontFamily: family) ?? []
        
        for member in members {
            if let fontName = member[1] as? String,
               let weightNumber = member[2] as? NSNumber,
               let traits = member[3] as? NSNumber {
                
                let memberWeight = mapNSWeightToFontWeight(weightNumber.intValue)
                let traitMask = NSFontDescriptor.SymbolicTraits(rawValue: UInt32(traits.intValue))
                let memberStyle: FontStyle = traitMask.contains(.italic) ? .italic : .normal
                
                if memberWeight == weight && memberStyle == style {
                    if NSFont(name: fontName, size: 12) != nil {
                        return Font.custom(fontName, size: 12)
                    }
                }
            }
        }
        
        let descriptor = NSFontDescriptor(name: family, size: 12)
        let traits: NSFontDescriptor.SymbolicTraits = style == .italic ? .italic : []
        let weightedDescriptor = descriptor.addingAttributes([
            .traits: [
                NSFontDescriptor.TraitKey.weight: weight.nsWeight.rawValue,
                NSFontDescriptor.TraitKey.symbolic: traits.rawValue
            ]
        ])
        
        if let nsFont = NSFont(descriptor: weightedDescriptor, size: 12) {
            return Font.custom(nsFont.fontName, size: 12)
        } else {
            return Font.system(size: 12, weight: weight.systemWeight, design: .default)
        }
    }
    
    private func mapNSWeightToFontWeight(_ nsWeight: Int) -> FontWeight {
        switch nsWeight {
        case 0...2: return .thin
        case 3: return .ultraLight
        case 4: return .light
        case 5: return .regular
        case 6: return .medium
        case 7...8: return .semibold
        case 9: return .bold
        case 10...11: return .heavy
        default: return .black
        }
    }
}
