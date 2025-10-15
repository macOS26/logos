import SwiftUI
import Combine
extension DrawingCanvas {
    internal func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !directSelectedShapeIDs.isEmpty {
            handleDirectSelectionShapeDrag(value: value, geometry: geometry)
            return
        }

        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle {
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let screenTolerance: Double = 15.0
            let tolerance: Double = screenTolerance / document.zoomLevel


            var foundPointOrHandle = false

            if !directSelectedShapeIDs.isEmpty {
                foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)
            }

            if !foundPointOrHandle {
                if directSelectWholeShape(at: canvasLocation) {
                    foundPointOrHandle = selectIndividualAnchorPointOrHandle(at: canvasLocation, tolerance: tolerance)

                    if !foundPointOrHandle && !directSelectedShapeIDs.isEmpty {
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

        for pointID in selectedPoints {
            if let unifiedObject = document.findObject(by: pointID.shapeID) {
                let layerIndex = unifiedObject.layerIndex
                if document.layers[layerIndex].isLocked {
                    return
                }
            }
        }

        for handleID in selectedHandles {
            if let unifiedObject = document.findObject(by: handleID.shapeID) {
                let layerIndex = unifiedObject.layerIndex
                if document.layers[layerIndex].isLocked {
                    return
                }
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

        let preciseZoom = Double(document.zoomLevel)
        let preciseTranslationX = Double(value.translation.width)
        let preciseTranslationY = Double(value.translation.height)

        let delta = CGPoint(
            x: preciseTranslationX / preciseZoom,
            y: preciseTranslationY / preciseZoom
        )


        var snappedDelta = delta

        if (document.snapToPoint || document.snapToGrid) && !selectedPoints.isEmpty {
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

        for shapeID in affectedShapeIDs {
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                   var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                    shape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
                    break
                }
            }
        }

        document.objectPositionUpdateTrigger.toggle()
    }


    private func handleDirectSelectionShapeDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if !isDraggingDirectSelectedShapes {
            isDraggingDirectSelectedShapes = true

            document.selectedObjectIDs = directSelectedShapeIDs

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

        for pointID in selectedPoints {
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == pointID.shapeID }),
                   let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                    var updatedShape = shape
                    updatedShape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                    break
                }
            }
        }
        for handleID in selectedHandles {
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == handleID.shapeID }),
                   let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                    var updatedShape = shape
                    updatedShape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                    break
                }
            }
        }

        //document.updateUnifiedObjectsOptimized(sendUpdate: false)

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
