import SwiftUI

extension VectorDocument {
    func addShape(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }

        let obj = VectorObject(shape: shape, layerIndex: layerIndex)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)

        selectedShapeIDs = [shape.id]
        selectedObjectIDs = [shape.id]
        syncSelectionArrays()
    }

    func addShapeToFront(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }

        let obj = VectorObject(shape: shape, layerIndex: layerIndex)

        let command = AddObjectCommand(object: obj)
        executeCommand(command)

        selectedShapeIDs = [shape.id]
        selectedObjectIDs = [shape.id]
        syncSelectionArrays()
    }

    func addShape(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }

        let obj = VectorObject(shape: shape, layerIndex: layerIndex)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)
    }

    func addShapeWithoutUndo(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }

        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }

    func removeSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }

        let objectsToRemove = unifiedObjects.filter { selectedShapeIDs.contains($0.id) }
        if !objectsToRemove.isEmpty {
            let command = DeleteObjectCommand(objects: objectsToRemove)
            executeCommand(command)
        }

        let shapesToRemove = getShapesForLayer(layerIndex).filter { shape in
            if selectedShapeIDs.contains(shape.id) {
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    Log.error("🚫 PROTECTED: Attempted to delete protected background shape '\(shape.name)' - BLOCKED", category: .error)
                    return false
                }
                return true
            }
            return false
        }

        for shape in shapesToRemove {
            removeShapesUnified(layerIndex: layerIndex, where: { $0.id == shape.id })
        }

        selectedShapeIDs.removeAll()

    }

    func removeSelectedObjects() {
        let objectsToDelete = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }

        if !objectsToDelete.isEmpty {
            let command = DeleteObjectCommand(objects: objectsToDelete)
            executeCommand(command)
        }

        let protectedObjects = objectsToDelete.filter { objectToDelete in
            switch objectToDelete.objectType {
            case .shape(let shape),
                 .text(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    Log.error("🚫 PROTECTED: Attempted to delete protected background shape '\(shape.name)' - BLOCKED", category: .error)
                    return false
                }
                return true
            }
        }

        if protectedObjects.count != objectsToDelete.count {
            let blockedCount = objectsToDelete.count - protectedObjects.count
            Log.error("🚫 PROTECTION: Blocked deletion of \(blockedCount) protected background shapes", category: .error)
        }

        for objectToDelete in protectedObjects {
            switch objectToDelete.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if let layerIndex = objectToDelete.layerIndex < layers.count ? objectToDelete.layerIndex : nil {
                    removeShapesUnified(layerIndex: layerIndex, where: { $0.id == shape.id })
                }
            case .text:
                break
            }
        }

        unifiedObjects.removeAll { selectedObjectIDs.contains($0.id) }

        selectedObjectIDs.removeAll()

        syncSelectionArrays()

    }

    func getSelectedShapes() -> [VectorShape] {
        var selectedShapes: [VectorShape] = []

        for unifiedObject in unifiedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if selectedShapeIDs.contains(shape.id) {
                    selectedShapes.append(shape)
                }
            case .text:
                break
            }
        }

        return selectedShapes
    }

    func getShapesByIds(_ shapeIDs: Set<UUID>) -> [VectorShape] {
        var shapes: [VectorShape] = []

        for unifiedObject in unifiedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shapeIDs.contains(shape.id) {
                    shapes.append(shape)
                }
            case .text:
                break
            }
        }

        return shapes
    }

    func getActiveShapeIDs() -> Set<UUID> {
        if currentTool == .directSelection || currentTool == .convertAnchorPoint || currentTool == .penPlusMinus,
           !directSelectedShapeIDs.isEmpty {
            return directSelectedShapeIDs
        }

        return selectedShapeIDs
    }

    func getActiveShapes() -> [VectorShape] {
        let activeShapeIDs = getActiveShapeIDs()
        return getShapesByIds(activeShapeIDs)
    }

    func getObjectsInStackingOrder() -> [VectorObject] {
        if let cached = cachedStackingOrder {
            return cached
        }

        // Array position IS the stacking order now
        let result = unifiedObjects
            .filter { object in
                guard object.isVisible else { return false }
                guard object.layerIndex < layers.count else { return false }
                let layer = layers[object.layerIndex]
                return layer.isVisible
            }

        cachedStackingOrder = result
        return result
    }

    func getSelectedShapesInStackingOrder() -> [VectorShape] {
        // Array position IS the stacking order now
        let sortedSelectedObjects = unifiedObjects
            .filter { object in
                switch object.objectType {
                case .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    return selectedShapeIDs.contains(shape.id)
                case .text:
                    return false
                }
            }

        return sortedSelectedObjects.compactMap { obj in
            switch obj.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape
            case .text:
                return nil
            }
        }
    }

    func selectShape(_ shapeID: UUID) {
        if let unifiedObject = findObject(by: shapeID) {
            selectedObjectIDs = [unifiedObject.id]
            syncSelectionArrays()
        }
    }

    func addToSelection(_ shapeID: UUID) {
        if let unifiedObject = findObject(by: shapeID) {
            selectedObjectIDs.insert(unifiedObject.id)
            syncSelectionArrays()
        }
    }

    func selectAll() {
        let visibleObjects = unifiedObjects.filter { object in
            guard object.isVisible && !object.isLocked else { return false }
            guard object.layerIndex < layers.count else { return false }
            return layers[object.layerIndex].isVisible
        }

        if !visibleObjects.isEmpty {
            selectedObjectIDs = Set(visibleObjects.map { $0.id })
            syncSelectionArrays()
        }
    }

    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }

        let selectedShapes = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) &&
                  unifiedObject.layerIndex == layerIndex else { return false }

            switch unifiedObject.objectType {
            case .shape, .warp, .group, .clipGroup, .clipMask:
                return true
            case .text:
                return false
            }
        }

        var newShapeIDs: Set<UUID> = []

        for unifiedObject in selectedShapes {
            switch unifiedObject.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                var newShape = shape
                newShape.id = UUID()
                if ImageContentRegistry.containsImage(shape),
                   let image = ImageContentRegistry.image(for: shape.id) {
                    ImageContentRegistry.register(image: image, for: newShape.id)
                }

                let offsetTransform = CGAffineTransform(translationX: 10, y: 10)
                newShape = applyTransformToShapeCoordinates(shape: newShape, transform: offsetTransform)
                newShape.updateBounds()
                addShape(newShape, to: layerIndex)
                newShapeIDs.insert(newShape.id)
            case .text:
                break
            }
        }

        selectedShapeIDs = newShapeIDs
        syncUnifiedSelectionFromLegacy()
    }

    internal func applyTransformToShapeCoordinates(shape: VectorShape, transform: CGAffineTransform) -> VectorShape {
        if transform.isIdentity {
            return shape
        }

        let transformedPath = shape.path.applying(transform)
        var newShape = shape
        newShape.path = transformedPath
        newShape.transform = .identity

        return newShape
    }
}
