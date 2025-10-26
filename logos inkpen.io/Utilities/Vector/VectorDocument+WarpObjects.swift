import SwiftUI
import Combine

extension VectorDocument {

    func unwrapWarpObject() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }

        var selectedWarpObjects: [VectorObject] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID],
               case .warp(let shape) = obj.objectType,
               shape.isWarpObject {
                selectedWarpObjects.append(obj)
            }
        }

        var oldShapes: [UUID: VectorShape] = [:]
        var affectedIDs: [UUID] = []
        for obj in selectedWarpObjects {
            if case .warp(let shape) = obj.objectType {
                oldShapes[shape.id] = shape
                affectedIDs.append(shape.id)
            }
        }

        for obj in selectedWarpObjects {
            if case .warp(let shape) = obj.objectType,
               let layerIndex = obj.layerIndex < layers.count ? obj.layerIndex : nil {
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

        var selectedWarpObjects: [VectorObject] = []
        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID],
               case .warp(let shape) = obj.objectType,
               shape.isWarpObject {
                selectedWarpObjects.append(obj)
            }
        }

        var oldShapes: [UUID: VectorShape] = [:]
        var affectedIDs: [UUID] = []
        for obj in selectedWarpObjects {
            if case .warp(let shape) = obj.objectType {
                oldShapes[shape.id] = shape
                affectedIDs.append(shape.id)
            }
        }

        for obj in selectedWarpObjects {
            if case .warp(let shape) = obj.objectType,
               let layerIndex = obj.layerIndex < layers.count ? obj.layerIndex : nil {
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
