import SwiftUI
import Combine

extension DrawingCanvas {
    internal func startSelectionDrag() {
        guard document.selectedLayerIndex != nil,
              !document.viewState.selectedObjectIDs.isEmpty else { return }

        dragUpdateCounter = 0

        let selectedObjects = document.viewState.selectedObjectIDs.compactMap { document.snapshot.objects[$0] }

        for object in selectedObjects {
            if object.layerIndex < document.layers.count {
                let layer = document.layers[object.layerIndex]
                if layer.isLocked {
                    return
                }
            }

            switch object.objectType {
            case .text:
                break
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shape.isLocked {
                    return
                }
            }
        }

        // Calculate combined bounding box in DOCUMENT coordinates (with transforms applied)
        var combinedBounds: CGRect?
        for object in selectedObjects {
            switch object.objectType {
            case .text:
                break
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                // Apply transform to get bounds in document coordinates
                let transformedBounds = bounds.applying(shape.transform)
                if let existing = combinedBounds {
                    combinedBounds = existing.union(transformedBounds)
                } else {
                    combinedBounds = transformedBounds
                }
            }
        }
        cachedSelectionBoundsForDrag = combinedBounds

        initialObjectPositions.removeAll()

        for object in selectedObjects {
            switch object.objectType {
            case .text(let shape):
                if let textObject = document.findText(by: shape.id) {
                    let centerX = textObject.position.x + textObject.bounds.width/2
                    let centerY = textObject.position.y + textObject.bounds.height/2
                    let calculatedCenter = CGPoint(x: centerX, y: centerY)
                    initialObjectPositions[object.id] = calculatedCenter
                } else {
                    let bounds = shape.bounds
                    let centerX = shape.transform.tx + bounds.width/2
                    let centerY = shape.transform.ty + bounds.height/2
                    let fallbackCenter = CGPoint(x: centerX, y: centerY)
                    initialObjectPositions[object.id] = fallbackCenter
                }
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                // Calculate center in DOCUMENT coordinates (not local bounds)
                let localCenter = CGPoint(x: bounds.midX, y: bounds.midY)
                let documentCenter = localCenter.applying(shape.transform)
                initialObjectPositions[object.id] = documentCenter

                initialObjectTransforms[object.id] = shape.transform
            }
        }
    }

    internal func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard document.selectedLayerIndex != nil,
              !document.viewState.selectedObjectIDs.isEmpty else { return }

        let selectedObjects = document.viewState.selectedObjectIDs.compactMap { document.snapshot.objects[$0] }

        for object in selectedObjects {
            if object.layerIndex < document.layers.count {
                let layer = document.layers[object.layerIndex]
                if layer.isLocked {
                    return
                }
            }

            switch object.objectType {
            case .text:
                break
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shape.isLocked {
                    return
                }
            }
        }

        let cursorDelta = CGPoint(
            x: value.location.x - selectionDragStart.x,
            y: value.location.y - selectionDragStart.y
        )

