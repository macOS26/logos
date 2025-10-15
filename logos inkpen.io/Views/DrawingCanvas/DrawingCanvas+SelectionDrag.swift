import SwiftUI
import Combine

extension DrawingCanvas {
    internal func startSelectionDrag() {
        guard document.selectedLayerIndex != nil,
              !document.selectedObjectIDs.isEmpty else { return }

        dragUpdateCounter = 0

        let selectedObjects = document.unifiedObjects.filter { document.selectedObjectIDs.contains($0.id) }

        for unifiedObject in selectedObjects {
            if unifiedObject.layerIndex < document.layers.count {
                let layer = document.layers[unifiedObject.layerIndex]
                if layer.isLocked {
                    return
                }
            }

            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isLocked {
                    return
                }
            }
        }

        var combinedBounds: CGRect?
        for unifiedObject in selectedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape):
                let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                if let existing = combinedBounds {
                    combinedBounds = existing.union(bounds)
                } else {
                    combinedBounds = bounds
                }
            }
        }
        document.cachedSelectionBounds = combinedBounds

        initialObjectPositions.removeAll()

        for unifiedObject in selectedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape):

                if shape.isTextObject {
                    if let textObject = document.findText(by: shape.id) {
                        let centerX = textObject.position.x + textObject.bounds.width/2
                        let centerY = textObject.position.y + textObject.bounds.height/2
                        let calculatedCenter = CGPoint(x: centerX, y: centerY)
                        initialObjectPositions[unifiedObject.id] = calculatedCenter
                    } else {
                        let bounds = shape.bounds
                        let centerX = shape.transform.tx + bounds.width/2
                        let centerY = shape.transform.ty + bounds.height/2
                        let fallbackCenter = CGPoint(x: centerX, y: centerY)
                        initialObjectPositions[unifiedObject.id] = fallbackCenter
                    }
                } else {
                    let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    let centerX = bounds.midX
                    let centerY = bounds.midY
                    initialObjectPositions[unifiedObject.id] = CGPoint(x: centerX, y: centerY)
                }

                initialObjectTransforms[unifiedObject.id] = shape.transform
            }
        }
    }

    internal func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard document.selectedLayerIndex != nil,
              !document.selectedObjectIDs.isEmpty else { return }

        let selectedObjects = document.unifiedObjects.filter { document.selectedObjectIDs.contains($0.id) }

        for unifiedObject in selectedObjects {
            if unifiedObject.layerIndex < document.layers.count {
                let layer = document.layers[unifiedObject.layerIndex]
                if layer.isLocked {
                    return
                }
            }

            switch unifiedObject.objectType {
            case .shape(let shape):
                if shape.isLocked {
                    return
                }
            }
        }

        let cursorDelta = CGPoint(
            x: value.location.x - selectionDragStart.x,
            y: value.location.y - selectionDragStart.y
        )

        let preciseZoom = Double(document.zoomLevel)
        var canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )

        if document.snapToGrid || document.snapToPoint {
            if let firstObjectID = document.selectedObjectIDs.first,
               let initialCenter = initialObjectPositions[firstObjectID],
               let firstObject = document.findObject(by: firstObjectID) {

                if case .shape(let shape) = firstObject.objectType {
                    let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds

                    let topLeftX = initialCenter.x - bounds.width/2 + canvasDelta.x
                    let topLeftY = initialCenter.y - bounds.height/2 + canvasDelta.y
                    let targetTopLeft = CGPoint(x: topLeftX, y: topLeftY)

                    let snappedTopLeft = applySnapping(to: targetTopLeft)

                    let snappedCenter = CGPoint(
                        x: snappedTopLeft.x + bounds.width/2,
                        y: snappedTopLeft.y + bounds.height/2
                    )

                    canvasDelta = CGPoint(x: snappedCenter.x - initialCenter.x, y: snappedCenter.y - initialCenter.y)
                }
            }
        }

        for unifiedObject in selectedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.isClippingPath {
                }
            }
        }

        currentDragDelta = canvasDelta
        document.currentDragOffset = canvasDelta

        dragUpdateCounter += 1
        if dragUpdateCounter % 60 == 0 {
            document.dragPreviewCoordinates = canvasDelta
        }

    }

    internal func finishSelectionDrag() {
        if document.isHandleScalingActive {
            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            currentDragDelta = .zero
            document.cachedSelectionBounds = nil
            return
        }

        if !initialObjectPositions.isEmpty && currentDragDelta != .zero {
            guard document.selectedLayerIndex != nil else { return }

            // Capture old shapes for undo
            var oldShapes: [UUID: VectorShape] = [:]
            var affectedObjectIDs: Set<UUID> = []
            let selectedObjects = document.unifiedObjects.filter { document.selectedObjectIDs.contains($0.id) }

            for unifiedObject in selectedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    oldShapes[unifiedObject.id] = shape
                    affectedObjectIDs.insert(unifiedObject.id)

                    // If this is a clipping mask, also capture all clipped shapes
                    if shape.isClippingPath {
                        let allShapes = document.getShapesForLayer(unifiedObject.layerIndex)
                        for clippedShape in allShapes {
                            if clippedShape.clippedByShapeID == shape.id {
                                if let clippedObj = document.unifiedObjects.first(where: { $0.id == clippedShape.id }) {
                                    oldShapes[clippedObj.id] = clippedShape
                                    affectedObjectIDs.insert(clippedObj.id)
                                }
                            }
                        }
                    }
                }
            }

            for unifiedObject in selectedObjects {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    let shapes = document.getShapesForLayer(unifiedObject.layerIndex)
                    if let shapeIndex = shapes.firstIndex(where: { $0.id == unifiedObject.id }) {
                        if shape.isClippingPath {
                            applyDragDeltaToShapeCoordinates(layerIndex: unifiedObject.layerIndex, shapeIndex: shapeIndex, delta: currentDragDelta)
                        } else {
                            applyDragDeltaToShapeCoordinates(layerIndex: unifiedObject.layerIndex, shapeIndex: shapeIndex, delta: currentDragDelta)
                        }
                    }

                    if let textObj = document.findText(by: unifiedObject.id),
                       let initialCenter = initialObjectPositions[unifiedObject.id] {
                        let textBounds = textObj.bounds
                        let newPositionX = initialCenter.x - textBounds.width/2 + currentDragDelta.x
                        let newPositionY = initialCenter.y - textBounds.height/2 + currentDragDelta.y

                        let delta = CGPoint(x: newPositionX - textObj.position.x, y: newPositionY - textObj.position.y)
                        document.translateTextInUnified(id: unifiedObject.id, delta: delta)
                    }
                }
            }

            syncUnifiedObjectsAfterMovement()

            // Capture new shapes after transformation (including clipped shapes)
            var newShapes: [UUID: VectorShape] = [:]
            for objectID in affectedObjectIDs {
                if let unifiedObject = document.unifiedObjects.first(where: { $0.id == objectID }),
                   case .shape(let shape) = unifiedObject.objectType {
                    // For text objects, get from unifiedObjects directly (findShape excludes text)
                    if shape.isTextObject {
                        if let index = document.unifiedObjects.firstIndex(where: { $0.id == shape.id }),
                           case .shape(let updatedShape) = document.unifiedObjects[index].objectType {
                            newShapes[objectID] = updatedShape
                        } else {
                            newShapes[objectID] = shape
                        }
                    } else if let updatedShape = document.findShape(by: shape.id) {
                        newShapes[objectID] = updatedShape
                    } else {
                        newShapes[objectID] = shape
                    }
                }
            }

            // Execute undo command with ALL affected objects (including clipped shapes)
            if !oldShapes.isEmpty && !newShapes.isEmpty {
                let command = ShapeModificationCommand(
                    objectIDs: Array(affectedObjectIDs),
                    oldShapes: oldShapes,
                    newShapes: newShapes
                )
                document.executeCommand(command)
            }

            document.updateTransformPanelValues()

            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            currentDragDelta = .zero
            document.currentDragOffset = .zero
            document.dragPreviewCoordinates = .zero
            document.cachedSelectionBounds = nil

        } else {
            document.cachedSelectionBounds = nil
        }
    }

    private func applyDragDeltaToShapeCoordinates(layerIndex: Int, shapeIndex: Int, delta: CGPoint) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }

        if ImageContentRegistry.containsImage(shape) {
            var updatedShape = shape

            if updatedShape.transform.isIdentity {
                updatedShape.transform = updatedShape.transform.translatedBy(x: delta.x, y: delta.y)
            } else {

                let currentTransform = updatedShape.transform

                let translationTransform = CGAffineTransform(translationX: delta.x, y: delta.y)

                updatedShape.transform = currentTransform.concatenating(translationTransform)

            }

            document.updateShapeTransformAndPathInUnified(id: updatedShape.id, transform: updatedShape.transform)
            return
        }

        if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
            var updatedGroupedShapes: [VectorShape] = []

            for var groupedShape in shape.groupedShapes {
                if groupedShape.isTextObject {
                    if let textPosition = groupedShape.textPosition {
                        groupedShape.textPosition = CGPoint(x: textPosition.x + delta.x, y: textPosition.y + delta.y)
                    }
                    document.translateTextInUnified(id: groupedShape.id, delta: delta)
                }

                var updatedElements: [PathElement] = []

                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to):
                        let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        updatedElements.append(.move(to: VectorPoint(newPoint)))

                    case .line(let to):
                        let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        updatedElements.append(.line(to: VectorPoint(newPoint)))

                    case .curve(let to, let control1, let control2):
                        let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        let newControl1 = CGPoint(x: control1.x + delta.x, y: control1.y + delta.y)
                        let newControl2 = CGPoint(x: control2.x + delta.x, y: control2.y + delta.y)
                        updatedElements.append(.curve(
                            to: VectorPoint(newTo),
                            control1: VectorPoint(newControl1),
                            control2: VectorPoint(newControl2)
                        ))

                    case .quadCurve(let to, let control):
                        let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                        let newControl = CGPoint(x: control.x + delta.x, y: control.y + delta.y)
                        updatedElements.append(.quadCurve(
                            to: VectorPoint(newTo),
                            control: VectorPoint(newControl)
                        ))

                    case .close:
                        updatedElements.append(.close)
                    }
                }

                groupedShape.path = VectorPath(elements: updatedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.updateBounds()

                updatedGroupedShapes.append(groupedShape)
            }

            var groupShape = shape
            groupShape.groupedShapes = updatedGroupedShapes

            if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                var updatedWarpEnvelope: [CGPoint] = []
                for corner in shape.warpEnvelope {
                    let movedCorner = CGPoint(x: corner.x + delta.x, y: corner.y + delta.y)
                    updatedWarpEnvelope.append(movedCorner)
                }
                groupShape.warpEnvelope = updatedWarpEnvelope

            }

            groupShape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: groupShape)
            return
        }

        var updatedElements: [PathElement] = []

        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                updatedElements.append(.move(to: VectorPoint(newPoint)))

            case .line(let to):
                let newPoint = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                updatedElements.append(.line(to: VectorPoint(newPoint)))

            case .curve(let to, let control1, let control2):
                let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                let newControl1 = CGPoint(x: control1.x + delta.x, y: control1.y + delta.y)
                let newControl2 = CGPoint(x: control2.x + delta.x, y: control2.y + delta.y)
                updatedElements.append(.curve(
                    to: VectorPoint(newTo),
                    control1: VectorPoint(newControl1),
                    control2: VectorPoint(newControl2)
                ))

            case .quadCurve(let to, let control):
                let newTo = CGPoint(x: to.x + delta.x, y: to.y + delta.y)
                let newControl = CGPoint(x: control.x + delta.x, y: control.y + delta.y)
                updatedElements.append(.quadCurve(
                    to: VectorPoint(newTo),
                    control: VectorPoint(newControl)
                ))

            case .close:
                updatedElements.append(.close)
            }
        }

        let updatedPath = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)

        var movedShape = shape
        movedShape.path = updatedPath

        if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
            var updatedWarpEnvelope: [CGPoint] = []
            for corner in shape.warpEnvelope {
                let movedCorner = CGPoint(x: corner.x + delta.x, y: corner.y + delta.y)
                updatedWarpEnvelope.append(movedCorner)
            }
            movedShape.warpEnvelope = updatedWarpEnvelope

        }

        if shape.isClippingPath {
            let shapes = document.getShapesForLayer(layerIndex)
            for (idx, checkShape) in shapes.enumerated() {
                if checkShape.clippedByShapeID == shape.id {
                    applyDragDeltaToShapeCoordinates(layerIndex: layerIndex, shapeIndex: idx, delta: delta)
                }
            }
        }

        movedShape.updateBounds()
        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: movedShape)
    }

    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let transform = shape.transform

        if transform.isIdentity {
            return
        }

        if shape.isGroupContainer && !shape.groupedShapes.isEmpty {
            var transformedGroupedShapes: [VectorShape] = []

            for var groupedShape in shape.groupedShapes {
                var transformedElements: [PathElement] = []

                for element in groupedShape.path.elements {
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

                groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.transform = .identity
                groupedShape.updateBounds()

                transformedGroupedShapes.append(groupedShape)
            }

            shape.groupedShapes = transformedGroupedShapes
            shape.transform = .identity
            shape.updateBounds()
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)

            return
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

        shape.path = transformedPath
        shape.transform = .identity
        shape.updateBounds()

        var updatedShape = shape
        if !updatedShape.cornerRadii.isEmpty && updatedShape.isRoundedRectangle {
            updatedShape.transform = transform
            applyTransformToCornerRadii(shape: &updatedShape)
            document.updateShapeCornerRadiiInUnified(id: updatedShape.id, cornerRadii: updatedShape.cornerRadii, path: updatedShape.path)
        }

    }

    private func syncUnifiedObjectsAfterMovement() {

        for i in document.unifiedObjects.indices {
            let unifiedObject = document.unifiedObjects[i]

            guard document.selectedObjectIDs.contains(unifiedObject.id) else { continue }

            switch unifiedObject.objectType {
            case .shape(let oldShape):
                if oldShape.isTextObject {
                    if let updatedText = document.findText(by: oldShape.id) {
                        let updatedShape = VectorShape.from(updatedText)
                        document.unifiedObjects[i] = VectorObject(
                            shape: updatedShape,
                            layerIndex: unifiedObject.layerIndex,
                            orderID: unifiedObject.orderID
                        )
                    }
                } else {
                    if let updatedShape = document.findShape(by: oldShape.id) {
                        document.unifiedObjects[i] = VectorObject(
                            shape: updatedShape,
                            layerIndex: unifiedObject.layerIndex,
                            orderID: unifiedObject.orderID
                        )
                    }
                }
            }
        }

    }
}
