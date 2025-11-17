import Foundation
import Combine

class DeleteObjectCommand: BaseCommand {
    private let objectsToRestore: [UUID: VectorObject]  // Backup - objects will be removed from snapshot

    init(objectIDs: [UUID], document: VectorDocument) {
        // Snapshot objects before deletion - minimal backup
        var dict: [UUID: VectorObject] = [:]
        for uuid in objectIDs {
            if let obj = document.snapshot.objects[uuid] {
                dict[uuid] = obj
            }
        }
        self.objectsToRestore = dict
    }

    // Legacy init for compatibility - avoid if possible
    private init(objectsDict: [UUID: VectorObject]) {
        self.objectsToRestore = objectsDict
    }

    convenience init(objects: [VectorObject]) {
        var dict: [UUID: VectorObject] = [:]
        for obj in objects {
            dict[obj.id] = obj
        }
        self.init(objectsDict: dict)
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
