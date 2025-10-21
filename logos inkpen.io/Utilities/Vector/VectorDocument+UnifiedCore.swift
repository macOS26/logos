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
            unifiedObjects[index] = VectorObject(shape: shape, layerIndex: layerIndex)
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
                updatedObject = VectorObject(shape: shape, layerIndex: layerIndex)

            case .shape(var shape):
                update(&shape)
                updatedObject = VectorObject(shape: shape, layerIndex: layerIndex)

            case .warp(var shape):
                update(&shape)
                updatedObject = VectorObject(shape: shape, layerIndex: layerIndex)

            case .group(var shape):
                update(&shape)
                updatedObject = VectorObject(shape: shape, layerIndex: layerIndex)

            case .clipGroup(var shape):
                update(&shape)
                updatedObject = VectorObject(shape: shape, layerIndex: layerIndex)

            case .clipMask(var shape):
                update(&shape)
                updatedObject = VectorObject(shape: shape, layerIndex: layerIndex)
            }

            // Update snapshot
            snapshot.objects[shapeID] = updatedObject

            // Notify only this specific object changed (unless silent)
            if !silent {
                changeNotifier.notifyObjectChanged(shapeID)
            }
            return
        }

        // Check in groups for child shapes
        for groupIndex in unifiedObjects.indices {
            switch unifiedObjects[groupIndex].objectType {
            case .group(var groupShape), .clipGroup(var groupShape):
                if groupShape.isGroupContainer {
                    if let childIndex = groupShape.groupedShapes.firstIndex(where: { $0.id == shapeID }) {
                        var childShape = groupShape.groupedShapes[childIndex]
                        update(&childShape)
                        groupShape.groupedShapes[childIndex] = childShape

                        let layerIndex = unifiedObjects[groupIndex].layerIndex
                        let updatedObject = VectorObject(shape: groupShape, layerIndex: layerIndex)
                        unifiedObjects[groupIndex] = updatedObject
                        unifiedObjectIndexCache[groupShape.id] = groupIndex

                        // Notify that the group changed (since child changed)
                        changeNotifier.notifyObjectChanged(groupShape.id)
                        return
                    }
                }
            default:
                continue
            }
        }
    }

    func getShapesForLayer(_ layerIndex: Int) -> [VectorShape] {
        // Array position IS the order now - no sorting needed
        return unifiedObjects
            .filter { $0.layerIndex == layerIndex }
            .compactMap { object -> VectorShape? in
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

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)

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

        print("📊 Snapshot now has \(snapshot.objects.count) objects total")
    }

    func addShapeToFrontOfUnifiedSystem(_ shape: VectorShape, layerIndex: Int) {
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }

        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }

        if isUndoRedoOperation {
            if findObject(by: shape.id) != nil {
                let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
        unifiedObjects.append(unifiedObject)
    }

    func addShapeBehindInUnifiedSystem(_ shape: VectorShape, layerIndex: Int, behindShapeIDs: Set<UUID>) {
        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .shape(let existingShape) = unifiedObject.objectType {
                return existingShape.id == shape.id
            }
            return false
        }

        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }

        // Find the first object that should be "behind" (i.e., we insert before it)
        var insertIndex: Int?
        for (index, unifiedObj) in unifiedObjects.enumerated() {
            if unifiedObj.layerIndex == layerIndex {
                if case .shape(let existingShape) = unifiedObj.objectType {
                    if behindShapeIDs.contains(existingShape.id) {
                        insertIndex = index
                        break
                    }
                }
            }
        }

        let unifiedObject = VectorObject(shape: shape, layerIndex: layerIndex)
        if let insertIndex = insertIndex {
            unifiedObjects.insert(unifiedObject, at: insertIndex)
        } else {
            unifiedObjects.append(unifiedObject)
        }
    }

    func addTextToUnifiedSystem(_ text: VectorText, layerIndex: Int) {

        let existingIndex = unifiedObjects.firstIndex { unifiedObject in
            if case .text(let existingShape) = unifiedObject.objectType {
                return existingShape.id == text.id
            }
            return false
        }

        if let existingIndex = existingIndex {
            unifiedObjects.remove(at: existingIndex)
        }

        var textWithLayer = text
        textWithLayer.layerIndex = layerIndex
        let textShape = VectorShape.from(textWithLayer)

        if isUndoRedoOperation {
            if findObject(by: text.id) != nil {
                let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex)
                unifiedObjects.append(unifiedObject)
                return
            }
        }

        let unifiedObject = VectorObject(shape: textShape, layerIndex: layerIndex)
        unifiedObjects.append(unifiedObject)

    }
}
