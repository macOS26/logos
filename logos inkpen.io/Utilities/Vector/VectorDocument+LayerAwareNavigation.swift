import SwiftUI

extension VectorDocument {
    // Select next/previous object within the SAME layer only
    func selectNextObjectUpWithinLayer() {
        guard !selectedObjectIDs.isEmpty,
              let currentID = selectedObjectIDs.first,
              let currentObj = findObject(by: currentID) else { return }

        let currentLayer = currentObj.layerIndex

        // Get all objects in the same layer, sorted by z-order
        let objectsInLayer = unifiedObjects
            .filter { $0.layerIndex == currentLayer }

        guard let currentIndex = objectsInLayer.firstIndex(where: { $0.id == currentID }) else { return }

        // Move up in z-order (earlier in array)
        if currentIndex > 0 {
            selectedObjectIDs = [objectsInLayer[currentIndex - 1].id]
            syncSelectionArrays()
        }
    }

    func selectNextObjectDownWithinLayer() {
        guard !selectedObjectIDs.isEmpty,
              let currentID = selectedObjectIDs.first,
              let currentObj = findObject(by: currentID) else { return }

        let currentLayer = currentObj.layerIndex

        // Get all objects in the same layer, sorted by z-order
        let objectsInLayer = unifiedObjects
            .filter { $0.layerIndex == currentLayer }

        guard let currentIndex = objectsInLayer.firstIndex(where: { $0.id == currentID }) else { return }

        // Move down in z-order (later in array)
        if currentIndex < objectsInLayer.count - 1 {
            selectedObjectIDs = [objectsInLayer[currentIndex + 1].id]
            syncSelectionArrays()
        }
    }

    // Move objects up/down in z-order within the SAME layer only
    func moveSelectedObjectsUpWithinLayer() {
        guard !selectedObjectIDs.isEmpty else { return }

        var affectedObjectIDs: [UUID] = []
        var oldIndices: [UUID: Int] = [:]
        var newIndices: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            // Record old indices for all objects in this layer
            for (offset, obj) in layerObjects {
                oldIndices[obj.id] = offset
                affectedObjectIDs.append(obj.id)
            }

            // Process each selected object in this layer
            for objectID in selectedObjectIDs {
                guard let obj = findObject(by: objectID),
                      obj.layerIndex == layerIndex,
                      let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == objectID }) else { continue }

                // Find next object UP (lower index) in same layer
                var targetIndex: Int? = nil
                for i in stride(from: selectedIndex - 1, through: 0, by: -1) {
                    if unifiedObjects[i].layerIndex == layerIndex {
                        targetIndex = i
                        break
                    }
                }

                // Move the object
                if let targetIndex = targetIndex {
                    let movedObj = unifiedObjects.remove(at: selectedIndex)
                    unifiedObjects.insert(movedObj, at: targetIndex)
                }
            }
        }

        // Record new indices
        for id in affectedObjectIDs {
            if let index = unifiedObjects.firstIndex(where: { $0.id == id }) {
                newIndices[id] = index
            }
        }

        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldIndices: oldIndices,
            newIndices: newIndices
        )
        commandManager.execute(command)
    }

    func moveSelectedObjectsDownWithinLayer() {
        guard !selectedObjectIDs.isEmpty else { return }

        var affectedObjectIDs: [UUID] = []
        var oldIndices: [UUID: Int] = [:]
        var newIndices: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            // Record old indices for all objects in this layer
            for (offset, obj) in layerObjects {
                oldIndices[obj.id] = offset
                affectedObjectIDs.append(obj.id)
            }

            // Process each selected object in this layer
            for objectID in selectedObjectIDs {
                guard let obj = findObject(by: objectID),
                      obj.layerIndex == layerIndex,
                      let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == objectID }) else { continue }

                // Find next object DOWN (higher index) in same layer
                var targetIndex: Int? = nil
                for i in (selectedIndex + 1)..<unifiedObjects.count {
                    if unifiedObjects[i].layerIndex == layerIndex {
                        targetIndex = i
                        break
                    }
                }

                // Move the object
                if let targetIndex = targetIndex {
                    let movedObj = unifiedObjects.remove(at: selectedIndex)
                    unifiedObjects.insert(movedObj, at: targetIndex)
                }
            }
        }

        // Record new indices
        for id in affectedObjectIDs {
            if let index = unifiedObjects.firstIndex(where: { $0.id == id }) {
                newIndices[id] = index
            }
        }

        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldIndices: oldIndices,
            newIndices: newIndices
        )
        commandManager.execute(command)
    }
}
