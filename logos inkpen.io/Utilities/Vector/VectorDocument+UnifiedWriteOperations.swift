//
//  VectorDocument+UnifiedWriteOperations.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import SwiftUI
import Combine

// MARK: - COMPREHENSIVE UNIFIED WRITE OPERATIONS
extension VectorDocument {
    // These methods ensure ALL operations go through unified system
    
    /// Append a shape to a layer through unified system
    func appendShapeToLayerUnified(layerIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Add directly to unified system
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        objectWillChange.send()
    }
    
    /// Remove a shape by ID through unified system
    func removeShapeByIdUnified(shapeID: UUID) {
        // Remove from unified objects
        removeShapeFromUnifiedSystem(id: shapeID)
        objectWillChange.send()
    }
    
    /// Remove all shapes matching a condition through unified system
    func removeShapesUnified(layerIndex: Int, where condition: (VectorShape) -> Bool) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Find shapes to remove in unified objects
        let shapesToRemove = unifiedObjects.compactMap { obj -> UUID? in
            if obj.layerIndex == layerIndex,
               case .shape(let shape) = obj.objectType,
               !shape.isTextObject,
               condition(shape) {
                return shape.id
            }
            return nil
        }
        
        // Remove each shape
        for shapeID in shapesToRemove {
            removeShapeFromUnifiedSystem(id: shapeID)
        }
        
        objectWillChange.send()
    }
    
    /// Insert a shape at a specific index through unified system
    func insertShapeUnified(layerIndex: Int, shape: VectorShape, at index: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // For now, just add to unified system (ordering handled by orderID)
        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        objectWillChange.send()
    }
    
    /// Append multiple shapes to a layer through unified system
    func appendShapesUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Add each shape to unified system
        for shape in shapes {
            addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        }
        
        objectWillChange.send()
    }
    
    /// Remove a shape at a specific index through unified system
    func removeShapeAtIndexUnified(layerIndex: Int, shapeIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Get shapes for this layer
        let shapesInLayer = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapesInLayer.count else { return }
        
        // Remove the shape at the specified index
        let shapeToRemove = shapesInLayer[shapeIndex]
        removeShapeFromUnifiedSystem(id: shapeToRemove.id)
        
        objectWillChange.send()
    }
    
    /// Set all shapes for a layer through unified system
    func setShapesForLayerUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Remove all existing shapes for this layer
        let existingShapes = getShapesForLayer(layerIndex)
        for shape in existingShapes {
            removeShapeFromUnifiedSystem(id: shape.id)
        }
        
        // Add new shapes
        for shape in shapes {
            addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
        }
        
        objectWillChange.send()
    }
}
