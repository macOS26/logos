import Foundation

class GroupCommand: BaseCommand {
    enum GroupOperation {
        case group
        case ungroup
        case flatten
        case unflatten
        case makeCompound
        case releaseCompound
        case makeLooping
        case releaseLooping
    }

    private let operation: GroupOperation
    private let layerIndex: Int

    private let removedObjectIDs: [UUID]
    private let removedShapes: [UUID: VectorShape]

    private let addedObjectIDs: [UUID]
    private let addedShapes: [UUID: VectorShape]

    private let oldSelectedObjectIDs: Set<UUID>
    private let newSelectedObjectIDs: Set<UUID>

    init(operation: GroupOperation,
         layerIndex: Int,
         removedObjectIDs: [UUID],
         removedShapes: [UUID: VectorShape],
         addedObjectIDs: [UUID],
         addedShapes: [UUID: VectorShape],
         oldSelectedObjectIDs: Set<UUID>,
         newSelectedObjectIDs: Set<UUID>) {
        self.operation = operation
        self.layerIndex = layerIndex
        self.removedObjectIDs = removedObjectIDs
        self.removedShapes = removedShapes
        self.addedObjectIDs = addedObjectIDs
        self.addedShapes = addedShapes
        self.oldSelectedObjectIDs = oldSelectedObjectIDs
        self.newSelectedObjectIDs = newSelectedObjectIDs
    }

    override func execute(on document: VectorDocument) {
        // Find the index of the first removed object to preserve order
        let insertionIndex = document.unifiedObjects.firstIndex { removedObjectIDs.contains($0.id) } ?? document.unifiedObjects.count

        document.unifiedObjects.removeAll { removedObjectIDs.contains($0.id) }

        // Insert objects at the correct position in the order they appear in addedObjectIDs
        for (offset, objectID) in addedObjectIDs.enumerated() {
            guard let shape = addedShapes[objectID] else { continue }
            let newObject = VectorObject(
                shape: shape,
                layerIndex: layerIndex
            )
            document.unifiedObjects.insert(newObject, at: insertionIndex + offset)
        }

        document.selectedObjectIDs = newSelectedObjectIDs
        document.selectedShapeIDs = newSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }) {
                switch obj.objectType {
                case .shape, .warp, .group, .clipGroup, .clipMask:
                    return true
                case .text:
                    return false
                }
            }
            return false
        }
        document.selectedTextIDs = newSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }) {
                switch obj.objectType {
                case .text:
                    return true
                case .shape, .warp, .group, .clipGroup, .clipMask:
                    return false
                }
            }
            return false
        }
    }

    override func undo(on document: VectorDocument) {
        document.unifiedObjects.removeAll { addedObjectIDs.contains($0.id) }

        for objectID in removedObjectIDs {
            guard let shape = removedShapes[objectID] else { continue }
            let restoredObject = VectorObject(
                shape: shape,
                layerIndex: layerIndex
            )
            document.unifiedObjects.append(restoredObject)
        }

        document.selectedObjectIDs = oldSelectedObjectIDs
        document.selectedShapeIDs = oldSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }) {
                switch obj.objectType {
                case .shape, .warp, .group, .clipGroup, .clipMask:
                    return true
                case .text:
                    return false
                }
            }
            return false
        }
        document.selectedTextIDs = oldSelectedObjectIDs.filter { id in
            if let obj = document.unifiedObjects.first(where: { $0.id == id }) {
                switch obj.objectType {
                case .text:
                    return true
                case .shape, .warp, .group, .clipGroup, .clipMask:
                    return false
                }
            }
            return false
        }
    }
}
