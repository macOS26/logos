//
//  VectorDocument+UnifiedTextProperties.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics

// MARK: - Unified Text Properties
extension VectorDocument {
    // MARK: - UNIFIED EDITING STATE HELPERS
    
    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Note: isEditing is stored in textObjects only, not in unified shapes
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].isEditing = isEditing
            }
        }
    }
    
    func updateTextLayerInUnified(id: UUID, layerIndex: Int) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Recreate VectorObject with new layerIndex (layerIndex is let constant)
            let existingObject = unifiedObjects[objectIndex]
            if case .shape(let shape) = existingObject.objectType {
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex,
                    orderID: existingObject.orderID
                )
            }
            
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].layerIndex = layerIndex
            }
        }
    }
    
    // MARK: - UNIFIED CONTENT HELPERS
    
    func updateTextContentInUnified(id: UUID, content: String) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].content = content
                updateUnifiedObjectsOptimized()
            }
        }
    }
    
    func updateTextCursorPositionInUnified(id: UUID, cursorPosition: Int) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].cursorPosition = cursorPosition
            }
        }
    }
    
    func updateTextPositionInUnified(id: UUID, position: CGPoint) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].position = position
            }
        }
    }
    
    func updateTextBoundsInUnified(id: UUID, bounds: CGRect) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].bounds = bounds
            }
        }
    }
    
    func updateTextAreaSizeInUnified(id: UUID, areaSize: CGSize) {
        // Check if text exists in unified system
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Sync to legacy array
            if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                textObjects[legacyIndex].areaSize = areaSize
            }
        }
    }
    
    // MARK: - UNIFIED FONT PROPERTY HELPERS
    
    /// Update text font family using unified system
    func updateTextFontFamilyInUnified(id: UUID, fontFamily: String) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.fontFamily = fontFamily
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.fontFamily = fontFamily
                }
            }
        }
    }
    
    /// Update text font weight using unified system
    func updateTextFontWeightInUnified(id: UUID, fontWeight: FontWeight) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.fontWeight = fontWeight
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.fontWeight = fontWeight
                }
            }
        }
    }
    
    /// Update text font style using unified system
    func updateTextFontStyleInUnified(id: UUID, fontStyle: FontStyle) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.fontStyle = fontStyle
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.fontStyle = fontStyle
                }
            }
        }
    }
    
    /// Update text font size using unified system
    func updateTextFontSizeInUnified(id: UUID, fontSize: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.fontSize = fontSize
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.fontSize = fontSize
                }
            }
        }
    }
    
    /// Update text alignment using unified system
    func updateTextAlignmentInUnified(id: UUID, alignment: TextAlignment) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.alignment = alignment
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.alignment = alignment
                }
            }
        }
    }
    
    /// Update text line spacing using unified system
    func updateTextLineSpacingInUnified(id: UUID, lineSpacing: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.lineSpacing = lineSpacing
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.lineSpacing = lineSpacing
                }
            }
        }
    }
    
    /// Update text line height using unified system
    func updateTextLineHeightInUnified(id: UUID, lineHeight: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.lineHeight = lineHeight
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to legacy array
                if let legacyIndex = textObjects.firstIndex(where: { $0.id == id }) {
                    textObjects[legacyIndex].typography.lineHeight = lineHeight
                }
            }
        }
    }
    
    /// Get text object from unified system by ID
    func getTextFromUnified(id: UUID) -> VectorText? {
        // Check unified system first
        if unifiedObjects.contains(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Return from legacy array (which is the source of truth for editing)
            return textObjects.first { $0.id == id }
        }
        return nil
    }
    
    /// Check if text exists in unified system by ID
    func textExistsInUnified(id: UUID) -> Bool {
        return unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }
    }
}