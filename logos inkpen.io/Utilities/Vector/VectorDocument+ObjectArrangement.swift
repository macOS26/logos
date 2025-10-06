//
//  VectorDocument+ObjectArrangement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Object Arrangement
extension VectorDocument {
    
    // MARK: - Helper Methods
    
    /// Expands selection to include complete clipping mask units (mask + all clipped shapes)
    private func expandSelectionForClippingMasks(_ selectedIDs: Set<UUID>, in layerObjects: [VectorObject]) -> Set<UUID> {
        var expandedSelectedIDs = selectedIDs

        for selectedID in selectedIDs {
            // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
            if let selectedObject = findObject(by: selectedID),
               case .shape(let selectedShape) = selectedObject.objectType {
                
                // If selected object is a mask, include all its clipped shapes
                if selectedShape.isClippingPath {
                    for obj in layerObjects {
                        if case .shape(let shape) = obj.objectType,
                           shape.clippedByShapeID == selectedShape.id {
                            expandedSelectedIDs.insert(obj.id)
                        }
                    }
                }
                // If selected object is clipped, include its mask
                else if let maskID = selectedShape.clippedByShapeID {
                    // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
                    if let maskObject = findObject(by: maskID) {
                        expandedSelectedIDs.insert(maskObject.id)
                        // Also include all other shapes clipped by the same mask
                        for obj in layerObjects {
                            if case .shape(let shape) = obj.objectType,
                               shape.clippedByShapeID == maskID {
                                expandedSelectedIDs.insert(obj.id)
                            }
                        }
                    }
                }
            }
        }
        
        return expandedSelectedIDs
    }
    
    // MARK: - Object Arrangement Methods
    
    /// Bring selected objects to front (unified system)
    func bringSelectedToFront() {
        guard !selectedObjectIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // CRITICAL FIX: Work directly with unified objects and orderID values
        // Group objects by layer and reorder within each layer
        for layerIndex in layers.indices {
            // Get all objects for this layer from unified array
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }
            
            // CLIPPING MASK FIX: Expand selection to include complete clipping mask units
            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)
            
            // Separate selected and unselected objects using expanded selection
            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            let unselectedObjects = layerObjects.filter { !expandedSelectedIDs.contains($0.id) }
            
            guard !selectedObjects.isEmpty else { continue }
            
            // Get current orderID range for this layer
            let currentOrderIDs = layerObjects.map { $0.orderID }
            let minOrderID = currentOrderIDs.min() ?? 0
            
            // Assign new orderIDs: unselected objects get lower orderIDs (back), selected get higher (front)
            var newOrderID = minOrderID
            
