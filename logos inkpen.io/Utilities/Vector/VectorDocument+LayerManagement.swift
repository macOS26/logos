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

        changeNotifier.notifyLayersChanged()
    }

    func duplicateLayer(at index: Int) {
        guard index >= 0 && index < layers.count else {
            Log.error("❌ Invalid layer index for duplicate: \(index)", category: .error)
            return
        }

        if index == 0 && layers[index].name == "Canvas" {
            return
        }

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
            if ImageContentRegistry.containsImage(shape, in: self),
               let image = ImageContentRegistry.image(for: shape.id, in: self) {
                ImageContentRegistry.register(image: image, for: duplicatedShape.id, in: self)
            }
            addShape(duplicatedShape, to: index + 1)
        }

        selectedLayerIndex = index + 1
        settings.selectedLayerId = duplicatedLayer.id
        settings.selectedLayerName = duplicatedLayer.name
        onSettingsChanged()
        changeNotifier.notifyLayersChanged()
    }

    func moveLayer(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < layers.count,
              targetIndex >= 0 && targetIndex <= layers.count,
              sourceIndex != targetIndex else { return }

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
                )
            } else if sourceIndex < adjustedTargetIndex {
                if currentLayerIndex > sourceIndex && currentLayerIndex <= adjustedTargetIndex {
                    updatedObject = VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: currentLayerIndex - 1,
                    )
                }
            } else if sourceIndex > adjustedTargetIndex {
                if currentLayerIndex >= adjustedTargetIndex && currentLayerIndex < sourceIndex {
                    updatedObject = VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: currentLayerIndex + 1,
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

        changeNotifier.notifyLayersChanged()
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

            var layerNumber = 1
            while existingNumbers.contains(layerNumber) {
                layerNumber += 1
            }

            layerName = "Layer \(layerNumber)"
        }

        let newLayer = VectorLayer(name: layerName, color: color)

        if let currentIndex = selectedLayerIndex, currentIndex < layers.count {
            layers.insert(newLayer, at: currentIndex + 1)
            selectedLayerIndex = currentIndex + 1

            var updatedObjects: [VectorObject] = []
            for object in unifiedObjects {
                if object.layerIndex > currentIndex {
                    updatedObjects.append(VectorObject(
                        shape: extractShape(from: object),
                        layerIndex: object.layerIndex + 1,
                    ))
                } else {
                    updatedObjects.append(object)
                }
            }
            unifiedObjects = updatedObjects
        } else {
            layers.append(newLayer)
            selectedLayerIndex = layers.count - 1
        }

        settings.selectedLayerId = newLayer.id
        settings.selectedLayerName = newLayer.name
        onSettingsChanged()
        changeNotifier.notifyLayersChanged()
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

        changeNotifier.notifyLayersChanged()
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

        let command = MoveObjectToLayerCommand(
            objectID: objectId,
            oldLayerIndex: sourceLayerIndex,
            newLayerIndex: targetLayerIndex
        )
        commandManager.execute(command)
    }

    func moveObjectsToLayer(objectIds: [UUID], targetLayerIndex: Int) {
        guard targetLayerIndex >= 0 && targetLayerIndex < layers.count else {
            Log.error("❌ Invalid target layer index: \(targetLayerIndex)", category: .error)
            return
        }

        var moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)] = []

        for objectId in objectIds {
            guard let objectIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }) else {
                continue
            }

            let object = unifiedObjects[objectIndex]
            let sourceLayerIndex = object.layerIndex

            if sourceLayerIndex != targetLayerIndex {
                moves.append((objectID: objectId, oldLayerIndex: sourceLayerIndex, newLayerIndex: targetLayerIndex))
            }
        }

        if !moves.isEmpty {
            let command = MoveObjectToLayerCommand(moves: moves)
            commandManager.execute(command)
        }
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
                return false
            }

        guard !visibleObjects.isEmpty else { return }

        if viewState.selectedObjectIDs.isEmpty {
            viewState.selectedObjectIDs = [visibleObjects.first!.id]
            
            return
        }

        guard let currentID = viewState.selectedObjectIDs.first,
              let currentIndex = visibleObjects.firstIndex(where: { $0.id == currentID }) else {
            viewState.selectedObjectIDs = [visibleObjects.first!.id]
            
            return
        }

        let nextIndex = (currentIndex > 0) ? currentIndex - 1 : currentIndex
        viewState.selectedObjectIDs = [visibleObjects[nextIndex].id]
        
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
                return false
            }

        guard !visibleObjects.isEmpty else { return }

        if viewState.selectedObjectIDs.isEmpty {
            viewState.selectedObjectIDs = [visibleObjects.last!.id]
            
            return
        }

        guard let currentID = viewState.selectedObjectIDs.first,
              let currentIndex = visibleObjects.firstIndex(where: { $0.id == currentID }) else {
            viewState.selectedObjectIDs = [visibleObjects.last!.id]
            
            return
        }

        let nextIndex = (currentIndex < visibleObjects.count - 1) ? currentIndex + 1 : currentIndex
        viewState.selectedObjectIDs = [visibleObjects[nextIndex].id]
        
    }

    func moveSelectedObjectsUp() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        var selectedObjects: [VectorObject] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        for selectedObj in selectedObjects {
            guard let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObj.id }) else { continue }
            guard selectedIndex < unifiedObjects.count - 1 else { continue }

            unifiedObjects.swapAt(selectedIndex, selectedIndex + 1)
        }
    }

    func moveSelectedObjectsDown() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        var selectedObjects: [VectorObject] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        for selectedObj in selectedObjects {
            guard let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObj.id }) else { continue }
            guard selectedIndex > 0 else { continue }

            unifiedObjects.swapAt(selectedIndex, selectedIndex - 1)
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

        let object = unifiedObjects.remove(at: sourceIndex)
        unifiedObjects.insert(object, at: targetIndex)
    }

    func moveObjectToTop(objectId: UUID) {
        guard let sourceIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }) else {
            Log.error("❌ Object not found for moving to top", category: .error)
            return
        }

        let sourceObject = unifiedObjects[sourceIndex]
        let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == sourceObject.layerIndex }

        guard let lastIndex = layerObjects.last?.offset else { return }
        guard sourceIndex != lastIndex else { return }

        let object = unifiedObjects.remove(at: sourceIndex)
        unifiedObjects.insert(object, at: lastIndex)
    }

    func moveObjectToBottom(objectId: UUID) {
        guard let sourceIndex = unifiedObjects.firstIndex(where: { $0.id == objectId }) else {
            Log.error("❌ Object not found for moving to bottom", category: .error)
            return
        }

        let sourceObject = unifiedObjects[sourceIndex]
        let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == sourceObject.layerIndex }

        guard let firstIndex = layerObjects.first?.offset else { return }
        guard sourceIndex != firstIndex else { return }

        let object = unifiedObjects.remove(at: sourceIndex)
        unifiedObjects.insert(object, at: firstIndex)
    }

    func reorderLayer(sourceLayerId: UUID, targetLayerId: UUID) {
        guard let sourceIndex = layers.firstIndex(where: { $0.id == sourceLayerId }),
              let targetIndex = layers.firstIndex(where: { $0.id == targetLayerId }) else {
            Log.error("❌ Layers not found for reordering", category: .error)
            return
        }

        guard sourceIndex != targetIndex else { return }

        var affectedObjectUpdates: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)] = []

        let newSourceIndex = targetIndex
        for object in unifiedObjects {
            let currentLayerIndex = object.layerIndex
            var newLayerIndex = currentLayerIndex

            if currentLayerIndex == sourceIndex {
                newLayerIndex = newSourceIndex
            } else if sourceIndex < targetIndex {
                if currentLayerIndex > sourceIndex && currentLayerIndex <= targetIndex {
                    newLayerIndex = currentLayerIndex - 1
                }
            } else {
                if currentLayerIndex >= targetIndex && currentLayerIndex < sourceIndex {
                    newLayerIndex = currentLayerIndex + 1
                }
            }

            if newLayerIndex != currentLayerIndex {
                affectedObjectUpdates.append((objectID: object.id, oldLayerIndex: currentLayerIndex, newLayerIndex: newLayerIndex))
            }
        }

        let command = LayerReorderCommand(
            sourceLayerId: sourceLayerId,
            targetLayerId: targetLayerId,
            sourceIndex: sourceIndex,
            targetIndex: targetIndex,
            affectedObjectUpdates: affectedObjectUpdates
        )
        commandManager.execute(command)
    }
}
