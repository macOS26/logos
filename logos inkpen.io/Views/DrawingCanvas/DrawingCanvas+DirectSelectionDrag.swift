import SwiftUI
import Combine
extension DrawingCanvas {
    internal func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        // Check for curve segment dragging first (before shape, points, or handles)
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle && !isDraggingCurveSegment {
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let screenTolerance: Double = 10.0
            let tolerance: Double = screenTolerance / document.viewState.zoomLevel

            // Try to find a curve segment at the click location (only if shapes are selected)
            if !selectedObjectIDs.isEmpty {
                if let curveSegment = findCurveSegmentInSelectedShapes(at: canvasLocation, tolerance: tolerance) {
                    isDraggingCurveSegment = true
                    draggedCurveSegment = curveSegment
                    dragStartLocation = canvasLocation

                    // Calculate parametric position t on the curve
                    if let shape = document.snapshot.objects[curveSegment.shapeID]?.shape {
                        curveSegmentDragT = calculateTOnCurveSegment(shape: shape, elementIndex: curveSegment.elementIndex, point: canvasLocation)
                    }

                    // Capture original handle positions
                    captureOriginalHandlesForCurveSegment(shapeID: curveSegment.shapeID, elementIndex: curveSegment.elementIndex)
                    return
                }
            }
        }

