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
            unifiedObjects[index] = VectorObject(shape: shape, layerIndex: layerIndex)
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
                let layerIndex = unifiedObjects[index].layerIndex
                unifiedObjects[index] = VectorObject(shape: shape, layerIndex: layerIndex)
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

                    let layerIndex = unifiedObjects[groupIndex].layerIndex
                    unifiedObjects[groupIndex] = VectorObject(shape: groupShape, layerIndex: layerIndex)
                    return
                }
            }
        }
    }

    func getShapesForLayer(_ layerIndex: Int) -> [VectorShape] {
        // Array position IS the order now - no sorting needed
        return getObjectsInLayer(layerIndex)
            .compactMap { object -> VectorShape? in
                if case .shape(let shape) = object.objectType {
                    return shape
                }
                return nil
            }
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
                let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
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
                let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
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

        // Find the first object that should be "behind" (i.e., we insert before it)
        var insertIndex: Int?
        for (index, unifiedObj) in unifiedObjects.enumerated() {
            if unifiedObj.layerIndex == layerIndex {
                if case .shape(let existingShape) = unifiedObj.objectType {
                    if behindShapeIDs.contains(existingShape.id) {
                        insertIndex = index
                        break
                    }
                }
            }
        }

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
        if let insertIndex = insertIndex {
            unifiedObjects.insert(unifiedObject, at: insertIndex)
        } else {
            unifiedObjects.append(unifiedObject)
        }
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
                let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex)
        unifiedObjects.append(unifiedObject)

    }
}
