//
//  VectorDocument+UnifiedTextHelpers.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import SwiftUI

// MARK: - UNIFIED TEXT LOCK/UNLOCK AND VISIBILITY HELPERS
extension VectorDocument {
    
    // MARK: - UNIFIED LOCK/UNLOCK HELPERS
    
    func lockTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isLocked = true
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync the updated shape back to layers through unified system
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }
    
    func unlockTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isLocked = false
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync the updated shape back to layers through unified system
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }
    
    // MARK: - UNIFIED VISIBILITY HELPERS
    
    func hideTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isVisible = false
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync the updated shape back to layers through unified system
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }
    
    func showTextInUnified(id: UUID) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.isVisible = true
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync the updated shape back to layers through unified system
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
            }
        }
    }
    
    // MARK: - UNIFIED OPACITY AND STROKE HELPERS
    
    func updateTextFillOpacityInUnified(id: UUID, opacity: Double) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.typography?.fillOpacity = opacity
        }
    }
    
    func updateTextStrokeWidthInUnified(id: UUID, width: Double) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            shape.typography?.strokeWidth = width
            shape.typography?.hasStroke = width > 0
        }
    }
    
    // MARK: - UNIFIED POSITION HELPERS
    
    func translateTextInUnified(id: UUID, delta: CGPoint) {
        // CRITICAL FIX: Use updateShapeByID to support grouped children
        updateShapeByID(id) { shape in
            // Update position in transform
            shape.transform.tx += delta.x
            shape.transform.ty += delta.y

            // Also update textPosition if it exists
            if let textPos = shape.textPosition {
                shape.textPosition = CGPoint(x: textPos.x + delta.x, y: textPos.y + delta.y)
            }
        }
    }
    
    func translateAllTextInUnified(delta: CGPoint) {
        // Get all text IDs from unified system
        let textIDs = unifiedObjects.compactMap { obj -> UUID? in
            if case .shape(let shape) = obj.objectType, shape.isTextObject {
                return shape.id
            }
            return nil
        }
        
        // Use unified helper for each text
        for textID in textIDs {
            translateTextInUnified(id: textID, delta: delta)
        }
    }
    
    // MARK: - UNIFIED EDITING STATE HELPERS
    
    func setTextEditingInUnified(id: UUID, isEditing: Bool) {
        // Update in unified objects
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // Update the isEditing state in the shape
                shape.isEditing = isEditing
                
                // Update unified objects
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Sync to layers
                syncShapeToLayer(shape, at: unifiedObjects[objectIndex].layerIndex)
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
            // Get the existing object and shape
            let existingObject = unifiedObjects[objectIndex]
            if case .shape(let shape) = existingObject.objectType {
                // Shape will be moved through unified objects
                // No need to manually remove from layers array
                
                // Update the unified object with new layerIndex
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex,
                    orderID: existingObject.orderID
                )
                
                // Sync the shape to the new layer
                syncShapeToLayer(shape, at: layerIndex)
            }
        }
    }
}
