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

        // print("🟣 GroupCommand.execute: operation=\(operation)")
        // print("🟣 GroupCommand.execute: removedObjectIDs=\(removedObjectIDs)")
        // print("🟣 GroupCommand.execute: addedObjectIDs=\(addedObjectIDs)")
        // print("🟣 GroupCommand.execute: BEFORE layer.objectIDs=\(document.snapshot.layers[layerIndex].objectIDs)")

        // Find the index in layer.objectIDs for insertion
        let insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { removedObjectIDs.contains($0) }
            ?? document.snapshot.layers[layerIndex].objectIDs.count

        // Remove from layer.objectIDs only (children stay in snapshot.objects for direct selection)
        document.snapshot.layers[layerIndex].objectIDs.removeAll { removedObjectIDs.contains($0) }

        // print("🟣 GroupCommand.execute: AFTER REMOVAL layer.objectIDs=\(document.snapshot.layers[layerIndex].objectIDs)")

        // Insert objects at the correct position in the order they appear in addedObjectIDs
        for (offset, objectID) in addedObjectIDs.enumerated() {
            guard let shape = addedShapes[objectID] else { continue }

            // For ungroup: child objects already exist in snapshot.objects (potentially updated)
            // Only update if this is a NEW object (group creation) or needs layer index update
            if operation == .group || document.snapshot.objects[objectID] == nil {
                // Creating new group or object doesn't exist - add it
                let newObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = newObject
            } else {
                // Ungrouping - object already exists, just ensure correct layerIndex
                if let existingObject = document.snapshot.objects[objectID] {
                    let updatedObject = VectorObject(
                        id: existingObject.id,
                        layerIndex: layerIndex,
                        objectType: existingObject.objectType
                    )
                    document.snapshot.objects[objectID] = updatedObject
                }
            }

            document.snapshot.layers[layerIndex].objectIDs.insert(objectID, at: insertionIndex + offset)

            // Log group contents
            if shape.isGroup || shape.isClippingGroup {
                // print("🟣 GroupCommand: Created \(shape.isClippingGroup ? "CLIPGROUP" : "GROUP") with \(shape.groupedShapes.count) children")
                for (idx, child) in shape.groupedShapes.enumerated() {
                    // print("🟣   Child[\(idx)]: id=\(child.id), in snapshot.objects=\(document.snapshot.objects[child.id] != nil)")
                }
            }
        }

        // print("🟣 GroupCommand.execute: FINAL layer.objectIDs=\(document.snapshot.layers[layerIndex].objectIDs)")

        document.viewState.selectedObjectIDs = newSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }

    override func undo(on document: VectorDocument) {
        // print("🔵 UNDO GROUP: operation=\(operation)")
        // print("🔵 UNDO GROUP: removedObjectIDs count=\(removedObjectIDs.count)")
        for (i, id) in removedObjectIDs.enumerated() {
            // print("🔵 UNDO GROUP: removedObjectIDs[\(i)]=\(id)")
        }

        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }

        // Find the index in layer.objectIDs where the grouped object was to restore original order
        let insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { addedObjectIDs.contains($0) }
            ?? document.snapshot.layers[layerIndex].objectIDs.count
        // print("🔵 UNDO GROUP: insertionIndex=\(insertionIndex)")

        // Remove group object from snapshot.objects
        for id in addedObjectIDs {
            document.snapshot.objects.removeValue(forKey: id)
        }

        // Remove group from layer.objectIDs
        document.snapshot.layers[layerIndex].objectIDs.removeAll { addedObjectIDs.contains($0) }

        // Restore child objects to layer.objectIDs (they never left snapshot.objects)
        for (offset, objectID) in removedObjectIDs.enumerated() {
            document.snapshot.layers[layerIndex].objectIDs.insert(objectID, at: insertionIndex + offset)
            // print("🔵 UNDO GROUP: Inserted \(objectID) at \(insertionIndex + offset)")
        }

        document.viewState.selectedObjectIDs = oldSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }
}
