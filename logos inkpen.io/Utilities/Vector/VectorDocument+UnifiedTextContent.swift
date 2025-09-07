//
//  VectorDocument+UnifiedTextContent.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - UNIFIED CONTENT HELPERS
extension VectorDocument {
    
    func updateTextContentInUnified(id: UUID, content: String) {
        // MIGRATION: Update text directly in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Update in unified objects
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.textContent = content
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].textContent = content
                        break
                    }
                }
            }
        }
    }
    
    func updateTextCursorPositionInUnified(id: UUID, cursorPosition: Int) {
        // Update cursor position in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Update in unified objects
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.cursorPosition = cursorPosition
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].cursorPosition = cursorPosition
                        break
                    }
                }
            }
        }
    }
    
    func updateTextPositionInUnified(id: UUID, position: CGPoint) {
        // MIGRATION: Update position directly in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            // Update in unified objects
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.transform = CGAffineTransform(translationX: position.x, y: position.y)
                shape.textPosition = position  // Update textPosition for proper reconstruction
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].transform = CGAffineTransform(translationX: position.x, y: position.y)
                        layers[layerIdx].shapes[shapeIdx].textPosition = position
                        break
                    }
                }
            }
        }
    }
    
    func updateTextBoundsInUnified(id: UUID, bounds: CGRect) {
        // Update bounds in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.bounds = bounds
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].bounds = bounds
                        break
                    }
                }
            }
        }
    }
    
    func updateTextAreaSizeInUnified(id: UUID, areaSize: CGSize) {
        // Update area size in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject && shape.id == id
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[unifiedIndex].objectType {
                shape.areaSize = areaSize
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: shape,
                    layerIndex: unifiedObjects[unifiedIndex].layerIndex,
                    orderID: unifiedObjects[unifiedIndex].orderID
                )
                
                // Update in layers
                for layerIdx in layers.indices {
                    if let shapeIdx = layers[layerIdx].shapes.firstIndex(where: { $0.id == id && $0.isTextObject }) {
                        layers[layerIdx].shapes[shapeIdx].areaSize = areaSize
                        break
                    }
                }
            }
        }
    }
    
    // MARK: - LAYER SHAPE ACCESS HELPERS (MIGRATION)
    
    /// Safe getter for shape at index in layer - returns from unified system
    func getShapeAtIndex(layerIndex: Int, shapeIndex: Int) -> VectorShape? {
        guard layerIndex >= 0 && layerIndex < layers.count else { return nil }
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return nil }
        return shapes[shapeIndex]
    }
    
    /// Safe setter for shape at index in layer - updates both legacy and unified
    func setShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        guard shapeIndex >= 0 && shapeIndex < layers[layerIndex].shapes.count else { return }
        
        // Update in layers array
        layers[layerIndex].shapes[shapeIndex] = shape
        
        // Update in unified system
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == layers[layerIndex].shapes[shapeIndex].id
            }
            return false
        }) {
            unifiedObjects[unifiedIndex] = VectorObject(
                shape: shape,
                layerIndex: layerIndex,
                orderID: unifiedObjects[unifiedIndex].orderID
            )
        }
    }
    
    /// Append shape to layer - adds to both legacy and unified
    func appendShapeToLayer(layerIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }
    
    /// Remove shape at index from layer - removes from both legacy and unified
    func removeShapeAtIndex(layerIndex: Int, shapeIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        guard shapeIndex >= 0 && shapeIndex < layers[layerIndex].shapes.count else { return }
        
        let shapeId = layers[layerIndex].shapes[shapeIndex].id
        layers[layerIndex].shapes.remove(at: shapeIndex)
        
        // Remove from unified
        unifiedObjects.removeAll { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == shapeId
            }
            return false
        }
    }
    
    /// Get shape count for layer from unified system
    func getShapeCount(layerIndex: Int) -> Int {
        guard layerIndex >= 0 && layerIndex < layers.count else { return 0 }
        return getShapesForLayer(layerIndex).count
    }
}