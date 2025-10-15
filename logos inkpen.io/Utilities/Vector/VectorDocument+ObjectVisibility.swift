import SwiftUI

extension VectorDocument {


    func lockSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }

        let allIDs = selectedShapeIDs.union(selectedTextIDs)
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        for id in allIDs {
            if let obj = unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                oldValues[id] = shape.isLocked
                newValues[id] = true
            }
        }

        let command = VisibilityCommand(
            objectIDs: Array(allIDs),
            property: .locked,
            oldValues: oldValues,
            newValues: newValues
        )
        executeCommand(command)

        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }

    func unlockAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }

        var affectedIDs: [UUID] = []
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        for obj in unifiedObjects where obj.layerIndex == layerIndex {
            if case .shape(let shape) = obj.objectType, shape.isLocked {
                affectedIDs.append(obj.id)
                oldValues[obj.id] = true
                newValues[obj.id] = false
            }
        }

        if !affectedIDs.isEmpty {
            let command = VisibilityCommand(
                objectIDs: affectedIDs,
                property: .locked,
                oldValues: oldValues,
                newValues: newValues
            )
            executeCommand(command)
        }
    }


    func hideSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }

        let allIDs = selectedShapeIDs.union(selectedTextIDs)
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        for id in allIDs {
            if let obj = unifiedObjects.first(where: { $0.id == id }),
               case .shape(let shape) = obj.objectType {
                oldValues[id] = shape.isVisible
                newValues[id] = false
            }
        }

        let command = VisibilityCommand(
            objectIDs: Array(allIDs),
            property: .visibility,
            oldValues: oldValues,
            newValues: newValues
        )
        executeCommand(command)

        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }

    func showAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }

        saveToUndoStack()

        var shownCount = 0

        let shapes = getShapesForLayer(layerIndex)
        for (shapeIndex, shape) in shapes.enumerated() {
            if !shape.isVisible {
                var updatedShape = shape
                updatedShape.isVisible = true
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                shownCount += 1
            }
        }

        for unifiedObj in unifiedObjects {
            if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject, shape.isVisible == false {
                showTextInUnified(id: shape.id)
                shownCount += 1
            }
        }

    }
}
