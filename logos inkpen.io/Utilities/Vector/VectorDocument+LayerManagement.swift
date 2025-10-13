import SwiftUI
import Combine

extension VectorDocument {
    func renameLayer(at index: Int, to newName: String) {
        guard index >= 0 && index < layers.count else {
            Log.error("❌ Invalid layer index for rename: \(index)", category: .error)
            return
        }

        if index == 0 && layers[index].name == "Canvas" {
            return
        }


        layers[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        if settings.selectedLayerId == layers[index].id {
            settings.selectedLayerName = layers[index].name
            onSettingsChanged()
        }

        saveToUndoStack()
    }

    func duplicateLayer(at index: Int) {
        guard index >= 0 && index < layers.count else {
            Log.error("❌ Invalid layer index for duplicate: \(index)", category: .error)
            return
        }

        if index == 0 && layers[index].name == "Canvas" {
            return
        }

        saveToUndoStack()

        let originalLayer = layers[index]
        var duplicatedLayer = VectorLayer(name: "\(originalLayer.name) Copy", color: originalLayer.color)

        duplicatedLayer.isVisible = originalLayer.isVisible
        duplicatedLayer.isLocked = originalLayer.isLocked
        duplicatedLayer.opacity = originalLayer.opacity

        layers.insert(duplicatedLayer, at: index + 1)

        let originalShapes = getShapesForLayer(index)
        for shape in originalShapes {
            var duplicatedShape = shape
            duplicatedShape.id = UUID()
            if ImageContentRegistry.containsImage(shape),
               let image = ImageContentRegistry.image(for: shape.id) {
                ImageContentRegistry.register(image: image, for: duplicatedShape.id)
            }
            addShape(duplicatedShape, to: index + 1)
        }

        updateUnifiedObjectsOptimized()

        selectedLayerIndex = index + 1
        settings.selectedLayerId = duplicatedLayer.id
        settings.selectedLayerName = duplicatedLayer.name
        onSettingsChanged()

    }

    func moveLayer(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < layers.count,
              targetIndex >= 0 && targetIndex <= layers.count,
              sourceIndex != targetIndex else { return }

        saveToUndoStack()

        let movingLayer = layers.remove(at: sourceIndex)

        let adjustedTargetIndex = (sourceIndex < targetIndex) ? targetIndex - 1 : targetIndex

        layers.insert(movingLayer, at: adjustedTargetIndex)

        var updatedObjects: [VectorObject] = []

        for object in unifiedObjects {
            var updatedObject = object
            let currentLayerIndex = object.layerIndex

            if currentLayerIndex == sourceIndex {
                updatedObject = VectorObject(
                    shape: extractShape(from: object),
                    layerIndex: adjustedTargetIndex,
                    orderID: object.orderID
                )
            } else if sourceIndex < adjustedTargetIndex {
                if currentLayerIndex > sourceIndex && currentLayerIndex <= adjustedTargetIndex {
                    updatedObject = VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: currentLayerIndex - 1,
                        orderID: object.orderID
                    )
                }
            } else if sourceIndex > adjustedTargetIndex {
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

        unifiedObjects = updatedObjects

        if selectedLayerIndex == sourceIndex {
            selectedLayerIndex = adjustedTargetIndex
        } else if let selectedIndex = selectedLayerIndex {
            if sourceIndex < selectedIndex && adjustedTargetIndex >= selectedIndex {
                selectedLayerIndex = selectedIndex - 1
            } else if sourceIndex > selectedIndex && adjustedTargetIndex <= selectedIndex {
                selectedLayerIndex = selectedIndex + 1
            }
        }
    }

    private func extractShape(from object: VectorObject) -> VectorShape {
        if case .shape(let shape) = object.objectType {
            return shape
        }
        fatalError("VectorObject does not contain a shape")
    }

    func addLayer(name: String = "New Layer") {
        let colors: [Color] = [.gray, .blue, .green, .orange, .purple, .red, .pink, .yellow, .cyan]
        let color = colors[layers.count % colors.count]

        // Generate next layer number - fill in gaps
        var layerName = name
        if name == "New Layer" {
            var existingNumbers = Set<Int>()

            for layer in layers {
                if layer.name.hasPrefix("Layer "),
                   let numberPart = layer.name.split(separator: " ").last,
                   let num = Int(numberPart) {
                    existingNumbers.insert(num)
                }
            }

            // Find the first available number starting from 1
            var layerNumber = 1
            while existingNumbers.contains(layerNumber) {
                layerNumber += 1
            }

            layerName = "Layer \(layerNumber)"
        }

        let newLayer = VectorLayer(name: layerName, color: color)

        // Insert in front of (above) the currently selected layer
        if let currentIndex = selectedLayerIndex, currentIndex < layers.count {
            // Insert right after the current selected layer (which appears above in the UI since layers are reversed)
            layers.insert(newLayer, at: currentIndex + 1)
            selectedLayerIndex = currentIndex + 1

            // Update all object indices that are at or above the insertion point
            var updatedObjects: [VectorObject] = []
            for object in unifiedObjects {
                if object.layerIndex > currentIndex {
                    updatedObjects.append(VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: object.layerIndex + 1,
                        orderID: object.orderID
                    ))
                } else {
                    updatedObjects.append(object)
                }
            }
            unifiedObjects = updatedObjects
        } else {
            // No layer selected or invalid index, append to end
            layers.append(newLayer)
            selectedLayerIndex = layers.count - 1
        }

        settings.selectedLayerId = newLayer.id
        settings.selectedLayerName = newLayer.name
        onSettingsChanged()
    }

    func removeLayer(at index: Int) {
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

        if removingSelectedLayer || settings.selectedLayerId == nil {
            validateSelectedLayer()
        }
    }

    func validateSelectedLayer() {
        if let savedId = settings.selectedLayerId,
           layers.first(where: { $0.id == savedId }) != nil {
            if let index = layers.firstIndex(where: { $0.id == savedId }) {
                selectedLayerIndex = index
                layerIndex = index
            }
            return
        }

        if let layer1Index = layers.firstIndex(where: { $0.name == "Layer 1" }) {
            let layer1 = layers[layer1Index]
            settings.selectedLayerId = layer1.id
            settings.selectedLayerName = layer1.name
            selectedLayerIndex = layer1Index
            layerIndex = layer1Index
            onSettingsChanged()
            return
        }

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

        if layers.count <= 2 {
            addLayer(name: "Layer 1")
        }
    }

    func moveObjectToLayer(objectId: UUID, targetLayerIndex: Int) {
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

        if sourceLayerIndex == targetLayerIndex {
            return
        }

        saveToUndoStack()

        let updatedObject = VectorObject(
            shape: extractShape(from: object),
            layerIndex: targetLayerIndex,
            orderID: object.orderID
        )

        unifiedObjects[objectIndex] = updatedObject
    }

    func selectNextObjectUp() {
        let visibleObjects = unifiedObjects
            .filter { obj in
                if obj.layerIndex >= 0 && obj.layerIndex < layers.count {
                    return layers[obj.layerIndex].isVisible
                }
                return false
            }
            .sorted { obj1, obj2 in
                if obj1.layerIndex != obj2.layerIndex {
                    return obj1.layerIndex > obj2.layerIndex
                }
                return obj1.orderID > obj2.orderID
            }

        guard !visibleObjects.isEmpty else { return }

        if selectedObjectIDs.isEmpty {
            selectedObjectIDs = [visibleObjects.first!.id]
            syncSelectionArrays()
            return
        }

        guard let currentID = selectedObjectIDs.first,
              let currentIndex = visibleObjects.firstIndex(where: { $0.id == currentID }) else {
            selectedObjectIDs = [visibleObjects.first!.id]
            syncSelectionArrays()
            return
        }

        let nextIndex = (currentIndex > 0) ? currentIndex - 1 : currentIndex
        selectedObjectIDs = [visibleObjects[nextIndex].id]
        syncSelectionArrays()
    }

    func selectNextObjectDown() {
        let visibleObjects = unifiedObjects
            .filter { obj in
                if obj.layerIndex >= 0 && obj.layerIndex < layers.count {
                    return layers[obj.layerIndex].isVisible
                }
                return false
            }
            .sorted { obj1, obj2 in
                if obj1.layerIndex != obj2.layerIndex {
                    return obj1.layerIndex > obj2.layerIndex
                }
                return obj1.orderID > obj2.orderID
            }

        guard !visibleObjects.isEmpty else { return }

        if selectedObjectIDs.isEmpty {
            selectedObjectIDs = [visibleObjects.last!.id]
            syncSelectionArrays()
            return
        }

        guard let currentID = selectedObjectIDs.first,
              let currentIndex = visibleObjects.firstIndex(where: { $0.id == currentID }) else {
            selectedObjectIDs = [visibleObjects.last!.id]
            syncSelectionArrays()
            return
        }

        let nextIndex = (currentIndex < visibleObjects.count - 1) ? currentIndex + 1 : currentIndex
        selectedObjectIDs = [visibleObjects[nextIndex].id]
        syncSelectionArrays()
    }

    func moveSelectedObjectsUp() {
        guard !selectedObjectIDs.isEmpty else { return }

        saveToUndoStack()

        var selectedObjects: [VectorObject] = []
        for objectID in selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        selectedObjects.sort { $0.orderID > $1.orderID }

        for selectedObj in selectedObjects {
            let higherObjects = unifiedObjects.filter {
                $0.layerIndex == selectedObj.layerIndex && $0.orderID > selectedObj.orderID
            }.sorted { $0.orderID < $1.orderID }

            guard let nextHigher = higherObjects.first else { continue }

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
    }

    func moveSelectedObjectsDown() {
        guard !selectedObjectIDs.isEmpty else { return }

        saveToUndoStack()

        var selectedObjects: [VectorObject] = []
        for objectID in selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        selectedObjects.sort { $0.orderID < $1.orderID }

        for selectedObj in selectedObjects {
            let lowerObjects = unifiedObjects.filter {
                $0.layerIndex == selectedObj.layerIndex && $0.orderID < selectedObj.orderID
            }.sorted { $0.orderID > $1.orderID }

            guard let nextLower = lowerObjects.first else { continue }

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
    }

    func reorderObject(objectId: UUID, targetObjectId: UUID) {
        guard let sourceIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }),
              let targetIndex = unifiedObjects.firstIndex(where: { $0.id == targetObjectId }) else {
            Log.error("❌ Objects not found for reordering", category: .error)
            return
        }

        let sourceObject = unifiedObjects[sourceIndex]
        let targetObject = unifiedObjects[targetIndex]

        guard sourceObject.layerIndex == targetObject.layerIndex else {
            return
        }

        saveToUndoStack()

        let targetOrderID = targetObject.orderID
        let sourceOrderID = sourceObject.orderID

        let newOrderID: Int
        if sourceOrderID < targetOrderID {
            newOrderID = targetOrderID
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
            newOrderID = targetOrderID
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

        unifiedObjects[sourceIndex] = VectorObject(
            shape: extractShape(from: sourceObject),
            layerIndex: sourceObject.layerIndex,
            orderID: newOrderID
        )
    }

    func moveObjectToTop(objectId: UUID) {
        guard let sourceIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }) else {
            Log.error("❌ Object not found for moving to top", category: .error)
            return
        }

        let sourceObject = unifiedObjects[sourceIndex]
        let layerObjects = unifiedObjects.filter { $0.layerIndex == sourceObject.layerIndex }
        let maxOrderID = layerObjects.map { $0.orderID }.max() ?? 0

        // If already at top, do nothing
        if sourceObject.orderID == maxOrderID {
            return
        }

        saveToUndoStack()

        // Shift down all objects above the source
        for i in 0..<unifiedObjects.count {
            let obj = unifiedObjects[i]
            if obj.layerIndex == sourceObject.layerIndex &&
               obj.orderID > sourceObject.orderID &&
               obj.id != sourceObject.id {
                unifiedObjects[i] = VectorObject(
                    shape: extractShape(from: obj),
                    layerIndex: obj.layerIndex,
                    orderID: obj.orderID - 1
                )
            }
        }

        // Move source to top
        unifiedObjects[sourceIndex] = VectorObject(
            shape: extractShape(from: sourceObject),
            layerIndex: sourceObject.layerIndex,
            orderID: maxOrderID
        )
    }

