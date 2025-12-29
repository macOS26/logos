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
        case pathOperation  // For pathfinder operations that replace shapes
    }

    private let operation: GroupOperation
    private let layerIndex: Int

    private let removedObjectIDs: [UUID]
    private let removedShapes: [UUID: VectorShape]

    private let addedObjectIDs: [UUID]
    private let addedShapes: [UUID: VectorShape]

    private let oldSelectedObjectIDs: Set<UUID>
    private let newSelectedObjectIDs: Set<UUID>

    // For cross-layer grouping: track original layer index for each object
    private let originalLayerIndices: [UUID: Int]

    init(operation: GroupOperation,
         layerIndex: Int,
         removedObjectIDs: [UUID],
         removedShapes: [UUID: VectorShape],
         addedObjectIDs: [UUID],
         addedShapes: [UUID: VectorShape],
         oldSelectedObjectIDs: Set<UUID>,
         newSelectedObjectIDs: Set<UUID>,
         originalLayerIndices: [UUID: Int] = [:]) {
        self.operation = operation
        self.layerIndex = layerIndex
        self.removedObjectIDs = removedObjectIDs
        self.removedShapes = removedShapes
        self.addedObjectIDs = addedObjectIDs
        self.addedShapes = addedShapes
        self.oldSelectedObjectIDs = oldSelectedObjectIDs
        self.newSelectedObjectIDs = newSelectedObjectIDs
        self.originalLayerIndices = originalLayerIndices
    }

    override func execute(on document: VectorDocument) {
        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }

        // For cross-layer grouping: remove objects from their original layers first
        if !originalLayerIndices.isEmpty {
            var layerUpdates: [Int: [UUID]] = [:]
            for (objectID, origLayer) in originalLayerIndices {
                if origLayer != layerIndex && origLayer >= 0 && origLayer < document.snapshot.layers.count {
                    layerUpdates[origLayer, default: []].append(objectID)
                }
            }
            for (origLayerIdx, objectIDs) in layerUpdates {
                var layerObjectIDs = document.snapshot.layers[origLayerIdx].objectIDs
                layerObjectIDs.removeAll { objectIDs.contains($0) }
                document.updateLayerObjectIDs(layerIndex: origLayerIdx, newObjectIDs: layerObjectIDs)
            }
        }

        // Find the index in layer.objectIDs for insertion
        let insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { removedObjectIDs.contains($0) }
            ?? document.snapshot.layers[layerIndex].objectIDs.count

        // Remove from layer.objectIDs first
        var updatedObjectIDs = document.snapshot.layers[layerIndex].objectIDs
        updatedObjectIDs.removeAll { removedObjectIDs.contains($0) }

        // Handle based on operation type
        switch operation {
        case .group:
            // For group: member objects stay in snapshot.objects, just remove from layer.objectIDs
            // (already done above)

            // Add the group object to snapshot.objects
            for (offset, objectID) in addedObjectIDs.enumerated() {
                guard let shape = addedShapes[objectID] else { continue }

                let newObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = newObject
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)

                // Update parent cache with memberIDs
                if shape.isGroup || shape.isClippingGroup {
                    let childIDs = shape.memberIDs.isEmpty ? shape.groupedShapes.map { $0.id } : shape.memberIDs
                    document.updateParentCacheForGroup(objectID, childIDs: childIDs)
                }
            }

        case .ungroup:
            // For ungroup: remove group from snapshot.objects
            for objectID in removedObjectIDs {
                document.snapshot.objects.removeValue(forKey: objectID)
                document.removeParentCacheForGroup(objectID)
            }

            // Add member IDs back to layer.objectIDs
            for (offset, objectID) in addedObjectIDs.enumerated() {
                // For legacy groups, shapes need to be created in snapshot.objects
                if let shape = addedShapes[objectID] {
                    let newObject = VectorObject(
                        shape: shape,
                        layerIndex: layerIndex
                    )
                    document.snapshot.objects[objectID] = newObject
                }
                // For modern groups, shapes already exist in snapshot.objects
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }

        default:
            // For other operations (flatten, compound, etc.) - use the old behavior
            // Remove objects from snapshot.objects
            for objectID in removedObjectIDs {
                document.snapshot.objects.removeValue(forKey: objectID)
            }

            // Add new objects
            for (offset, objectID) in addedObjectIDs.enumerated() {
                guard let shape = addedShapes[objectID] else { continue }

                let newObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = newObject
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }
        }

        // Apply all objectID changes at once with automatic trigger
        document.updateLayerObjectIDs(layerIndex: layerIndex, newObjectIDs: updatedObjectIDs)

        document.viewState.orderedSelectedObjectIDs = Array(newSelectedObjectIDs)
        document.viewState.selectedObjectIDs = newSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }

    override func undo(on document: VectorDocument) {
        guard layerIndex >= 0 && layerIndex < document.snapshot.layers.count else { return }

        // Find the index in layer.objectIDs where we need to restore
        let insertionIndex = document.snapshot.layers[layerIndex].objectIDs.firstIndex { addedObjectIDs.contains($0) }
            ?? document.snapshot.layers[layerIndex].objectIDs.count

        // Remove added objects from layer.objectIDs
        var updatedObjectIDs = document.snapshot.layers[layerIndex].objectIDs
        updatedObjectIDs.removeAll { addedObjectIDs.contains($0) }

        // Handle based on operation type
        switch operation {
        case .group:
            // Undo group: remove group from snapshot.objects, restore members to their original layers
            for id in addedObjectIDs {
                document.snapshot.objects.removeValue(forKey: id)
                document.removeParentCacheForGroup(id)
            }

            // For cross-layer grouping: restore objects to their original layers
            if !originalLayerIndices.isEmpty {
                var layerRestores: [Int: [UUID]] = [:]
                for objectID in removedObjectIDs {
                    let origLayer = originalLayerIndices[objectID] ?? layerIndex
                    layerRestores[origLayer, default: []].append(objectID)
                }
                // Restore to each original layer
                for (origLayerIdx, objectIDs) in layerRestores {
                    guard origLayerIdx >= 0 && origLayerIdx < document.snapshot.layers.count else { continue }
                    if origLayerIdx == layerIndex {
                        // Will be handled below with updatedObjectIDs
                        for (offset, objectID) in objectIDs.enumerated() {
                            updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
                        }
                    } else {
                        var layerObjectIDs = document.snapshot.layers[origLayerIdx].objectIDs
                        layerObjectIDs.append(contentsOf: objectIDs)
                        document.updateLayerObjectIDs(layerIndex: origLayerIdx, newObjectIDs: layerObjectIDs)
                        document.triggerLayerUpdate(for: origLayerIdx)
                    }
                }
            } else {
                // Standard single-layer undo: restore member IDs to layer.objectIDs
                for (offset, objectID) in removedObjectIDs.enumerated() {
                    updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
                }
            }

        case .ungroup:
            // Undo ungroup: restore group to snapshot.objects, remove members from layer.objectIDs

            // For legacy groups, remove the shapes that were created during ungroup
            for objectID in addedObjectIDs {
                if addedShapes[objectID] != nil {
                    document.snapshot.objects.removeValue(forKey: objectID)
                }
            }

            for (objectID, shape) in removedShapes {
                let restoredObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = restoredObject

                // Restore parent cache
                if shape.isGroup || shape.isClippingGroup {
                    let childIDs = shape.memberIDs.isEmpty ? shape.groupedShapes.map { $0.id } : shape.memberIDs
                    document.updateParentCacheForGroup(objectID, childIDs: childIDs)
                }
            }

            // Restore group IDs to layer.objectIDs
            for (offset, objectID) in removedObjectIDs.enumerated() {
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }

        default:
            // For other operations - use the old behavior
            // Remove added objects from snapshot.objects
            for id in addedObjectIDs {
                document.snapshot.objects.removeValue(forKey: id)
            }

            // Restore removed shapes back to snapshot.objects
            for (objectID, shape) in removedShapes {
                let restoredObject = VectorObject(
                    shape: shape,
                    layerIndex: layerIndex
                )
                document.snapshot.objects[objectID] = restoredObject
            }

            // Restore to layer.objectIDs
            for (offset, objectID) in removedObjectIDs.enumerated() {
                updatedObjectIDs.insert(objectID, at: insertionIndex + offset)
            }
        }

        // Apply all objectID changes at once with automatic trigger
        document.updateLayerObjectIDs(layerIndex: layerIndex, newObjectIDs: updatedObjectIDs)

        document.viewState.orderedSelectedObjectIDs = Array(oldSelectedObjectIDs)
        document.viewState.selectedObjectIDs = oldSelectedObjectIDs
        document.triggerLayerUpdate(for: layerIndex)
    }
}
