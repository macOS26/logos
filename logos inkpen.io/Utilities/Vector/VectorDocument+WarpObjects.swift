
import SwiftUI
import Combine

extension VectorDocument {


    func unwrapWarpObject() {
        guard !selectedObjectIDs.isEmpty else { return }

        saveToUndoStack()

        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }

        for unifiedObject in selectedWarpObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
               let shapes = getShapesForLayer(layerIndex)
               if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {

                if let unwrappedShape = shape.unwrapWarpObject() {
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: unwrappedShape)

                    if let unifiedIndex = unifiedObjects.firstIndex(where: { $0.id == shape.id }) {
                        unifiedObjects[unifiedIndex] = VectorObject(shape: unwrappedShape, layerIndex: layerIndex, orderID: unifiedObjects[unifiedIndex].orderID)
                    }

                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(unwrappedShape.id)

                }
               }
            }
        }

        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }

    func expandWarpObject() {
        guard !selectedObjectIDs.isEmpty else { return }

        saveToUndoStack()

        let selectedWarpObjects = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) else { return false }
            if case .shape(let shape) = unifiedObject.objectType {
                return shape.isWarpObject
            }
            return false
        }

        for unifiedObject in selectedWarpObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               let layerIndex = unifiedObject.layerIndex < layers.count ? unifiedObject.layerIndex : nil {
               let shapes = getShapesForLayer(layerIndex)
               if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {

                if let expandedShape = shape.expandWarpObject() {
                    setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: expandedShape)

                    if let unifiedIndex = unifiedObjects.firstIndex(where: { $0.id == shape.id }) {
                        unifiedObjects[unifiedIndex] = VectorObject(shape: expandedShape, layerIndex: layerIndex, orderID: unifiedObjects[unifiedIndex].orderID)
                    }

                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(expandedShape.id)

                }
               }
            }
        }

        updateUnifiedObjectsOptimized()
        objectWillChange.send()
    }
}
