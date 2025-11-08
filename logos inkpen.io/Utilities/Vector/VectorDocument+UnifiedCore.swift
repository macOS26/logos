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

        let objectType = VectorObject.determineType(for: shape)
        let updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        // Update snapshot ONLY
        snapshot.objects[shape.id] = updatedObject

        // Trigger layer update
        triggerLayerUpdate(for: layerIndex)
    }

    func updateShapeByID(_ shapeID: UUID, silent: Bool = false, update: (inout VectorShape) -> Void) {
        print("🟣 updateShapeByID: shapeID=\(shapeID)")
        print("🟣 CALLER STACK:")
        for (index, symbol) in Thread.callStackSymbols.prefix(8).enumerated() {
            print("  [\(index)] \(symbol)")
        }

        var foundInTopLevel = false

        // Update in snapshot (primary) if exists as top-level
        if let object = snapshot.objects[shapeID] {
            print("🟣 updateShapeByID: found in snapshot.objects as top-level")
            let layerIndex = object.layerIndex
            var updatedObject = object

            switch object.objectType {
            case .text(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .text(shape))

            case .shape(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .shape(shape))

            case .image(var shape):
                update(&shape)
                updatedObject = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: .image(shape))

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
            print("🟣 updateShapeByID: updated top-level object")
            foundInTopLevel = true
            // DON'T RETURN - also need to update in groups!
        }

        print("🟣 updateShapeByID: searching groups for shape copies...")
        // ALSO check in groups for child shapes (even if found in top-level)
        for (groupID, groupObject) in snapshot.objects {
            switch groupObject.objectType {
            case .group(var groupShape), .clipGroup(var groupShape):
                print("🟣 updateShapeByID: checking group \(groupID), isGroupContainer=\(groupShape.isGroupContainer), groupedShapes.count=\(groupShape.groupedShapes.count)")
                if groupShape.isGroupContainer {
                    if let childIndex = groupShape.groupedShapes.firstIndex(where: { $0.id == shapeID }) {
                        print("🟣 updateShapeByID: FOUND in group \(groupID) at index \(childIndex)!")
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
                        print("🟣 updateShapeByID: updated grouped object copy")
                        // Continue searching - might be in multiple groups
                    }
                }
            default:
                continue
            }
        }

        if !foundInTopLevel {
            print("🟣 updateShapeByID: WARNING - shape not found in top-level snapshot.objects")
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

        // Add to snapshot ONLY
        snapshot.objects[shape.id] = unifiedObject
        if !snapshot.layers[layerIndex].objectIDs.contains(shape.id) {
            snapshot.layers[layerIndex].objectIDs.append(shape.id)
        }

        triggerLayerUpdate(for: layerIndex)
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
