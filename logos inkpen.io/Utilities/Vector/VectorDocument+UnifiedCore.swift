import SwiftUI

extension VectorDocument {

    func syncShapeToLayer(_ shape: VectorShape, at layerIndex: Int) {
    }

    func getShapeAtIndex(layerIndex: Int, shapeIndex: Int) -> VectorShape? {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return nil }
        return shapes[shapeIndex]
    }

    func getShapeCount(layerIndex: Int) -> Int {
        return getShapesForLayer(layerIndex).count
    }

    func setShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return }
        let oldShape = shapes[shapeIndex]

        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == oldShape.id
            }
            return false
        }) {
            let orderID = unifiedObjects[index].orderID
            unifiedObjects[index] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        }
    }

    func updateShapeByID(_ shapeID: UUID, update: (inout VectorShape) -> Void) {
        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == shapeID
            }
            return false
        }) {
            if case .shape(var shape) = unifiedObjects[index].objectType {
                update(&shape)
                let orderID = unifiedObjects[index].orderID
                let layerIndex = unifiedObjects[index].layerIndex
                unifiedObjects[index] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
            }
            return
        }

        for groupIndex in unifiedObjects.indices {
            if case .shape(var groupShape) = unifiedObjects[groupIndex].objectType,
               groupShape.isGroupContainer {
                if let childIndex = groupShape.groupedShapes.firstIndex(where: { $0.id == shapeID }) {
                    var childShape = groupShape.groupedShapes[childIndex]
                    update(&childShape)
                    groupShape.groupedShapes[childIndex] = childShape

                    let orderID = unifiedObjects[groupIndex].orderID
                    let layerIndex = unifiedObjects[groupIndex].layerIndex
                    unifiedObjects[groupIndex] = VectorObject(shape: groupShape, layerIndex: layerIndex, orderID: orderID)
                    return
                }
            }
        }
    }

    func getShapesForLayer(_ layerIndex: Int) -> [VectorShape] {
        return getObjectsInLayer(layerIndex)
            .sorted { $0.orderID < $1.orderID }
            .compactMap { object -> VectorShape? in
                if case .shape(let shape) = object.objectType {
                    return shape
                }
                return nil
            }
    }

    private func getNextOrderID(for layerIndex: Int) -> Int {
        let existingOrderIDs = getObjectsInLayer(layerIndex).map { $0.orderID }
        return existingOrderIDs.isEmpty ? 0 : (existingOrderIDs.max() ?? -1) + 1
    }

    func addShapeToUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }

        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }

        if isUndoRedoOperation {
            if let existingObject = findObject(by: shape.id) {
                let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: existingObject.orderID)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let orderID = getNextOrderID(for: layerIndex)
        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }

    func addShapeToFrontOfUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }

        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }

        if isUndoRedoOperation {
            if let existingObject = findObject(by: shape.id) {
                let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: existingObject.orderID)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let existingOrderIDs = getObjectsInLayer(layerIndex).map { $0.orderID }
        let highestOrderID = existingOrderIDs.isEmpty ? 0 : (existingOrderIDs.max() ?? 0)
        let orderID = highestOrderID + 1

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }

    func addShapeBehindInUnifiedSystem(_ shape: VectorShape, layerIndex: Int, behindShapeIDs: Set<UUID>) {
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }

        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }

        let layerObjects = getObjectsInLayer(layerIndex)
        let targetOrderIDs = layerObjects.compactMap { unifiedObj -> Int? in
            switch unifiedObj.objectType {
            case .shape(let existingShape):
                return behindShapeIDs.contains(existingShape.id) ? unifiedObj.orderID : nil
            }
        }

        let orderID: Int
        if let minTargetOrderID = targetOrderIDs.min() {
            orderID = minTargetOrderID - 1
        } else {
            let existingOrderIDs = layerObjects.map { $0.orderID }
            orderID = (existingOrderIDs.min() ?? 0) - 1
        }

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)
    }

    func addTextToUnifiedSystem(_ text: VectorText, layerIndex: Int) {

        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == text.id && existingShape.isTextObject
            }
            return false
        }

        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }

        var textWithLayer = text
        textWithLayer.layerIndex = layerIndex
        let textShape = VectorShape.from(textWithLayer)

        if isUndoRedoOperation {
            if let existingObject = findObject(by: text.id) {
                let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex, orderID: existingObject.orderID)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let orderID = getNextOrderID(for: layerIndex)
        let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex, orderID: orderID)
        unifiedObjects.append(unifiedObject)

    }
}
