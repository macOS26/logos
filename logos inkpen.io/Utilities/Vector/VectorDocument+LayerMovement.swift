//
//  VectorDocument+LayerMovement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

// MARK: - Layer Movement
extension VectorDocument {

    // MARK: - Drag and Drop Object Movement Between Layers

    /// Move a shape from one layer to another
    func moveShapeToLayer(shapeId: UUID, fromLayerIndex: Int, toLayerIndex: Int) {
        guard fromLayerIndex >= 0 && fromLayerIndex < layers.count,
              toLayerIndex >= 0 && toLayerIndex < layers.count,
              fromLayerIndex != toLayerIndex else {
            Log.error("❌ Invalid layer indices for shape move: from=\(fromLayerIndex), to=\(toLayerIndex)", category: .error)
            return
        }
        
        // Don't allow moving to locked layers
        if layers[toLayerIndex].isLocked {
            Log.info("🚫 Cannot move objects to locked layer '\(layers[toLayerIndex].name)'", category: .general)
            return
        }
        
        // Don't allow moving from locked layers unless it's a selection operation
        if layers[fromLayerIndex].isLocked {
            Log.info("🚫 Cannot move objects from locked layer '\(layers[fromLayerIndex].name)'", category: .general)
            return
        }
        
        // Find and remove the shape from source layer
        guard let shapeIndex = layers[fromLayerIndex].shapes.firstIndex(where: { $0.id == shapeId }) else {
            Log.error("❌ Shape not found in source layer \(fromLayerIndex)", category: .error)
            return
        }
        
        saveToUndoStack()
        
        let shape = layers[fromLayerIndex].shapes.remove(at: shapeIndex)
        layers[toLayerIndex].shapes.append(shape)
        
        // Update selection to follow the moved shape
        selectedShapeIDs = [shapeId]
        selectedLayerIndex = toLayerIndex
        
        Log.info("✅ Moved shape '\(shape.name)' from layer '\(layers[fromLayerIndex].name)' to '\(layers[toLayerIndex].name)'", category: .fileOperations)
    }
    
    /// Move a text object to a specific layer (conceptually)
    func moveTextToLayer(textId: UUID, toLayerIndex: Int) {
        guard toLayerIndex >= 0 && toLayerIndex < layers.count else {
            Log.error("❌ Invalid layer index for text move: \(toLayerIndex)", category: .error)
            return
        }
        
        // Don't allow moving to locked layers
        if layers[toLayerIndex].isLocked {
            Log.info("🚫 Cannot move text to locked layer '\(layers[toLayerIndex].name)'", category: .general)
            return
        }
        
        guard let textIndex = textObjects.firstIndex(where: { $0.id == textId }) else {
            Log.error("❌ Text object not found", category: .error)
            return
        }
        
        saveToUndoStack()
        
        // Update the text object's layer association using unified helper
        updateTextLayerInUnified(id: textObjects[textIndex].id, layerIndex: toLayerIndex)
        
        // Update selection to the target layer
        selectedTextIDs = [textId]
        selectedShapeIDs.removeAll()
        selectedLayerIndex = toLayerIndex
        
        Log.info("✅ Moved text object to layer '\(layers[toLayerIndex].name)'", category: .fileOperations)
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
