//
//  VectorDocument+WarpObjects.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

// MARK: - Warp Objects
extension VectorDocument {
    
    // MARK: - Warp Object Methods
    
    /// Unwrap selected warp object back to its original shape
    func unwrapWarpObject() {
        guard !selectedObjectIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Get selected objects that are warp objects
        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }
        
        for unifiedObject in selectedWarpObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil,
               let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                
                if let unwrappedShape = shape.unwrapWarpObject() {
                    // Replace warp object with unwrapped shape
                    layers[layerIndex].shapes[shapeIndex] = unwrappedShape
                    
                    // Update the unified objects system to reflect the new unwrapped shape
                    if let unifiedIndex = unifiedObjects.firstIndex(where: { $0.id == shape.id }) {
                        unifiedObjects[unifiedIndex] = VectorObject(shape: unwrappedShape, layerIndex: layerIndex, orderID: unifiedObjects[unifiedIndex].orderID)
                    }
                    
                    // Update selection to the unwrapped shape
                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(unwrappedShape.id)
                    
                    Log.info("✅ UNWRAPPED WARP OBJECT: \(shape.name) → \(unwrappedShape.name)", category: .fileOperations)
                }
            }
        }
        
        // CRITICAL FIX: Sync unified objects after unwrapping to ensure UI updates
        syncUnifiedObjectsAfterPropertyChange()
        objectWillChange.send()
    }
    
    /// Expand selected warp object to permanently apply the warp transformation
    func expandWarpObject() {
        guard !selectedObjectIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Get selected objects that are warp objects
        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }
        
        for unifiedObject in selectedWarpObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil,
               let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                
                if let expandedShape = shape.expandWarpObject() {
                    // Replace warp object with expanded shape
                    layers[layerIndex].shapes[shapeIndex] = expandedShape
                    
                    // Update the unified objects system to reflect the new expanded shape
                    if let unifiedIndex = unifiedObjects.firstIndex(where: { $0.id == shape.id }) {
                        unifiedObjects[unifiedIndex] = VectorObject(shape: expandedShape, layerIndex: layerIndex, orderID: unifiedObjects[unifiedIndex].orderID)
                    }
                    
                    // Update selection to the expanded shape
                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(expandedShape.id)
                    
                    Log.info("✅ EXPANDED WARP OBJECT: \(shape.name) → \(expandedShape.name)", category: .fileOperations)
                }
            }
        }
        
        // CRITICAL FIX: Sync unified objects after expanding to ensure UI updates
        syncUnifiedObjectsAfterPropertyChange()
        objectWillChange.send()
    }
}
