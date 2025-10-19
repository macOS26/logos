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

}
