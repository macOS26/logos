import Foundation
import Combine

class DeleteObjectCommand: BaseCommand {
    private let objects: [VectorObject]

    init(objects: [VectorObject]) {
        self.objects = objects
    }

    convenience init(object: VectorObject) {
        self.init(objects: [object])
    }

    override func execute(on document: VectorDocument) {
        let idsToRemove = Set(objects.map { $0.id })

        // Remove from snapshot.objects dictionary (O(1) per object)
        for id in idsToRemove {
            document.snapshot.objects.removeValue(forKey: id)
        }

        // Remove object IDs from layers
        for i in 0..<document.snapshot.layers.count {
            document.snapshot.layers[i].objectIDs.removeAll { idsToRemove.contains($0) }
        }

        // Remove from unifiedObjects
        document.unifiedObjects.removeAll { idsToRemove.contains($0.id) }

        // Also remove from viewState selection
        document.viewState.selectedObjectIDs = document.viewState.selectedObjectIDs.subtracting(idsToRemove)

        document.viewState.objectUpdateTrigger &+= 1
    }

    override func undo(on document: VectorDocument) {
        // Restore to snapshot.objects dictionary
        for obj in objects {
            document.snapshot.objects[obj.id] = obj

            // Add back to appropriate layer
            if obj.layerIndex < document.snapshot.layers.count {
                if !document.snapshot.layers[obj.layerIndex].objectIDs.contains(obj.id) {
                    document.snapshot.layers[obj.layerIndex].objectIDs.append(obj.id)
                }
            }

            // Restore to unifiedObjects
            if !document.unifiedObjects.contains(where: { $0.id == obj.id }) {
                document.unifiedObjects.append(obj)
            }
        }

        document.viewState.objectUpdateTrigger &+= 1
    }
}
