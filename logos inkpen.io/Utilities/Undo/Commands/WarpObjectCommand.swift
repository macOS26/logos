import Foundation

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
        var affectedLayers = Set<Int>()

        for (id, shape) in shapes {
            if let obj = document.snapshot.objects[id] {
                let newObj = VectorObject(
                    shape: shape,
                    layerIndex: obj.layerIndex
                )
                document.snapshot.objects[id] = newObj
                affectedLayers.insert(obj.layerIndex)
            }
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }
}
