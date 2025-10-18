import SwiftUI
import SwiftUI
import Combine

extension VectorDocument {

    @available(*, deprecated, message: "Use populateUnifiedObjectsFromLayersPreservingOrder() instead - this function reverses order!")
    internal func populateUnifiedObjectsFromLayers() {
        Log.error("⚠️ CRITICAL BUG PREVENTED: populateUnifiedObjectsFromLayers() blocked to prevent layer corruption! Using safe version.", category: .error)
        populateUnifiedObjectsFromLayersPreservingOrder()
        return
    }

    internal func populateUnifiedObjectsFromLayersPreservingOrder() {
        if isUndoRedoOperation {
            return
        }

    }

    func syncSelectionArrays() {

        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()

        for objectID in selectedObjectIDs {
            if let unifiedObject = findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .text(let shape):
                    selectedTextIDs.insert(shape.id)
                case .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    selectedShapeIDs.insert(shape.id)
                }
            }
        }
    }

    func syncUnifiedSelectionFromLegacy() {
        selectedObjectIDs.removeAll()

        let allSelectedIDs = selectedShapeIDs.union(selectedTextIDs)

        for object in unifiedObjects {
            if allSelectedIDs.contains(object.id) {
                selectedObjectIDs.insert(object.id)
            }
        }
    }
}
