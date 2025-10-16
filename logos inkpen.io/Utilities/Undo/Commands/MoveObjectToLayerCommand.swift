import Foundation

class MoveObjectToLayerCommand: BaseCommand {
    private let objectID: UUID
    private let oldLayerIndex: Int
    private let newLayerIndex: Int

    init(objectID: UUID, oldLayerIndex: Int, newLayerIndex: Int) {
        self.objectID = objectID
        self.oldLayerIndex = oldLayerIndex
        self.newLayerIndex = newLayerIndex
    }

    override func execute(on document: VectorDocument) {
        applyMove(toLayerIndex: newLayerIndex, document: document)
    }

    override func undo(on document: VectorDocument) {
        applyMove(toLayerIndex: oldLayerIndex, document: document)
    }

    private func applyMove(toLayerIndex: Int, document: VectorDocument) {
        guard let objectIndex = document.unifiedObjects.firstIndex(where: { $0.id == objectID }) else {
            return
        }

        let object = document.unifiedObjects[objectIndex]

        if case .shape(let shape) = object.objectType {
            document.unifiedObjects[objectIndex] = VectorObject(
                shape: shape,
                layerIndex: toLayerIndex,
                orderID: object.orderID
            )
        }
    }
}
