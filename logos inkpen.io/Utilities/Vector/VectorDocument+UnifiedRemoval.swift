import SwiftUI

extension VectorDocument {

    func removeShapeFromUnifiedSystem(id: UUID) {
        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                if shape.id == id {
                    ImageContentRegistry.remove(for: id)
                    return true
                }
            }
            return false
        }

        selectedShapeIDs.remove(id)
        selectedTextIDs.remove(id)
        if let unifiedObj = findObject(by: id) {
            selectedObjectIDs.remove(unifiedObj.id)
        }
    }

    func removeTextFromUnifiedSystem(id: UUID) {

        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && shape.isTextObject
            }
            return false
        }

        selectedTextIDs.remove(id)
        if let unifiedObj = findObject(by: id) {
            selectedObjectIDs.remove(unifiedObj.id)
        }

    }

    func updateEntireTextInUnified(id: UUID, updater: (inout VectorText) -> Void) {
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.id == id && shape.isTextObject
            }
            return false
        }) {
            if case .shape(let shape) = unifiedObjects[unifiedIndex].objectType,
               var vectorText = VectorText.from(shape) {

                updater(&vectorText)

                let updatedShape = VectorShape.from(vectorText)
                let layerIndex = unifiedObjects[unifiedIndex].layerIndex
                unifiedObjects[unifiedIndex] = VectorObject(
                    shape: updatedShape,
                    layerIndex: layerIndex,
                )

            }
        }
    }

    func getTextCount() -> Int {
        return unifiedObjects.filter { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }.count
    }

    func hasTextObjects() -> Bool {
        return unifiedObjects.contains { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }
    }
    func getTextByID(_ id: UUID) -> VectorText? {
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               shape.isTextObject,
               shape.id == id,
               var vectorText = VectorText.from(shape) {
                vectorText.layerIndex = unifiedObject.layerIndex
                return vectorText
            }
        }
        return nil
    }

    func getFirstText(where predicate: (VectorText) -> Bool) -> VectorText? {
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               shape.isTextObject,
               var vectorText = VectorText.from(shape) {
                vectorText.layerIndex = unifiedObject.layerIndex
                if predicate(vectorText) {
                    return vectorText
                }
            }
        }
        return nil
    }

    func removeAllText() {
        unifiedObjects.removeAll { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.isTextObject
            }
            return false
        }

    }
}