    func moveObjectToBottom(objectId: UUID) {
        guard let sourceIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }) else {
            Log.error("❌ Object not found for moving to bottom", category: .error)
            return
        }

        let sourceObject = unifiedObjects[sourceIndex]
        let layerObjects = unifiedObjects.filter { $0.layerIndex == sourceObject.layerIndex }
        let minOrderID = layerObjects.map { $0.orderID }.min() ?? 0

        // If already at bottom, do nothing
        if sourceObject.orderID == minOrderID {
            return
        }

        saveToUndoStack()

        // Shift up all objects below the source
        for i in 0..<unifiedObjects.count {
            let obj = unifiedObjects[i]
            if obj.layerIndex == sourceObject.layerIndex &&
               obj.orderID < sourceObject.orderID &&
               obj.id != sourceObject.id {
                unifiedObjects[i] = VectorObject(
                    shape: extractShape(from: obj),
                    layerIndex: obj.layerIndex,
                    orderID: obj.orderID + 1
                )
            }
        }

        // Move source to bottom
        unifiedObjects[sourceIndex] = VectorObject(
            shape: extractShape(from: sourceObject),
            layerIndex: sourceObject.layerIndex,
            orderID: minOrderID
        )
    }

    func reorderLayer(sourceLayerId: UUID, targetLayerId: UUID) {
        guard let sourceIndex = layers.firstIndex(where: { $0.id == sourceLayerId }),
              let targetIndex = layers.firstIndex(where: { $0.id == targetLayerId }) else {
            Log.error("❌ Layers not found for reordering", category: .error)
            return
        }

        guard sourceIndex != targetIndex else { return }

        saveToUndoStack()

        // Remove source layer and insert at target position - matches reorderObject behavior
        let sourceLayer = layers.remove(at: sourceIndex)
        layers.insert(sourceLayer, at: targetIndex)

        // Calculate the actual new index after insertion
        let newSourceIndex = targetIndex

        // Update all objects to reflect the layer reordering - shift layers in between
        var updatedObjects: [VectorObject] = []
        for object in unifiedObjects {
            var updatedObject = object
            let currentLayerIndex = object.layerIndex

            if currentLayerIndex == sourceIndex {
                // Move source layer's objects to new position
                updatedObject = VectorObject(
                    shape: extractShape(from: object),
                    layerIndex: newSourceIndex,
                    orderID: object.orderID
                )
            } else if sourceIndex < targetIndex {
                // Moving down: shift layers between source and target up by 1
                if currentLayerIndex > sourceIndex && currentLayerIndex <= targetIndex {
                    updatedObject = VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: currentLayerIndex - 1,
                        orderID: object.orderID
                    )
                }
            } else {
                // Moving up: shift layers between target and source down by 1
                if currentLayerIndex >= targetIndex && currentLayerIndex < sourceIndex {
                    updatedObject = VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: currentLayerIndex + 1,
                        orderID: object.orderID
                    )
                }
            }

            updatedObjects.append(updatedObject)
        }

        unifiedObjects = updatedObjects

        // Update selected layer index accounting for the shift
        if selectedLayerIndex == sourceIndex {
            selectedLayerIndex = newSourceIndex
        } else if let selectedIndex = selectedLayerIndex {
            if sourceIndex < targetIndex {
                // Moving down: shift selected index up if it was in between
                if selectedIndex > sourceIndex && selectedIndex <= targetIndex {
                    selectedLayerIndex = selectedIndex - 1
                }
            } else {
                // Moving up: shift selected index down if it was in between
                if selectedIndex >= targetIndex && selectedIndex < sourceIndex {
                    selectedLayerIndex = selectedIndex + 1
                }
            }
        }
    }
}
