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

        // Update live preview positions (don't modify actual data during drag)
        for pointID in selectedPoints {
            if let originalPosition = originalPointPositions[pointID] {
                livePointPositions[pointID] = CGPoint(
                    x: originalPosition.x + snappedDelta.x,
                    y: originalPosition.y + snappedDelta.y
                )
            }
        }

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

    private func updateLiveLinkedHandle(handleID: HandleID, newPosition: CGPoint) {
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType,
              handleID.elementIndex < shape.path.elements.count else { return }

        let element = shape.path.elements[handleID.elementIndex]

        // Get anchor point
        var anchorPoint: CGPoint?
        var anchorPointID: PointID?
        var oppositeHandleID: HandleID?
        var oppositeOriginalPosition: CGPoint?

        if handleID.handleType == .control2 {
            // Dragging control2 (incoming handle) -> update control1 of next element (outgoing)
            guard case .curve(let to, _, _) = element else { return }
            anchorPoint = CGPoint(x: to.x, y: to.y)
            anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: handleID.elementIndex)

            let nextIndex = handleID.elementIndex + 1
            if nextIndex < shape.path.elements.count,
               case .curve(_, let nextControl1, _) = shape.path.elements[nextIndex] {
                oppositeHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                oppositeOriginalPosition = CGPoint(x: nextControl1.x, y: nextControl1.y)
            }
        } else if handleID.handleType == .control1 {
            // Dragging control1 (outgoing handle) -> update control2 of previous element (incoming)
            let prevIndex = handleID.elementIndex - 1
            if prevIndex >= 0,
               case .curve(let prevTo, _, let prevControl2) = shape.path.elements[prevIndex] {
                anchorPoint = CGPoint(x: prevTo.x, y: prevTo.y)
                anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex)
                oppositeHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
                oppositeOriginalPosition = CGPoint(x: prevControl2.x, y: prevControl2.y)
            }
        }

        guard var anchor = anchorPoint,
              let oppositeID = oppositeHandleID,
              let oppositeOriginal = oppositeOriginalPosition else { return }

        // Use live anchor position if available
        if let liveAnchor = anchorPointID, let livePos = livePointPositions[liveAnchor] {
            anchor = livePos
        }

        // Calculate linked handle position
        let linkedPosition = calculateLinkedHandle(
            anchorPoint: anchor,
            draggedHandle: newPosition,
            originalOppositeHandle: oppositeOriginal
        )

        liveHandlePositions[oppositeID] = linkedPosition
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
        for (pointID, livePosition) in livePointPositions {
            movePointToAbsolutePosition(pointID, to: livePosition)
        }

        for (handleID, livePosition) in liveHandlePositions {
            moveHandleToAbsolutePosition(handleID, to: livePosition)
        }

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
