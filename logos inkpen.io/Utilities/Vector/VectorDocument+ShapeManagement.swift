import SwiftUI

extension VectorDocument {
    func addShape(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }

        let obj = VectorObject(shape: shape, layerIndex: layerIndex)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)

        viewState.selectedObjectIDs = [shape.id]
        viewState.selectedObjectIDs = [shape.id]
        
    }

    func addShapeToFront(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }

        let obj = VectorObject(shape: shape, layerIndex: layerIndex)

        let command = AddObjectCommand(object: obj)
        executeCommand(command)

        viewState.selectedObjectIDs = [shape.id]
        viewState.selectedObjectIDs = [shape.id]
        
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

        let objectsToRemove = unifiedObjects.filter { viewState.selectedObjectIDs.contains($0.id) }
        if !objectsToRemove.isEmpty {
            let command = DeleteObjectCommand(objects: objectsToRemove)
            executeCommand(command)
        }

        let shapesToRemove = getShapesForLayer(layerIndex).filter { shape in
            if viewState.selectedObjectIDs.contains(shape.id) {
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

        viewState.selectedObjectIDs.removeAll()

    }

    func removeSelectedObjects() {
        let candidateObjects = unifiedObjects.filter { viewState.selectedObjectIDs.contains($0.id) }

        // Filter out protected objects (locked layers, Canvas/Pasteboard layers, background shapes)
        let objectsToDelete = candidateObjects.filter { object in
            // Skip objects on locked layers
            if object.layerIndex < layers.count && layers[object.layerIndex].isLocked {
                return false
            }

            // Skip objects on Canvas or Pasteboard layers (indices 1 and 0)
            if object.layerIndex <= 1 {
                return false
            }

            // Skip background shapes
            switch object.objectType {
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
            }

            return true
        }

        if candidateObjects.count != objectsToDelete.count {
            let blockedCount = candidateObjects.count - objectsToDelete.count
            Log.error("🚫 PROTECTION: Blocked deletion of \(blockedCount) protected object(s)", category: .error)
        }

        if !objectsToDelete.isEmpty {
            let command = DeleteObjectCommand(objects: objectsToDelete)
            executeCommand(command)
        }

        viewState.selectedObjectIDs.removeAll()
        
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
                if viewState.selectedObjectIDs.contains(shape.id) {
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
        if viewState.currentTool == .directSelection || viewState.currentTool == .convertAnchorPoint || viewState.currentTool == .penPlusMinus,
           !viewState.selectedObjectIDs.isEmpty {
            return viewState.selectedObjectIDs
        }

        return viewState.selectedObjectIDs
    }

    func getActiveShapes() -> [VectorShape] {
        let activeShapeIDs = getActiveShapeIDs()
        return getShapesByIds(activeShapeIDs)
    }

    func getObjectsInStackingOrder() -> [VectorObject] {
        // Iterate layers in stack order, then objects in draw order
        var result: [VectorObject] = []

        for layer in snapshot.layers {
            // Skip invisible layers
            guard layer.isVisible else { continue }

            // Get objects for this layer in draw order
            for objectID in layer.objectIDs {
                guard let object = snapshot.objects[objectID] else { continue }
                // Skip invisible objects
                guard object.isVisible else { continue }

                result.append(object)
            }
        }

        return result
    }

    func getSelectedShapesInStackingOrder() -> [VectorShape] {
        // Iterate layers in stack order, then objects in draw order
        var result: [VectorShape] = []

        for layer in snapshot.layers {
            for objectID in layer.objectIDs {
                // Only include selected objects
                guard viewState.selectedObjectIDs.contains(objectID) else { continue }
                guard let object = snapshot.objects[objectID] else { continue }

                switch object.objectType {
                case .text(let shape),
                     .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    result.append(shape)
                }
            }
        }

        return result
    }

    func selectShape(_ shapeID: UUID) {
        if let unifiedObject = findObject(by: shapeID) {
            viewState.selectedObjectIDs = [unifiedObject.id]
            
        }
    }

    func addToSelection(_ shapeID: UUID) {
        if let unifiedObject = findObject(by: shapeID) {
            viewState.selectedObjectIDs.insert(unifiedObject.id)
            
        }
    }

    func selectAll() {
        let visibleObjects = unifiedObjects.filter { object in
            // Skip invisible or locked objects
            guard object.isVisible && !object.isLocked else { return false }

            // Skip if layer doesn't exist
            guard object.layerIndex < layers.count else { return false }

            let layer = layers[object.layerIndex]

            // Skip objects on invisible or locked layers
            guard layer.isVisible && !layer.isLocked else { return false }

            // Skip objects on Canvas or Pasteboard layers (layer indices 1 and 0)
            guard object.layerIndex > 1 else { return false }

            // Skip background shapes
            switch object.objectType {
            case .shape(let shape),
                 .text(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    return false
                }
            }

            return true
        }

        if !visibleObjects.isEmpty {
            viewState.selectedObjectIDs = Set(visibleObjects.map { $0.id })
            
        }
    }

    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }

        let selectedShapes = unifiedObjects.filter { unifiedObject in
            guard viewState.selectedObjectIDs.contains(unifiedObject.id) &&
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
                if ImageContentRegistry.containsImage(shape, in: self),
                   let image = ImageContentRegistry.image(for: shape.id, in: self) {
                    ImageContentRegistry.register(image: image, for: newShape.id, in: self)
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

        viewState.selectedObjectIDs = newShapeIDs
        
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
