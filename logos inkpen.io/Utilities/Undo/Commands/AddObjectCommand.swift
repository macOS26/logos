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
        for obj in objects {
            document.unifiedObjects.append(obj)

            // Also update snapshot
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.objects[obj.id] = obj
                if !document.snapshot.layers[layerIndex].objectIDs.contains(obj.id) {
                    document.snapshot.layers[layerIndex].objectIDs.append(obj.id)
                }
            }
        }

        document.viewState.objectUpdateTrigger &+= 1
    }

    override func undo(on document: VectorDocument) {
        let idsToRemove = Set(objects.map { $0.id })
        document.unifiedObjects.removeAll { idsToRemove.contains($0.id) }

        // Remove from snapshot
        for obj in objects {
            document.snapshot.objects.removeValue(forKey: obj.id)
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == obj.id }
            }
        }

        document.viewState.objectUpdateTrigger &+= 1
    }
}
