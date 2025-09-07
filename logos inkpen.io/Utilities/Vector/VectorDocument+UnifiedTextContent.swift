//
//  VectorDocument+UnifiedTextContent.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - Unified Text Content Management
extension VectorDocument {
    
    func updateTextContentInUnified(id: UUID, content: String) {
        // Update directly in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.textContent = content
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateTextCursorPositionInUnified(id: UUID, cursorPosition: Int?) {
        // Update directly in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.cursorPosition = cursorPosition
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateTextPositionInUnified(id: UUID, position: CGPoint) {
        // Update directly in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.transform = CGAffineTransform(translationX: position.x, y: position.y)
                shape.textPosition = position
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateTextBoundsInUnified(id: UUID, bounds: CGRect) {
        // Update directly in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.bounds = bounds
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    func updateTextAreaSizeInUnified(id: UUID, areaSize: CGSize?) {
        // Update directly in unified objects
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            var updatedObject = unifiedObjects[index]
            if case .shape(var shape) = updatedObject.objectType {
                shape.areaSize = areaSize
                updatedObject = VectorObject(shape: shape, layerIndex: updatedObject.layerIndex, orderID: updatedObject.orderID)
                unifiedObjects[index] = updatedObject
                objectWillChange.send()
            }
        }
    }
    
    // These layer-based functions are deprecated
    func updateShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        // No longer using layer indices - operations should go through unified system
        Log.warning("updateShapeAtIndex is deprecated - use unified system", category: .general)
    }
    
    func removeShapeAtIndex(layerIndex: Int, shapeIndex: Int) {
        // No longer using layer indices - operations should go through unified system  
        Log.warning("removeShapeAtIndex is deprecated - use unified system", category: .general)
    }
}