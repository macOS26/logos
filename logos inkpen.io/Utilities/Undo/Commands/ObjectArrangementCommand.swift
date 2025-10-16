import Foundation
import Combine

class ObjectArrangementCommand: BaseCommand {
    private let affectedObjectIDs: [UUID]
    private let oldIndices: [UUID: Int]
    private let newIndices: [UUID: Int]

    init(affectedObjectIDs: [UUID],
         oldIndices: [UUID: Int],
         newIndices: [UUID: Int]) {
        self.affectedObjectIDs = affectedObjectIDs
        self.oldIndices = oldIndices
        self.newIndices = newIndices
    }

    override func execute(on document: VectorDocument) {
        applyIndices(newIndices, to: document)
    }

    override func undo(on document: VectorDocument) {
        applyIndices(oldIndices, to: document)
    }

    private func applyIndices(_ targetIndices: [UUID: Int], to document: VectorDocument) {
        var objects = document.unifiedObjects
        var affectedObjects: [(UUID, VectorObject)] = []

        for id in affectedObjectIDs {
            if let index = objects.firstIndex(where: { $0.id == id }) {
                affectedObjects.append((id, objects[index]))
                objects.remove(at: index)
            }
        }

        for (id, obj) in affectedObjects {
            if let targetIndex = targetIndices[id] {
                let insertIndex = min(targetIndex, objects.count)
                objects.insert(obj, at: insertIndex)
            }
        }

        document.unifiedObjects = objects
    }
}
