import SwiftUI

extension VectorDocument {


    private func expandSelectionForClippingMasks(_ selectedIDs: Set<UUID>, in layerObjects: [VectorObject]) -> Set<UUID> {
        var expandedSelectedIDs = selectedIDs

        for selectedID in selectedIDs {
            if let selectedObject = findObject(by: selectedID),
               case .shape(let selectedShape) = selectedObject.objectType {

                if selectedShape.isClippingPath {
                    for obj in layerObjects {
                        if case .shape(let shape) = obj.objectType,
                           shape.clippedByShapeID == selectedShape.id {
                            expandedSelectedIDs.insert(obj.id)
                        }
                    }
                }
                else if let maskID = selectedShape.clippedByShapeID {
                    if let maskObject = findObject(by: maskID) {
                        expandedSelectedIDs.insert(maskObject.id)
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


    func bringSelectedToFront() {
        guard !selectedObjectIDs.isEmpty else { return }

        // Capture old orderIDs
        var oldOrderIDs: [UUID: Int] = [:]
        var newOrderIDs: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            let unselectedObjects = layerObjects.filter { !expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            // Capture old orderIDs before changes
            for obj in layerObjects {
                oldOrderIDs[obj.id] = obj.orderID
            }

            let currentOrderIDs = layerObjects.map { $0.orderID }
            let minOrderID = currentOrderIDs.min() ?? 0

            var newOrderID = minOrderID

            for unselectedObject in unselectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == unselectedObject.id }) {
                    newOrderIDs[unselectedObject.id] = newOrderID
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

            for selectedObject in selectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }) {
                    newOrderIDs[selectedObject.id] = newOrderID
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

        // Create command
        let command = BulkReorderCommand(oldOrderIDs: oldOrderIDs, newOrderIDs: newOrderIDs)
        executeCommand(command)
    }

    func bringSelectedForward() {
        guard !selectedObjectIDs.isEmpty else { return }

        // Capture old orderIDs
        var oldOrderIDs: [UUID: Int] = [:]
        var newOrderIDs: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            let sortedLayerObjects = layerObjects.sorted { $0.orderID < $1.orderID }

            // Capture old orderIDs before changes
            for obj in layerObjects {
                if oldOrderIDs[obj.id] == nil {
                    oldOrderIDs[obj.id] = obj.orderID
                }
            }

            for selectedObject in selectedObjects {
                if let currentIndex = sortedLayerObjects.firstIndex(where: { $0.id == selectedObject.id }),
                   currentIndex < sortedLayerObjects.count - 1 {
                    let objectInFront = sortedLayerObjects[currentIndex + 1]

                    if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }),
                       let frontIndex = unifiedObjects.firstIndex(where: { $0.id == objectInFront.id }) {

                        let selectedOrderID = unifiedObjects[selectedIndex].orderID
                        let frontOrderID = unifiedObjects[frontIndex].orderID

                        newOrderIDs[selectedObject.id] = frontOrderID
                        newOrderIDs[objectInFront.id] = selectedOrderID

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
                        }
                    }
                }
            }
        }

        // Create command
        let command = BulkReorderCommand(oldOrderIDs: oldOrderIDs, newOrderIDs: newOrderIDs)
        executeCommand(command)
    }

    func sendSelectedBackward() {
        guard !selectedObjectIDs.isEmpty else { return }

        // Capture old orderIDs
        var oldOrderIDs: [UUID: Int] = [:]
        var newOrderIDs: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            let sortedLayerObjects = layerObjects.sorted { $0.orderID < $1.orderID }

            // Capture old orderIDs before changes
            for obj in layerObjects {
                if oldOrderIDs[obj.id] == nil {
                    oldOrderIDs[obj.id] = obj.orderID
                }
            }

            for selectedObject in selectedObjects {
                if let currentIndex = sortedLayerObjects.firstIndex(where: { $0.id == selectedObject.id }),
                   currentIndex > 0 {
                    let objectBehind = sortedLayerObjects[currentIndex - 1]

                    if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }),
                       let behindIndex = unifiedObjects.firstIndex(where: { $0.id == objectBehind.id }) {

                        let selectedOrderID = unifiedObjects[selectedIndex].orderID
                        let behindOrderID = unifiedObjects[behindIndex].orderID

                        newOrderIDs[selectedObject.id] = behindOrderID
                        newOrderIDs[objectBehind.id] = selectedOrderID

                        switch selectedObject.objectType {
                        case .shape(let shape):
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
                        }
                    }
                }
            }
        }

        // Create command
        let command = BulkReorderCommand(oldOrderIDs: oldOrderIDs, newOrderIDs: newOrderIDs)
        executeCommand(command)
    }

    func sendSelectedToBack() {
        guard !selectedObjectIDs.isEmpty else { return }

        // Capture old orderIDs
        var oldOrderIDs: [UUID: Int] = [:]
        var newOrderIDs: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            let unselectedObjects = layerObjects.filter { !expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            // Capture old orderIDs before changes
            for obj in layerObjects {
                oldOrderIDs[obj.id] = obj.orderID
            }

            let currentOrderIDs = layerObjects.map { $0.orderID }
            let minOrderID = currentOrderIDs.min() ?? 0

            var newOrderID = minOrderID

            for selectedObject in selectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }) {
                    newOrderIDs[selectedObject.id] = newOrderID
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

            for unselectedObject in unselectedObjects {
                if let index = unifiedObjects.firstIndex(where: { $0.id == unselectedObject.id }) {
                    newOrderIDs[unselectedObject.id] = newOrderID
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

        // Create command
        let command = BulkReorderCommand(oldOrderIDs: oldOrderIDs, newOrderIDs: newOrderIDs)
        executeCommand(command)
    }
}
