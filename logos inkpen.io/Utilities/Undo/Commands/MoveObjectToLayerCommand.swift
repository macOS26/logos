import Foundation

class MoveObjectToLayerCommand: BaseCommand {
    private let moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]

    init(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int) {
        self.moves = [(objectID: objectID, oldLayerIndex: oldLayerIndex, newLayerIndex: newLayerIndex)]
    }

    init(moves: [(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int)]) {
        self.moves = moves
    }

    override func execute(on document: VectorDocument) {
        for move in moves {
            applyMove(objectID: move.objectID, toLayerIndex: move.newLayerIndex, document: document)
        }
    }

    override func undo(on document: VectorDocument) {
        for move in moves.reversed() {
            applyMove(objectID: move.objectID, toLayerIndex: move.oldLayerIndex, document: document)
        }
    }

    private func applyMove(objectID: UUID, toLayerIndex: Int, document: VectorDocument) {
        guard let object = document.snapshot.objects[objectID] else {
            return
        }

        let oldLayerIndex = object.layerIndex

        // Remove from old layer's objectIDs
        if oldLayerIndex >= 0 && oldLayerIndex < document.snapshot.layers.count {
            if let index = document.snapshot.layers[oldLayerIndex].objectIDs.firstIndex(of: objectID) {
                document.snapshot.layers[oldLayerIndex].objectIDs.remove(at: index)
            }
        }

        // Add to new layer's objectIDs
        if toLayerIndex >= 0 && toLayerIndex < document.snapshot.layers.count {
            document.snapshot.layers[toLayerIndex].objectIDs.append(objectID)
        }

        // Update the object's layerIndex in snapshot.objects
        switch object.objectType {
        case .text(let shape),
             .shape(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            document.snapshot.objects[objectID] = VectorObject(
                shape: shape,
                layerIndex: toLayerIndex
            )
        }

        document.changeNotifier.notifyLayersChanged()
    }
}
