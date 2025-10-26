import SwiftUI
import AppKit
import Combine

extension VectorDocument {

    func migrateLegacyTextObjects() {
        for (objectID, object) in snapshot.objects {
            if case .text(var shape) = object.objectType,
               let typography = shape.typography {
                let needsFontVariantMigration = typography.fontVariant == nil || typography.fontVariant?.isEmpty == true

                if needsFontVariantMigration {
                    let nsFont = typography.nsFont
                    let actualFontFamily = nsFont.familyName ?? typography.fontFamily

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

                    if fontVariant == nil {
                        fontVariant = "Regular"
                    }

                    var updatedTypography = typography
                    updatedTypography.fontFamily = actualFontFamily
                    updatedTypography.fontVariant = fontVariant

                    shape.typography = updatedTypography

                    let updatedObject = VectorObject(
                        id: shape.id,
                        layerIndex: object.layerIndex,
                        objectType: .text(shape)
                    )
                    snapshot.objects[objectID] = updatedObject
                }
            }
        }
    }
}
