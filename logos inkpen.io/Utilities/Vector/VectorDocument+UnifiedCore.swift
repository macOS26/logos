import SwiftUI

extension VectorDocument {

    /// Removes orphaned objects from snapshot.objects that are not in any layer's objectIDs
    /// and are not referenced by any group's memberIDs.
    /// These can be left behind by buggy operations (e.g., offset path with incorrect undo handling).
    func cleanupOrphanedObjects() {
        // Build set of all valid object IDs from layers
        var validObjectIDs = Set<UUID>()
        for layer in snapshot.layers {
            for objectID in layer.objectIDs {
                validObjectIDs.insert(objectID)
            }
        }

        // Also include all objects referenced by group memberIDs (recursively)
        for object in snapshot.objects.values {
            switch object.objectType {
            case .group(let shape), .clipGroup(let shape):
                collectMemberIDsRecursively(shape.memberIDs, into: &validObjectIDs)
            default:
                break
            }
        }

        // Find orphaned objects
        let allObjectIDs = Set(snapshot.objects.keys)
        let orphanedIDs = allObjectIDs.subtracting(validObjectIDs)

        // Remove orphans
        if !orphanedIDs.isEmpty {
            Log.info("🧹 Cleaning up \(orphanedIDs.count) orphaned object(s)", category: .general)
            for orphanID in orphanedIDs {
                snapshot.objects.removeValue(forKey: orphanID)
            }
        }
    }

    /// Recursively collects all memberIDs from groups and nested groups
    private func collectMemberIDsRecursively(_ memberIDs: [UUID], into validIDs: inout Set<UUID>) {
        for memberID in memberIDs {
            validIDs.insert(memberID)
            // Check if this member is also a group with its own members
            if let memberObject = snapshot.objects[memberID] {
                switch memberObject.objectType {
                case .group(let shape), .clipGroup(let shape):
                    collectMemberIDsRecursively(shape.memberIDs, into: &validIDs)
                default:
                    break
                }
            }
        }
    }

