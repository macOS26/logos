//
//  VectorDocument+UnifiedWriteOperations.swift
//  logos inkpen.io
//
//  Split from VectorDocument+UnifiedObjectManagement.swift
//

import Foundation
import CoreGraphics

// MARK: - COMPREHENSIVE UNIFIED WRITE OPERATIONS
extension VectorDocument {
    // These methods ensure ALL operations go through unified system - NO direct layer access
    
    /// Append a shape to a layer through unified system
    func appendShapeToLayerUnified(layerIndex: Int, shape: VectorShape) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Add to legacy layer (temporary until full migration)
        layers[layerIndex].shapes.append(shape)
        
        // Update unified system immediately
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Remove a shape by ID through unified system
    func removeShapeByIdUnified(shapeID: UUID) {
        // Find and remove from legacy layers
        for layerIndex in layers.indices {
            if let index = layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                layers[layerIndex].shapes.remove(at: index)
                break
            }
        }
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Remove all shapes matching a condition through unified system
    func removeShapesUnified(layerIndex: Int, where condition: (VectorShape) -> Bool) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Remove from legacy layer
        layers[layerIndex].shapes.removeAll(where: condition)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Insert a shape at specific index through unified system
    func insertShapeUnified(layerIndex: Int, shape: VectorShape, at index: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Insert into legacy layer
        let safeIndex = min(index, layers[layerIndex].shapes.count)
        layers[layerIndex].shapes.insert(shape, at: safeIndex)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Append multiple shapes through unified system
    func appendShapesUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Append to legacy layer
        layers[layerIndex].shapes.append(contentsOf: shapes)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Remove shape at specific index through unified system
    func removeShapeAtIndexUnified(layerIndex: Int, shapeIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count,
              shapeIndex >= 0 && shapeIndex < layers[layerIndex].shapes.count else { return }
        
        // Remove from legacy layer
        layers[layerIndex].shapes.remove(at: shapeIndex)
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
    
    /// Replace all shapes in a layer through unified system
    func setShapesForLayerUnified(layerIndex: Int, shapes: [VectorShape]) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        
        // Replace in legacy layer
        layers[layerIndex].shapes = shapes
        
        // Update unified system
        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
}