//
//  VectorDocument+LayerMovement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Layer Movement
extension VectorDocument {

    // MARK: - Drag and Drop Object Movement Between Layers

    /// Move a shape from one layer to another
    func moveShapeToLayer(shapeId: UUID, fromLayerIndex: Int, toLayerIndex: Int) {
        guard fromLayerIndex >= 0 && fromLayerIndex < layers.count,
              toLayerIndex >= 0 && toLayerIndex < layers.count,
              fromLayerIndex != toLayerIndex else {
            // Log.error("❌ Invalid layer indices for shape move: from=\(fromLayerIndex), to=\(toLayerIndex)", category: .error)
            return
        }
        
        // Don't allow moving to locked layers
        if layers[toLayerIndex].isLocked {
            return
        }
        
        // Don't allow moving from locked layers unless it's a selection operation
        if layers[fromLayerIndex].isLocked {
            return
        }
        
        // Find and remove the shape from source layer
        let shapes = getShapesForLayer(fromLayerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == shapeId }) else {
            // Log.error("❌ Shape not found in source layer \(fromLayerIndex)", category: .error)
            return
        }
        
        saveToUndoStack()
        
        // Get the shape before removing it
        guard let shape = getShapeAtIndex(layerIndex: fromLayerIndex, shapeIndex: shapeIndex) else {
            // Log.error("❌ Failed to get shape from source layer", category: .error)
            return
        }
        
        // Remove from source layer and add to destination layer
        removeShapeAtIndexUnified(layerIndex: fromLayerIndex, shapeIndex: shapeIndex)
        appendShapeToLayerUnified(layerIndex: toLayerIndex, shape: shape)
        
        // Update selection to follow the moved shape
        selectedShapeIDs = [shapeId]
        selectedLayerIndex = toLayerIndex
        
    }
    
    /// Move a text object to a specific layer (conceptually)
    func moveTextToLayer(textId: UUID, toLayerIndex: Int) {
        guard toLayerIndex >= 0 && toLayerIndex < layers.count else {
            // Log.error("❌ Invalid layer index for text move: \(toLayerIndex)", category: .error)
            return
        }
        
        // Don't allow moving to locked layers
        if layers[toLayerIndex].isLocked {
            return
        }
        
        // Check if text exists in unified system
        guard findText(by: textId) != nil else {
            // Log.error("❌ Text object not found", category: .error)
            return
        }
        
        saveToUndoStack()
        
        // Update the text object's layer association using unified helper
        updateTextLayerInUnified(id: textId, layerIndex: toLayerIndex)
        
        // Update selection to the target layer
        selectedTextIDs = [textId]
        selectedShapeIDs.removeAll()
        selectedLayerIndex = toLayerIndex
        
    }
    
    /// Handle dropping a draggable object onto a layer
    func handleObjectDrop(_ draggableObject: DraggableVectorObject, ontoLayerIndex: Int) {
        switch draggableObject.objectType {
        case .shape:
            moveShapeToLayer(
                shapeId: draggableObject.objectId,
                fromLayerIndex: draggableObject.sourceLayerIndex,
                toLayerIndex: ontoLayerIndex
            )
        case .text:
            moveTextToLayer(
                textId: draggableObject.objectId,
                toLayerIndex: ontoLayerIndex
            )
        }
    }
}
