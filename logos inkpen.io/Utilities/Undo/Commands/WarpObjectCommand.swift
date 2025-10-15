import Foundation
import Combine

class WarpObjectCommand: BaseCommand {
    private let affectedObjectIDs: [UUID]
    private let oldShapes: [UUID: VectorShape]
    private let newShapes: [UUID: VectorShape]

    init(affectedObjectIDs: [UUID],
         oldShapes: [UUID: VectorShape],
         newShapes: [UUID: VectorShape]) {
        self.affectedObjectIDs = affectedObjectIDs
        self.oldShapes = oldShapes
        self.newShapes = newShapes
    }

    override func execute(on document: VectorDocument) {
        applyShapes(newShapes, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyShapes(oldShapes, to: document)
    }

    private func applyShapes(_ shapes: [UUID: VectorShape], to document: VectorDocument) {
        for (id, shape) in shapes {
            if let index = document.unifiedObjects.firstIndex(where: { $0.id == id }) {
                let obj = document.unifiedObjects[index]
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: obj.layerIndex,
                    orderID: obj.orderID
                )
            }
        }
    }
}
