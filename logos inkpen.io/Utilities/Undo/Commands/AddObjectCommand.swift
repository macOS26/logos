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
            let layerIndex = obj.layerIndex
            if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                document.snapshot.objects[obj.id] = obj
                if !document.snapshot.layers[layerIndex].objectIDs.contains(obj.id) {
                    document.snapshot.layers[layerIndex].objectIDs.append(obj.id)
                }
            }
        }
    }

    override func undo(on document: VectorDocument) {
        let idsToRemove = Set(objects.map { $0.id })
        for id in idsToRemove {
            if let obj = document.snapshot.objects[id] {
                let layerIndex = obj.layerIndex
                if layerIndex >= 0 && layerIndex < document.snapshot.layers.count {
                    document.snapshot.layers[layerIndex].objectIDs.removeAll { $0 == id }
                }
                document.snapshot.objects.removeValue(forKey: id)
            }
        }
    }
}
