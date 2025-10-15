import Foundation
import Combine

/// Command for object arrangement operations (bring to front, send to back, etc.)
class ObjectArrangementCommand: BaseCommand {
    private let affectedObjectIDs: [UUID]
    private let oldOrderIDs: [UUID: Int]
    private let newOrderIDs: [UUID: Int]

    init(affectedObjectIDs: [UUID],
         oldOrderIDs: [UUID: Int],
         newOrderIDs: [UUID: Int]) {
        self.affectedObjectIDs = affectedObjectIDs
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
        for (id, orderID) in orderIDs {
            if let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) {
                let obj = document.unifiedObjects[index]
                if case .shape(let shape) = obj.objectType {
                    document.unifiedObjects[index] = VectorObject(
                        shape: shape,
                        layerIndex: obj.layerIndex,
                        orderID: orderID
                    )
                }
            }
        }
    }
}
