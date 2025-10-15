import Foundation

/// Command for bulk reordering of objects (bring to front, send to back, etc.)
class BulkReorderCommand: BaseCommand {
    private let oldOrderIDs: [UUID: Int]
    private let newOrderIDs: [UUID: Int]

    init(oldOrderIDs: [UUID: Int], newOrderIDs: [UUID: Int]) {
        self.oldOrderIDs = oldOrderIDs
        self.newOrderIDs = newOrderIDs
    }

    override func execute(on document: VectorDocument) {
        applyOrderIDs(newOrderIDs, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyOrderIDs(oldOrderIDs, to: document)
    }

    private func applyOrderIDs(_ orderIDs: [UUID: Int], to document: VectorDocument) {
        for (objectID, orderID) in orderIDs {
            if let index = document.unifiedObjects.firstIndex(where: { $0.id == objectID }),
               case .shape(let shape) = document.unifiedObjects[index].objectType {
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: document.unifiedObjects[index].layerIndex,
                    orderID: orderID
                )
            }
        }
    }
}
