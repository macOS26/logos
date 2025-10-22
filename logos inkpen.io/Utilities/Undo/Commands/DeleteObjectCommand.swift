import Foundation
import Combine

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
        removedIndices = []
        let idsToRemove = Set(objects.map { $0.id })

        for (index, obj) in document.unifiedObjects.enumerated().reversed() {
            if idsToRemove.contains(obj.id) {
                removedIndices.insert(index, at: 0)
            }
        }

        document.unifiedObjects.removeAll { idsToRemove.contains($0.id) }

        // CRITICAL FIX: Remove from snapshot.objects dictionary
        for id in idsToRemove {
            document.snapshot.objects.removeValue(forKey: id)

            // Also remove from layer's objectIDs array
            for index in document.snapshot.layers.indices {
                document.snapshot.layers[index].objectIDs.removeAll { $0 == id }
            }
        }
    }

    override func undo(on document: VectorDocument) {
        for (obj, index) in zip(objects, removedIndices) {
            if index <= document.unifiedObjects.count {
                document.unifiedObjects.insert(obj, at: index)
            } else {
                document.unifiedObjects.append(obj)
            }

            // Restore to snapshot.objects dictionary
            document.snapshot.objects[obj.id] = obj

            // Restore to appropriate layer's objectIDs array
            let layerIndex = obj.layerIndex
            if layerIndex < document.snapshot.layers.count {
                if !document.snapshot.layers[layerIndex].objectIDs.contains(obj.id) {
                    document.snapshot.layers[layerIndex].objectIDs.append(obj.id)
                }
            }
        }
    }
}
