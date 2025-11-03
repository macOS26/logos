import SwiftUI
import Combine
extension DrawingCanvas {
    internal func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !selectedObjectIDs.isEmpty {
            handleDirectSelectionShapeDrag(value: value, geometry: geometry)
            return
        }

        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle {
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let screenTolerance: Double = 15.0
            let tolerance: Double = screenTolerance / document.viewState.zoomLevel
            var foundPointOrHandle = false

            if !selectedObjectIDs.isEmpty {
                foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)
            }

            if !foundPointOrHandle {
                if directSelectWholeShape(at: canvasLocation) {
                    foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)

                    if !foundPointOrHandle && !selectedObjectIDs.isEmpty {
                        handleDirectSelectionShapeDrag(value: value, geometry: geometry)
                        return
                    }
                }
            }

            if !foundPointOrHandle {
                return
            }

        }

        guard !selectedPoints.isEmpty || !selectedHandles.isEmpty else { return }

        // O(1) lock check - any selected object locked?
        for pointID in selectedPoints {
            if lockedObjectIDs.contains(pointID.shapeID) {
                return
            }
        }

        for handleID in selectedHandles {
            if lockedObjectIDs.contains(handleID.shapeID) {
                return
            }
        }

        if !isDraggingPoint && !isDraggingHandle {
            isDraggingPoint = !selectedPoints.isEmpty
            isDraggingHandle = !selectedHandles.isEmpty

            // Enable live point drag mode to skip spatial index rebuilds
            document.viewState.isLivePointDrag = true

            var affectedShapeIDs = Set<UUID>()
            for pointID in selectedPoints {
                affectedShapeIDs.insert(pointID.shapeID)
            }
            for handleID in selectedHandles {
                affectedShapeIDs.insert(handleID.shapeID)
            }

            originalDragShapes.removeAll()
            for shapeID in affectedShapeIDs {
                if let shape = document.findShape(by: shapeID) {
                    originalDragShapes[shapeID] = shape
                }
            }

            captureOriginalPositions()
        }

        let preciseZoom = Double(document.viewState.zoomLevel)
        let preciseTranslationX = Double(value.translation.width)
        let preciseTranslationY = Double(value.translation.height)
        let delta = CGPoint(
            x: preciseTranslationX / preciseZoom,
            y: preciseTranslationY / preciseZoom
        )

        var snappedDelta = delta

        if (document.gridSettings.snapToPoint || document.gridSettings.snapToGrid) && !selectedPoints.isEmpty {
            if let firstPointID = selectedPoints.first,
               let originalPosition = originalPointPositions[firstPointID] {
                let unsnappedPosition = CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                )
                let snappedPosition = applySnapping(to: unsnappedPosition)

                snappedDelta = CGPoint(
                    x: snappedPosition.x - originalPosition.x,
                    y: snappedPosition.y - originalPosition.y
                )
            }
        }

        // If handles are selected, prioritize handle dragging over point dragging
        let shouldDragPoints = selectedHandles.isEmpty && !selectedPoints.isEmpty
        let shouldDragHandles = !selectedHandles.isEmpty

        // Update live preview positions (don't modify actual data during drag)
        if shouldDragPoints {
            for pointID in selectedPoints {
                if let originalPosition = originalPointPositions[pointID] {
                    let newPointPosition = CGPoint(
                        x: originalPosition.x + snappedDelta.x,
                        y: originalPosition.y + snappedDelta.y
                    )
                    livePointPositions[pointID] = newPointPosition

                    // Move attached handles with the point
                    updateLiveHandlesForMovedPoint(pointID: pointID, delta: snappedDelta)
                }
            }
        }

        if shouldDragHandles {
            for handleID in selectedHandles {
            if let originalPosition = originalHandlePositions[handleID] {
                let newPosition = CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                )
                liveHandlePositions[handleID] = newPosition

                // Calculate and update linked handle for smooth curves (if not holding Option)
                if !isOptionPressed {
                    updateLiveLinkedHandle(handleID: handleID, newPosition: newPosition)
                }
            }
            }
        }
    }

    private func updateLiveHandlesForMovedPoint(pointID: PointID, delta: CGPoint) {
        guard let object = document.snapshot.objects[pointID.shapeID],
              case .shape(let shape) = object.objectType,
              pointID.elementIndex < shape.path.elements.count else { return }

        let element = shape.path.elements[pointID.elementIndex]

        // Move incoming handle (control2 of current element)
        if case .curve(_, _, let control2) = element {
            let handleID = HandleID(shapeID: pointID.shapeID, pathIndex: 0, elementIndex: pointID.elementIndex, handleType: .control2)
            if let originalHandlePos = originalHandlePositions[handleID] {
                liveHandlePositions[handleID] = CGPoint(
                    x: originalHandlePos.x + delta.x,
                    y: originalHandlePos.y + delta.y
                )
            } else {
                // Handle wasn't being dragged, move it by the point's delta
                liveHandlePositions[handleID] = CGPoint(
                    x: control2.x + delta.x,
                    y: control2.y + delta.y
                )
            }
        }

        // Move outgoing handle (control1 of next element)
        let nextIndex = pointID.elementIndex + 1
        if nextIndex < shape.path.elements.count {
            let nextElement = shape.path.elements[nextIndex]
            if case .curve(_, let control1, _) = nextElement {
                let handleID = HandleID(shapeID: pointID.shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                if let originalHandlePos = originalHandlePositions[handleID] {
                    liveHandlePositions[handleID] = CGPoint(
                        x: originalHandlePos.x + delta.x,
                        y: originalHandlePos.y + delta.y
                    )
                } else {
                    // Handle wasn't being dragged, move it by the point's delta
                    liveHandlePositions[handleID] = CGPoint(
                        x: control1.x + delta.x,
                        y: control1.y + delta.y
                    )
                }
            }
        }
    }

    private func updateLiveLinkedHandle(handleID: HandleID, newPosition: CGPoint) {
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType,
              handleID.elementIndex < shape.path.elements.count else { return }

        let elements = shape.path.elements

        // Check for first/last coincident points (closed paths)
        if checkFirstLastCoincidentForLive(elements: elements, handleID: handleID, newPosition: newPosition) {
            return
        }

        // Regular linked handle logic
        let element = elements[handleID.elementIndex]
        var anchorPoint: CGPoint?
        var anchorPointID: PointID?
        var oppositeHandleID: HandleID?
        var oppositeOriginalPosition: CGPoint?

        if handleID.handleType == .control2 {
            guard case .curve(let to, _, _) = element else { return }
            anchorPoint = CGPoint(x: to.x, y: to.y)
            anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: handleID.elementIndex)

            let nextIndex = handleID.elementIndex + 1
            if nextIndex < elements.count,
               case .curve(_, let nextControl1, _) = elements[nextIndex] {
                oppositeHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                oppositeOriginalPosition = CGPoint(x: nextControl1.x, y: nextControl1.y)
            }
        } else if handleID.handleType == .control1 {
            let prevIndex = handleID.elementIndex - 1
            if prevIndex >= 0,
               case .curve(let prevTo, _, let prevControl2) = elements[prevIndex] {
                anchorPoint = CGPoint(x: prevTo.x, y: prevTo.y)
                anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex)
                oppositeHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
                oppositeOriginalPosition = CGPoint(x: prevControl2.x, y: prevControl2.y)
            }
        }

        guard var anchor = anchorPoint,
              let oppositeID = oppositeHandleID,
              let oppositeOriginal = oppositeOriginalPosition else { return }

        if let liveAnchor = anchorPointID, let livePos = livePointPositions[liveAnchor] {
            anchor = livePos
        }

        let linkedPosition = calculateLinkedHandle(
            anchorPoint: anchor,
            draggedHandle: newPosition,
            originalOppositeHandle: oppositeOriginal
        )

        liveHandlePositions[oppositeID] = linkedPosition
    }

    private func checkFirstLastCoincidentForLive(elements: [PathElement], handleID: HandleID, newPosition: CGPoint) -> Bool {
        guard elements.count >= 2 else { return false }

        // Get first and last points
        let firstPoint: CGPoint?
        if case .move(let firstTo) = elements[0] {
            firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)
        } else {
            firstPoint = nil
        }

        var lastElementIndex = elements.count - 1
        if case .close = elements[lastElementIndex] {
            lastElementIndex -= 1
        }

        let lastPoint: CGPoint?
        if lastElementIndex >= 0 {
            switch elements[lastElementIndex] {
            case .curve(let lastTo, _, _), .line(let lastTo), .quadCurve(let lastTo, _):
                lastPoint = CGPoint(x: lastTo.x, y: lastTo.y)
            default:
                lastPoint = nil
            }
        } else {
            lastPoint = nil
        }

        guard let first = firstPoint, let last = lastPoint,
              abs(first.x - last.x) < 0.001 && abs(first.y - last.y) < 0.001 else {
            return false
        }

        let anchorPoint = first

        // Dragging first point's outgoing handle -> update last point's incoming handle
        if handleID.handleType == .control1 && handleID.elementIndex == 1 {
            if case .curve(_, _, let lastControl2) = elements[lastElementIndex] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: lastControl2.x, y: lastControl2.y)
                )

                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)
                liveHandlePositions[oppositeHandleID] = oppositeHandle
                return true
            }
        }

        // Dragging last point's incoming handle -> update first point's outgoing handle
        if handleID.handleType == .control2 && handleID.elementIndex == lastElementIndex {
            if elements.count > 1, case .curve(_, let secondControl1, _) = elements[1] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: secondControl1.x, y: secondControl1.y)
                )

                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                liveHandlePositions[oppositeHandleID] = oppositeHandle
                return true
            }
        }

        return false
    }

    private func moveHandleToAbsolutePositionWithoutLinked(_ handleID: HandleID, to newPosition: CGPoint) {
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType else { return }

        guard handleID.elementIndex < shape.path.elements.count else { return }

        let newHandle = VectorPoint(newPosition.x, newPosition.y)
        var elements = shape.path.elements

        switch elements[handleID.elementIndex] {
        case .curve(let to, let control1, let control2):
            if handleID.handleType == .control1 {
                elements[handleID.elementIndex] = .curve(to: to, control1: newHandle, control2: control2)
            } else {
                elements[handleID.elementIndex] = .curve(to: to, control1: control1, control2: newHandle)
            }
        case .quadCurve(let to, _):
            if handleID.handleType == .control1 {
                elements[handleID.elementIndex] = .quadCurve(to: to, control: newHandle)
            }
        default:
            break
        }

        // DON'T call updateLinkedHandle - we already calculated linked positions during drag

        document.updateShapeByID(handleID.shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
    }

    private func calculateLinkedHandle(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
        let draggedVector = CGPoint(
            x: draggedHandle.x - anchorPoint.x,
            y: draggedHandle.y - anchorPoint.y
        )

        let originalVector = CGPoint(
            x: originalOppositeHandle.x - anchorPoint.x,
            y: originalOppositeHandle.y - anchorPoint.y
        )

        let originalLength = sqrt(originalVector.x * originalVector.x + originalVector.y * originalVector.y)
        let draggedLength = sqrt(draggedVector.x * draggedVector.x + draggedVector.y * draggedVector.y)

        guard draggedLength > 0.1 else { return originalOppositeHandle }

        let normalizedDragged = CGPoint(
            x: draggedVector.x / draggedLength,
            y: draggedVector.y / draggedLength
        )

        return CGPoint(
            x: anchorPoint.x - normalizedDragged.x * originalLength,
            y: anchorPoint.y - normalizedDragged.y * originalLength
        )
    }

    private func handleDirectSelectionShapeDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if !isDraggingDirectSelectedShapes {
            isDraggingDirectSelectedShapes = true

            document.viewState.selectedObjectIDs = selectedObjectIDs

            startSelectionDrag()
            selectionDragStart = value.startLocation
        }

        handleSelectionDrag(value: value, geometry: geometry)
    }

    internal func finishDirectSelectionDrag() {
        if isDraggingDirectSelectedShapes {
            finishSelectionDrag()
            isDraggingDirectSelectedShapes = false

            return
        }

        // Apply all live positions to actual data in one batch
        // We already calculated linked handles during drag, so skip recalculating them
        let originalSelectedHandles = selectedHandles  // Save current selection

        for (pointID, livePosition) in livePointPositions {
            movePointToAbsolutePosition(pointID, to: livePosition)
        }

        for (handleID, livePosition) in liveHandlePositions {
            moveHandleToAbsolutePositionWithoutLinked(handleID, to: livePosition)
        }

        // Restore original selection (don't select auto-calculated linked handles)
        selectedHandles = originalSelectedHandles

        // Clear live preview state
        livePointPositions.removeAll()
        liveHandlePositions.removeAll()

        // Disable live drag mode to allow spatial index rebuild
        document.viewState.isLivePointDrag = false

        isDraggingPoint = false
        isDraggingHandle = false
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()

        // O(1) bounds update using snapshot
        var affectedShapeIDs = Set<UUID>()
        for pointID in selectedPoints {
            affectedShapeIDs.insert(pointID.shapeID)
        }
        for handleID in selectedHandles {
            affectedShapeIDs.insert(handleID.shapeID)
        }

        // Rebuild spatial index once at drag end
        var affectedLayers = Set<Int>()
        for shapeID in affectedShapeIDs {
            if let object = document.snapshot.objects[shapeID] {
                affectedLayers.insert(object.layerIndex)
            }
        }
        document.triggerLayerUpdates(for: affectedLayers)

        if !originalDragShapes.isEmpty {
            var newShapes: [UUID: VectorShape] = [:]
            var objectIDs: [UUID] = []

            for (shapeID, _) in originalDragShapes {
                objectIDs.append(shapeID)
                if let updatedShape = document.findShape(by: shapeID) {
                    newShapes[shapeID] = updatedShape
                }
            }

            let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: originalDragShapes, newShapes: newShapes)
            document.commandManager.execute(command)

            originalDragShapes.removeAll()
        }
    }
}
