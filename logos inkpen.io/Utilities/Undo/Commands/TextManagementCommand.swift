import Foundation
import Combine

class TextManagementCommand: BaseCommand {
    enum Operation {
        case addText(textID: UUID, shape: VectorShape, layerIndex: Int)
        case removeText(textIDs: [UUID], removedObjects: [VectorObject])
        case duplicateText(originalIDs: [UUID], duplicatedObjects: [VectorObject])
        case convertToOutlines(removedTextIDs: [UUID], removedObjects: [VectorObject], addedShapeIDs: [UUID], addedObjects: [VectorObject])
    }

    private let operation: Operation
    private let oldSelection: Set<UUID>
    private let newSelection: Set<UUID>

    init(operation: Operation, oldSelection: Set<UUID>, newSelection: Set<UUID>) {
        self.operation = operation
        self.oldSelection = oldSelection
        self.newSelection = newSelection
    }

    override func execute(on document: VectorDocument) {
        switch operation {
        case .addText(let textID, let shape, let layerIndex):
            let newObject = VectorObject(shape: shape, layerIndex: layerIndex)
            document.unifiedObjects.append(newObject)
            document.selectedObjectIDs = [textID]
            document.selectedTextIDs = [textID]
            document.selectedShapeIDs.removeAll()

        case .removeText(let textIDs, _):
            document.unifiedObjects.removeAll { obj in
                if case .shape(let shape) = obj.objectType {
                    return textIDs.contains(shape.id) && shape.isTextObject
                }
                return false
            }
            document.selectedTextIDs.removeAll()
            document.selectedObjectIDs = newSelection

        case .duplicateText(_, let duplicatedObjects):
            for obj in duplicatedObjects {
                document.unifiedObjects.append(obj)
            }
            document.selectedObjectIDs = newSelection
            document.selectedTextIDs = newSelection

        case .convertToOutlines(let removedTextIDs, _, _, let addedObjects):
            document.unifiedObjects.removeAll { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.isTextObject && removedTextIDs.contains(shape.id)
                }
                return false
            }
            for obj in addedObjects {
                document.unifiedObjects.append(obj)
            }
            document.selectedTextIDs.removeAll()
            document.selectedShapeIDs = newSelection
            document.selectedObjectIDs = newSelection
        }
    }

    override func undo(on document: VectorDocument) {
        switch operation {
        case .addText(let textID, _, _, _):
            document.unifiedObjects.removeAll { $0.id == textID }
            document.selectedObjectIDs = oldSelection

        case .removeText(_, let removedObjects):
            for obj in removedObjects {
                document.unifiedObjects.append(obj)
            }
            document.selectedObjectIDs = oldSelection

        case .duplicateText(_, let duplicatedObjects):
            let duplicatedIDs = duplicatedObjects.map { $0.id }
            document.unifiedObjects.removeAll { duplicatedIDs.contains($0.id) }
            document.selectedObjectIDs = oldSelection

        case .convertToOutlines(_, let removedObjects, let addedShapeIDs, _):
            document.unifiedObjects.removeAll { obj in
                addedShapeIDs.contains(obj.id)
            }
            for obj in removedObjects {
                document.unifiedObjects.append(obj)
            }
            document.selectedObjectIDs = oldSelection
        }
    }
}
