//
//  VectorDocument+LegacyTextMigration.swift
//  logos inkpen.io
//
//  Migration for legacy text objects missing font properties
//

import SwiftUI
import AppKit
import Combine

extension VectorDocument {

    /// Migrate legacy text objects that don't have font family or weight populated
    /// Reads the actual font from the NSFont and repopulates typography
    func migrateLegacyTextObjects() {
        var needsMigration = false

        // Check all unified objects for text objects with missing font info
        for (index, object) in unifiedObjects.enumerated() {
            if case .shape(var shape) = object.objectType,
               shape.isTextObject,
               let typography = shape.typography {

                // Check if font family or weight is missing/default
                let needsFontFix = typography.fontFamily.isEmpty ||
                                  typography.fontFamily == "Helvetica" ||
                                  typography.fontWeight == .regular && typography.fontVariant == nil

                if needsFontFix {
                    // Read the actual font from NSFont and extract properties
                    let nsFont = typography.nsFont

                    // Get font family name
                    let actualFontFamily = nsFont.familyName ?? typography.fontFamily

                    // Get font descriptor to extract weight
                    let descriptor = nsFont.fontDescriptor

                    // Extract weight from font descriptor
                    var fontWeight = typography.fontWeight
                    if let weightTrait = descriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any],
                       let weight = weightTrait[.weight] as? NSNumber {
                        fontWeight = fontManager.mapNSWeightToFontWeight(Int(weight.floatValue * 10))
                    }

                    // Extract variant name by matching with available members
                    var fontVariant: String? = nil
                    let fontManagerNS = NSFontManager.shared
                    let members = fontManagerNS.availableMembers(ofFontFamily: actualFontFamily) ?? []

                    for member in members {
                        if let postScriptName = member[0] as? String,
                           postScriptName == nsFont.fontName,
                           let displayName = member[1] as? String {
                            fontVariant = displayName
                            break
                        }
                    }

                    // Update typography with detected values (fontStyle is deprecated - info now in variant)
                    var updatedTypography = typography
                    updatedTypography.fontFamily = actualFontFamily
                    updatedTypography.fontWeight = fontWeight
                    updatedTypography.fontVariant = fontVariant

                    // Update the shape
                    shape.typography = updatedTypography

                    unifiedObjects[index] = VectorObject(
                        shape: shape,
                        layerIndex: object.layerIndex,
                        orderID: object.orderID
                    )

                    needsMigration = true

                    Log.info("✅ Migrated legacy text: '\(shape.textContent?.prefix(20) ?? "")' - Font: \(actualFontFamily) \(fontVariant ?? "")", category: .general)
                }
            }
        }

        if needsMigration {
            objectWillChange.send()
            Log.info("🔄 Legacy text migration complete", category: .general)
        }
    }
}
