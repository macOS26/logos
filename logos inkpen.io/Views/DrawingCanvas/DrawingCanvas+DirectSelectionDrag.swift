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

        var affectedShapeIDs = Set<UUID>()
        for pointID in selectedPoints {
            if let originalPosition = originalPointPositions[pointID] {
                movePointToAbsolutePositionBatched(pointID, to: CGPoint(
                    x: originalPosition.x + snappedDelta.x,
                    y: originalPosition.y + snappedDelta.y
                ))
                affectedShapeIDs.insert(pointID.shapeID)
            }
        }

        for handleID in selectedHandles {
            if let originalPosition = originalHandlePositions[handleID] {
                moveHandleToAbsolutePositionBatched(handleID, to: CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                ))
                affectedShapeIDs.insert(handleID.shapeID)
            }
        }

        // Update bounds using O(1) snapshot lookup - don't iterate layers
        for shapeID in affectedShapeIDs {
            if let object = document.snapshot.objects[shapeID], case .shape(var shape) = object.objectType {
                shape.updateBounds()
                let updatedObject = VectorObject(id: object.id, layerIndex: object.layerIndex, objectType: .shape(shape))
                document.snapshot.objects[shapeID] = updatedObject
            }
        }

        document.viewState.objectPositionUpdateTrigger.toggle()
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

        for shapeID in affectedShapeIDs {
            if let object = document.snapshot.objects[shapeID], case .shape(var shape) = object.objectType {
                shape.updateBounds()
                let updatedObject = VectorObject(id: object.id, layerIndex: object.layerIndex, objectType: .shape(shape))
                document.snapshot.objects[shapeID] = updatedObject
            }
        }

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
