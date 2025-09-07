//
//  VectorDocument+UnifiedTextColor.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - UNIFIED TEXT COLOR HELPERS (MIGRATED FROM COLORSWATCHGRID)
extension VectorDocument {
    
    /// MIGRATED FROM ColorSwatchGrid - Update text fill color using unified system 
    /// NO MORE DUPLICATES - USE THIS ONE HELPER EVERYWHERE
    func updateTextFillColorInUnified(id: UUID, color: VectorColor) {
        Log.fileOperation("🔍 updateTextFillColorInUnified START - id: \(id), color: \(color)", level: .info)
        
        // LOG INITIAL STATE
        if let textObject = findText(by: id) {
            Log.fileOperation("📝 BEFORE COLOR CHANGE - Text Typography:", level: .info)
            Log.fileOperation("  - Font: \(textObject.typography.fontFamily)", level: .info)
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
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
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
                        Log.fileOperation("✅ Restored typography with font: \(textObject.typography.fontFamily)", level: .info)
                    } else {
                        Log.fileOperation("❌ COULD NOT RESTORE TYPOGRAPHY - NO TEXT OBJECT!", level: .error)
                    }
                }
                
                Log.fileOperation("📊 AFTER COLOR UPDATE - Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
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
                
                // Sync the updated shape back to layers through unified system
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
                Log.fileOperation("✅ Synced text color update to layer \(unifiedObjects[objectIndex].layerIndex)", level: .info)
                
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
        Log.fileOperation("  - New Font: \(typography.fontFamily) \(typography.fontSize)pt", level: .info)
        
        // Update in unified objects array
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                Log.fileOperation("📊 BEFORE - Unified Shape Typography:", level: .info)
                Log.fileOperation("  - Old Font: \(shape.typography?.fontFamily ?? "nil") \(shape.typography?.fontSize ?? 0)pt", level: .info)
                
                // Update the typography
                shape.typography = typography
                
                Log.fileOperation("📊 AFTER - Unified Shape Typography:", level: .info)
                Log.fileOperation("  - New Font: \(shape.typography?.fontFamily ?? "nil") \(shape.typography?.fontSize ?? 0)pt", level: .info)
                
                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync the updated shape back to layers through unified system
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
                Log.fileOperation("✅ Synced typography update to layer \(unifiedObjects[objectIndex].layerIndex)", level: .info)
                
                // Text is now fully managed in unified system
            }
        } else {
            Log.fileOperation("⚠️ Could not find text in unified objects with id: \(id)", level: .warning)
        }
        
        // No need for explicit objectWillChange.send() - @Published properties handle this
        
        Log.fileOperation("🔍 updateTextTypographyInUnified END", level: .info)
    }
    
    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        Log.fileOperation("🔍 updateTextStrokeColorInUnified START - id: \(id), color: \(color)", level: .info)
        
        // LOG INITIAL STATE
        if let textObject = findText(by: id) {
            Log.fileOperation("📝 BEFORE STROKE COLOR CHANGE - Text Typography:", level: .info)
            Log.fileOperation("  - Font: \(textObject.typography.fontFamily)", level: .info)
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
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
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
                        Log.fileOperation("✅ Restored typography with font: \(textObject.typography.fontFamily)", level: .info)
                    } else {
                        Log.fileOperation("❌ COULD NOT RESTORE TYPOGRAPHY - NO TEXT OBJECT!", level: .error)
                    }
                }
                
                Log.fileOperation("📊 AFTER STROKE COLOR UPDATE - Shape Typography:", level: .info)
                if let typo = shape.typography {
                    Log.fileOperation("  - Font: \(typo.fontFamily)", level: .info)
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
                
                // Sync the updated shape back to layers through unified system
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
                Log.fileOperation("✅ Synced stroke color update to layer \(unifiedObjects[objectIndex].layerIndex)", level: .info)
                
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