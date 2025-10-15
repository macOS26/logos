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

        // Capture old state
        var oldOrderIDs: [UUID: Int] = [:]
        var affectedObjectIDs: [UUID] = []

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            for obj in layerObjects {
                oldOrderIDs[obj.id] = obj.orderID
                affectedObjectIDs.append(obj.id)
            }
        }

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            let unselectedObjects = layerObjects.filter { !expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            let currentOrderIDs = layerObjects.map { $0.orderID }
            let minOrderID = currentOrderIDs.min() ?? 0

            var newOrderID = minOrderID

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

        // Capture new state and create command
        var newOrderIDs: [UUID: Int] = [:]
        for id in affectedObjectIDs {
            if let index = unifiedObjects.firstIndex(where: { $0.id == id }) {
                newOrderIDs[id] = unifiedObjects[index].orderID
            }
        }
        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldOrderIDs: oldOrderIDs,
            newOrderIDs: newOrderIDs
        )
        commandManager.execute(command)
    }

    func bringSelectedForward() {
        guard !selectedObjectIDs.isEmpty else { return }

        // Capture old state
        var oldOrderIDs: [UUID: Int] = [:]
        var affectedObjectIDs: [UUID] = []

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            for obj in layerObjects {
                oldOrderIDs[obj.id] = obj.orderID
                affectedObjectIDs.append(obj.id)
            }
        }

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            let sortedLayerObjects = layerObjects.sorted { $0.orderID < $1.orderID }

            for selectedObject in selectedObjects {
                if let currentIndex = sortedLayerObjects.firstIndex(where: { $0.id == selectedObject.id }),
                   currentIndex < sortedLayerObjects.count - 1 {
                    let objectInFront = sortedLayerObjects[currentIndex + 1]

                    if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }),
                       let frontIndex = unifiedObjects.firstIndex(where: { $0.id == objectInFront.id }) {

                        let selectedOrderID = unifiedObjects[selectedIndex].orderID
                        let frontOrderID = unifiedObjects[frontIndex].orderID

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

        // Capture new state and create command
        var newOrderIDs: [UUID: Int] = [:]
        for id in affectedObjectIDs {
            if let index = unifiedObjects.firstIndex(where: { $0.id == id }) {
                newOrderIDs[id] = unifiedObjects[index].orderID
            }
        }
        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldOrderIDs: oldOrderIDs,
            newOrderIDs: newOrderIDs
        )
        commandManager.execute(command)
    }

    func sendSelectedBackward() {
        guard !selectedObjectIDs.isEmpty else { return }

        // Capture old state
        var oldOrderIDs: [UUID: Int] = [:]
        var affectedObjectIDs: [UUID] = []

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            for obj in layerObjects {
                oldOrderIDs[obj.id] = obj.orderID
                affectedObjectIDs.append(obj.id)
            }
        }

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            let sortedLayerObjects = layerObjects.sorted { $0.orderID < $1.orderID }

            for selectedObject in selectedObjects {
                if let currentIndex = sortedLayerObjects.firstIndex(where: { $0.id == selectedObject.id }),
                   currentIndex > 0 {
                    let objectBehind = sortedLayerObjects[currentIndex - 1]

                    if let selectedIndex = unifiedObjects.firstIndex(where: { $0.id == selectedObject.id }),
                       let behindIndex = unifiedObjects.firstIndex(where: { $0.id == objectBehind.id }) {

                        let selectedOrderID = unifiedObjects[selectedIndex].orderID
                        let behindOrderID = unifiedObjects[behindIndex].orderID

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

        // Capture new state and create command
        var newOrderIDs: [UUID: Int] = [:]
        for id in affectedObjectIDs {
            if let index = unifiedObjects.firstIndex(where: { $0.id == id }) {
                newOrderIDs[id] = unifiedObjects[index].orderID
            }
        }
        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldOrderIDs: oldOrderIDs,
            newOrderIDs: newOrderIDs
        )
        commandManager.execute(command)
    }

    func sendSelectedToBack() {
        guard !selectedObjectIDs.isEmpty else { return }

        // Capture old state
        var oldOrderIDs: [UUID: Int] = [:]
        var affectedObjectIDs: [UUID] = []

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            for obj in layerObjects {
                oldOrderIDs[obj.id] = obj.orderID
                affectedObjectIDs.append(obj.id)
            }
        }

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.filter { $0.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects)

            let selectedObjects = layerObjects.filter { expandedSelectedIDs.contains($0.id) }
            let unselectedObjects = layerObjects.filter { !expandedSelectedIDs.contains($0.id) }

            guard !selectedObjects.isEmpty else { continue }

            let currentOrderIDs = layerObjects.map { $0.orderID }
            let minOrderID = currentOrderIDs.min() ?? 0

            var newOrderID = minOrderID

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

        // Capture new state and create command
        var newOrderIDs: [UUID: Int] = [:]
        for id in affectedObjectIDs {
            if let index = unifiedObjects.firstIndex(where: { $0.id == id }) {
                newOrderIDs[id] = unifiedObjects[index].orderID
            }
        }
        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldOrderIDs: oldOrderIDs,
            newOrderIDs: newOrderIDs
        )
        commandManager.execute(command)
    }
}
