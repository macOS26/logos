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
            document.snapshot.objects[textID] = newObject
            if layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.append(textID)
            }
            document.viewState.selectedObjectIDs = [textID]

        case .removeText(let textIDs, _):
            for textID in textIDs {
                if let obj = document.snapshot.objects[textID] {
                    document.snapshot.objects.removeValue(forKey: textID)
                    if obj.layerIndex < document.snapshot.layers.count {
                        document.snapshot.layers[obj.layerIndex].objectIDs.removeAll { $0 == textID }
                    }
                }
            }
            document.viewState.selectedObjectIDs = newSelection

        case .duplicateText(_, let duplicatedObjects):
            for obj in duplicatedObjects {
                document.snapshot.objects[obj.id] = obj
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.append(obj.id)
                }
            }
            document.viewState.selectedObjectIDs = newSelection

        case .convertToOutlines(let removedTextIDs, _, _, let addedObjects):
            for textID in removedTextIDs {
                if let obj = document.snapshot.objects[textID] {
                    document.snapshot.objects.removeValue(forKey: textID)
                    if obj.layerIndex < document.snapshot.layers.count {
                        document.snapshot.layers[obj.layerIndex].objectIDs.removeAll { $0 == textID }
                    }
                }
            }
            for obj in addedObjects {
                document.snapshot.objects[obj.id] = obj
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.append(obj.id)
                }
            }
            document.viewState.selectedObjectIDs = newSelection
        }
    }

    override func undo(on document: VectorDocument) {
        switch operation {
        case .addText(let textID, _, _):
            if let obj = document.snapshot.objects[textID] {
                document.snapshot.objects.removeValue(forKey: textID)
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.removeAll { $0 == textID }
                }
            }
            document.viewState.selectedObjectIDs = oldSelection

        case .removeText(_, let removedObjects):
            for obj in removedObjects {
                document.snapshot.objects[obj.id] = obj
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.append(obj.id)
                }
            }
            document.viewState.selectedObjectIDs = oldSelection

        case .duplicateText(_, let duplicatedObjects):
            for obj in duplicatedObjects {
                if let layerIdx = document.snapshot.objects[obj.id]?.layerIndex {
                    document.snapshot.objects.removeValue(forKey: obj.id)
                    if layerIdx < document.snapshot.layers.count {
                        document.snapshot.layers[layerIdx].objectIDs.removeAll { $0 == obj.id }
                    }
                }
            }
            document.viewState.selectedObjectIDs = oldSelection

        case .convertToOutlines(_, let removedObjects, let addedShapeIDs, _):
            for shapeID in addedShapeIDs {
                if let obj = document.snapshot.objects[shapeID] {
                    document.snapshot.objects.removeValue(forKey: shapeID)
                    if obj.layerIndex < document.snapshot.layers.count {
                        document.snapshot.layers[obj.layerIndex].objectIDs.removeAll { $0 == shapeID }
                    }
                }
            }
            for obj in removedObjects {
                document.snapshot.objects[obj.id] = obj
                if obj.layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[obj.layerIndex].objectIDs.append(obj.id)
                }
            }
            document.viewState.selectedObjectIDs = oldSelection
        }
    }
}
