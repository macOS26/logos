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

        var affectedObjectIDs: [UUID] = []
        var oldIndices: [UUID: Int] = [:]
        var newIndices: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects.map { $0.element })
            let selectedIndices = layerObjects.filter { expandedSelectedIDs.contains($0.element.id) }.map { $0.offset }
            let unselectedIndices = layerObjects.filter { !expandedSelectedIDs.contains($0.element.id) }.map { $0.offset }

            guard !selectedIndices.isEmpty else { continue }

            for index in layerObjects.map({ $0.offset }) {
                let obj = unifiedObjects[index]
                oldIndices[obj.id] = index
                affectedObjectIDs.append(obj.id)
            }

            var removedObjects: [VectorObject] = []
            for index in selectedIndices.sorted(by: >) {
                removedObjects.insert(unifiedObjects.remove(at: index), at: 0)
            }

            if let lastUnselectedIndex = unselectedIndices.max() {
                var insertionPoint = lastUnselectedIndex - selectedIndices.filter { $0 < lastUnselectedIndex }.count + 1
                for obj in removedObjects {
                    unifiedObjects.insert(obj, at: insertionPoint)
                    insertionPoint += 1
                }
            } else {
                for obj in removedObjects.reversed() {
                    unifiedObjects.insert(obj, at: layerObjects.first!.offset)
                }
            }
        }

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

    func bringSelectedForward() {
        guard !selectedObjectIDs.isEmpty else { return }

        var affectedObjectIDs: [UUID] = []
        var oldIndices: [UUID: Int] = [:]
        var newIndices: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects.map { $0.element })

            for index in layerObjects.map({ $0.offset }) {
                let obj = unifiedObjects[index]
                oldIndices[obj.id] = index
                affectedObjectIDs.append(obj.id)
            }

            var tempObjects = unifiedObjects
            let sortedIndices = layerObjects.map { $0.offset }.sorted(by: >)
            for index in sortedIndices {
                let obj = tempObjects[index]
                if expandedSelectedIDs.contains(obj.id) && index < tempObjects.count - 1 {
                    let nextObj = tempObjects[index + 1]
                    if nextObj.layerIndex == layerIndex && !expandedSelectedIDs.contains(nextObj.id) {
                        tempObjects.swapAt(index, index + 1)
                    }
                }
            }

            for id in affectedObjectIDs {
                if let index = tempObjects.firstIndex(where: { $0.id == id }) {
                    newIndices[id] = index
                }
            }
        }

        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldIndices: oldIndices,
            newIndices: newIndices
        )
        commandManager.execute(command)
    }

    func sendSelectedBackward() {
        guard !selectedObjectIDs.isEmpty else { return }

        var affectedObjectIDs: [UUID] = []
        var oldIndices: [UUID: Int] = [:]
        var newIndices: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects.map { $0.element })

            for index in layerObjects.map({ $0.offset }) {
                let obj = unifiedObjects[index]
                oldIndices[obj.id] = index
                affectedObjectIDs.append(obj.id)
            }

            var tempObjects = unifiedObjects
            let sortedIndices = layerObjects.map { $0.offset }.sorted()
            for index in sortedIndices {
                let obj = tempObjects[index]
                if expandedSelectedIDs.contains(obj.id) && index > 0 {
                    let prevObj = tempObjects[index - 1]
                    if prevObj.layerIndex == layerIndex && !expandedSelectedIDs.contains(prevObj.id) {
                        tempObjects.swapAt(index, index - 1)
                    }
                }
            }

            for id in affectedObjectIDs {
                if let index = tempObjects.firstIndex(where: { $0.id == id }) {
                    newIndices[id] = index
                }
            }
        }

        let command = ObjectArrangementCommand(
            affectedObjectIDs: affectedObjectIDs,
            oldIndices: oldIndices,
            newIndices: newIndices
        )
        commandManager.execute(command)
    }

    func sendSelectedToBack() {
        guard !selectedObjectIDs.isEmpty else { return }

        var affectedObjectIDs: [UUID] = []
        var oldIndices: [UUID: Int] = [:]
        var newIndices: [UUID: Int] = [:]

        for layerIndex in layers.indices {
            let layerObjects = unifiedObjects.enumerated().filter { $0.element.layerIndex == layerIndex }
            guard !layerObjects.isEmpty else { continue }

            let expandedSelectedIDs = expandSelectionForClippingMasks(selectedObjectIDs, in: layerObjects.map { $0.element })
            let selectedIndices = layerObjects.filter { expandedSelectedIDs.contains($0.element.id) }.map { $0.offset }
            let unselectedIndices = layerObjects.filter { !expandedSelectedIDs.contains($0.element.id) }.map { $0.offset }

            guard !selectedIndices.isEmpty else { continue }

            for index in layerObjects.map({ $0.offset }) {
                let obj = unifiedObjects[index]
                oldIndices[obj.id] = index
                affectedObjectIDs.append(obj.id)
            }

            var removedObjects: [VectorObject] = []
            for index in selectedIndices.sorted(by: >) {
                removedObjects.insert(unifiedObjects.remove(at: index), at: 0)
            }

            if let firstUnselectedIndex = unselectedIndices.min() {
                let insertionPoint = firstUnselectedIndex
                for obj in removedObjects.reversed() {
                    unifiedObjects.insert(obj, at: insertionPoint)
                }
            } else {
                for obj in removedObjects.reversed() {
                    unifiedObjects.insert(obj, at: layerObjects.first!.offset)
                }
            }
        }

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
