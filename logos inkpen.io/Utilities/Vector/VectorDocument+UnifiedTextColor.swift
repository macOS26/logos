//
//  VectorDocument+UnifiedTextColor.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import SwiftUI
import Combine

// MARK: - UNIFIED TEXT COLOR HELPERS (MIGRATED FROM COLORSWATCHGRID)
extension VectorDocument {
    
    /// FAST O(1) update - change ONLY the font family
    func updateTextFontFamilyDirect(id: UUID, fontFamily: String) {
        saveToUndoStack()

        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.typography?.fontFamily = fontFamily
        }
    }

    /// FAST O(1) update - change ONLY the font variant
    func updateTextFontVariantDirect(id: UUID, fontVariant: String) {
        saveToUndoStack()

        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.typography?.fontVariant = fontVariant

            // Also derive weight and style from the variant
            if let typography = shape.typography {
                let fontManager = NSFontManager.shared
                let members = fontManager.availableMembers(ofFontFamily: typography.fontFamily) ?? []

                for member in members {
                    if let displayName = member[1] as? String,
                       displayName == fontVariant,
                       let weightNumber = member[2] as? NSNumber {

                        // Map weight
                        let nsWeight = weightNumber.intValue
                        shape.typography?.fontWeight = self.fontManager.mapNSWeightToFontWeight(nsWeight)

                        // Style is now in variant name, no need to set deprecated fontStyle
                        break
                    }
                }
            }
        }
    }

    /// FAST O(1) update - change ONLY the font weight
    func updateTextFontWeightDirect(id: UUID, fontWeight: FontWeight) {
        saveToUndoStack()

        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.typography?.fontWeight = fontWeight
        }
    }

    // DEPRECATED: fontStyle removed - style is now encoded in fontVariant name

    /// FAST O(1) preview update - change ONLY the font size for live preview
    /// Uses preview typography to avoid updating unified objects during drag
    func updateTextFontSizePreview(id: UUID, fontSize: CGFloat) {
        // Find the current text object
        if let textObject = findText(by: id) {
            var previewTypography = textObject.typography
            let oldFontSize = previewTypography.fontSize
            let lineHeightRatio = previewTypography.lineHeight / oldFontSize
            previewTypography.fontSize = fontSize
            previewTypography.lineHeight = fontSize * lineHeightRatio

            // Store in preview dictionary instead of updating unified objects
            textPreviewTypography[id] = previewTypography

            // Trigger lightweight update notification for text views only
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    /// FAST O(1) preview update - change ONLY the line spacing for live preview
    /// Uses preview typography to avoid updating unified objects during drag
    func updateTextLineSpacingPreview(id: UUID, lineSpacing: Double) {
        // Find the current text object
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.lineSpacing = lineSpacing

            // Store in preview dictionary instead of updating unified objects
            textPreviewTypography[id] = previewTypography

            // Trigger lightweight update notification for text views only
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }
    
    /// FAST O(1) preview update - change ONLY the line height for live preview
    /// Uses preview typography to avoid updating unified objects during drag
    func updateTextLineHeightPreview(id: UUID, lineHeight: Double) {
        // Find the current text object
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.lineHeight = lineHeight
            
            // Store in preview dictionary instead of updating unified objects
            textPreviewTypography[id] = previewTypography
            
            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    /// Clear preview typography when drag ends
    func clearTextPreviewTypography(id: UUID) {
        textPreviewTypography.removeValue(forKey: id)
    }

    /// MIGRATED FROM ColorSwatchGrid - Update text fill color using unified system
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE
    func updateTextFillColorInUnified(id: UUID, color: VectorColor) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            if shape.typography != nil {
                shape.typography?.fillColor = color
                shape.typography?.fillOpacity = defaultFillOpacity
            } else if let textObject = findText(by: id) {
                shape.typography = textObject.typography
                shape.typography?.fillColor = color
                shape.typography?.fillOpacity = defaultFillOpacity
            }
        }
    }
    
    /// MIGRATED FROM ColorPanel - Update text stroke color using unified system
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE
    /// CRITICAL FIX: Update text typography in unified objects and layers to keep them in sync
    /// This prevents typography from being reset when color changes
    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.typography = typography
        }
    }

    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            if shape.typography != nil {
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = color
            } else if let textObject = findText(by: id) {
                shape.typography = textObject.typography
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = color
            }
        }
    }
}
