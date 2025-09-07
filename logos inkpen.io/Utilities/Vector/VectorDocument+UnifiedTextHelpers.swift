//
//  VectorDocument+UnifiedTextHelpers.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = true
                }
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = false
                }
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = false
                }
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
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = true
                }
            }
        }
    }
    
    // MARK: - UNIFIED OPACITY AND STROKE HELPERS
    
    func updateTextFillOpacityInUnified(id: UUID, opacity: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.fillOpacity = opacity
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].typography?.fillOpacity = opacity
                }
            }
        }
    }
    
    func updateTextStrokeWidthInUnified(id: UUID, width: Double) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                shape.typography?.strokeWidth = width
                shape.typography?.hasStroke = width > 0
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // CRITICAL: Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].typography?.strokeWidth = width
                    layers[layerIndex].shapes[shapeIndex].typography?.hasStroke = width > 0
                }
            }
        }
    }
    
    // MARK: - UNIFIED POSITION HELPERS
    
    func translateTextInUnified(id: UUID, delta: CGPoint) {
        if let objectIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[objectIndex].objectType {
                // Update position in transform
                shape.transform.tx += delta.x
                shape.transform.ty += delta.y
                
                // Also update textPosition if it exists
                if let textPos = shape.textPosition {
                    shape.textPosition = CGPoint(x: textPos.x + delta.x, y: textPos.y + delta.y)
                }
                
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[objectIndex].layerIndex,
                    orderID: unifiedObjects[objectIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].transform.tx += delta.x
                        layers[layerIdx].shapes[shapeIdx].transform.ty += delta.y
                        if let textPos = layers[layerIdx].shapes[shapeIdx].textPosition {
                            layers[layerIdx].shapes[shapeIdx].textPosition = CGPoint(x: textPos.x + delta.x, y: textPos.y + delta.y)
                        }
                        break
                    }
                }
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
                
                // Update the shape in the layers array
                let layerIndex = unifiedObjects[objectIndex].layerIndex
                if layerIndex < layers.count,
                   let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                    layers[layerIndex].shapes[shapeIndex].isEditing = isEditing
                }
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
                // Find and remove the shape from its current layer
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes.remove(at: shapeIdx)
                        break
                    }
                }
                
                // Add the shape to the new layer
                if layerIndex < layers.count {
                    layers[layerIndex].shapes.append(shape)
                }
                
                // Update the unified object with new layerIndex
                unifiedObjects[objectIndex] = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex,
                    orderID: existingObject.orderID
                )
            }
        }
    }
}