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
        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }

        // Find the index in layer.objectIDs for insertion
        let insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { removedObjectIDs.contains($0) }
            ?? document.snapshot.layers[layerIndex].objectIDs.count

        // Remove from snapshot.objects
        for id in removedObjectIDs {
            document.snapshot.objects.removeValue(forKey: id)
        }

        // Remove from layer.objectIDs
        document.snapshot.layers[layerIndex].objectIDs.removeAll { removedObjectIDs.contains($0) }

        // Insert objects at the correct position in the order they appear in addedObjectIDs
        for (offset, objectID) in addedObjectIDs.enumerated() {
            guard let shape = addedShapes[objectID] else { continue }
            let newObject = VectorObject(
                shape: shape,
                layerIndex: layerIndex
            )
            document.snapshot.objects[objectID] = newObject
            document.snapshot.layers[layerIndex].objectIDs.insert(objectID, at: insertionIndex + offset)
        }

        document.viewState.selectedObjectIDs = newSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }

    override func undo(on document: VectorDocument) {
        print("🔵 UNDO GROUP: operation=\(operation)")
        print("🔵 UNDO GROUP: removedObjectIDs count=\(removedObjectIDs.count)")
        for (i, id) in removedObjectIDs.enumerated() {
            print("🔵 UNDO GROUP: removedObjectIDs[\(i)]=\(id)")
        }

        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }

        // Find the index in layer.objectIDs where the grouped object was to restore original order
        let insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { addedObjectIDs.contains($0) }
            ?? document.snapshot.layers[layerIndex].objectIDs.count
        print("🔵 UNDO GROUP: insertionIndex=\(insertionIndex)")

        // Remove from snapshot.objects
        for id in addedObjectIDs {
            document.snapshot.objects.removeValue(forKey: id)
        }

        // Remove from layer.objectIDs
        document.snapshot.layers[layerIndex].objectIDs.removeAll { addedObjectIDs.contains($0) }

        // Insert objects at the correct position in the order they appear in removedObjectIDs
        for (offset, objectID) in removedObjectIDs.enumerated() {
            guard let shape = removedShapes[objectID] else { continue }
            let restoredObject = VectorObject(
                shape: shape,
                layerIndex: layerIndex
            )
            document.snapshot.objects[objectID] = restoredObject
            document.snapshot.layers[layerIndex].objectIDs.insert(objectID, at: insertionIndex + offset)
            print("🔵 UNDO GROUP: Inserted \(objectID) at \(insertionIndex + offset)")
        }

        document.viewState.selectedObjectIDs = oldSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }
}