            // First assign orderIDs to unselected objects (they stay in back)
            for unselectedObject in unselectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == unselectedObject.id }) {
                    switch unselectedObject.objectType {
                    case .shape(let shape):
                        unifiedObjects[index] = VectorObject(
                            shape: shape,
                            layerIndex: unselectedObject.layerIndex,
                            orderID: newOrderID
                        )
                    }
                    newOrderID += 1
                }
            }
            
            // Then assign orderIDs to selected objects (they go to the front)
            for selectedObject in selectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }) {
                    switch selectedObject.objectType {
                    case .shape(let shape):
                        unifiedObjects[index] = VectorObject(
                            shape: shape,
                            layerIndex: selectedObject.layerIndex,
                            orderID: newOrderID
                        )
                    }
                    newOrderID += 1
                }
            }
        }
        
        // CRITICAL FIX: No more rebuilding arrays - just work with unifiedObjects directly
        // syncLegacyArraysFromUnified() - REMOVED to prevent object corruption
        
    }
    
    /// Bring selected objects forward (unified system)
    func bringSelectedForward() {
        guard !selectedObjectIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // CRITICAL FIX: Work directly with unified objects and orderID values like sendSelectedToBack
        // Group objects by layer and reorder within each layer
        for layerIndex in layers.indices {
            // Get all objects for this layer from unified array
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }
            
            // CLIPPING MASK FIX: Expand selection to include complete clipping mask units
            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)
            
            // Separate selected and unselected objects using expanded selection
            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            
            guard !selectedObjects.isEmpty else { continue }
            
            // Sort objects by orderID to get current stacking order (back to front)
            let sortedLayerObjects = layerObjects.sorted { $0.orderID < $1.orderID }
            
            // For each selected object, try to move it one step forward
            for selectedObject in selectedObjects {
                // Find the object that's currently in front of this selected object
                if let currentIndex = sortedLayerObjects.firstIndex(where: { $0.id == selectedObject.id }),
                   currentIndex < sortedLayerObjects.count - 1 {
                    // Get the object that's currently in front of this one
                    let objectInFront = sortedLayerObjects[currentIndex + 1]
                    
                    // Swap their orderIDs
                    if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }),
                       let frontIndex = unifiedObjects.firstIndex(where: { $0.id == objectInFront.id }) {
                        
                        // Get the current orderIDs
                        let selectedOrderID = unifiedObjects[selectedIndex].orderID
                        let frontOrderID = unifiedObjects[frontIndex].orderID
                        
                        // Swap the orderIDs
                        switch selectedObject.objectType {
                        case .shape(let shape):
                            unifiedObjects[selectedIndex] = VectorObject(
                                shape: shape,
                                layerIndex: selectedObject.layerIndex,
                                orderID: frontOrderID
                            )
                                                }
                        
                        switch objectInFront.objectType {
                        case .shape(let shape):
                            unifiedObjects[frontIndex] = VectorObject(
                                shape: shape,
                                layerIndex: objectInFront.layerIndex,
                                orderID: selectedOrderID
                            )
                                                    unifiedObjects[frontIndex] = VectorObject(
                                shape: shape,
                                layerIndex: objectInFront.layerIndex,
                                orderID: selectedOrderID
                            )
                        }
                    }
                }
            }
        }
        
    }
    
    /// Send selected objects backward (unified system)
    func sendSelectedBackward() {
        guard !selectedObjectIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // CRITICAL FIX: Work directly with unified objects and orderID values like sendSelectedToBack
        // Group objects by layer and reorder within each layer
        for layerIndex in layers.indices {
            // Get all objects for this layer from unified array
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }
            
            // CLIPPING MASK FIX: Expand selection to include complete clipping mask units
            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)
            
            // Separate selected and unselected objects using expanded selection
            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            
            guard !selectedObjects.isEmpty else { continue }
            
            // Sort objects by orderID to get current stacking order (back to front)
            let sortedLayerObjects = layerObjects.sorted { $0.orderID < $1.orderID }
            
            // For each selected object, try to move it one step backward
            for selectedObject in selectedObjects {
                // Find the object that's currently behind this selected object
                if let currentIndex = sortedLayerObjects.firstIndex(where: { $0.id == selectedObject.id }),
                   currentIndex > 0 {
                    // Get the object that's currently behind this one
                    let objectBehind = sortedLayerObjects[currentIndex - 1]
                    
                    // Swap their orderIDs
                    if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }),
                       let behindIndex = unifiedObjects.firstIndex(where: { $0.id == objectBehind.id }) {
                        
                        // Get the current orderIDs
                        let selectedOrderID = unifiedObjects[selectedIndex].orderID
                        let behindOrderID = unifiedObjects[behindIndex].orderID
                        
                        // Swap the orderIDs
                        switch selectedObject.objectType {
                        case .shape(let shape):
                            unifiedObjects[selectedIndex] = VectorObject(
                                shape: shape,
                                layerIndex: selectedObject.layerIndex,
                                orderID: behindOrderID
                            )
                                                    unifiedObjects[selectedIndex] = VectorObject(
                                shape: shape,
                                layerIndex: selectedObject.layerIndex,
                                orderID: behindOrderID
                            )
                        }
                        
                        switch objectBehind.objectType {
                        case .shape(let shape):
                            unifiedObjects[behindIndex] = VectorObject(
                                shape: shape,
                                layerIndex: objectBehind.layerIndex,
                                orderID: selectedOrderID
                            )
                                                    unifiedObjects[behindIndex] = VectorObject(
                                shape: shape,
                                layerIndex: objectBehind.layerIndex,
                                orderID: selectedOrderID
                            )
                        }
                    }
                }
            }
        }
        
    }
    
    /// Send selected objects to back (unified system)
    func sendSelectedToBack() {
        guard !selectedObjectIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // CRITICAL FIX: Work directly with unified objects and orderID values
        // Group objects by layer and reorder within each layer
        for layerIndex in layers.indices {
            // Get all objects for this layer from unified array
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }
            
            // CLIPPING MASK FIX: Expand selection to include complete clipping mask units
            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)
            
            // Separate selected and unselected objects using expanded selection
            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            let unselectedObjects = layerObjects.filter { !expandedSelectedIDs.contains($0.id) }
            
            guard !selectedObjects.isEmpty else { continue }
            
            // Get current orderID range for this layer
            let currentOrderIDs = layerObjects.map { $0.orderID }
            let minOrderID = currentOrderIDs.min() ?? 0
            
            // Assign new orderIDs: selected objects get lower orderIDs (back), unselected get higher (front)
            var newOrderID = minOrderID
            
            // First assign orderIDs to selected objects (they go to the back)
            for selectedObject in selectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }) {
                    switch selectedObject.objectType {
                    case .shape(let shape):
                        unifiedObjects[index] = VectorObject(
                            shape: shape,
                            layerIndex: selectedObject.layerIndex,
                            orderID: newOrderID
                        )
                    }
                    newOrderID += 1
                }
            }
            
            // Then assign orderIDs to unselected objects (they stay in front)
            for unselectedObject in unselectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == unselectedObject.id }) {
                    switch unselectedObject.objectType {
                    case .shape(let shape):
                        unifiedObjects[index] = VectorObject(
                            shape: shape,
                            layerIndex: unselectedObject.layerIndex,
                            orderID: newOrderID
                        )
                    }
                    newOrderID += 1
                }
            }
        }
        
        // CRITICAL FIX: No more rebuilding arrays - just work with unifiedObjects directly
        // syncLegacyArraysFromUnified() - REMOVED to prevent object corruption
        
    }
}
