import Foundation
import Combine

class DeleteObjectCommand: BaseCommand {
    private let objectsToRestore: [UUID: VectorObject]  // Store by UUID for O(1) lookup

    init(objects: [VectorObject]) {
        var dict: [UUID: VectorObject] = [:]
        for obj in objects {
            dict[obj.id] = obj
        }
        self.objectsToRestore = dict
    }

    convenience init(object: VectorObject) {
        self.init(objects: [object])
    }

    override func execute(on document: VectorDocument) {
        let idsToRemove = Set(objectsToRestore.keys)
        var affectedLayers = Set<Int>()

        // Track affected layers (O(n) where n = number of objects to delete)
        for (_, obj) in objectsToRestore {
            affectedLayers.insert(obj.layerIndex)
        }

        // Remove from snapshot.objects dictionary (O(1) per object)
        for id in idsToRemove {
            document.snapshot.objects.removeValue(forKey: id)
        }

        // Remove object IDs from their specific layers only
        for (uuid, obj) in objectsToRestore {
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == uuid }
            }
        }

        // Also remove from viewState selection
        document.viewState.selectedObjectIDs = document.viewState.selectedObjectIDs.subtracting(idsToRemove)

        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        var affectedLayers = Set<Int>()

        // Restore to snapshot.objects dictionary (O(1) per object)
        for (uuid, obj) in objectsToRestore {
            document.snapshot.objects[uuid] = obj
            affectedLayers.insert(obj.layerIndex)

            // Add back to appropriate layer
            if obj.layerIndex < document.snapshot.layers.count {
                if !document.snapshot.layers[obj.layerIndex].objectIDs.contains(uuid) {
                    document.snapshot.layers[obj.layerIndex].objectIDs.append(uuid)
                }
            }
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }
}
