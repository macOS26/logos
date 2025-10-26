import Foundation

class LayerObjectOrderCommand: BaseCommand {
    private let layerIndex: Int
    private let oldObjectIDs: [UUID]
    private let newObjectIDs: [UUID]

    init(layerIndex: Int, oldObjectIDs: [UUID], newObjectIDs: [UUID]) {
        self.layerIndex = layerIndex
        self.oldObjectIDs = oldObjectIDs
        self.newObjectIDs = newObjectIDs
    }

    override func execute(on document: VectorDocument) {
        applyOrder(newObjectIDs, to: document)
        document.triggerLayerUpdate(for: layerIndex)
    }

    override func undo(on document: VectorDocument) {
        applyOrder(oldObjectIDs, to: document)
        document.triggerLayerUpdate(for: layerIndex)
    }

    private func applyOrder(_ objectIDs: [UUID], to document: VectorDocument) {
        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }

        // Update snapshot layer
        var layer = document.snapshot.layers[layerIndex]
        layer.objectIDs = objectIDs
        document.snapshot.layers[layerIndex] = layer

        // Update VectorLayer in layers array if needed
        if layerIndex < document.layers.count {
            _ = document.layers[layerIndex]
            // VectorLayer might have different structure, just update snapshot is enough
            // The layers array should be synced from snapshot elsewhere
        }
    }
}
