
import SwiftUI

extension VectorDocument {
    func addShape(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()

        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)

        selectedShapeIDs = [shape.id]
        selectedObjectIDs = [shape.id]
        syncSelectionArrays()
    }

    func addShapeToFront(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()

        addShapeToFrontOfUnifiedSystem(shape, layerIndex: layerIndex)

        selectedShapeIDs = [shape.id]
        selectedObjectIDs = [shape.id]
        syncSelectionArrays()
    }

    func addShape(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }
        saveToUndoStack()

        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }

    func addShapeWithoutUndo(_ shape: VectorShape, to layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < layers.count else { return }

        addShapeToUnifiedSystem(shape, layerIndex: layerIndex)
    }

    func removeSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()

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
        saveToUndoStack()

        let objectsToDelete = unifiedObjects.filter { selectedObjectIDs.contains($0.id) }

        let protectedObjects = objectsToDelete.filter { objectToDelete in
            switch objectToDelete.objectType {
            case .shape(let shape):
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
            case .shape(let shape):
                if !shape.isTextObject {
                    if let layerIndex = objectToDelete.layerIndex < layers.count ? objectToDelete.layerIndex : nil {
                        removeShapesUnified(layerIndex: layerIndex, where: { $0.id == shape.id })
                    }
                }
            }
        }

        unifiedObjects.removeAll { selectedObjectIDs.contains($0.id) }

        selectedObjectIDs.removeAll()

        syncSelectionArrays()

    }

    func getSelectedShapes() -> [VectorShape] {
        var selectedShapes: [VectorShape] = []

        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if selectedShapeIDs.contains(shape.id) {
                    selectedShapes.append(shape)
                }
            }
        }

        return selectedShapes
    }

    func getShapesByIds(_ shapeIDs: Set<UUID>) -> [VectorShape] {
        var shapes: [VectorShape] = []

        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shapeIDs.contains(shape.id) {
                    shapes.append(shape)
                }
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
        return unifiedObjects
            .filter { object in
                guard object.isVisible else { return false }
                guard object.layerIndex < layers.count else { return false }
                let layer = layers[object.layerIndex]
                return layer.isVisible
            }
            .sorted { obj1, obj2 in
                if obj1.layerIndex != obj2.layerIndex {
                    return obj1.layerIndex < obj2.layerIndex
                }
                return obj1.orderID < obj2.orderID
            }
    }

    func getSelectedShapesInStackingOrder() -> [VectorShape] {
        var stackingOrderShapes: [VectorShape] = []

        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if selectedShapeIDs.contains(shape.id) {
                    stackingOrderShapes.append(shape)
                }
            }
        }

        return stackingOrderShapes
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
        guard let layerIndex = selectedLayerIndex else { return }

        let layerObjects = unifiedObjects.filter {
            $0.layerIndex == layerIndex && $0.isVisible && !$0.isLocked
        }

        if !layerObjects.isEmpty {
            selectedObjectIDs = Set(layerObjects.map { $0.id })
            syncSelectionArrays()
        }
    }

    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()

        let selectedShapes = unifiedObjects.filter { unifiedObject in
            guard selectedObjectIDs.contains(unifiedObject.id) &&
                  unifiedObject.layerIndex == layerIndex else { return false }

            if case .shape = unifiedObject.objectType {
                return true
            } else {
                return false
            }
        }

        var newShapeIDs: Set<UUID> = []

        for unifiedObject in selectedShapes {
            if case .shape(let shape) = unifiedObject.objectType {
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
            }
        }

        selectedShapeIDs = newShapeIDs
        syncUnifiedSelectionFromLegacy()
    }

    internal func applyTransformToShapeCoordinates(shape: VectorShape, transform: CGAffineTransform) -> VectorShape {
        if transform.isIdentity {
            return shape
        }

        var transformedElements: [PathElement] = []

        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))

            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))

            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))

            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))

            case .close:
                transformedElements.append(.close)
            }
        }

        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)

        var newShape = shape
        newShape.path = transformedPath
        newShape.transform = .identity

        return newShape
    }
}
