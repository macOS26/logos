import Foundation
import Combine

class ShapeModificationCommand: BaseCommand {
    private let objectIDs: [UUID]
    private let oldShapes: [UUID: VectorShape]
    private let newShapes: [UUID: VectorShape]

    init(objectIDs: [UUID],
         oldShapes: [UUID: VectorShape],
         newShapes: [UUID: VectorShape]) {
        self.objectIDs = objectIDs
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
        for id in objectIDs {
            if let index = document.unifiedObjects.firstIndex(where: { $0.id == id }),
               let shape = shapes[id] {
                let obj = document.unifiedObjects[index]
                document.unifiedObjects[index] = VectorObject(
                    shape: shape,
                    layerIndex: obj.layerIndex,
                )
            }
        }
    }
}
