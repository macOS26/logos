import Foundation
import Combine

/// Command for deleting objects from the document
class DeleteObjectCommand: BaseCommand {
    private let objects: [VectorObject]
    private var removedIndices: [Int] = []

    init(objects: [VectorObject]) {
        self.objects = objects
    }

    convenience init(object: VectorObject) {
        self.init(objects: [object])
    }

    override func execute(on document: VectorDocument) {
        // Store indices for proper restoration
        removedIndices = []
        let idsToRemove = Set(objects.map { $0.id })

        for (index, obj) in document.unifiedObjects.enumerated().reversed() {
            if idsToRemove.contains(obj.id) {
                removedIndices.insert(index, at: 0)
            }
        }

        document.unifiedObjects.removeAll { idsToRemove.contains($0.id) }
    }

    override func undo(on document: VectorDocument) {
        // Restore objects at their original indices
        for (obj, index) in zip(objects, removedIndices) {
            if index <= document.unifiedObjects.count {
                document.unifiedObjects.insert(obj, at: index)
            } else {
                document.unifiedObjects.append(obj)
            }
        }
    }
}
