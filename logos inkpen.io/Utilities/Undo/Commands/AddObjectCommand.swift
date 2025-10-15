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
        }
    }

    override func undo(on document: VectorDocument) {
        let idsToRemove = Set(objects.map { $0.id })
        document.unifiedObjects.removeAll { idsToRemove.contains($0.id) }
    }
}
