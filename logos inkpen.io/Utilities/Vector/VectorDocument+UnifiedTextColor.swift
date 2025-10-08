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

        guard let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }),
        case .shape(var shape) = unifiedObjects[index].objectType else { return }

        shape.typography?.fontFamily = fontFamily
        unifiedObjects[index] = VectorObject(
            shape: shape,
            layerIndex: unifiedObjects[index].layerIndex,
            orderID: unifiedObjects[index].orderID
        )
        objectWillChange.send()
    }

    /// FAST O(1) update - change ONLY the font variant
    func updateTextFontVariantDirect(id: UUID, fontVariant: String) {
        saveToUndoStack()

        guard let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }),
        case .shape(var shape) = unifiedObjects[index].objectType else { return }

        shape.typography?.fontVariant = fontVariant

        // Also derive weight and style from the variant
        if let typography = shape.typography {
            let fontManager = NSFontManager.shared
            let members = fontManager.availableMembers(ofFontFamily: typography.fontFamily) ?? []

            for member in members {
                if let displayName = member[1] as? String,
                   displayName == fontVariant,
                   let weightNumber = member[2] as? NSNumber,
                   let traits = member[3] as? NSNumber {

                    let traitMask = NSFontDescriptor.SymbolicTraits(rawValue: UInt32(traits.intValue))

                    // Map weight
                    let nsWeight = weightNumber.intValue
                    shape.typography?.fontWeight = self.fontManager.mapNSWeightToFontWeight(nsWeight)

                    // Map style
                    shape.typography?.fontStyle = traitMask.contains(.italic) ? .italic : .normal
                    break
                }
            }
        }

        unifiedObjects[index] = VectorObject(
            shape: shape,
            layerIndex: unifiedObjects[index].layerIndex,
            orderID: unifiedObjects[index].orderID
        )
        objectWillChange.send()
    }

    /// FAST O(1) update - change ONLY the font weight
    func updateTextFontWeightDirect(id: UUID, fontWeight: FontWeight) {
        saveToUndoStack()

        guard let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }),
        case .shape(var shape) = unifiedObjects[index].objectType else { return }

        shape.typography?.fontWeight = fontWeight
        unifiedObjects[index] = VectorObject(
            shape: shape,
            layerIndex: unifiedObjects[index].layerIndex,
            orderID: unifiedObjects[index].orderID
        )
        objectWillChange.send()
    }

    /// FAST O(1) update - change ONLY the font style
    func updateTextFontStyleDirect(id: UUID, fontStyle: FontStyle) {
        saveToUndoStack()

        guard let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }),
        case .shape(var shape) = unifiedObjects[index].objectType else { return }

        shape.typography?.fontStyle = fontStyle
        unifiedObjects[index] = VectorObject(
            shape: shape,
            layerIndex: unifiedObjects[index].layerIndex,
            orderID: unifiedObjects[index].orderID
        )
        objectWillChange.send()
    }

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
        guard let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }),
        case .shape(var shape) = unifiedObjects[objectIndex].objectType else { return }

        if shape.typography != nil {
            shape.typography?.fillColor = color
            shape.typography?.fillOpacity = defaultFillOpacity
        } else if let textObject = findText(by: id) {
            shape.typography = textObject.typography
            shape.typography?.fillColor = color
            shape.typography?.fillOpacity = defaultFillOpacity
        }

        unifiedObjects[objectIndex] = VectorObject(
            shape: shape,
            layerIndex: unifiedObjects[objectIndex].layerIndex,
            orderID: unifiedObjects[objectIndex].orderID
        )
    }
    
    /// MIGRATED FROM ColorPanel - Update text stroke color using unified system
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE
    /// CRITICAL FIX: Update text typography in unified objects and layers to keep them in sync
    /// This prevents typography from being reset when color changes
    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {
        guard let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }),
        case .shape(var shape) = unifiedObjects[objectIndex].objectType else { return }

        shape.typography = typography
        unifiedObjects[objectIndex] = VectorObject(
            shape: shape,
            layerIndex: unifiedObjects[objectIndex].layerIndex,
            orderID: unifiedObjects[objectIndex].orderID
        )
    }

    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        guard let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }),
        case .shape(var shape) = unifiedObjects[objectIndex].objectType else { return }

        if shape.typography != nil {
            shape.typography?.hasStroke = true
            shape.typography?.strokeColor = color
        } else if let textObject = findText(by: id) {
            shape.typography = textObject.typography
            shape.typography?.hasStroke = true
            shape.typography?.strokeColor = color
        }

        unifiedObjects[objectIndex] = VectorObject(
            shape: shape,
            layerIndex: unifiedObjects[objectIndex].layerIndex,
            orderID: unifiedObjects[objectIndex].orderID
        )
    }
}
