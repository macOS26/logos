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
            guard selectedIndex > 0 else { continue }

            let prevObj = unifiedObjects[selectedIndex - 1]

            // Only swap if both objects are in the same layer
            if selectedObj.layerIndex == prevObj.layerIndex {
                unifiedObjects.swapAt(selectedIndex - 1, selectedIndex)
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
            guard selectedIndex < unifiedObjects.count - 1 else { continue }

            let nextObj = unifiedObjects[selectedIndex + 1]

            // Only swap if both objects are in the same layer
            if selectedObj.layerIndex == nextObj.layerIndex {
                unifiedObjects.swapAt(selectedIndex, selectedIndex + 1)
            }
        }

        // Trigger UI update
        objectPositionUpdateTrigger.toggle()
    }
}
