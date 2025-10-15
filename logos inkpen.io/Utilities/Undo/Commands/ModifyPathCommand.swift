import Foundation
import Combine

class ModifyPathCommand: BaseCommand {
    private let objectID: UUID
    private let oldPath: VectorPath
    private let newPath: VectorPath

    init(objectID: UUID, oldPath: VectorPath, newPath: VectorPath) {
        self.objectID = objectID
        self.oldPath = oldPath
        self.newPath = newPath
    }

    override func execute(on document: VectorDocument) {
        applyPath(newPath, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyPath(oldPath, to: document)
    }

    private func applyPath(_ path: VectorPath, to document: VectorDocument) {

        if let index = document.unifiedObjects.firstIndex(where: { $0.id == objectID }) {
            var obj = document.unifiedObjects[index]

            if case .shape(var shape) = obj.objectType {
                shape.path = path
                obj = VectorObject(shape: shape, layerIndex: obj.layerIndex, orderID: obj.orderID)
                document.unifiedObjects[index] = obj
            }
        }

    }
}
