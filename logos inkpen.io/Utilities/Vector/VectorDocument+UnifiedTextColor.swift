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
                let oldFont = shape.typography?.fontFamily ?? ""

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
                Log.fileOperation("🎯 TYPE DIRECT UPDATE: \(oldFont) → \(fontFamily) for ID: \(id.uuidString.prefix(8))", level: .info)
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
                let oldWeight = shape.typography?.fontWeight ?? .regular

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
                Log.fileOperation("🎯 WEIGHT DIRECT UPDATE: \(oldWeight.rawValue) → \(fontWeight.rawValue) for ID: \(id.uuidString.prefix(8))", level: .info)
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
                let oldStyle = shape.typography?.fontStyle ?? .normal

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
                Log.fileOperation("🎯 STYLE DIRECT UPDATE: \(oldStyle.rawValue) → \(fontStyle.rawValue) for ID: \(id.uuidString.prefix(8))", level: .info)
            }
        }
    }

    /// FAST O(1) preview update - change ONLY the font size for live preview
    /// Uses preview typography to avoid updating unified objects during drag
    func updateTextFontSizePreview(id: UUID, fontSize: CGFloat) {
        // Find the current text object
        if let unifiedObj = unifiedObjects.first(where: { $0.id == id }),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject,
           var textObject = VectorText.from(shape) {
            textObject.layerIndex = unifiedObj.layerIndex
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
        if let unifiedObj = unifiedObjects.first(where: { $0.id == id }),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject,
           var textObject = VectorText.from(shape) {
            textObject.layerIndex = unifiedObj.layerIndex
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
        if let unifiedObj = unifiedObjects.first(where: { $0.id == id }),
           case .shape(let shape) = unifiedObj.objectType,
           shape.isTextObject,
           var textObject = VectorText.from(shape) {
            textObject.layerIndex = unifiedObj.layerIndex
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
        Log.fileOperation("🔍 updateTextFillColorInUnified START - id: \(id), color: \(color)", level: .info)
        
        // LOG INITIAL STATE
        if let textObject = findText(by: id) {
            Log.fileOperation("📝 BEFORE COLOR CHANGE - Text Typography:", level: .info)
            Log.fileOperation("  - Type: \(textObject.typography.fontFamily)", level: .info)
            Log.fileOperation("  - Size: \(textObject.typography.fontSize)", level: .info)
            Log.fileOperation("  - Weight: \(String(describing: textObject.typography.fontWeight))", level: .info)
            Log.fileOperation("  - Style: \(String(describing: textObject.typography.fontStyle))", level: .info)
            Log.fileOperation("  - Alignment: \(textObject.typography.alignment)", level: .info)
            Log.fileOperation("  - Current Fill Color: \(textObject.typography.fillColor)", level: .info)
        } else {
            Log.fileOperation("⚠️ NO TEXT FOUND WITH ID: \(id)", level: .warning)
        }
        
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            Log.fileOperation("✅ Found object at unified index: \(objectIndex)", level: .info)
            
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                Log.fileOperation("📊 BEFORE - Unified Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Type: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                } else {
                    Log.fileOperation("  ⚠️ Typography is NIL in unified shape!", level: .warning)
                }
                
                // CRITICAL: Only update color, preserve ALL other typography properties
                if shape.typography != nil {
                    Log.fileOperation("📝 Updating existing typography - ONLY changing fillColor", level: .info)
                    shape.typography?.fillColor = color
                    shape.typography?.fillOpacity = defaultFillOpacity
                } else {
                    // If typography is nil, we need to get it from the text object
                    Log.fileOperation("⚠️ Typography was NIL - restoring from text object", level: .warning)
                    if let textObject = findText(by: id) {
                        shape.typography = textObject.typography
                        shape.typography?.fillColor = color
                        shape.typography?.fillOpacity = defaultFillOpacity
                        Log.fileOperation("✅ Restored typography with type: \(textObject.typography.fontFamily)", level: .info)
                    } else {
                        Log.fileOperation("❌ COULD NOT RESTORE TYPOGRAPHY - NO TEXT OBJECT!", level: .error)
                    }
                }
                
                Log.fileOperation("📊 AFTER COLOR UPDATE - Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Type: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                    Log.fileOperation("  - New Fill Color: \(typo.fillColor)", level: .info)
                }
                
                // Update unified objects
                Log.fileOperation("🔄 Creating new VectorObject to update unified array", level: .info)
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // REMOVED: syncShapeToLayer call - it's a no-op and wastes cycles
                Log.fileOperation("✅ Updated text color in unified objects for layer \(unifiedObjects[objectIndex].layerIndex)", level: .info)
                
                // Text is now fully managed in unified system
            } else {
                Log.fileOperation("❌ Failed to cast unified object to shape!", level: .error)
            }
        } else {
            Log.fileOperation("❌ Could not find object in unified array with id: \(id)", level: .error)
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
        Log.fileOperation("🔍 updateTextFillColorInUnified END", level: .info)
    }
    
    /// MIGRATED FROM ColorPanel - Update text stroke color using unified system
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE  
    /// CRITICAL FIX: Update text typography in unified objects and layers to keep them in sync
    /// This prevents typography from being reset when color changes
    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {
        Log.fileOperation("🔍 updateTextTypographyInUnified START - id: \(id)", level: .info)
        Log.fileOperation("  - New Type: \(typography.fontFamily) \(typography.fontSize)pt", level: .info)

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

                Log.fileOperation("📊 BEFORE - Unified Shape Typography:", level: .info)
                Log.fileOperation("  - Old Type: \(shape.typography?.fontFamily ?? "nil") \(shape.typography?.fontSize ?? 0)pt", level: .info)

                // Update the typography
                shape.typography = typography

                Log.fileOperation("📊 AFTER - Unified Shape Typography:", level: .info)
                Log.fileOperation("  - New Type: \(shape.typography?.fontFamily ?? "nil") \(shape.typography?.fontSize ?? 0)pt", level: .info)

                // Update unified objects - must recreate due to value semantics
                // TODO: Consider making VectorShape a class for better performance
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )

                Log.fileOperation("✅ Updated typography in unified objects for layer \(unifiedObjects[objectIndex].layerIndex)", level: .info)
                
                // Text is now fully managed in unified system

                // REMOVED: objectWillChange.send() - unifiedObjects is @Published and will auto-trigger updates
                // REMOVED: Array reassignment - We already replaced the entire VectorObject above which triggers updates
            }
        } else {
            Log.fileOperation("⚠️ Could not find text in unified objects with id: \(id)", level: .warning)
        }
        
        Log.fileOperation("🔍 updateTextTypographyInUnified END", level: .info)
    }
    
    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        Log.fileOperation("🔍 updateTextStrokeColorInUnified START - id: \(id), color: \(color)", level: .info)
        
        // LOG INITIAL STATE
        if let textObject = findText(by: id) {
            Log.fileOperation("📝 BEFORE STROKE COLOR CHANGE - Text Typography:", level: .info)
            Log.fileOperation("  - Type: \(textObject.typography.fontFamily)", level: .info)
            Log.fileOperation("  - Size: \(textObject.typography.fontSize)", level: .info)
            Log.fileOperation("  - Weight: \(String(describing: textObject.typography.fontWeight))", level: .info)
            Log.fileOperation("  - Style: \(String(describing: textObject.typography.fontStyle))", level: .info)
            Log.fileOperation("  - Alignment: \(textObject.typography.alignment)", level: .info)
            Log.fileOperation("  - Current Stroke Color: \(textObject.typography.strokeColor)", level: .info)
            Log.fileOperation("  - Has Stroke: \(textObject.typography.hasStroke)", level: .info)
        } else {
            Log.fileOperation("⚠️ NO TEXT FOUND WITH ID: \(id)", level: .warning)
        }
        
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            Log.fileOperation("✅ Found object at unified index: \(objectIndex)", level: .info)
            
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                Log.fileOperation("📊 BEFORE - Unified Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Type: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                    Log.fileOperation("  - Has Stroke: \(typo.hasStroke)", level: .info)
                } else {
                    Log.fileOperation("  ⚠️ Typography is NIL in unified shape!", level: .warning)
                }
                
                // CRITICAL: Only update stroke color, preserve ALL other typography properties
                if shape.typography != nil {
                    Log.fileOperation("📝 Updating existing typography - ONLY changing strokeColor", level: .info)
                    shape.typography?.hasStroke = true
                    shape.typography?.strokeColor = color
                } else {
                    // If typography is nil, we need to get it from the text object
                    Log.fileOperation("⚠️ Typography was NIL - restoring from text object", level: .warning)
                    if let textObject = findText(by: id) {
                        shape.typography = textObject.typography
                        shape.typography?.hasStroke = true
                        shape.typography?.strokeColor = color
                        Log.fileOperation("✅ Restored typography with type: \(textObject.typography.fontFamily)", level: .info)
                    } else {
                        Log.fileOperation("❌ COULD NOT RESTORE TYPOGRAPHY - NO TEXT OBJECT!", level: .error)
                    }
                }
                
                Log.fileOperation("📊 AFTER STROKE COLOR UPDATE - Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Type: \(typo.fontFamily)", level: .info)
                    Log.fileOperation("  - Size: \(typo.fontSize)", level: .info)
                    Log.fileOperation("  - Weight: \(String(describing: typo.fontWeight))", level: .info)
                    Log.fileOperation("  - Style: \(String(describing: typo.fontStyle))", level: .info)
                    Log.fileOperation("  - Alignment: \(typo.alignment)", level: .info)
                    Log.fileOperation("  - New Stroke Color: \(typo.strokeColor)", level: .info)
                    Log.fileOperation("  - Has Stroke: \(typo.hasStroke)", level: .info)
                }
                
                // Update unified objects
                Log.fileOperation("🔄 Creating new VectorObject to update unified array", level: .info)
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // REMOVED: syncShapeToLayer call - it's a no-op and wastes cycles
                Log.fileOperation("✅ Updated stroke color in unified objects for layer \(unifiedObjects[objectIndex].layerIndex)", level: .info)
                
                // Text is now fully managed in unified system
            } else {
                Log.fileOperation("❌ Failed to cast unified object to shape!", level: .error)
            }
        } else {
            Log.fileOperation("❌ Could not find object in unified array with id: \(id)", level: .error)
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
        Log.fileOperation("🔍 updateTextStrokeColorInUnified END", level: .info)
    }
}
