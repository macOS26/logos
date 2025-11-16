import SwiftUI
import Combine
extension DrawingCanvas {
    internal func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        // Check for curve segment dragging first (before shape, points, or handles)
        if selectedPoints.isEmpty && selectedHandles.isEmpty && !isDraggingPoint && !isDraggingHandle && !isDraggingCurveSegment {
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let screenTolerance: Double = 10.0
            let tolerance: Double = screenTolerance / zoomLevel

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
            let tolerance: Double = screenTolerance / zoomLevel
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

        let preciseZoom = Double(zoomLevel)
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

                // Auto-link if geometrically smooth (within 5° of 180°)
                // Cusp points won't pass this check because they have 90° or other angles
                if !isOptionPressed && isPointSmooth(handleID: handleID) {
                    updateLiveLinkedHandle(handleID: handleID, newPosition: newPosition)
                }
            }
            }
        }
    }

    private func isCoincidentPointSmooth(elements: [PathElement], handleID: HandleID) -> Bool {
        guard elements.count >= 2 else { return false }

        // Check for explicit anchor type first (for element 0, which is the coincident point)
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType else { return false }

        if let explicitType = shape.anchorTypes[0] {
            // User explicitly set the type for the coincident point
            switch explicitType {
            case .smooth: return true
            case .corner, .cusp: return false
            case .auto: break  // Use geometry detection
            }
        }

        // Get first and last points
        let firstPoint: CGPoint?
        if case .move(let firstTo) = elements[0] {
            firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)
        } else {
            return false
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
                return false
            }
        } else {
            return false
        }

        // Check if first and last are coincident
        guard let first = firstPoint, let last = lastPoint,
              abs(first.x - last.x) < 0.1 && abs(first.y - last.y) < 0.1 else {
            return false
        }

        // Check if this is one of the coincident handles
        let isFirstOutgoing = (handleID.handleType == .control1 && handleID.elementIndex == 1)
        let isLastIncoming = (handleID.handleType == .control2 && handleID.elementIndex == lastElementIndex)

        if !isFirstOutgoing && !isLastIncoming {
            return false
        }

        // Get both handles
        var handle1: CGPoint?
        var handle2: CGPoint?

        if case .curve(_, let firstControl1, _) = elements[1] {
            handle1 = CGPoint(x: firstControl1.x, y: firstControl1.y)
        }

        if case .curve(_, _, let lastControl2) = elements[lastElementIndex] {
            handle2 = CGPoint(x: lastControl2.x, y: lastControl2.y)
        }

        guard let h1 = handle1, let h2 = handle2 else { return false }

        // Check if both handles are at the anchor (corner point)
        if (abs(h1.x - first.x) < 0.1 && abs(h1.y - first.y) < 0.1) ||
           (abs(h2.x - first.x) < 0.1 && abs(h2.y - first.y) < 0.1) {
            return false
        }

        // Calculate vectors
        let vec1 = CGPoint(x: h1.x - first.x, y: h1.y - first.y)
        let vec2 = CGPoint(x: h2.x - first.x, y: h2.y - first.y)

        let len1 = sqrt(vec1.x * vec1.x + vec1.y * vec1.y)
        let len2 = sqrt(vec2.x * vec2.x + vec2.y * vec2.y)

        if len1 < 0.1 || len2 < 0.1 { return false }

        // Normalize and check angle
        let norm1 = CGPoint(x: vec1.x / len1, y: vec1.y / len1)
        let norm2 = CGPoint(x: vec2.x / len2, y: vec2.y / len2)

        let dot = norm1.x * norm2.x + norm1.y * norm2.y

        return dot < -0.9962  // cos(175°) ≈ -0.9962
    }

    private func isPointSmooth(handleID: HandleID) -> Bool {
        guard let object = document.snapshot.objects[handleID.shapeID],
              case .shape(let shape) = object.objectType,
              handleID.elementIndex < shape.path.elements.count else { return false }

        let elements = shape.path.elements
        let element = elements[handleID.elementIndex]

        // Check for explicit anchor type first
        let anchorElementIndex = handleID.handleType == .control2 ? handleID.elementIndex : handleID.elementIndex - 1
        if let explicitType = shape.anchorTypes[anchorElementIndex] {
            // User explicitly set the type
            switch explicitType {
            case .smooth: return true
            case .corner, .cusp: return false
            case .auto: break  // Use geometry detection
            }
        }

        // Check for coincident points first
        if isCoincidentPointSmooth(elements: elements, handleID: handleID) {
            return true
        }

        var anchorPoint: CGPoint?
        var handle1: CGPoint?
        var handle2: CGPoint?

        // Get anchor point and both handles
        if handleID.handleType == .control2 {
            // This is incoming handle to anchor
            guard case .curve(let to, _, let control2) = element else { return false }
            anchorPoint = CGPoint(x: to.x, y: to.y)
            handle1 = CGPoint(x: control2.x, y: control2.y)

            // Get opposite handle (outgoing from this anchor)
            let nextIndex = handleID.elementIndex + 1
            if nextIndex < elements.count,
               case .curve(_, let nextControl1, _) = elements[nextIndex] {
                handle2 = CGPoint(x: nextControl1.x, y: nextControl1.y)
            }
        } else if handleID.handleType == .control1 {
            // This is outgoing handle from anchor
            guard case .curve(_, let control1, _) = element else { return false }
            handle2 = CGPoint(x: control1.x, y: control1.y)

            // Get anchor and opposite handle (incoming to this anchor)
            let prevIndex = handleID.elementIndex - 1
            if prevIndex >= 0,
               case .curve(let prevTo, _, let prevControl2) = elements[prevIndex] {
                anchorPoint = CGPoint(x: prevTo.x, y: prevTo.y)
                handle1 = CGPoint(x: prevControl2.x, y: prevControl2.y)
            }
        }

        guard let anchor = anchorPoint,
              let h1 = handle1,
              let h2 = handle2 else { return false }

        // Calculate vectors from anchor to each handle
        let vec1 = CGPoint(x: h1.x - anchor.x, y: h1.y - anchor.y)
        let vec2 = CGPoint(x: h2.x - anchor.x, y: h2.y - anchor.y)

        let len1 = sqrt(vec1.x * vec1.x + vec1.y * vec1.y)
        let len2 = sqrt(vec2.x * vec2.x + vec2.y * vec2.y)

        // If either handle is at the anchor, not smooth
        if len1 < 0.1 || len2 < 0.1 { return false }

        // Normalize vectors
        let norm1 = CGPoint(x: vec1.x / len1, y: vec1.y / len1)
        let norm2 = CGPoint(x: vec2.x / len2, y: vec2.y / len2)

        // Calculate dot product (should be -1 for 180 degrees)
        let dot = norm1.x * norm2.x + norm1.y * norm2.y

        // Consider smooth if within 5 degrees of 180 degrees
        // This is a more reasonable threshold for detecting smooth points
        return dot < -0.9962  // cos(175°) ≈ -0.9962
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
        // Only links if geometrically smooth (within 1° threshold)
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

    private func handleCoincidentForLiveHandle(handleID: HandleID, newPosition: CGPoint, shape: VectorShape) {
        let elements = shape.path.elements
        guard elements.count >= 2 else { return }

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
            return
        }

        let anchorPoint = first

        // If dragging first curve's outgoing handle (control1) -> update last curve's incoming handle (control2)
        if handleID.handleType == .control2 && handleID.elementIndex == 0 {
            if case .curve(_, _, _) = elements[lastElementIndex],
               let originalLastControl2 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }

        // If dragging last curve's incoming handle (control2) -> update first curve's outgoing handle (control1)
        if handleID.handleType == .control2 && handleID.elementIndex == lastElementIndex {
            if elements.count > 1, case .curve(_, _, _) = elements[1],
               let originalFirstControl1 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalFirstControl1.x, y: originalFirstControl1.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }

        // If dragging first curve's outgoing handle (control1 at element 1) -> update last curve's incoming handle
        if handleID.handleType == .control1 && handleID.elementIndex == 1 {
            if case .curve(_, _, _) = elements[lastElementIndex],
               let originalLastControl2 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: lastElementIndex, handleType: .control2)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }

        // If dragging next curve's outgoing handle (control1) -> update first curve's outgoing handle
        if handleID.handleType == .control1 && handleID.elementIndex == lastElementIndex {
            if elements.count > 1, case .curve(_, _, _) = elements[1],
               let originalFirstControl1 = originalHandlePositions[HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)] {
                let linkedPos = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newPosition,
                    originalOppositeHandle: CGPoint(x: originalFirstControl1.x, y: originalFirstControl1.y)
                )
                let oppositeHandleID = HandleID(shapeID: handleID.shapeID, pathIndex: 0, elementIndex: 1, handleType: .control1)
                liveHandlePositions[oppositeHandleID] = linkedPos
                visibleHandles.insert(oppositeHandleID)
            }
        }
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

        // Only link if this coincident point is smooth (within 1° threshold)
        if !isCoincidentPointSmooth(elements: elements, handleID: handleID) {
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

    private func applyPointUpdatesToShape(shapeID: UUID, pointUpdates: [(PointID, CGPoint)]) {
        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType else { return }

        var elements = shape.path.elements

        // Apply all point updates to the elements array
        for (pointID, newPosition) in pointUpdates {
            guard pointID.elementIndex < elements.count else { continue }

            let newPoint = VectorPoint(newPosition.x, newPosition.y)
            let originalPosition: CGPoint

            // Get original position
            switch elements[pointID.elementIndex] {
            case .move(let to), .line(let to):
                originalPosition = CGPoint(x: to.x, y: to.y)
            case .curve(let to, _, _):
                originalPosition = CGPoint(x: to.x, y: to.y)
            case .quadCurve(let to, _):
                originalPosition = CGPoint(x: to.x, y: to.y)
            case .close:
                continue
            }

            let deltaX = newPosition.x - originalPosition.x
            let deltaY = newPosition.y - originalPosition.y

            // Update the point
            switch elements[pointID.elementIndex] {
            case .move(_):
                elements[pointID.elementIndex] = .move(to: newPoint)
            case .line(_):
                elements[pointID.elementIndex] = .line(to: newPoint)
            case .curve(let oldTo, let control1, let control2):
                let control2Collapsed = (abs(control2.x - oldTo.x) < 0.1 && abs(control2.y - oldTo.y) < 0.1)
                let newControl1 = control1
                let newControl2 = control2Collapsed ? newPoint : VectorPoint(control2.x + deltaX, control2.y + deltaY)
                elements[pointID.elementIndex] = .curve(to: newPoint, control1: newControl1, control2: newControl2)
            case .quadCurve(_, let control):
                elements[pointID.elementIndex] = .quadCurve(to: newPoint, control: control)
            case .close:
                break
            }

            // Update next element's outgoing control if it's collapsed
            if pointID.elementIndex + 1 < elements.count {
                if case .curve(let nextTo, let nextControl1, let nextControl2) = elements[pointID.elementIndex + 1] {
                    let outgoingCollapsed = (abs(nextControl1.x - originalPosition.x) < 0.1 && abs(nextControl1.y - originalPosition.y) < 0.1)
                    let newNextControl1 = outgoingCollapsed ? newPoint : VectorPoint(nextControl1.x + deltaX, nextControl1.y + deltaY)
                    elements[pointID.elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
        }

        // Update shape once with all changes
        document.updateShapeByID(shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
    }

    private func applyHandleUpdatesToShape(shapeID: UUID, handleUpdates: [(HandleID, CGPoint)]) {
        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType else { return }

        var elements = shape.path.elements

        // Apply all handle updates to the elements array
        for (handleID, newPosition) in handleUpdates {
            guard handleID.elementIndex < elements.count else { continue }

            let newHandle = VectorPoint(newPosition.x, newPosition.y)

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

            // Handle coincident points for smooth tangency
            handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: handleID, newDraggedPosition: newPosition)
        }

        // Update shape once with all changes
        document.updateShapeByID(shapeID, silent: true) { shape in
            shape.path.elements = elements
            shape.updateBounds()
        }
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

        // Handle coincident points for smooth tangency
        handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: handleID, newDraggedPosition: newPosition)

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

        // Group points by shapeID to batch updates
        var pointsByShape: [UUID: [(PointID, CGPoint)]] = [:]
        for (pointID, livePosition) in livePointPositions {
            pointsByShape[pointID.shapeID, default: []].append((pointID, livePosition))
        }

        for (shapeID, points) in pointsByShape {
            applyPointUpdatesToShape(shapeID: shapeID, pointUpdates: points)
        }

        // Group handles by shapeID to batch updates
        var handlesByShape: [UUID: [(HandleID, CGPoint)]] = [:]
        for (handleID, livePosition) in liveHandlePositions {
            handlesByShape[handleID.shapeID, default: []].append((handleID, livePosition))
        }

        // Update each shape once with all its handle changes
        for (shapeID, handles) in handlesByShape {
            applyHandleUpdatesToShape(shapeID: shapeID, handleUpdates: handles)
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

            var firstPoint: VectorPoint?

            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .move(let to):
                    previousPoint = to
                    firstPoint = to
                case .line(let to):
                    // Check if clicking on line segment
                    if let prev = previousPoint {
                        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                        let end = CGPoint(x: to.x, y: to.y).applying(shape.transform)

                        if isPointNearLineSegment(point: location, start: start, end: end, tolerance: tolerance) {
                            return (shape.id, elementIndex)
                        }
                    }
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
                case .close:
                    // Check if clicking on the closing line segment (from last point back to first)
                    if let prev = previousPoint, let first = firstPoint {
                        let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                        let end = CGPoint(x: first.x, y: first.y).applying(shape.transform)

                        if isPointNearLineSegment(point: location, start: start, end: end, tolerance: tolerance) {
                            return (shape.id, elementIndex)
                        }
                    }
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

    private func captureOriginalHandlesForCurveSegment(shapeID: UUID, elementIndex: Int, maintainTangency: Bool = true) {
        // Clear previous state
        originalHandlePositions.removeAll()
        liveHandlePositions.removeAll()

        guard let object = document.snapshot.objects[shapeID],
              case .shape(let shape) = object.objectType,
              elementIndex < shape.path.elements.count else { return }

        let element = shape.path.elements[elementIndex]

        // Handle line segments differently
        if case .line = element {
            // For lines, we'll move both endpoints
            // No handles to capture
            return
        }

        // Now extract the control handles for curves
        guard case .curve(_, let control1, let control2) = element else { return }

        // For curve from A to B at elementIndex:
        // - control1 is A's outgoing handle (what we drag)
        // - control2 is B's incoming handle (what we drag)

        let control1HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: elementIndex, handleType: .control1)
        let control2HandleID = HandleID(shapeID: shapeID, pathIndex: 0, elementIndex: elementIndex, handleType: .control2)

        originalHandlePositions[control1HandleID] = control1
        originalHandlePositions[control2HandleID] = control2

        // Only capture opposite handles for tangency if requested
        if maintainTangency {
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
    }

    private func convertCloseSegmentToCurveAndDrag(shape: VectorShape, elementIndex: Int, offset: CGPoint, curveSegment: (shapeID: UUID, elementIndex: Int)) {
        // Find first point (should be at element 0)
        var firstPoint: VectorPoint?
        if case .move(let to) = shape.path.elements[0] {
            firstPoint = to
        }

        // Find last point (element before close)
        var lastPoint: VectorPoint?
        let prevIndex = elementIndex - 1
        if prevIndex >= 0 {
            switch shape.path.elements[prevIndex] {
            case .move(let prev), .line(let prev):
                lastPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                lastPoint = prev
            default:
                break
            }
        }

        guard let start = lastPoint, let end = firstPoint else { return }

        // Create control points 1/3 along the line from each endpoint
        let control1 = VectorPoint(
            start.x + (end.x - start.x) / 3.0,
            start.y + (end.y - start.y) / 3.0
        )
        let control2 = VectorPoint(
            start.x + 2.0 * (end.x - start.x) / 3.0,
            start.y + 2.0 * (end.y - start.y) / 3.0
        )

        // Convert .close to .curve
        document.updateShapeByID(curveSegment.shapeID) { updatedShape in
            updatedShape.path.elements[elementIndex] = .curve(to: end, control1: control1, control2: control2)
            updatedShape.updateBounds()
        }

        // Re-capture handles now that it's a curve (DON'T maintain tangency with neighbors)
        captureOriginalHandlesForCurveSegment(shapeID: curveSegment.shapeID, elementIndex: elementIndex, maintainTangency: false)

        // Now get the updated shape and proceed with curve dragging
        guard let updatedObject = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let updatedShape) = updatedObject.objectType,
              case .curve = updatedShape.path.elements[elementIndex] else { return }

        // Continue with standard curve segment dragging
        dragCurveSegmentWithHandles(shape: updatedShape, curveSegment: curveSegment, offset: offset)
    }

    private func convertLineToCurveAndDrag(shape: VectorShape, elementIndex: Int, to: VectorPoint, offset: CGPoint, curveSegment: (shapeID: UUID, elementIndex: Int)) {
        // Find previous point
        var prevPoint: VectorPoint?
        if elementIndex > 0 {
            switch shape.path.elements[elementIndex - 1] {
            case .move(let prev), .line(let prev):
                prevPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                prevPoint = prev
            default:
                break
            }
        }

        guard let start = prevPoint else { return }

        // Create control points 1/3 along the line from each endpoint
        let control1 = VectorPoint(
            start.x + (to.x - start.x) / 3.0,
            start.y + (to.y - start.y) / 3.0
        )
        let control2 = VectorPoint(
            start.x + 2.0 * (to.x - start.x) / 3.0,
            start.y + 2.0 * (to.y - start.y) / 3.0
        )

        // Convert line to curve
        document.updateShapeByID(curveSegment.shapeID) { updatedShape in
            updatedShape.path.elements[elementIndex] = .curve(to: to, control1: control1, control2: control2)
            updatedShape.updateBounds()
        }

        // Re-capture handles now that it's a curve (DON'T maintain tangency with neighbors)
        captureOriginalHandlesForCurveSegment(shapeID: curveSegment.shapeID, elementIndex: elementIndex, maintainTangency: false)

        // Now get the updated shape and proceed with curve dragging
        guard let updatedObject = document.snapshot.objects[curveSegment.shapeID],
              case .shape(let updatedShape) = updatedObject.objectType,
              case .curve = updatedShape.path.elements[elementIndex] else { return }

        // Continue with standard curve segment dragging
        dragCurveSegmentWithHandles(shape: updatedShape, curveSegment: curveSegment, offset: offset)
    }

    private func handleCloseSegmentDrag(shape: VectorShape, elementIndex: Int, offset: CGPoint) {
        // Find first point (should be at element 0)
        var firstPoint: VectorPoint?
        if case .move(let to) = shape.path.elements[0] {
            firstPoint = to
        }

        // Find last point (element before close)
        var lastPoint: VectorPoint?
        let prevIndex = elementIndex - 1
        if prevIndex >= 0 {
            switch shape.path.elements[prevIndex] {
            case .move(let prev), .line(let prev):
                lastPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                lastPoint = prev
            default:
                break
            }
        }

        guard let first = firstPoint, let last = lastPoint else { return }

        // Calculate line direction vector (from last to first)
        let dx = first.x - last.x
        let dy = first.y - last.y
        let length = sqrt(dx * dx + dy * dy)

        guard length > 0.001 else { return }

        // Normalized direction
        let dirX = dx / length
        let dirY = dy / length

        // Perpendicular direction (rotate 90 degrees)
        let perpX = -dirY
        let perpY = dirX

        // Project drag offset onto perpendicular direction
        let perpDist = offset.x * perpX + offset.y * perpY

        // Move both points perpendicular to the line
        let moveOffset = CGPoint(x: perpDist * perpX, y: perpDist * perpY)

        // First point is at element 0
        let firstPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: 0)
        // Last point is at prevIndex
        let lastPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: prevIndex)

        livePointPositions[firstPointID] = CGPoint(x: first.x + moveOffset.x, y: first.y + moveOffset.y)
        livePointPositions[lastPointID] = CGPoint(x: last.x + moveOffset.x, y: last.y + moveOffset.y)
    }

    private func handleLineSegmentDrag(shape: VectorShape, elementIndex: Int, to: VectorPoint, offset: CGPoint) {
        // Find previous point
        var prevPoint: VectorPoint?
        if elementIndex > 0 {
            switch shape.path.elements[elementIndex - 1] {
            case .move(let prev), .line(let prev):
                prevPoint = prev
            case .curve(let prev, _, _), .quadCurve(let prev, _):
                prevPoint = prev
            default:
                break
            }
        }

        guard let start = prevPoint else { return }

        // Calculate line direction vector
        let dx = to.x - start.x
        let dy = to.y - start.y
        let length = sqrt(dx * dx + dy * dy)

        guard length > 0.001 else { return }

        // Normalized direction
        let dirX = dx / length
        let dirY = dy / length

        // Perpendicular direction (rotate 90 degrees)
        let perpX = -dirY
        let perpY = dirX

        // Project drag offset onto perpendicular direction
        let perpDist = offset.x * perpX + offset.y * perpY

        // Move both points perpendicular to the line
        let moveOffset = CGPoint(x: perpDist * perpX, y: perpDist * perpY)

        let startPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex - 1)
        let endPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)

        livePointPositions[startPointID] = CGPoint(x: start.x + moveOffset.x, y: start.y + moveOffset.y)
        livePointPositions[endPointID] = CGPoint(x: to.x + moveOffset.x, y: to.y + moveOffset.y)
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

        let element = shape.path.elements[curveSegment.elementIndex]

        // Handle line segments
        if case .line(let to) = element {
            // Check Option key state from NSEvent
            let optionKeyPressed = NSEvent.modifierFlags.contains(.option)

            // Option key: convert to curve and drag with handles
            // No Option key: just move perpendicular
            if optionKeyPressed {
                convertLineToCurveAndDrag(shape: shape, elementIndex: curveSegment.elementIndex, to: to, offset: offset, curveSegment: curveSegment)
                return
            } else {
                handleLineSegmentDrag(shape: shape, elementIndex: curveSegment.elementIndex, to: to, offset: offset)
                return
            }
        }

        // Handle close segments (closing line from last point to first)
        if case .close = element {
            // Check Option key state from NSEvent
            let optionKeyPressed = NSEvent.modifierFlags.contains(.option)

            // Option key: convert to curve and drag with handles
            // No Option key: just move perpendicular
            if optionKeyPressed {
                convertCloseSegmentToCurveAndDrag(shape: shape, elementIndex: curveSegment.elementIndex, offset: offset, curveSegment: curveSegment)
                return
            } else {
                handleCloseSegmentDrag(shape: shape, elementIndex: curveSegment.elementIndex, offset: offset)
                return
            }
        }

        // Curve segment dragging
        dragCurveSegmentWithHandles(shape: shape, curveSegment: curveSegment, offset: offset)
    }

    private func dragCurveSegmentWithHandles(shape: VectorShape, curveSegment: (shapeID: UUID, elementIndex: Int), offset: CGPoint) {
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

            // Get anchor point A
            var anchorA: CGPoint?
            if prevIndex >= 0 {
                if case .curve(let toA, _, _) = shape.path.elements[prevIndex] {
                    anchorA = CGPoint(x: toA.x, y: toA.y)
                } else if case .move(let toA) = shape.path.elements[prevIndex] {
                    anchorA = CGPoint(x: toA.x, y: toA.y)
                }
            }

            if prevIndex >= 0, let anchor = anchorA {
                // Try to update previous element's control2 if it's a curve
                if case .curve = shape.path.elements[prevIndex] {
                    let prevControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: prevIndex, handleType: .control2)
                    if let originalPrevControl2 = originalHandlePositions[prevControl2HandleID] {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl1Pos,
                            originalOppositeHandle: CGPoint(x: originalPrevControl2.x, y: originalPrevControl2.y)
                        )
                        liveHandlePositions[prevControl2HandleID] = linkedPos
                        visibleHandles.insert(prevControl2HandleID)
                    }
                }
                // If previous is MOVE (element 0), check for coincident point at end of path
                else if case .move = shape.path.elements[prevIndex], isClosed {
                    // Update last curve's control2 (incoming to coincident point)
                    let lastControl2HandleID = HandleID(shapeID: curveSegment.shapeID, pathIndex: 0, elementIndex: lastCurveIndex, handleType: .control2)
                    if let originalLastControl2 = originalHandlePositions[lastControl2HandleID] {
                        let linkedPos = calculateLinkedHandle(
                            anchorPoint: anchor,
                            draggedHandle: newControl1Pos,
                            originalOppositeHandle: CGPoint(x: originalLastControl2.x, y: originalLastControl2.y)
                        )
                        liveHandlePositions[lastControl2HandleID] = linkedPos
                        visibleHandles.insert(lastControl2HandleID)
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
                        visibleHandles.insert(nextControl1HandleID)

                        // Check if THIS linked handle also needs coincident point propagation
                        handleCoincidentForLiveHandle(handleID: nextControl1HandleID, newPosition: linkedPos, shape: shape)
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

        // Apply all live handle positions - group by shape to batch updates
        var handlesByShape: [UUID: [(HandleID, CGPoint)]] = [:]
        for (handleID, livePosition) in liveHandlePositions {
            handlesByShape[handleID.shapeID, default: []].append((handleID, livePosition))
        }

        for (shapeID, handles) in handlesByShape {
            applyHandleUpdatesToShape(shapeID: shapeID, handleUpdates: handles)
        }

        // Apply all live point positions (for line segment dragging) - group by shape to batch updates
        var pointsByShape: [UUID: [(PointID, CGPoint)]] = [:]
        for (pointID, livePosition) in livePointPositions {
            pointsByShape[pointID.shapeID, default: []].append((pointID, livePosition))
        }

        for (shapeID, points) in pointsByShape {
            applyPointUpdatesToShape(shapeID: shapeID, pointUpdates: points)
        }

        // Clear live state
        liveHandlePositions.removeAll()
        livePointPositions.removeAll()
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
    private func isPointNearLineSegment(point: CGPoint, start: CGPoint, end: CGPoint, tolerance: Double) -> Bool {
        // Calculate distance from point to line segment
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy

        if lengthSquared == 0 {
            // Start and end are the same point
            let dist = sqrt(pow(point.x - start.x, 2) + pow(point.y - start.y, 2))
            return dist <= tolerance
        }

        // Calculate projection of point onto line
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))

        // Find closest point on segment
        let closestX = start.x + t * dx
        let closestY = start.y + t * dy

        // Calculate distance
        let distance = sqrt(pow(point.x - closestX, 2) + pow(point.y - closestY, 2))

        return distance <= tolerance
    }

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
