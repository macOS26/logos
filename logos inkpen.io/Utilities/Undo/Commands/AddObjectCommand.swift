import Foundation
import Combine

class AddObjectCommand: BaseCommand {
    private let objects: [VectorObject]

    init(objects: [VectorObject]) {
        self.objects = objects
    }

    convenience init(object: VectorObject) {
        self.init(objects: [object])
    }

    override func execute(on document: VectorDocument) {
        var affectedLayers = Set<Int>()

        for obj in objects {
            document.unifiedObjects.append(obj)

            // Also update snapshot
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.objects[obj.id] = obj
                if !document.snapshot.layers[layerIndex].objectIDs.contains(obj.id) {
                    document.snapshot.layers[layerIndex].objectIDs.append(obj.id)
                }
                affectedLayers.insert(layerIndex)
            }
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }

    override func undo(on document: VectorDocument) {
        let idsToRemove = Set(objects.map { $0.id })
        var affectedLayers = Set<Int>()

        document.unifiedObjects.removeAll { idsToRemove.contains($0.id) }

        // Remove from snapshot
        for obj in objects {
            document.snapshot.objects.removeValue(forKey: obj.id)
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == obj.id }
                affectedLayers.insert(layerIndex)
            }
        }

        document.triggerLayerUpdates(for: affectedLayers)
    }
}
