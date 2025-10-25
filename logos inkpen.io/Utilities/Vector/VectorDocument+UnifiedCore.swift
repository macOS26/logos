import SwiftUI

extension VectorDocument {

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
        let oldShape = shapes[shapeIndex]

        if let index = unifiedObjects.firstIndex(where: { obj in
            if case .shape(let s) = obj.objectType {
                return s.id == oldShape.id
            }
            return false
        }) {
            let objectType = VectorObject.determineType(for: shape)
            let updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

            // Update snapshot.objects (primary)
            snapshot.objects[shape.id] = updatedObject

            // Update unifiedObjects (for compatibility)
            unifiedObjects[index] = updatedObject

            changeNotifier.notifyObjectChanged(shape.id)
        }
    }

    func updateShapeByID(_ shapeID: UUID, silent: Bool = false, update: (inout VectorShape) -> Void) {
        // Update in snapshot (primary)
        if let object = snapshot.objects[shapeID] {
            let layerIndex = object.layerIndex
            var updatedObject = object

            switch object.objectType {
            case .text(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .text(shape))

            case .shape(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .shape(shape))

            case .warp(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .warp(shape))

            case .group(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .group(shape))

            case .clipGroup(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .clipGroup(shape))

            case .clipMask(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .clipMask(shape))
            }

            // Update snapshot ONLY
            snapshot.objects[shapeID] = updatedObject

            // Trigger layer update (unless silent)
            if !silent {
                triggerLayerUpdate(for: layerIndex)
            }
            return
        }

        // Check in groups for child shapes
        for (groupID, groupObject) in snapshot.objects {
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
                        snapshot.objects[groupID] = updatedObject

                        // Trigger layer update (unless silent)
                        if !silent {
                            triggerLayerUpdate(for: layerIndex)
                        }
                        return
                    }
                }
            default:
                continue
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
            }
        }
    }

    func addShapeToUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else {
            print("❌ addShapeToUnifiedSystem: Invalid layer index \(layerIndex), layers count: \(snapshot.layers.count)")
            return
        }

        let objectType = VectorObject.determineType(for: shape)
        let unifiedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        // Remove existing if it exists
        if snapshot.objects[shape.id] != nil {
            // Remove from old layer
            for i in 0..<snapshot.layers.count {
                snapshot.layers[i].objectIDs.removeAll { $0 == shape.id }
            }
        }

        // Add to snapshot
        snapshot.objects[shape.id] = unifiedObject
        if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
            snapshot.layers[layerIndex].objectIDs.append(shape.id)
            print("✅ Added shape \(shape.id) to layer \(layerIndex), layer now has \(snapshot.layers[layerIndex].objectIDs.count) objects")

            // Debug: Check if we can retrieve it immediately
            let testObjects = snapshot.layers[layerIndex].objectIDs.compactMap { id in
                snapshot.objects[id]
            }.filter { $0.isVisible }
            print("🔍 TEST: Can retrieve \(testObjects.count) visible objects from layer \(layerIndex)")
            if testObjects.isEmpty && !snapshot.layers[layerIndex].objectIDs.isEmpty {
                print("   ❌ Objects exist but can't retrieve them!")
                print("   Object visible? \(unifiedObject.isVisible)")
            }
        }

        // Keep unifiedObjects in sync for now (for undo/redo)
        let existingIndex = unifiedObjects.firstIndex { $0.id == shape.id }
        if let existingIndex = existingIndex {
            unifiedObjects[existingIndex] = unifiedObject
        } else {
            unifiedObjects.append(unifiedObject)
        }

        triggerLayerUpdate(for: layerIndex)
        print("📊 Snapshot now has \(snapshot.objects.count) objects total")
    }

    func addShapeToFrontOfUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        let objectType = VectorObject.determineType(for: shape)
        let newVectorObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        // Update snapshot ONLY
        snapshot.objects[shape.id] = newVectorObject
        if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
            snapshot.layers[layerIndex].objectIDs.append(shape.id)
        }
        triggerLayerUpdate(for: layerIndex)
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
            snapshot.layers[layerIndex].objectIDs.insert(shape.id, at: insertIndex)
        } else {
            if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
                snapshot.layers[layerIndex].objectIDs.append(shape.id)
            }
        }
        triggerLayerUpdate(for: layerIndex)
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
            snapshot.layers[layerIndex].objectIDs.append(textShape.id)
        }
        triggerLayerUpdate(for: layerIndex)
    }
}