        let preciseZoom = Double(document.viewState.zoomLevel)
        var canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )

        if document.gridSettings.snapToGrid || document.gridSettings.snapToPoint {
            if let firstObjectID = document.viewState.selectedObjectIDs.first,
               let initialCenter = initialObjectPositions[firstObjectID],
               let firstObject = document.snapshot.objects[firstObjectID] {

                if case .shape(let shape) = firstObject.objectType {
                    let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    // Calculate transformed bounds size in document coordinates
                    let transformedBounds = bounds.applying(shape.transform)
                    let topLeftX = initialCenter.x - transformedBounds.width/2 + canvasDelta.x
                    let topLeftY = initialCenter.y - transformedBounds.height/2 + canvasDelta.y
                    let targetTopLeft = CGPoint(x: topLeftX, y: topLeftY)
                    let snappedTopLeft = applySnapping(to: targetTopLeft)

                    let snappedCenter = CGPoint(
                        x: snappedTopLeft.x + transformedBounds.width/2,
                        y: snappedTopLeft.y + transformedBounds.height/2
                    )

                    canvasDelta = CGPoint(x: snappedCenter.x - initialCenter.x, y: snappedCenter.y - initialCenter.y)
                }
            }
        }

        for object in selectedObjects {
            if case .shape(let shape) = object.objectType {
                if shape.isClippingPath {
                }
            }
        }

        currentDragDelta = canvasDelta
        liveDragOffset = canvasDelta

        // Set active layer for performance optimization (hides other layers during drag)
        if document.activeLayerIndexDuringDrag == nil, let firstSelected = document.viewState.selectedObjectIDs.first {
            if let obj = document.findObject(by: firstSelected) {
                document.activeLayerIndexDuringDrag = obj.layerIndex

                // Set all layers that are at 100% opacity to 0.9999999999 during drag
                for layer in document.layers {
                    if layer.opacity == 1.0 {
                        layerPreviewOpacities[layer.id] = 0.9999999999
                    }
                }
            }
        }
    }

    internal func finishSelectionDrag() {
        if document.isHandleScalingActive {
            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            currentDragDelta = .zero
            liveDragOffset = .zero
            cachedSelectionBoundsForDrag = nil
            document.activeLayerIndexDuringDrag = nil
            layerPreviewOpacities.removeAll()
            return
        }

        if !initialObjectPositions.isEmpty && currentDragDelta != .zero {
            guard document.selectedLayerIndex != nil else { return }

            var oldShapes: [UUID: VectorShape] = [:]
            var affectedObjectIDs: Set<UUID> = []
            let selectedObjects = document.viewState.selectedObjectIDs.compactMap { document.snapshot.objects[$0] }

            for object in selectedObjects {
                if case .shape(let shape) = object.objectType {
                    oldShapes[object.id] = shape
                    affectedObjectIDs.insert(object.id)

                    if shape.isClippingPath {
                        let allShapes = document.getShapesForLayer(object.layerIndex)
                        for clippedShape in allShapes {
                            if clippedShape.clippedByShapeID == shape.id {
                                if let clippedObj = document.snapshot.objects[clippedShape.id] {
                                    oldShapes[clippedObj.id] = clippedShape
                                    affectedObjectIDs.insert(clippedObj.id)
                                }
                            }
                        }
                    }
                }
            }

            // print("🟣 DRAG FINISH: Processing \(selectedObjects.count) selected objects")
            for object in selectedObjects {
                switch object.objectType {
                case .text(let shape):
                    // print("🟣 DRAG FINISH: Text object \(shape.id)")
                    document.translateTextInUnified(id: shape.id, delta: currentDragDelta)
                    affectedObjectIDs.insert(object.id)
                    oldShapes[object.id] = shape
                case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    // print("🟣 DRAG FINISH: Calling applyDragDeltaToUnifiedObject for \(shape.id), isGroupContainer=\(shape.isGroupContainer)")
                    applyDragDeltaToUnifiedObject(objectID: shape.id, delta: currentDragDelta)
                    affectedObjectIDs.insert(object.id)
                    oldShapes[object.id] = shape
                }
            }

            syncUnifiedObjectsAfterMovement()

            var newShapes: [UUID: VectorShape] = [:]
            for objectID in affectedObjectIDs {
                if let object = document.snapshot.objects[objectID] {
                    switch object.objectType {
                    case .text(let shape):
                        if let updatedObject = document.snapshot.objects[shape.id],
                           case .text(let updatedShape) = updatedObject.objectType {
                            newShapes[objectID] = updatedShape
                        } else {
                            newShapes[objectID] = shape
                        }
                    case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                        if let updatedShape = document.findShape(by: shape.id) {
                            newShapes[objectID] = updatedShape
                        } else {
                            newShapes[objectID] = shape
                        }
                    }
                }
            }

            if !oldShapes.isEmpty && !newShapes.isEmpty {
                let command = ShapeModificationCommand(
                    objectIDs: Array(affectedObjectIDs),
                    oldShapes: oldShapes,
                    newShapes: newShapes
                )
                document.executeCommand(command)
            }

            document.updateTransformPanelValues()
            // Note: Layer triggers handled by ShapeModificationCommand

            initialObjectPositions.removeAll()
            initialObjectTransforms.removeAll()
            selectionDragStart = CGPoint.zero
            currentDragDelta = .zero
            liveDragOffset = .zero
            cachedSelectionBoundsForDrag = nil
            document.currentDragOffset = .zero
            document.dragPreviewCoordinates = .zero
            document.cachedSelectionBounds = nil
            document.activeLayerIndexDuringDrag = nil

            // Clear layer preview opacities
            layerPreviewOpacities.removeAll()

        } else {
            liveDragOffset = .zero
            cachedSelectionBoundsForDrag = nil
            document.cachedSelectionBounds = nil
        }
    }

    private func applyDragDeltaToUnifiedObject(objectID: UUID, delta: CGPoint) {
        guard let object = document.snapshot.objects[objectID] else {
            print("🔴 DRAG: Could not find object \(objectID)")
            return
        }

        switch object.objectType {
        case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
            applyDragDeltaToShape(shape: shape, delta: delta)
        case .text:
            return
        }
    }

    private func applyDragDeltaToShapeCoordinates(layerIndex: Int, shapeIndex: Int, delta: CGPoint) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        applyDragDeltaToShape(shape: shape, delta: delta)
    }

    private func applyDragDeltaToShape(shape: VectorShape, delta: CGPoint) {
        // print("      🟢 applyDragDeltaToShape: shape.id=\(shape.id), name=\(shape.name), delta=\(delta)")
        // print("         isGroupContainer=\(shape.isGroupContainer), hasImage=\(ImageContentRegistry.containsImage(shape, in: document))")
        // print("         path.elements.count=\(shape.path.elements.count), bounds=\(shape.bounds)")

        if ImageContentRegistry.containsImage(shape, in: document) {
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
                let objectType = VectorObject.determineType(for: groupedShape)
                if case .text = objectType {
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
            document.updateShapeByID(groupShape.id) { $0 = groupShape }
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
            for object in document.snapshot.objects.values {
                switch object.objectType {
                case .shape(let checkShape), .warp(let checkShape), .group(let checkShape), .clipGroup(let checkShape), .clipMask(let checkShape):
                    if checkShape.clippedByShapeID == shape.id {
                        applyDragDeltaToUnifiedObject(objectID: checkShape.id, delta: delta)
                    }
                case .text:
                    break
                }
            }
        }

        movedShape.updateBounds()
        document.updateShapeByID(movedShape.id) { $0 = movedShape }
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

            guard document.viewState.selectedObjectIDs.contains(unifiedObject.id) else { continue }

            switch unifiedObject.objectType {
            case .text(let oldShape):
                if let updatedText = document.findText(by: oldShape.id) {
                    let updatedShape = VectorShape.from(updatedText)
                    document.unifiedObjects[i] = VectorObject(
                        shape: updatedShape,
                        layerIndex: unifiedObject.layerIndex,
                    )
                }
            case .shape(let oldShape),
                 .warp(let oldShape),
                 .group(let oldShape),
                 .clipGroup(let oldShape),
                 .clipMask(let oldShape):
                if let updatedShape = document.findShape(by: oldShape.id) {
                    document.unifiedObjects[i] = VectorObject(
                        shape: updatedShape,
                        layerIndex: unifiedObject.layerIndex,
                    )
                }
            }
        }

    }
}
