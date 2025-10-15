import SwiftUI

struct ProfessionalDirectSelectionView: View {
    let document: VectorDocument
    let selectedPoints: Set<PointID>
    let selectedHandles: Set<HandleID>
    let visibleHandles: Set<HandleID>
    let directSelectedShapeIDs: Set<UUID>
    let geometry: GeometryProxy

    private var dragOffset: CGPoint {
        if document.currentDragOffset != .zero && !directSelectedShapeIDs.isEmpty && selectedPoints.isEmpty && selectedHandles.isEmpty {
            return document.currentDragOffset
        }
        return .zero
    }

    var body: some View {
        ZStack {
            ForEach(Array(document.unifiedObjects), id: \.id) { unifiedObject in
                if case .shape(let shape) = unifiedObject.objectType {
                    if shape.isVisible && directSelectedShapeIDs.contains(shape.id) {
                        if shape.isGroupContainer {
                            ForEach(shape.groupedShapes.indices, id: \.self) { groupedShapeIndex in
                                let groupedShape = shape.groupedShapes[groupedShapeIndex]
                                if groupedShape.isVisible {
                                    professionalBezierDisplay(for: groupedShape)
                                }
                            }
                        } else {
                            professionalBezierDisplay(for: shape)
                        }
                    }
                }
            }

            ForEach(Array(selectedHandles), id: \.self) { handleID in
                if let handleInfo = getHandleInfo(handleID),
                   let shape = getShapeForHandle(handleID) {
                    Path { path in
                        path.move(to: handleInfo.pointLocation)
                        path.addLine(to: handleInfo.handleLocation)
                    }
                    .stroke(Color.blue.opacity(0.5), lineWidth: 1.0 / document.zoomLevel)
                    .transformEffect(shape.transform)
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

                    let transformedHandle = CGPoint(x: handleInfo.handleLocation.x, y: handleInfo.handleLocation.y).applying(shape.transform)
                    Circle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 8, height: 8)
                        .position(CGPoint(
                            x: transformedHandle.x * document.zoomLevel + document.canvasOffset.x,
                            y: transformedHandle.y * document.zoomLevel + document.canvasOffset.y
                        ))
                }
            }

            ForEach(Array(selectedPoints), id: \.self) { pointID in
                if let pointLocation = getPointLocation(pointID),
                   let shape = getShapeForPoint(pointID) {
                    let transformedPoint = CGPoint(x: pointLocation.x, y: pointLocation.y).applying(shape.transform)
                    Rectangle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 10, height: 10)
                        .position(CGPoint(
                            x: transformedPoint.x * document.zoomLevel + document.canvasOffset.x,
                            y: transformedPoint.y * document.zoomLevel + document.canvasOffset.y
                        ))
                }
            }
        }
    }

    @ViewBuilder
    private func professionalBezierDisplay(for shape: VectorShape) -> some View {
        ZStack {
            ForEach(Array(shape.path.elements.enumerated()), id: \.offset) { elementIndex, element in
                bezierElementView(shape: shape, elementIndex: elementIndex, element: element)
            }
        }
    }

    @ViewBuilder
    private func bezierElementView(shape: VectorShape, elementIndex: Int, element: PathElement) -> some View {
        Group {
            bezierHandlesView(shape: shape, elementIndex: elementIndex, element: element)

            bezierAnchorPointView(shape: shape, elementIndex: elementIndex, element: element)
        }
    }

    @ViewBuilder
    private func bezierHandlesView(shape: VectorShape, elementIndex: Int, element: PathElement) -> some View {
        switch element {
        case .curve(let to, _, let control2):
            bezierCurveHandles(shape: shape, elementIndex: elementIndex, to: to, control2: control2)
        case .move(let to), .line(let to):
            bezierLineHandles(shape: shape, elementIndex: elementIndex, to: to)
        default:
            EmptyView()
        }
    }

    private func bezierCurveHandles(shape: VectorShape, elementIndex: Int, to: VectorPoint, control2: VectorPoint) -> some View {
        let pointID = PointID(
            shapeID: shape.id,
            pathIndex: 0,
            elementIndex: elementIndex
        )
        let isPointSelected = selectedPoints.contains(pointID)

        let incomingHandleID = HandleID(
            shapeID: shape.id,
            pathIndex: 0,
            elementIndex: elementIndex,
            handleType: .control2
        )
        let isIncomingHandleSelected = selectedHandles.contains(incomingHandleID)
        let isIncomingHandleVisible = selectedHandles.contains(incomingHandleID) || visibleHandles.contains(incomingHandleID)

        let outgoingHandleID: HandleID? = {
            if elementIndex + 1 < shape.path.elements.count {
                return HandleID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex + 1,
                    handleType: .control1
                )
            }
            return nil
        }()
        let isOutgoingHandleSelected = outgoingHandleID != nil ? selectedHandles.contains(outgoingHandleID!) : false
        let isOutgoingHandleVisible = outgoingHandleID != nil ? (selectedHandles.contains(outgoingHandleID!) || visibleHandles.contains(outgoingHandleID!)) : false

        let shouldShowBothHandlesAtThisPoint = isIncomingHandleVisible || isOutgoingHandleVisible

        let coincidentPoints = findCoincidentPoints(to: pointID, in: document, tolerance: 1.0)
        let anyCoincidentPointSelected = !coincidentPoints.isEmpty && coincidentPoints.contains { selectedPoints.contains($0) }

        let anyCoincidentHandleSelected: Bool = {
            if shape.path.elements.last == .close {
                let lastPointIndex = shape.path.elements.count - 2
                if elementIndex == 0 {
                    let lastPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex, handleType: .control2)
                    let lastPointOutgoingHandle: HandleID? = lastPointIndex + 1 < shape.path.elements.count ?
                        HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex + 1, handleType: .control1) : nil

                    return selectedHandles.contains(lastPointIncomingHandle) || visibleHandles.contains(lastPointIncomingHandle) ||
                           (lastPointOutgoingHandle != nil && (selectedHandles.contains(lastPointOutgoingHandle!) || visibleHandles.contains(lastPointOutgoingHandle!)))
                } else if elementIndex == lastPointIndex {
                    let firstPointOutgoingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 1, handleType: .control1)
                    var firstPointHasIncomingHandle = false
                    if case .curve = shape.path.elements[0] {
                        let firstPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 0, handleType: .control2)
                        firstPointHasIncomingHandle = selectedHandles.contains(firstPointIncomingHandle) || visibleHandles.contains(firstPointIncomingHandle)
                    }

                    return selectedHandles.contains(firstPointOutgoingHandle) || visibleHandles.contains(firstPointOutgoingHandle) || firstPointHasIncomingHandle
                }
            }
            return false
        }()

        let shouldShowHandles = isPointSelected || anyCoincidentPointSelected || shouldShowBothHandlesAtThisPoint || anyCoincidentHandleSelected

        return Group {
            if shouldShowHandles {
            let anchorLocation = CGPoint(x: to.x, y: to.y)
            let control2Location = CGPoint(x: control2.x, y: control2.y)

            let incomingHandleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
            if !incomingHandleCollapsed {
                bezierHandleLineAndCircle(from: anchorLocation, to: control2Location, shape: shape, isSelected: isIncomingHandleSelected)
            }

            if elementIndex + 1 < shape.path.elements.count {
                let nextElement = shape.path.elements[elementIndex + 1]
                if case .curve(_, let nextControl1, _) = nextElement {
                    let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                    let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !outgoingHandleCollapsed {
                        bezierHandleLineAndCircle(from: anchorLocation, to: control1Location, shape: shape, isSelected: isOutgoingHandleSelected)
                    }
                }
            }
        }
        }
    }

    private func bezierLineHandles(shape: VectorShape, elementIndex: Int, to: VectorPoint) -> some View {
        let pointID = PointID(
            shapeID: shape.id,
            pathIndex: 0,
            elementIndex: elementIndex
        )
        let isPointSelected = selectedPoints.contains(pointID)

        let coincidentPoints = findCoincidentPoints(to: pointID, in: document, tolerance: 1.0)
        let anyCoincidentPointSelected = !coincidentPoints.isEmpty && coincidentPoints.contains { selectedPoints.contains($0) }

        let outgoingHandleID: HandleID? = {
            if elementIndex + 1 < shape.path.elements.count {
                let nextElement = shape.path.elements[elementIndex + 1]
                if case .curve = nextElement {
                    return HandleID(
                        shapeID: shape.id,
                        pathIndex: 0,
                        elementIndex: elementIndex + 1,
                        handleType: .control1
                    )
                }
            }
            return nil
        }()

        let isOutgoingHandleSelected = outgoingHandleID != nil && selectedHandles.contains(outgoingHandleID!)
        let isOutgoingHandleVisible = outgoingHandleID != nil && (selectedHandles.contains(outgoingHandleID!) || visibleHandles.contains(outgoingHandleID!))

        let anyCoincidentHandleSelected: Bool = {
            if shape.path.elements.last == .close {
                let lastPointIndex = shape.path.elements.count - 2
                if elementIndex == 0 {
                    if case .curve = shape.path.elements[lastPointIndex] {
                        let lastPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex, handleType: .control2)
                        if selectedHandles.contains(lastPointIncomingHandle) || visibleHandles.contains(lastPointIncomingHandle) {
                            return true
                        }
                    }
                    if lastPointIndex + 1 < shape.path.elements.count {
                        if case .curve = shape.path.elements[lastPointIndex + 1] {
                            let lastPointOutgoingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: lastPointIndex + 1, handleType: .control1)
                            if selectedHandles.contains(lastPointOutgoingHandle) || visibleHandles.contains(lastPointOutgoingHandle) {
                                return true
                            }
                        }
                    }
                } else if elementIndex == lastPointIndex {
                    if case .curve = shape.path.elements[0] {
                        let firstPointIncomingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 0, handleType: .control2)
                        if selectedHandles.contains(firstPointIncomingHandle) || visibleHandles.contains(firstPointIncomingHandle) {
                            return true
                        }
                    }
                    if shape.path.elements.count > 1 {
                        if case .curve = shape.path.elements[1] {
                            let firstPointOutgoingHandle = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: 1, handleType: .control1)
                            if selectedHandles.contains(firstPointOutgoingHandle) || visibleHandles.contains(firstPointOutgoingHandle) {
                                return true
                            }
                        }
                    }
                }
            }
            return false
        }()

        let shouldShowHandles = isPointSelected || anyCoincidentPointSelected || isOutgoingHandleVisible || anyCoincidentHandleSelected

        return Group {
            if shouldShowHandles {
            let anchorLocation = CGPoint(x: to.x, y: to.y)

            if elementIndex + 1 < shape.path.elements.count {
                let nextElement = shape.path.elements[elementIndex + 1]
                if case .curve(_, let nextControl1, _) = nextElement {
                    let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                    let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                    if !outgoingHandleCollapsed {
                        bezierHandleLineAndCircle(from: anchorLocation, to: control1Location, shape: shape, isSelected: isOutgoingHandleSelected)
                    }
                }
            }
        }
        }
    }

    @ViewBuilder
    private func bezierHandleLineAndCircle(from: CGPoint, to: CGPoint, shape: VectorShape, isSelected: Bool = false) -> some View {
        let offsetFrom = CGPoint(x: from.x + dragOffset.x, y: from.y + dragOffset.y)
        let offsetTo = CGPoint(x: to.x + dragOffset.x, y: to.y + dragOffset.y)

        Path { path in
            path.move(to: offsetFrom)
            path.addLine(to: offsetTo)
        }
        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel)
        .transformEffect(shape.transform)
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

        let transformedTo = CGPoint(x: offsetTo.x, y: offsetTo.y).applying(shape.transform)
        Circle()
            .fill(isSelected ? Color.orange : Color.blue)
            .stroke(Color.white, lineWidth: 0.5)
            .frame(width: 6, height: 6)
            .position(CGPoint(
                x: transformedTo.x * document.zoomLevel + document.canvasOffset.x,
                y: transformedTo.y * document.zoomLevel + document.canvasOffset.y
            ))
    }

    @ViewBuilder
    private func bezierAnchorPointView(shape: VectorShape, elementIndex: Int, element: PathElement) -> some View {
        if let point = extractPointFromElement(element) {
            let rawPointLocation = CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
            let transformedPointLocation = rawPointLocation.applying(shape.transform)

            let pointID = PointID(
                shapeID: shape.id,
                pathIndex: 0,
                elementIndex: elementIndex
            )
            let isPointSelected = selectedPoints.contains(pointID)

            let hasCoincidentPoints = !findCoincidentPoints(to: pointID, in: document, tolerance: 1.0).isEmpty

            Rectangle()
                .fill(isPointSelected ? Color.blue : Color.white)
                .stroke(hasCoincidentPoints ? Color.orange : Color.blue, lineWidth: hasCoincidentPoints ? 2.0 : 1.0)
                .frame(width: 8, height: 8)
                .position(CGPoint(
                    x: transformedPointLocation.x * document.zoomLevel + document.canvasOffset.x,
                    y: transformedPointLocation.y * document.zoomLevel + document.canvasOffset.y
                ))
        }
    }

    private func extractPointFromElement(_ element: PathElement) -> VectorPoint? {
        switch element {
        case .move(let to), .line(let to):
            return to
        case .curve(let to, _, _), .quadCurve(let to, _):
            return to
        case .close:
            return nil
        }
    }

    private func getAnchorPointForHandle(_ handleID: HandleID) -> Int? {
        if handleID.handleType == .control1 && handleID.elementIndex > 0 {
            return handleID.elementIndex - 1
        } else if handleID.handleType == .control2 {
            return handleID.elementIndex
        }
        return nil
    }

    private func getPointLocation(_ pointID: PointID) -> CGPoint? {
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == pointID.shapeID {
                    if pointID.elementIndex < shape.path.elements.count {
                        let element = shape.path.elements[pointID.elementIndex]

                        switch element {
                        case .move(let to), .line(let to):
                            return CGPoint(x: to.x, y: to.y)
                        case .curve(let to, _, _):
                            return CGPoint(x: to.x, y: to.y)
                        case .quadCurve(let to, _):
                            return CGPoint(x: to.x, y: to.y)
                        case .close:
                            return nil
                        }
                    }
                }

                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
                        if pointID.elementIndex < groupedShape.path.elements.count {
                            let element = groupedShape.path.elements[pointID.elementIndex]

                            switch element {
                            case .move(let to), .line(let to):
                                return CGPoint(x: to.x, y: to.y)
                            case .curve(let to, _, _):
                                return CGPoint(x: to.x, y: to.y)
                            case .quadCurve(let to, _):
                                return CGPoint(x: to.x, y: to.y)
                            case .close:
                                return nil
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    private func getHandleInfo(_ handleID: HandleID) -> (pointLocation: CGPoint, handleLocation: CGPoint)? {

        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == handleID.shapeID {
                    return getHandleInfoFromShape(shape, handleID: handleID)
                }

                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == handleID.shapeID }) {
                        return getHandleInfoFromShape(groupedShape, handleID: handleID)
                    }
                }
            }
        }
        return nil
    }

    private func getHandleInfoFromShape(_ shape: VectorShape, handleID: HandleID) -> (pointLocation: CGPoint, handleLocation: CGPoint)? {
        if handleID.elementIndex < shape.path.elements.count {
            let element = shape.path.elements[handleID.elementIndex]

            switch element {
            case .curve(let to, let control1, let control2):
                if handleID.handleType == .control1 {
                    if handleID.elementIndex > 0 {
                        let prevElement = shape.path.elements[handleID.elementIndex - 1]
                        switch prevElement {
                        case .move(let prevTo), .line(let prevTo):
                            let pointLocation = CGPoint(x: prevTo.x + dragOffset.x, y: prevTo.y + dragOffset.y)
                            let handleLocation = CGPoint(x: control1.x + dragOffset.x, y: control1.y + dragOffset.y)
                            return (pointLocation, handleLocation)
                        case .curve(let prevTo, _, _):
                            let pointLocation = CGPoint(x: prevTo.x + dragOffset.x, y: prevTo.y + dragOffset.y)
                            let handleLocation = CGPoint(x: control1.x + dragOffset.x, y: control1.y + dragOffset.y)
                            return (pointLocation, handleLocation)
                        default:
                            return nil
                        }
                    }
                } else {
                    let pointLocation = CGPoint(x: to.x + dragOffset.x, y: to.y + dragOffset.y)
                    let handleLocation = CGPoint(x: control2.x + dragOffset.x, y: control2.y + dragOffset.y)
                    return (pointLocation, handleLocation)
                }
            case .quadCurve(let to, let control):
                if handleID.handleType == .control1 {
                    if handleID.elementIndex > 0 {
                        let prevElement = shape.path.elements[handleID.elementIndex - 1]
                        switch prevElement {
                        case .move(let prevTo), .line(let prevTo), .curve(let prevTo, _, _):
                            let pointLocation = CGPoint(x: prevTo.x + dragOffset.x, y: prevTo.y + dragOffset.y)
                            let handleLocation = CGPoint(x: control.x + dragOffset.x, y: control.y + dragOffset.y)
                            return (pointLocation, handleLocation)
                        default:
                            return nil
                        }
                    }
                } else {
                    let pointLocation = CGPoint(x: to.x + dragOffset.x, y: to.y + dragOffset.y)
                    let handleLocation = CGPoint(x: control.x + dragOffset.x, y: control.y + dragOffset.y)
                    return (pointLocation, handleLocation)
                }
            default:
                return nil
            }
        }
        return nil
    }

    private func getShapeForHandle(_ handleID: HandleID) -> VectorShape? {
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == handleID.shapeID {
                    return shape
                }

                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == handleID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }

    private func getShapeForPoint(_ pointID: PointID) -> VectorShape? {
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if shape.id == pointID.shapeID {
                    return shape
                }

                if shape.isGroupContainer {
                    if let groupedShape = shape.groupedShapes.first(where: { $0.id == pointID.shapeID }) {
                        return groupedShape
                    }
                }
            }
        }
        return nil
    }
}
