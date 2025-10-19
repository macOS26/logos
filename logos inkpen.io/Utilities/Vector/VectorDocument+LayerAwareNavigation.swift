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

        var selectedObjects: [VectorObject] = []
        for objectID in selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        for selectedObj in selectedObjects {
            guard let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObj.id }) else { continue }

            let currentLayer = selectedObj.layerIndex

            // Find the next object UP (toward front/lower index) in the SAME layer
            var targetIndex: Int? = nil
            for i in stride(from: selectedIndex - 1, through: 0, by: -1) {
                if unifiedObjects[i].layerIndex == currentLayer {
                    targetIndex = i
                    break
                }
            }

            // Swap with the found object in same layer
            if let targetIndex = targetIndex {
                unifiedObjects.swapAt(selectedIndex, targetIndex)
            }
        }

        // Trigger UI update
        objectPositionUpdateTrigger.toggle()
    }

    func moveSelectedObjectsDownWithinLayer() {
        guard !selectedObjectIDs.isEmpty else { return }

        var selectedObjects: [VectorObject] = []
        for objectID in selectedObjectIDs {
            if let obj = findObject(by: objectID) {
                selectedObjects.append(obj)
            }
        }

        for selectedObj in selectedObjects {
            guard let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObj.id }) else { continue }

            let currentLayer = selectedObj.layerIndex

            // Find the next object DOWN (toward back/higher index) in the SAME layer
            var targetIndex: Int? = nil
            for i in (selectedIndex + 1)..<unifiedObjects.count {
                if unifiedObjects[i].layerIndex == currentLayer {
                    targetIndex = i
                    break
                }
            }

            // Swap with the found object in same layer
            if let targetIndex = targetIndex {
                unifiedObjects.swapAt(selectedIndex, targetIndex)
            }
        }

        // Trigger UI update
        objectPositionUpdateTrigger.toggle()
    }
}
