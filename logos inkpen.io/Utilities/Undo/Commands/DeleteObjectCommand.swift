import Foundation
import Combine

class DeleteObjectCommand: BaseCommand {
    private let objectsToRestore: [UUID: VectorObject]  // Backup - objects will be removed from snapshot
    private var originalPositions: [UUID: (layerIndex: Int, position: Int)] = [:]  // Original z-order positions

    init(objectIDs: [UUID], document: VectorDocument) {
        // Snapshot objects before deletion - minimal backup
        var dict: [UUID: VectorObject] = [:]
        var positions: [UUID: (layerIndex: Int, position: Int)] = [:]
        for uuid in objectIDs {
            if let obj = document.snapshot.objects[uuid] {
                dict[uuid] = obj
                // Record original position in the layer's objectIDs for z-order restore
                let layerIdx = obj.layerIndex
                if layerIdx >= 0 && layerIdx < document.snapshot.layers.count,
                   let pos = document.snapshot.layers[layerIdx].objectIDs.firstIndex(of: uuid) {
                    positions[uuid] = (layerIndex: layerIdx, position: pos)
                }
            }
        }
        self.objectsToRestore = dict
        self.originalPositions = positions
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

        // Record original positions before removal (if not already captured)
        if originalPositions.isEmpty {
            for (uuid, obj) in objectsToRestore {
                let layerIdx = obj.layerIndex
                if layerIdx >= 0 && layerIdx < document.snapshot.layers.count,
                   let pos = document.snapshot.layers[layerIdx].objectIDs.firstIndex(of: uuid) {
                    originalPositions[uuid] = (layerIndex: layerIdx, position: pos)
                }
            }
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

        // Restore objects sorted by original position so insertions don't shift indices
        let sortedRestores = objectsToRestore.sorted { a, b in
            let posA = originalPositions[a.key]?.position ?? Int.max
            let posB = originalPositions[b.key]?.position ?? Int.max
            return posA < posB
        }

        for (uuid, obj) in sortedRestores {
            document.snapshot.objects[uuid] = obj
            affectedLayers.insert(obj.layerIndex)

            // Restore to original z-order position
            if obj.layerIndex < document.snapshot.layers.count {
                if !document.snapshot.layers[obj.layerIndex].objectIDs.contains(uuid) {
                    if let pos = originalPositions[uuid]?.position {
                        let clampedPos = min(pos, document.snapshot.layers[obj.layerIndex].objectIDs.count)
                        document.snapshot.layers[obj.layerIndex].objectIDs.insert(uuid, at: clampedPos)
                    } else {
                        document.snapshot.layers[obj.layerIndex].objectIDs.append(uuid)
                    }
                }
            }
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }
}
