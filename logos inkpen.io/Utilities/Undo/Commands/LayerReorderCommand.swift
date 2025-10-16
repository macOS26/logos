import Foundation

class LayerReorderCommand: BaseCommand {
    private let sourceLayerId: UUID
    private let targetLayerId: UUID
    private let sourceIndex: Int
    private let targetIndex: Int
    private let affectedObjectUpdates: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]

    init(sourceLayerId: UUID, targetLayerId: UUID, sourceIndex: Int, targetIndex: Int, affectedObjectUpdates: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]) {
        self.sourceLayerId = sourceLayerId
        self.targetLayerId = targetLayerId
        self.sourceIndex = sourceIndex
        self.targetIndex = targetIndex
        self.affectedObjectUpdates = affectedObjectUpdates
    }

    override func execute(on document: VectorDocument) {
        applyReorder(forward: true, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyReorder(forward: false, to: document)
    }

    private func applyReorder(forward: Bool, to document: VectorDocument) {
        let fromIndex = forward ? sourceIndex : targetIndex
        let toIndex = forward ? targetIndex : sourceIndex

        guard fromIndex >= 0 && fromIndex < document.layers.count,
              toIndex >= 0 && toIndex < document.layers.count else {
            return
        }

        let layer = document.layers.remove(at: fromIndex)
        document.layers.insert(layer, at: toIndex)

        for update in affectedObjectUpdates {
            if let objIndex = document.unifiedObjects.firstIndex(where: { $0.id == update.objectID }) {
                let obj = document.unifiedObjects[objIndex]
                let newLayerIndex = forward ? update.newLayerIndex : update.oldLayerIndex

                if case .shape(let shape) = obj.objectType {
                    document.unifiedObjects[objIndex] = VectorObject(
                        shape: shape,
                        layerIndex: newLayerIndex,
                    )
                }
            }
        }

        if document.selectedLayerIndex == fromIndex {
            document.selectedLayerIndex = toIndex
        } else if let selectedIndex = document.selectedLayerIndex {
            if fromIndex < toIndex {
                if selectedIndex > fromIndex && selectedIndex <= toIndex {
                    document.selectedLayerIndex = selectedIndex - 1
                }
            } else {
                if selectedIndex >= toIndex && selectedIndex < fromIndex {
                    document.selectedLayerIndex = selectedIndex + 1
                }
            }
        }
    }
}
