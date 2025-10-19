import SwiftUI
import Combine

extension VectorDocument {

    func unwrapWarpObject() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard viewState.selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .warp(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }

        var oldShapes: [UUID: VectorShape] = [:]
        var affectedIDs: [UUID] = []
        for unifiedObject in selectedWarpObjects {
            if case .warp(let shape) = unifiedObject.objectType {
                oldShapes[shape.id] = shape
                affectedIDs.append(shape.id)
            }
        }

        for unifiedObject in selectedWarpObjects {
            if case .warp(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
               let shapes = getShapesForLayer(layerIndex)
               if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {

                if let unwrappedShape = shape.unwrapWarpObject() {
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: unwrappedShape)

                    viewState.selectedObjectIDs.remove(shape.id)
                    viewState.selectedObjectIDs.insert(unwrappedShape.id)

                }
               }
            }
        }

        populateUnifiedObjectsFromLayersPreservingOrder()

        var newShapes: [UUID: VectorShape] = [:]
        for id in affectedIDs {
            if let shape = findShape(by: id) {
                newShapes[id] = shape
            }
        }

        let command = WarpObjectCommand(
            affectedObjectIDs: affectedIDs,
            oldShapes: oldShapes,
            newShapes: newShapes
        )
        commandManager.execute(command)
    }

    func expandWarpObject() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard viewState.selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .warp(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }

        var oldShapes: [UUID: VectorShape] = [:]
        var affectedIDs: [UUID] = []
        for unifiedObject in selectedWarpObjects {
            if case .warp(let shape) = unifiedObject.objectType {
                oldShapes[shape.id] = shape
                affectedIDs.append(shape.id)
            }
        }

        for unifiedObject in selectedWarpObjects {
            if case .warp(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
               let shapes = getShapesForLayer(layerIndex)
               if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {

                if let expandedShape = shape.expandWarpObject() {
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: expandedShape)

                    viewState.selectedObjectIDs.remove(shape.id)
                    viewState.selectedObjectIDs.insert(expandedShape.id)

                }
               }
            }
        }

        populateUnifiedObjectsFromLayersPreservingOrder()

        var newShapes: [UUID: VectorShape] = [:]
        for id in affectedIDs {
            if let shape = findShape(by: id) {
                newShapes[id] = shape
            }
        }

        let command = WarpObjectCommand(
            affectedObjectIDs: affectedIDs,
            oldShapes: oldShapes,
            newShapes: newShapes
        )
        commandManager.execute(command)
    }
}
