import SwiftUI

extension VectorDocument {

    func removeShapeFromUnifiedSystem(id: UUID) {
        unifiedObjects.removeAll { obj in
            switch obj.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shape.id == id {
                    ImageContentRegistry.remove(for: id, in: self)
                    return true
                }
            case .text:
                break
            }
            return false
        }

        viewState.selectedObjectIDs.remove(id)
    }

    func removeTextFromUnifiedSystem(id: UUID) {

        unifiedObjects.removeAll { obj in
            if case .text(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }

        viewState.selectedObjectIDs.remove(id)

    }

    func updateEntireTextInUnified(id: UUID, updater: (inout VectorText) -> Void) {
        if let unifiedIndex = unifiedObjects.firstIndex(where: { obj in
            if case .text(let shape) = obj.objectType {
                return shape.id == id
            }
            return false
        }) {
            if case .text(let shape) = unifiedObjects[unifiedIndex].objectType,
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
            if case .text = obj.objectType {
                return true
            }
            return false
        }.count
    }

    func hasTextObjects() -> Bool {
        return unifiedObjects.contains { obj in
            if case .text = obj.objectType {
                return true
            }
            return false
        }
    }
    func getTextByID(_ id: UUID) -> VectorText? {
        for unifiedObject in unifiedObjects {
            if case .text(let shape) = unifiedObject.objectType,
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
            if case .text(let shape) = unifiedObject.objectType,
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
            if case .text = obj.objectType {
                return true
            }
            return false
        }

    }
}
