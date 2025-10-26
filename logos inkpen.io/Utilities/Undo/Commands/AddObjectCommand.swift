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
            // Update snapshot ONLY
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
        var affectedLayers = Set<Int>()

        // Remove from snapshot ONLY
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
