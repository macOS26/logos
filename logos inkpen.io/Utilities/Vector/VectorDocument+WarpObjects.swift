import SwiftUI
import Combine

extension VectorDocument {


    func unwrapWarpObject() {
        guard !selectedObjectIDs.isEmpty else { return }

        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }

        // Capture old/new shapes
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]

        for unifiedObject in selectedWarpObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
               let shapes = getShapesForLayer(layerIndex)
               if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {

                if let unwrappedShape = shape.unwrapWarpObject() {
                    oldShapes[shape.id] = shape
                    newShapes[shape.id] = unwrappedShape

                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: unwrappedShape)

                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(unwrappedShape.id)
                }
               }
            }
        }

        if !oldShapes.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: Array(oldShapes.keys),
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            executeCommand(command)
        }

        populateUnifiedObjectsFromLayersPreservingOrder()
    }

    func expandWarpObject() {
        guard !selectedObjectIDs.isEmpty else { return }

        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }

        // Capture old/new shapes
        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]

        for unifiedObject in selectedWarpObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
               let shapes = getShapesForLayer(layerIndex)
               if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {

                if let expandedShape = shape.expandWarpObject() {
                    oldShapes[shape.id] = shape
                    newShapes[shape.id] = expandedShape

                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: expandedShape)

                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(expandedShape.id)
                }
               }
            }
        }

        if !oldShapes.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: Array(oldShapes.keys),
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            executeCommand(command)
        }

        populateUnifiedObjectsFromLayersPreservingOrder()
    }
}
