import SwiftUI

extension VectorDocument {
    func addShape(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }

        let objectType = VectorObject.determineType(for: shape)
        let obj = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)

        viewState.orderedSelectedObjectIDs = [shape.id]
        viewState.selectedObjectIDs = [shape.id]
    }

    func addShapeToFront(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }

        let objectType = VectorObject.determineType(for: shape)
        let obj = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)

        let command = AddObjectCommand(object: obj)
        executeCommand(command)

        viewState.orderedSelectedObjectIDs = [shape.id]
        viewState.selectedObjectIDs = [shape.id]
    }

    func addShape(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        let objectType = VectorObject.determineType(for: shape)
        let obj = VectorObject(id: shape.id, layerIndex: layerIndex, objectType: objectType)
        let command = AddObjectCommand(object: obj)
        executeCommand(command)
    }

    func addShapeWithoutUndo(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }

    func removeSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }

        // Pass UUIDs only - command will snapshot from document.snapshot.objects
        if !viewState.selectedObjectIDs.isEmpty {
            let command = DeleteObjectCommand(objectIDs: Array(viewState.selectedObjectIDs), document: self)
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
        // Filter UUIDs directly - no temporary VectorObject array
        let objectIDsToDelete = viewState.selectedObjectIDs.filter { uuid in
            guard let object = snapshot.objects[uuid] else { return false }

            // Filter out protected objects (locked layers, Canvas/Pasteboard layers, background shapes)
            // Skip objects on locked layers
            if object.layerIndex < snapshot.layers.count && snapshot.layers[object.layerIndex].isLocked {
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
                 .image(let shape),
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

        let candidateCount = viewState.selectedObjectIDs.count
        if candidateCount != objectIDsToDelete.count {
            let blockedCount = candidateCount - objectIDsToDelete.count
            Log.error("🚫 PROTECTION: Blocked deletion of \(blockedCount) protected object(s)", category: .error)
        }

        if !objectIDsToDelete.isEmpty {
            let command = DeleteObjectCommand(objectIDs: Array(objectIDsToDelete), document: self)
            executeCommand(command)
        }

        viewState.selectedObjectIDs.removeAll()
        
    }

    func getSelectedShapes() -> [VectorShape] {
        var selectedShapes: [VectorShape] = []

        for objectID in viewState.selectedObjectIDs {
            if let obj = snapshot.objects[objectID] {
                switch obj.objectType {
                case .shape(let shape),
                 .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    selectedShapes.append(shape)
                case .text:
                    break
                }
            }
        }

        return selectedShapes
    }

    func getShapesByIds(_ shapeIDs: Set<UUID>) -> [VectorShape] {
        var shapes: [VectorShape] = []

        for shapeID in shapeIDs {
            if let obj = snapshot.objects[shapeID] {
                switch obj.objectType {
                case .shape(let shape),
                 .image(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    shapes.append(shape)
                case .text:
                    break
                }
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
                     .image(let shape),
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

    // MARK: - Selection with Undo Support

    /// Changes selection with undo/redo support
    func setSelectionWithUndo(_ newSelectedIDs: Set<UUID>, ordered: [UUID]? = nil) {
        let oldSelectedIDs = viewState.selectedObjectIDs
        let oldOrderedIDs = viewState.orderedSelectedObjectIDs

        // Don't create command if nothing changed
        guard newSelectedIDs != oldSelectedIDs else { return }

        let newOrderedIDs = ordered ?? Array(newSelectedIDs)

        let command = SelectionCommand(
            oldSelectedIDs: oldSelectedIDs,
            newSelectedIDs: newSelectedIDs,
            oldOrderedIDs: oldOrderedIDs,
            newOrderedIDs: newOrderedIDs
        )
        executeCommand(command)
    }

    /// Adds to selection with undo/redo support
    func addToSelectionWithUndo(_ shapeID: UUID) {
        guard findObject(by: shapeID) != nil else { return }

        var newSelectedIDs = viewState.selectedObjectIDs
        newSelectedIDs.insert(shapeID)

        var newOrderedIDs = viewState.orderedSelectedObjectIDs
        if !newOrderedIDs.contains(shapeID) {
            newOrderedIDs.append(shapeID)
        }

        setSelectionWithUndo(newSelectedIDs, ordered: newOrderedIDs)
    }

    /// Removes from selection with undo/redo support
    func removeFromSelectionWithUndo(_ shapeID: UUID) {
        var newSelectedIDs = viewState.selectedObjectIDs
        newSelectedIDs.remove(shapeID)

        var newOrderedIDs = viewState.orderedSelectedObjectIDs
        newOrderedIDs.removeAll { $0 == shapeID }

        setSelectionWithUndo(newSelectedIDs, ordered: newOrderedIDs)
    }

    /// Toggles selection with undo/redo support
    func toggleSelectionWithUndo(_ shapeID: UUID) {
        if viewState.selectedObjectIDs.contains(shapeID) {
            removeFromSelectionWithUndo(shapeID)
        } else {
            addToSelectionWithUndo(shapeID)
        }
    }

    /// Clears selection with undo/redo support
    func clearSelectionWithUndo() {
        guard !viewState.selectedObjectIDs.isEmpty else { return }
        setSelectionWithUndo([], ordered: [])
    }

    func selectShape(_ shapeID: UUID) {
        if let vectorObject = findObject(by: shapeID) {
            setSelectionWithUndo([vectorObject.id], ordered: [vectorObject.id])
        }
    }

    func addToSelection(_ shapeID: UUID) {
        if let vectorObject = findObject(by: shapeID) {
            addToSelectionWithUndo(vectorObject.id)
        }
    }

    func selectAll() {
        let visibleObjects = snapshot.objects.values.filter { object in
            // Skip invisible or locked objects
            guard object.isVisible && !object.isLocked else { return false }

            // Skip if layer doesn't exist
            guard object.layerIndex < snapshot.layers.count else { return false }

            let layer = snapshot.layers[object.layerIndex]

            // Skip objects on invisible or locked layers
            guard layer.isVisible && !layer.isLocked else { return false }

            // Skip objects on Canvas or Pasteboard layers (layer indices 1 and 0)
            guard object.layerIndex > 1 else { return false }

            // Skip background shapes
            switch object.objectType {
            case .shape(let shape),
                 .text(let shape),
                 .image(let shape),
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
            // Sort by area (largest to smallest) so largest object is selection #1
            let sortedByArea = visibleObjects.sorted { obj1, obj2 in
                let bounds1 = obj1.shape.isGroupContainer ? obj1.shape.groupBounds : obj1.shape.bounds
                let bounds2 = obj2.shape.isGroupContainer ? obj2.shape.groupBounds : obj2.shape.bounds
                let area1 = bounds1.width * bounds1.height
                let area2 = bounds2.width * bounds2.height
                return area1 > area2
            }

            let orderedIDs = sortedByArea.map { $0.id }
            let selectedIDs = Set(visibleObjects.map { $0.id })
            setSelectionWithUndo(selectedIDs, ordered: orderedIDs)
        }
    }

    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }

        var newShapeIDs: Set<UUID> = []

        // Iterate directly over UUIDs and lookup from snapshot - O(1) per lookup
        for objectID in viewState.selectedObjectIDs {
            guard let obj = snapshot.objects[objectID],
                  obj.layerIndex == layerIndex else { continue }

            switch obj.objectType {
            case .shape(let shape),
                 .image(let shape),
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
