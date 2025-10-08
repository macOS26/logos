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

    /// Migrate legacy text objects that don't have fontVariant populated
    /// Reads the actual font from NSFont and extracts the variant name
    /// Also migrates old fontWeight + fontStyle to fontVariant
    func migrateLegacyTextObjects() {
        var needsMigration = false

        // Check all unified objects for text objects with missing font info
        for (index, object) in unifiedObjects.enumerated() {
            if case .shape(var shape) = object.objectType,
               shape.isTextObject,
               let typography = shape.typography {

                // MIGRATION: If fontVariant is missing, we need to extract it
                let needsFontVariantMigration = typography.fontVariant == nil || typography.fontVariant?.isEmpty == true

                if needsFontVariantMigration {
                    // Read the actual font from NSFont and extract properties
                    let nsFont = typography.nsFont

                    // Get font family name
                    let actualFontFamily = nsFont.familyName ?? typography.fontFamily

                    // Extract variant name by matching with available members
                    var fontVariant: String? = nil
                    let fontManagerNS = NSFontManager.shared
                    let members = fontManagerNS.availableMembers(ofFontFamily: actualFontFamily) ?? []

                    // Try to find exact match by PostScript name
                    for member in members {
                        if let postScriptName = member[0] as? String,
                           postScriptName == nsFont.fontName,
                           let displayName = member[1] as? String {
                            fontVariant = displayName
                            break
                        }
                    }

                    // FALLBACK: Default to Regular
                    if fontVariant == nil {
                        fontVariant = "Regular"
                    }

                    // Update typography with extracted variant
                    var updatedTypography = typography
                    updatedTypography.fontFamily = actualFontFamily
                    updatedTypography.fontVariant = fontVariant

                    // Update the shape
                    shape.typography = updatedTypography

                    unifiedObjects[index] = VectorObject(
                        shape: shape,
                        layerIndex: object.layerIndex,
                        orderID: object.orderID
                    )

                    needsMigration = true

                    Log.info("✅ Migrated legacy text: '\(shape.textContent?.prefix(20) ?? "")' - Font: \(actualFontFamily) Variant: \(fontVariant ?? "Regular")", category: .general)
                }
            }
        }

        if needsMigration {
            objectWillChange.send()
            Log.info("🔄 Legacy text migration complete - fontVariant extracted from fontWeight + fontStyle", category: .general)
        }
    }
}