    func getShapeAtIndex(layerIndex: Int, shapeIndex: Int) -> VectorShape? {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return nil }
        return shapes[shapeIndex]
    }

    func getShapeCount(layerIndex: Int) -> Int {
        return getShapesForLayer(layerIndex).count
    }

    func setShapeAtIndex(layerIndex: Int, shapeIndex: Int, shape: VectorShape) {
        let shapes = getShapesForLayer(layerIndex)
        guard shapeIndex >= 0 && shapeIndex < shapes.count else { return }

        let objectType = VectorObject.determineType(for: shape)
        let updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        // Update snapshot ONLY
        snapshot.objects[shape.id] = updatedObject

        // Trigger layer update
        triggerLayerUpdate(for: layerIndex)
    }

    func updateShapeByID(_ shapeID: UUID, silent: Bool = false, update: (inout VectorShape) -> Void) {
        // Fast path: check if it's a top-level selected object first (most common case)
        if let object = snapshot.objects[shapeID] {
            let layerIndex = object.layerIndex
            var updatedObject = object

            switch object.objectType {
            case .text(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)

            case .shape(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)

            case .image(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)

            case .warp(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)

            case .group(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)

            case .clipGroup(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)

            case .clipMask(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)

            case .guide(var shape):
                update(&shape)
                let newType = VectorObject.determineType(for: shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: newType)
            }

            // Update snapshot ONLY
            snapshot.objects[shapeID] = updatedObject

            // Trigger layer update (unless silent)
            if !silent {
                triggerLayerUpdate(for: layerIndex)
            }

            // Early return for top-level objects - no need to check groups
            return
        }

        // Only check parent group cache if not found as top-level object
        if let parentGroupID = snapshot.parentGroupCache[shapeID],
           let groupObject = snapshot.objects[parentGroupID] {
            switch groupObject.objectType {
            case .group(var groupShape), .clipGroup(var groupShape):
                if groupShape.isGroupContainer {
                    if let childIndex = groupShape.groupedShapes.firstIndex(where: { $0.id == shapeID }) {
                        var childShape = groupShape.groupedShapes[childIndex]
                        update(&childShape)
                        groupShape.groupedShapes[childIndex] = childShape

                        let layerIndex = groupObject.layerIndex
                        // Preserve the existing group type (group or clipGroup)
                        let updatedType: VectorObject.ObjectType
                        switch groupObject.objectType {
                        case .clipGroup:
                            updatedType = .clipGroup(groupShape)
                        default:
                            updatedType = .group(groupShape)
                        }
                        let updatedObject = VectorObject(id: groupShape.id, layerIndex: layerIndex, objectType: updatedType)

                        // Update snapshot ONLY
                        snapshot.objects[parentGroupID] = updatedObject

                        // Trigger layer update (unless silent)
                        if !silent {
                            triggerLayerUpdate(for: layerIndex)
                        }
                    }
                }
            default:
                break
            }
        }
    }

    func getShapesForLayer(_ layerIndex: Int) -> [VectorShape] {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return [] }

        // Use snapshot.layers for proper ordering
        let layer = snapshot.layers[layerIndex]
        return layer.objectIDs.compactMap { objectID in
            guard let object = snapshot.objects[objectID] else { return nil }
            switch object.objectType {
            case .shape(let shape):
                return shape
            case .image(let shape):
                return shape
            case .text(let shape):
                return shape
            case .group(let shape):
                return shape
            case .warp(let shape):
                return shape
            case .clipGroup(let shape):
                return shape
            case .clipMask(let shape):
                return shape
            case .guide(let shape):
                return shape
            }
        }
    }

    func addShapeToUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else {
            // print("❌ addShapeToUnifiedSystem: Invalid layer index \(layerIndex), layers count: \(snapshot.layers.count)")
            return
        }

        let objectType = VectorObject.determineType(for: shape)
        let vectorObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        // Remove existing if it exists
        if let existingObject = snapshot.objects[shape.id] {
            // Remove from old layer only (O(1) lookup instead of O(n) loop)
            removeFromLayer(layerIndex: existingObject.layerIndex, objectID: shape.id)
        }

        // Add to snapshot ONLY
        snapshot.objects[shape.id] = vectorObject
        if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
            appendToLayer(layerIndex: layerIndex, objectID: shape.id)
        } else {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func addShapeToFrontOfUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        let objectType = VectorObject.determineType(for: shape)
        let newVectorObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        // Update snapshot ONLY
        snapshot.objects[shape.id] = newVectorObject
        if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
            appendToLayer(layerIndex: layerIndex, objectID: shape.id)
        } else {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    func addShapeBehindInUnifiedSystem(_ shape: VectorShape, layerIndex: Int, behindShapeIDs: Set<UUID>) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        let objectType = VectorObject.determineType(for: shape)
        let newVectorObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        // Update snapshot ONLY
        snapshot.objects[shape.id] = newVectorObject

        // Find insertion point in layer's objectIDs
        var insertIndex: Int?
        for (index, objectID) in snapshot.layers[layerIndex].objectIDs.enumerated() {
            if behindShapeIDs.contains(objectID) {
                insertIndex = index
                break
            }
        }

        if let insertIndex = insertIndex {
            insertIntoLayer(layerIndex: layerIndex, objectID: shape.id, at: insertIndex)
        } else {
            if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
                appendToLayer(layerIndex: layerIndex, objectID: shape.id)
            } else {
                triggerLayerUpdate(for: layerIndex)
            }
        }
    }

    func addTextToUnifiedSystem(_ text: VectorText, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        var textWithLayer = text
        textWithLayer.layerIndex = layerIndex
        let textShape = VectorShape.from(textWithLayer)

        let newVectorObject = VectorObject(id: textShape.id, layerIndex: layerIndex, objectType: .text(textShape))

        // Update snapshot ONLY
        snapshot.objects[textShape.id] = newVectorObject
        if !snapshot.layers[layerIndex].objectIDs.contains(textShape.id) {
            appendToLayer(layerIndex: layerIndex, objectID: textShape.id)
        } else {
            triggerLayerUpdate(for: layerIndex)
        }
    }

    // MARK: - Parent Group Cache Maintenance

    /// Rebuild the entire parent group cache from scratch (called after document load)
    func rebuildParentGroupCache() {
        snapshot.parentGroupCache.removeAll()
        snapshot.clippedObjectsCache.removeAll()

        for (groupID, object) in snapshot.objects {
            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                if groupShape.isGroupContainer {
                    for childShape in groupShape.groupedShapes {
                        snapshot.parentGroupCache[childShape.id] = groupID
                    }
                }
            case .shape(let shape), .image(let shape), .warp(let shape), .clipMask(let shape):
                // Build clipping path cache
                if shape.isClippingPath {
                    snapshot.clippedObjectsCache[shape.id] = []
                }
            default:
                continue
            }
        }

        // Second pass: find clipped objects
        for (objectID, object) in snapshot.objects {
            switch object.objectType {
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                if let clippingPathID = shape.clippedByShapeID {
                    snapshot.clippedObjectsCache[clippingPathID, default: []].append(objectID)
                }
            default:
                continue
            }
        }
    }

    /// Update cache when a group is created or modified
    func updateParentCacheForGroup(_ groupID: UUID, childIDs: [UUID]) {
        // Remove old mappings for this group's children
        for (childID, parentID) in snapshot.parentGroupCache where parentID == groupID {
            snapshot.parentGroupCache.removeValue(forKey: childID)
        }
        // Add new mappings
        for childID in childIDs {
            snapshot.parentGroupCache[childID] = groupID
        }
    }

    /// Remove cache entries when a group is deleted
    func removeParentCacheForGroup(_ groupID: UUID) {
        snapshot.parentGroupCache = snapshot.parentGroupCache.filter { $0.value != groupID }
    }

    /// Remove cache entry when an object is removed from a group
    func removeParentCacheForChild(_ childID: UUID) {
        snapshot.parentGroupCache.removeValue(forKey: childID)
    }
}
