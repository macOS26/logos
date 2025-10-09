//
//  VectorDocument+LayerManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

// MARK: - Layer Management
extension VectorDocument {
    /// Rename a layer at the specified index
    func renameLayer(at index: Int, to newName: String) {
        guard index >= 0 && index < layers.count else {
            Log.error("❌ Invalid layer index for rename: \(index)", category: .error)
            return
        }
        
        // Don't allow renaming Canvas layer
        if index == 0 && layers[index].name == "Canvas" {
            return
        }
        
        
        layers[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Update settings if this is the selected layer
        if settings.selectedLayerId == layers[index].id {
            settings.selectedLayerName = layers[index].name
            onSettingsChanged()
        }

        saveToUndoStack()
    }
    
    /// Duplicate a layer at the specified index
    func duplicateLayer(at index: Int) {
        guard index >= 0 && index < layers.count else {
            Log.error("❌ Invalid layer index for duplicate: \(index)", category: .error)
            return
        }
        
        // Don't allow duplicating Canvas layer
        if index == 0 && layers[index].name == "Canvas" {
            return
        }
        
        saveToUndoStack()
        
        let originalLayer = layers[index]
        var duplicatedLayer = VectorLayer(name: "\(originalLayer.name) Copy")
        
        // Copy all properties
        duplicatedLayer.isVisible = originalLayer.isVisible
        duplicatedLayer.isLocked = originalLayer.isLocked
        duplicatedLayer.opacity = originalLayer.opacity
        
        // Insert the duplicated layer right after the original
        layers.insert(duplicatedLayer, at: index + 1)
        
        // Deep copy all shapes with new IDs from unified objects
        let originalShapes = getShapesForLayer(index)
        for shape in originalShapes {
            var duplicatedShape = shape
            duplicatedShape.id = UUID() // New unique ID
            // If this shape carries raster content, duplicate the image registry entry to the new ID
            if ImageContentRegistry.containsImage(shape),
               let image = ImageContentRegistry.image(for: shape.id) {
                ImageContentRegistry.register(image: image, for: duplicatedShape.id)
            }
            // Add shape to the new layer through unified objects
            addShape(duplicatedShape, to: index + 1)
        }
        
        // Update unified objects after adding shapes
        updateUnifiedObjectsOptimized()
        
        // Select the new layer
        selectedLayerIndex = index + 1
        settings.selectedLayerId = duplicatedLayer.id
        settings.selectedLayerName = duplicatedLayer.name
        onSettingsChanged()
        
    }
    
    /// Move a layer from one index to another
    func moveLayer(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < layers.count,
              targetIndex >= 0 && targetIndex <= layers.count,
              sourceIndex != targetIndex else { return }

        if sourceIndex == 0 && layers[sourceIndex].name == "Pasteboard" { return }
        if sourceIndex == 1 && layers[sourceIndex].name == "Canvas" { return }
        if targetIndex == 0 { return }
        if targetIndex == 1 && targetIndex < layers.count && layers[targetIndex].name == "Canvas" { return }

        saveToUndoStack()

        let movingLayer = layers.remove(at: sourceIndex)

        let adjustedTargetIndex = (sourceIndex < targetIndex) ? targetIndex - 1 : targetIndex

        layers.insert(movingLayer, at: adjustedTargetIndex)

        // CRITICAL: Update all object layerIndex values to match the new layer positions
        // This ensures objects move with their layers when reordering
        var updatedObjects: [VectorObject] = []

        for object in unifiedObjects {
            var updatedObject = object
            let currentLayerIndex = object.layerIndex

            // Update layerIndex based on the layer move
            if currentLayerIndex == sourceIndex {
                // Objects in the moved layer get the new index
                updatedObject = VectorObject(
                    shape: extractShape(from: object),
                    layerIndex: adjustedTargetIndex,
                    orderID: object.orderID
                )
            } else if sourceIndex < adjustedTargetIndex {
                // Moving layer forward - shift intermediate layers back
                if currentLayerIndex > sourceIndex && currentLayerIndex <= adjustedTargetIndex {
                    updatedObject = VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: currentLayerIndex - 1,
                        orderID: object.orderID
                    )
                }
            } else if sourceIndex > adjustedTargetIndex {
                // Moving layer backward - shift intermediate layers forward
                if currentLayerIndex >= adjustedTargetIndex && currentLayerIndex < sourceIndex {
                    updatedObject = VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: currentLayerIndex + 1,
                        orderID: object.orderID
                    )
                }
            }

            updatedObjects.append(updatedObject)
        }

        // Replace unified objects with updated ones
        unifiedObjects = updatedObjects

