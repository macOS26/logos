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
        guard let objectIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectID }) else {
            return
        }

        let object = document.unifiedObjects[objectIndex]

        switch object.objectType {
        case .text(let shape),
             .shape(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            document.unifiedObjects[objectIndex] = VectorObject(
                shape: shape,
                layerIndex: toLayerIndex,
            )
        }
    }
}
