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

                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(unwrappedShape.id)

                }
               }
            }
        }

        populateUnifiedObjectsFromLayersPreservingOrder()
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

                    selectedObjectIDs.remove(shape.id)
                    selectedObjectIDs.insert(expandedShape.id)

                }
               }
            }
        }

        populateUnifiedObjectsFromLayersPreservingOrder()
        objectWillChange.send()
    }
}
