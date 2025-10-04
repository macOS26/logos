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
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[index].objectType {
                // ALWAYS UPDATE - USER WANTS IT
                shape.typography?.fontFamily = fontFamily

                // Create new object to trigger KVO
                let newObj = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[index].layerIndex,
                    orderID: unifiedObjects[index].orderID
                )

                // CRITICAL: Must replace the object to trigger didSet
                unifiedObjects[index] = newObj

                // FORCE UPDATE BY TRIGGERING WILL CHANGE
                objectWillChange.send()

                // Log the change
            }
        }
    }

    /// FAST O(1) update - change ONLY the font weight
    func updateTextFontWeightDirect(id: UUID, fontWeight: FontWeight) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[index].objectType {
                // ALWAYS UPDATE - USER WANTS IT
                shape.typography?.fontWeight = fontWeight

                // Create new object to trigger KVO
                let newObj = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[index].layerIndex,
                    orderID: unifiedObjects[index].orderID
                )

                // CRITICAL: Must replace the object to trigger didSet
                unifiedObjects[index] = newObj

                // FORCE UPDATE BY TRIGGERING WILL CHANGE
                objectWillChange.send()

                // Log the change
            }
        }
    }

    /// FAST O(1) update - change ONLY the font style
    func updateTextFontStyleDirect(id: UUID, fontStyle: FontStyle) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[index].objectType {
                // ALWAYS UPDATE - USER WANTS IT
                shape.typography?.fontStyle = fontStyle

                // Create new object to trigger KVO
                let newObj = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[index].layerIndex,
                    orderID: unifiedObjects[index].orderID
                )

                // CRITICAL: Must replace the object to trigger didSet
                unifiedObjects[index] = newObj

                // FORCE UPDATE BY TRIGGERING WILL CHANGE
                objectWillChange.send()

                // Log the change
            }
        }
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

            // Trigger lightweight update notification for text views only
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

        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {

            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // CRITICAL: Only update color, preserve ALL other typography properties
                if shape.typography != nil {
                    shape.typography?.fillColor = color
                    shape.typography?.fillOpacity = defaultFillOpacity
                } else {
                    // If typography is nil, we need to get it from the text object
                    if let textObject = findText(by: id) {
                        shape.typography = textObject.typography
                        shape.typography?.fillColor = color
                        shape.typography?.fillOpacity = defaultFillOpacity
                    } else {
                    }
                }


                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // REMOVED: syncShapeToLayer call - it's a no-op and wastes cycles
                
                // Text is now fully managed in unified system
            } else {
            }
        } else {
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
    }
    
    /// MIGRATED FROM ColorPanel - Update text stroke color using unified system
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE  
    /// CRITICAL FIX: Update text typography in unified objects and layers to keep them in sync
    /// This prevents typography from being reset when color changes
    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {

        // Update in unified objects array
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // REMOVED: Skip check - always update when user selects something
                // The user is explicitly requesting an update, so do it!


                // Update the typography
                shape.typography = typography


                // Update unified objects - must recreate due to value semantics
                // TODO: Consider making VectorShape a class for better performance
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                
                // Text is now fully managed in unified system

                // REMOVED: objectWillChange.send() - unifiedObjects is @Published and will auto-trigger updates
                // REMOVED: Array reassignment - We already replaced the entire VectorObject above which triggers updates
            }
        } else {
        }
        
    }
    
    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {

        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {

            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // CRITICAL: Only update stroke color, preserve ALL other typography properties
                if shape.typography != nil {
                    shape.typography?.hasStroke = true
                    shape.typography?.strokeColor = color
                } else {
                    // If typography is nil, we need to get it from the text object
                    if let textObject = findText(by: id) {
                        shape.typography = textObject.typography
                        shape.typography?.hasStroke = true
                        shape.typography?.strokeColor = color
                    } else {
                    }
                }
                
                
                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // REMOVED: syncShapeToLayer call - it's a no-op and wastes cycles
                
                // Text is now fully managed in unified system
            } else {
            }
        } else {
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
    }
}