        if selectedPoints.isEmpty && selectedHandles.isEmpty && !selectedObjectIDs.isEmpty && !isDraggingCurveSegment {
            handleDirectSelectionShapeDrag(value: value, geometry: geometry)
            return
        }

        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle && !isDraggingCurveSegment {
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

        // Handle curve segment dragging
        if isDraggingCurveSegment {
            handleCurveSegmentDrag(value: value, geometry: geometry)
            return
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
        if isDraggingCurveSegment {
            finishCurveSegmentDrag()
            isDraggingCurveSegment = false
            draggedCurveSegment = nil
            return
        }

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

    // MARK: - Curve Segment Dragging

    private func findCurveSegmentInSelectedShapes(at location: CGPoint, tolerance: Double) -> (shapeID: UUID, elementIndex: Int)? {
        for objectID in selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID],
                  case .shape(let shape) = object.objectType,
                  shape.isVisible && !shape.isLocked else { continue }

            var previousPoint: VectorPoint?

            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .move(let to):
                    previousPoint = to
                case .line(let to):
                    previousPoint = to
                case .curve(let to, let control1, let control2):
                    if let prev = previousPoint {
                        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                        let c1 = CGPoint(x: control1.x, y: control1.y).applying(shape.transform)
                        let c2 = CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                        let end = CGPoint(x: to.x, y: to.y).applying(shape.transform)

                        if isPointNearBezierCurve(point: location, p0: start, p1: c1, p2: c2, p3: end, tolerance: tolerance) {
                            return (shape.id, elementIndex)
                        }
                    }
                    previousPoint = to
                case .quadCurve(let to, _):
                    previousPoint = to
                default:
                    break
                }
            }
        }
        return nil
    }

    private func calculateTOnCurveSegment(shape: VectorShape, elementIndex: Int, point: CGPoint) -> Double {
        guard elementIndex < shape.path.elements.count,
              case .curve(let to, let control1, let control2) = shape.path.elements[elementIndex] else {
            return 0.5
        }

        var previousPoint: VectorPoint?
        for (idx, element) in shape.path.elements.enumerated() {
            if idx == elementIndex {
                break
            }
            switch element {
            case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                previousPoint = to
            default:
                break
            }
        }

        guard let prev = previousPoint else { return 0.5 }

        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
        let c1 = CGPoint(x: control1.x, y: control1.y).applying(shape.transform)
        let c2 = CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
        let end = CGPoint(x: to.x, y: to.y).applying(shape.transform)

        var bestT: Double = 0.5
        var bestDistance: Double = Double.infinity

        for i in 0...100 {
            let t = Double(i) / 100.0
            let curvePoint = evaluateCubicBezier(p0: start, p1: c1, p2: c2, p3: end, t: t)
            let dist = distance(point, curvePoint)

            if dist < bestDistance {
                bestDistance = dist
                bestT = t
            }
        }

        return bestT
    }

    private func captureOriginalHandlesForCurveSegment(shapeID: UUID, elementIndex: Int) {
        // Clear previous state
        originalHandlePositions.removeAll()
        liveHandlePositions.removeAll()

        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType,
              elementIndex < shape.path.elements.count,
              case .curve(_, let control1, let control2) = shape.path.elements[elementIndex] else { return }

        // For curve from A to B at elementIndex:
        // - control1 is A's outgoing handle (what we drag)
        // - control2 is B's incoming handle (what we drag)

        let control1HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: elementIndex, handleType: .control1)
        let control2HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: elementIndex, handleType: .control2)

        originalHandlePositions[control1HandleID] = control1
        originalHandlePositions[control2HandleID] = control2

        // Check if this is a closed path
        let isClosed = shape.path.elements.last.map { element in
            if case .close = element { return true }
            return false
        } ?? false

        // Find last curve element index (skip .close if present)
        var lastCurveIndex = shape.path.elements.count - 1
        if isClosed && lastCurveIndex >= 0, case .close = shape.path.elements[lastCurveIndex] {
            lastCurveIndex -= 1
        }

        // Now find and capture the OPPOSITE handles for tangency maintenance
        // A's incoming handle (control2 of element at elementIndex-1)
        let prevIndex = elementIndex - 1
        if prevIndex >= 0, case .curve(_, _, let prevControl2) = shape.path.elements[prevIndex] {
            let prevControl2HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
            originalHandlePositions[prevControl2HandleID] = prevControl2
        } else if isClosed && elementIndex == 1 {
            // First curve segment in closed path - opposite handle is last curve's incoming handle
            if lastCurveIndex >= 0, case .curve(_, _, let lastControl2) = shape.path.elements[lastCurveIndex] {
                let lastControl2HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
                originalHandlePositions[lastControl2HandleID] = lastControl2
            }
        }

        // B's outgoing handle (control1 of element at elementIndex+1)
        let nextIndex = elementIndex + 1
        if nextIndex < shape.path.elements.count, case .curve(_, let nextControl1, _) = shape.path.elements[nextIndex] {
            let nextControl1HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
            originalHandlePositions[nextControl1HandleID] = nextControl1
        } else if isClosed && elementIndex == lastCurveIndex {
            // Last curve segment in closed path - opposite handle is first curve's outgoing handle
            if shape.path.elements.count > 1, case .curve(_, let firstControl1, _) = shape.path.elements[1] {
                let firstControl1HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                originalHandlePositions[firstControl1HandleID] = firstControl1
            }
        }
    }

    private func handleCurveSegmentDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let curveSegment = draggedCurveSegment else { return }

        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        let offset = CGPoint(
            x: currentLocation.x - dragStartLocation.x,
            y: currentLocation.y - dragStartLocation.y
        )

        guard let object = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let shape) = object.objectType,
              curveSegment.elementIndex < shape.path.elements.count else { return }

        // Adjust handles based on parametric position t and drag offset
        let t = curveSegmentDragT

        // Weighted influence based on where on curve was clicked
        let control1Weight = 1.0 - t  // More influence at t=0 (near point A)
        let control2Weight = t        // More influence at t=1 (near point B)

        // The two handles that define this curve segment
        let control1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: curveSegment.elementIndex, handleType: .control1)
        let control2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: curveSegment.elementIndex, handleType: .control2)

        // Check if this is a closed path
        let isClosed = shape.path.elements.last.map { element in
            if case .close = element { return true }
            return false
        } ?? false

        // Find last curve element index
        var lastCurveIndex = shape.path.elements.count - 1
        if isClosed && lastCurveIndex >= 0, case .close = shape.path.elements[lastCurveIndex] {
            lastCurveIndex -= 1
        }

        // Apply weighted offsets to the curve's control handles
        if let originalControl1 = originalHandlePositions[control1HandleID] {
            let newControl1Pos = CGPoint(
                x: originalControl1.x + offset.x * control1Weight,
                y: originalControl1.y + offset.y * control1Weight
            )
            liveHandlePositions[control1HandleID] = newControl1Pos

            // Calculate tangent for A's incoming handle (maintain smooth curve at point A)
            let prevIndex = curveSegment.elementIndex - 1
            if prevIndex >= 0 {
                let prevControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
                if let originalPrevControl2 = originalHandlePositions[prevControl2HandleID] {
                    // Get anchor point A
                    var anchorA: CGPoint?
                    if case .curve(let toA, _, _) = shape.path.elements[prevIndex] {
                        anchorA = CGPoint(x: toA.x, y: toA.y)
                    }

                    if let anchor = anchorA {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl1Pos,
                            originalOppositeHandle: CGPoint(x: originalPrevControl2.x, y: originalPrevControl2.y)
                        )
                        liveHandlePositions[prevControl2HandleID] = linkedPos
                    }
                }
            } else if isClosed && curveSegment.elementIndex == 1 {
                // First curve in closed path - update last curve's incoming handle
                let lastControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
                if let originalLastControl2 = originalHandlePositions[lastControl2HandleID] {
                    // Get anchor point (first/last coincident point)
                    var anchorA: CGPoint?
                    if case .curve(let toA, _, _) = shape.path.elements[lastCurveIndex] {
                        anchorA = CGPoint(x: toA.x, y: toA.y)
                    }

                    if let anchor = anchorA {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl1Pos,
                            originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                        )
                        liveHandlePositions[lastControl2HandleID] = linkedPos
                        visibleHandles.insert(lastControl2HandleID)
                    }
                }
            }
        }

        if let originalControl2 = originalHandlePositions[control2HandleID] {
            let newControl2Pos = CGPoint(
                x: originalControl2.x + offset.x * control2Weight,
                y: originalControl2.y + offset.y * control2Weight
            )
            liveHandlePositions[control2HandleID] = newControl2Pos

            // Calculate tangent for B's outgoing handle (maintain smooth curve at point B)
            let nextIndex = curveSegment.elementIndex + 1
            if nextIndex < shape.path.elements.count, case .curve = shape.path.elements[nextIndex] {
                let nextControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
                if let originalNextControl1 = originalHandlePositions[nextControl1HandleID] {
                    // Get anchor point B
                    var anchorB: CGPoint?
                    if case .curve(let toB, _, _) = shape.path.elements[curveSegment.elementIndex] {
                        anchorB = CGPoint(x: toB.x, y: toB.y)
                    }

                    if let anchor = anchorB {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl2Pos,
                            originalOppositeHandle: CGPoint(x: originalNextControl1.x, y: originalNextControl1.y)
                        )
                        liveHandlePositions[nextControl1HandleID] = linkedPos
                    }
                }
            } else if isClosed && curveSegment.elementIndex == lastCurveIndex {
                // Last curve in closed path - update first curve's outgoing handle
                let firstControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                if let originalFirstControl1 = originalHandlePositions[firstControl1HandleID] {
                    // Get anchor point B (first/last coincident point)
                    var anchorB: CGPoint?
                    if case .curve(let toB, _, _) = shape.path.elements[curveSegment.elementIndex] {
                        anchorB = CGPoint(x: toB.x, y: toB.y)
                    }

                    if let anchor = anchorB {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl2Pos,
                            originalOppositeHandle: CGPoint(x: originalFirstControl1.x, y: originalFirstControl1.y)
                        )
                        liveHandlePositions[firstControl1HandleID] = linkedPos
                        visibleHandles.insert(firstControl1HandleID)
                    }
                }
            }
        }

        // Make handles visible during drag
        visibleHandles.insert(control1HandleID)
        visibleHandles.insert(control2HandleID)

        // Also show the opposite handles for tangency
        let prevIndex = curveSegment.elementIndex - 1
        if prevIndex >= 0 {
            let prevControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
            visibleHandles.insert(prevControl2HandleID)
        } else if isClosed && curveSegment.elementIndex == 1 {
            // First curve - show last curve's incoming handle
            let lastControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
            visibleHandles.insert(lastControl2HandleID)
        }

        let nextIndex = curveSegment.elementIndex + 1
        if nextIndex < shape.path.elements.count, case .curve = shape.path.elements[nextIndex] {
            let nextControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: nextIndex, handleType: .control1)
            visibleHandles.insert(nextControl1HandleID)
        } else if isClosed && curveSegment.elementIndex == lastCurveIndex {
            // Last curve - show first curve's outgoing handle
            let firstControl1HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
            visibleHandles.insert(firstControl1HandleID)
        }
    }

    private func finishCurveSegmentDrag() {
        guard let curveSegment = draggedCurveSegment else { return }

        // Save original shape
        guard let object = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let originalShape) = object.objectType else {
            liveHandlePositions.removeAll()
            originalHandlePositions.removeAll()
            return
        }

        // Apply all live handle positions
        for (handleID, livePosition) in liveHandlePositions {
            moveHandleToAbsolutePositionWithoutLinked(handleID, to: livePosition)
        }

        // Clear live state
        liveHandlePositions.removeAll()
        originalHandlePositions.removeAll()

        // Create undo command
        if let updatedShape = document.findShape(by: curveSegment.shapeID) {
            let command = ShapeModificationCommand(
                objectIDs: [curveSegment.shapeID],
                oldShapes: [curveSegment.shapeID: originalShape],
                newShapes: [curveSegment.shapeID: updatedShape]
            )
            document.commandManager.execute(command)
        }
    }

    // Utility functions
    private func isPointNearBezierCurve(point: CGPoint, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tolerance: Double) -> Bool {
        for i in 0...20 {
            let t = Double(i) / 20.0
            let curvePoint = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
            if distance(point, curvePoint) <= tolerance {
                return true
            }
        }
        return false
    }

    private func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> CGPoint {
        let mt = 1.0 - t
        let mt2 = mt * mt
        let mt3 = mt2 * mt
        let t2 = t * t
        let t3 = t2 * t

        return CGPoint(
            x: mt3 * p0.x + 3.0 * mt2 * t * p1.x + 3.0 * mt * t2 * p2.x + t3 * p3.x,
            y: mt3 * p0.y + 3.0 * mt2 * t * p1.y + 3.0 * mt * t2 * p2.y + t3 * p3.y
        )
    }

}
