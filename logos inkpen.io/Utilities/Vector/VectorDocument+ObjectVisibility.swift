import SwiftUI

extension VectorDocument {

    func lockSelectedObjects() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        let allIDs = viewState.selectedObjectIDs
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        for id in allIDs {
            if let obj = unifiedObjects.first(where: { $0.id == id }) {
                switch obj.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    oldValues[id] = shape.isLocked
                    newValues[id] = true
                }
            }
        }

        let command = VisibilityCommand(
            objectIDs: Array(allIDs),
            property: .locked,
            oldValues: oldValues,
            newValues: newValues
        )
        executeCommand(command)

        viewState.selectedObjectIDs.removeAll()
    }

    func unlockAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }

        var affectedIDs: [UUID] = []
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        for obj in unifiedObjects where obj.layerIndex == layerIndex {
            switch obj.objectType {
            case .text(let shape),
                 .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shape.isLocked {
                    affectedIDs.append(obj.id)
                    oldValues[obj.id] = true
                    newValues[obj.id] = false
                }
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
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        let allIDs = viewState.selectedObjectIDs
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]

        for id in allIDs {
            if let obj = unifiedObjects.first(where: { $0.id == id }) {
                switch obj.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    oldValues[id] = shape.isVisible
                    newValues[id] = false
                }
            }
        }

        let command = VisibilityCommand(
            objectIDs: Array(allIDs),
            property: .visibility,
            oldValues: oldValues,
            newValues: newValues
        )
        executeCommand(command)

        viewState.selectedObjectIDs.removeAll()
    }

    func showAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }

        var affectedIDs: [UUID] = []
        var oldValues: [UUID: Bool] = [:]
        var newValues: [UUID: Bool] = [:]
        let shapes = getShapesForLayer(layerIndex)
        for (shapeIndex, shape) in shapes.enumerated() {
            if !shape.isVisible {
                affectedIDs.append(shape.id)
                oldValues[shape.id] = false
                newValues[shape.id] = true

                var updatedShape = shape
                updatedShape.isVisible = true
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            }
        }

        for unifiedObj in unifiedObjects {
            if case .text(let shape) = unifiedObj.objectType, shape.isVisible == false {
                affectedIDs.append(shape.id)
                oldValues[shape.id] = false
                newValues[shape.id] = true

                showTextInUnified(id: shape.id)
            }
        }

        if !affectedIDs.isEmpty {
            let command = VisibilityCommand(
                objectIDs: affectedIDs,
                property: .visibility,
                oldValues: oldValues,
                newValues: newValues
            )
            executeCommand(command)
        }
    }
}