        // Update selected layer index to follow the moved layer
        if selectedLayerIndex == sourceIndex {
            selectedLayerIndex = adjustedTargetIndex
        } else if let selectedIndex = selectedLayerIndex {
            // Adjust selection if it was affected by the move
            if sourceIndex < selectedIndex && adjustedTargetIndex >= selectedIndex {
                selectedLayerIndex = selectedIndex - 1
            } else if sourceIndex > selectedIndex && adjustedTargetIndex <= selectedIndex {
                selectedLayerIndex = selectedIndex + 1
            }
        }

        // Force update
        objectWillChange.send()
    }

    // Helper to extract shape from VectorObject
    private func extractShape(from object: VectorObject) -> VectorShape {
        if case .shape(let shape) = object.objectType {
            return shape
        }
        fatalError("VectorObject does not contain a shape")
    }
    
    func addLayer(name: String = "New Layer") {
        let newLayer = VectorLayer(name: name)
        layers.append(newLayer)
        selectedLayerIndex = layers.count - 1

        // Update selected layer in settings
        settings.selectedLayerId = newLayer.id
        settings.selectedLayerName = newLayer.name
        onSettingsChanged()
    }
    
    func removeLayer(at index: Int) {
        // Allow deletion of any layer, just prevent deleting the last layer
        guard index >= 0 && index < layers.count && layers.count > 1 else {
            return
        }

        let removingSelectedLayer = settings.selectedLayerId == layers[index].id

        layers.remove(at: index)
        if selectedLayerIndex == index {
            selectedLayerIndex = min(index, layers.count - 1)
        } else if let selected = selectedLayerIndex, selected > index {
            selectedLayerIndex = selected - 1
        }

        // Update selected layer if we removed it
        if removingSelectedLayer || settings.selectedLayerId == nil {
            validateSelectedLayer()
        }
    }

    /// Ensures a layer is always selected, defaulting to Layer 1 or first available layer
    func validateSelectedLayer() {
        // First try to find the layer with the saved ID
        if let savedId = settings.selectedLayerId,
           layers.first(where: { $0.id == savedId }) != nil {
            // Layer still exists, update index to match
            if let index = layers.firstIndex(where: { $0.id == savedId }) {
                selectedLayerIndex = index
                layerIndex = index
            }
            return
        }

        // Try to find "Layer 1" as fallback
        if let layer1Index = layers.firstIndex(where: { $0.name == "Layer 1" }) {
            let layer1 = layers[layer1Index]
            settings.selectedLayerId = layer1.id
            settings.selectedLayerName = layer1.name
            selectedLayerIndex = layer1Index
            layerIndex = layer1Index
            onSettingsChanged()
            return
        }

        // Find first non-Canvas, non-Pasteboard layer as last resort
        for (index, layer) in layers.enumerated() {
            if layer.name != "Canvas" && layer.name != "Pasteboard" && !layer.isLocked {
                settings.selectedLayerId = layer.id
                settings.selectedLayerName = layer.name
                selectedLayerIndex = index
                layerIndex = index
                onSettingsChanged()
                return
            }
        }

        // Absolute fallback: create Layer 1 if nothing exists
        if layers.count <= 2 { // Only Canvas and Pasteboard
            addLayer(name: "Layer 1")
        }
    }

    /// Move an object from its current layer to a target layer
    func moveObjectToLayer(objectId: UUID, targetLayerIndex: Int) {
        // Find the object in unified objects
        guard let objectIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }) else {
            Log.error("❌ Object not found for layer move: \(objectId)", category: .error)
            return
        }

        guard targetLayerIndex >= 0 && targetLayerIndex < layers.count else {
            Log.error("❌ Invalid target layer index: \(targetLayerIndex)", category: .error)
            return
        }

        let object = unifiedObjects[objectIndex]
        let sourceLayerIndex = object.layerIndex

        // Don't do anything if already on target layer
        if sourceLayerIndex == targetLayerIndex {
            return
        }

        saveToUndoStack()

        // Create new object with updated layer index
        let updatedObject = VectorObject(
            shape: extractShape(from: object),
            layerIndex: targetLayerIndex,
            orderID: object.orderID
        )

        // Replace the object in unified objects
        unifiedObjects[objectIndex] = updatedObject

        // Force UI update
        objectWillChange.send()
    }

    /// Move selected objects up in stacking order (increase orderID - toward front)
    func moveSelectedObjectsUp() {
        guard !selectedObjectIDs.isEmpty else { return }

        saveToUndoStack()

        // Get all selected objects
        var selectedObjects: [VectorObject] = []
        for objectID in selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        // Sort by orderID (highest first) to process from front to back
        selectedObjects.sort { $0.orderID > $1.orderID }

        // For each selected object, swap with the next higher orderID object on the same layer
        for selectedObj in selectedObjects {
            // Find the object with the next higher orderID on the same layer
            let higherObjects = unifiedObjects.filter {
                $0.layerIndex == selectedObj.layerIndex && $0.orderID > selectedObj.orderID
            }.sorted { $0.orderID < $1.orderID }

            guard let nextHigher = higherObjects.first else { continue }

            // Swap orderIDs
            if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObj.id }),
               let higherIndex = unifiedObjects.firstIndex(where: { $0.id == nextHigher.id }) {
                let tempOrderID = unifiedObjects[selectedIndex].orderID
                unifiedObjects[selectedIndex] = VectorObject(
                    shape: extractShape(from: unifiedObjects[selectedIndex]),
                    layerIndex: unifiedObjects[selectedIndex].layerIndex,
                    orderID: unifiedObjects[higherIndex].orderID
                )
                unifiedObjects[higherIndex] = VectorObject(
                    shape: extractShape(from: unifiedObjects[higherIndex]),
                    layerIndex: unifiedObjects[higherIndex].layerIndex,
                    orderID: tempOrderID
                )
            }
        }

        objectWillChange.send()
    }

    /// Move selected objects down in stacking order (decrease orderID - toward back)
    func moveSelectedObjectsDown() {
        guard !selectedObjectIDs.isEmpty else { return }

        saveToUndoStack()

        // Get all selected objects
        var selectedObjects: [VectorObject] = []
        for objectID in selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        // Sort by orderID (lowest first) to process from back to front
        selectedObjects.sort { $0.orderID < $1.orderID }

        // For each selected object, swap with the next lower orderID object on the same layer
        for selectedObj in selectedObjects {
            // Find the object with the next lower orderID on the same layer
            let lowerObjects = unifiedObjects.filter {
                $0.layerIndex == selectedObj.layerIndex && $0.orderID < selectedObj.orderID
            }.sorted { $0.orderID > $1.orderID }

            guard let nextLower = lowerObjects.first else { continue }

            // Swap orderIDs
            if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObj.id }),
               let lowerIndex = unifiedObjects.firstIndex(where: { $0.id == nextLower.id }) {
                let tempOrderID = unifiedObjects[selectedIndex].orderID
                unifiedObjects[selectedIndex] = VectorObject(
                    shape: extractShape(from: unifiedObjects[selectedIndex]),
                    layerIndex: unifiedObjects[selectedIndex].layerIndex,
                    orderID: unifiedObjects[lowerIndex].orderID
                )
                unifiedObjects[lowerIndex] = VectorObject(
                    shape: extractShape(from: unifiedObjects[lowerIndex]),
                    layerIndex: unifiedObjects[lowerIndex].layerIndex,
                    orderID: tempOrderID
                )
            }
        }

        objectWillChange.send()
    }

    /// Reorder an object by placing it just above the target object in stacking order
    func reorderObject(objectId: UUID, targetObjectId: UUID) {
        // Find both objects
        guard let sourceIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }),
              let targetIndex = unifiedObjects.firstIndex(where: { $0.id == targetObjectId }) else {
            Log.error("❌ Objects not found for reordering", category: .error)
            return
        }

        let sourceObject = unifiedObjects[sourceIndex]
        let targetObject = unifiedObjects[targetIndex]

        // Only allow reordering within the same layer
        guard sourceObject.layerIndex == targetObject.layerIndex else {
            return
        }

        saveToUndoStack()

        // Get the target object's orderID (we want to place source just above target)
        let targetOrderID = targetObject.orderID
        let sourceOrderID = sourceObject.orderID

        // Determine new orderID for source object
        // If moving down (to lower orderID), place source at target's position
        // If moving up (to higher orderID), place source at target's position
        let newOrderID: Int
        if sourceOrderID < targetOrderID {
            // Moving up - place at target position, shift others down
            newOrderID = targetOrderID
            // Shift all objects between source and target down by 1
            for i in 0..<unifiedObjects.count {
                let obj = unifiedObjects[i]
                if obj.layerIndex == sourceObject.layerIndex &&
                   obj.orderID > sourceOrderID &&
                   obj.orderID <= targetOrderID &&
                   obj.id != sourceObject.id {
                    unifiedObjects[i] = VectorObject(
                        shape: extractShape(from: obj),
                        layerIndex: obj.layerIndex,
                        orderID: obj.orderID - 1
                    )
                }
            }
        } else {
            // Moving down - place at target position, shift others up by 1
            newOrderID = targetOrderID
            // Shift all objects between target and source up by 1
            for i in 0..<unifiedObjects.count {
                let obj = unifiedObjects[i]
                if obj.layerIndex == sourceObject.layerIndex &&
                   obj.orderID >= targetOrderID &&
                   obj.orderID < sourceOrderID &&
                   obj.id != sourceObject.id {
                    unifiedObjects[i] = VectorObject(
                        shape: extractShape(from: obj),
                        layerIndex: obj.layerIndex,
                        orderID: obj.orderID + 1
                    )
                }
            }
        }

        // Update source object with new orderID
        unifiedObjects[sourceIndex] = VectorObject(
            shape: extractShape(from: sourceObject),
            layerIndex: sourceObject.layerIndex,
            orderID: newOrderID
        )

        objectWillChange.send()
    }
}
