import SwiftUI
import Combine

extension DrawingCanvas {

    internal func selectIndividualAnchorPointOrHandle(at location: CGPoint, tolerance: Double) -> Bool {
        for shapeID in directSelectedShapeIDs {
            if let unifiedObject = document.findObject(by: shapeID),
               case .shape(let shape) = unifiedObject.objectType {
                let layerIndex = unifiedObject.layerIndex
                let layer = document.layers[layerIndex]

                    if layer.isLocked || shape.isLocked {

                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        syncDirectSelectionWithDocument()
                        return true
                    }

                    if shape.isGroupContainer {
                        for groupedShape in shape.groupedShapes {
                            if !groupedShape.isVisible { continue }

                            if checkAnchorPointsInShape(groupedShape, at: location, tolerance: tolerance) {
                                return true
                            }
                        }
                    } else {
                        if checkAnchorPointsInShape(shape, at: location, tolerance: tolerance) {
                            return true
                        }
                    }
            }
        }

        return false
    }

    private func checkAnchorPointsInShape(_ shape: VectorShape, at location: CGPoint, tolerance: Double) -> Bool {
        let pointSelectionRadius: Double = 6.0 / document.zoomLevel
        let handleSelectionRadius: Double = 4.0 / document.zoomLevel

        let pointCount = shape.path.elements.filter {
            switch $0 {
            case .close: return false
            default: return true
            }
        }.count

        if pointCount >= 50 {
            var points: [CGPoint] = []
            var elementIndices: [Int] = []

            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                    points.append(CGPoint(x: to.x, y: to.y))
                    elementIndices.append(elementIndex)
                case .close:
                    continue
                }
            }

            if let nearestIndex = MetalComputeEngine.shared.findNearestPointGPU(
                points: points,
                tapLocation: location,
                selectionRadius: pointSelectionRadius,
                transform: shape.transform
            ) {
                let elementIndex = elementIndices[nearestIndex]
                let pointID = PointID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex
                )

                if isShiftPressed && selectedPoints.contains(pointID) {
                    let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                    let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
                    selectedPoints.remove(pointID)
                    for coincidentPoint in coincidentPoints {
                        selectedPoints.remove(coincidentPoint)
                    }
                    for endpointID in closedPathEndpoints {
                        selectedPoints.remove(endpointID)
                    }
                } else {
                    selectPointWithCoincidents(pointID, addToSelection: isShiftPressed)
                }
                return true
            }
        } else {
            for (elementIndex, element) in shape.path.elements.enumerated() {
                let point: VectorPoint

                switch element {
                case .move(let to), .line(let to):
                    point = to
                case .curve(let to, _, _):
                    point = to
                case .quadCurve(let to, _):
                    point = to
                case .close:
                    continue
                }

                let pointLocation = CGPoint(x: point.x, y: point.y).applying(shape.transform)
                if distance(location, pointLocation) <= pointSelectionRadius {
                    let pointID = PointID(
                        shapeID: shape.id,
                        pathIndex: 0,
                        elementIndex: elementIndex
                    )

                    if isShiftPressed && selectedPoints.contains(pointID) {
                        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                        let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
                        selectedPoints.remove(pointID)
                        for coincidentPoint in coincidentPoints {
                            selectedPoints.remove(coincidentPoint)
                        }
                        for endpointID in closedPathEndpoints {
                            selectedPoints.remove(endpointID)
                        }
                    } else {
                        selectPointWithCoincidents(pointID, addToSelection: isShiftPressed)
                    }
                    return true
                }
            }
        }

        let handleCount = shape.path.elements.filter {
            switch $0 {
            case .curve: return true
            case .quadCurve: return true
            default: return false
            }
        }.count

        if handleCount >= 50 {
            var handlePoints: [CGPoint] = []
            var anchorPoints: [CGPoint] = []
            var handleMetadata: [(elementIndex: Int, handleType: HandleType)] = []

            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .curve(let to, _, let control2):
                    handlePoints.append(CGPoint(x: control2.x, y: control2.y))
                    anchorPoints.append(CGPoint(x: to.x, y: to.y))
                    handleMetadata.append((elementIndex: elementIndex, handleType: .control2))

                    if elementIndex + 1 < shape.path.elements.count,
                       case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                        handlePoints.append(CGPoint(x: nextControl1.x, y: nextControl1.y))
                        anchorPoints.append(CGPoint(x: to.x, y: to.y))
                        handleMetadata.append((elementIndex: elementIndex + 1, handleType: .control1))
                    }

                case .quadCurve(let to, let control):
                    handlePoints.append(CGPoint(x: control.x, y: control.y))
                    anchorPoints.append(CGPoint(x: to.x, y: to.y))
                    handleMetadata.append((elementIndex: elementIndex, handleType: .control1))

                case .move(let to), .line(let to):
                    if elementIndex + 1 < shape.path.elements.count,
                       case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                        handlePoints.append(CGPoint(x: nextControl1.x, y: nextControl1.y))
                        anchorPoints.append(CGPoint(x: to.x, y: to.y))
                        handleMetadata.append((elementIndex: elementIndex + 1, handleType: .control1))
                    }

                case .close:
                    continue
                }
            }

            if let nearestIndex = MetalComputeEngine.shared.findNearestHandleGPU(
                handlePoints: handlePoints,
                anchorPoints: anchorPoints,
                tapLocation: location,
                selectionRadius: handleSelectionRadius,
                transform: shape.transform
            ) {
                let metadata = handleMetadata[nearestIndex]
                let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: metadata.elementIndex, handleType: metadata.handleType)

                if isShiftPressed && selectedHandles.contains(handleID) {
                    selectedHandles.remove(handleID)
                } else {
                    if !isShiftPressed {
                        selectedHandles.removeAll()
                        selectedPoints.removeAll()
                        visibleHandles.removeAll()
                    }
                    selectedHandles.insert(handleID)

                    selectCoincidentHandles(for: handleID, shape: shape)
                }
                return true
            }
        } else {
            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .curve(let to, _, let control2):
                let handle2Collapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                if !handle2Collapsed {
                    let handle2Location = CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                    if distance(location, handle2Location) <= handleSelectionRadius {
                        let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control2)
                        if isShiftPressed && selectedHandles.contains(handleID) {
                            selectedHandles.remove(handleID)
                        } else {
                            if !isShiftPressed {
                                selectedHandles.removeAll()
                                selectedPoints.removeAll()
                                visibleHandles.removeAll()
                            }
                            selectedHandles.insert(handleID)

                            selectCoincidentHandles(for: handleID, shape: shape)

                        }
                        return true
                    }
                }

                if elementIndex + 1 < shape.path.elements.count {
                    if case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                        let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                        if !outgoingHandleCollapsed {
                            let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y).applying(shape.transform)
                            if distance(location, outgoingHandleLocation) <= handleSelectionRadius {
                                let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex + 1, handleType: .control1)
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                        visibleHandles.removeAll()
                                    }
                                    selectedHandles.insert(handleID)

                                    selectCoincidentHandles(for: handleID, shape: shape)

                                }
                                return true
                            }
                        }
                    }
                }

            case .quadCurve(let to, let control):
                let quadHandleCollapsed = (abs(control.x - to.x) < 0.1 && abs(control.y - to.y) < 0.1)
                if !quadHandleCollapsed {
                    let handleLocation = CGPoint(x: control.x, y: control.y).applying(shape.transform)
                    if distance(location, handleLocation) <= handleSelectionRadius {
                        let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control1)
                        if isShiftPressed && selectedHandles.contains(handleID) {
                            selectedHandles.remove(handleID)
                        } else {
                            if !isShiftPressed {
                                selectedHandles.removeAll()
                                selectedPoints.removeAll()
                                visibleHandles.removeAll()
                            }
                            selectedHandles.insert(handleID)

                            selectCoincidentHandles(for: handleID, shape: shape)

                        }
                        return true
                    }
                }

            case .move(let to), .line(let to):
                if elementIndex + 1 < shape.path.elements.count {
                    if case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                        let outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                        if !outgoingHandleCollapsed {
                            let handleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y).applying(shape.transform)
                            if distance(location, handleLocation) <= handleSelectionRadius {
                                let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex + 1, handleType: .control1)
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                        visibleHandles.removeAll()
                                    }
                                    selectedHandles.insert(handleID)

                                    selectCoincidentHandles(for: handleID, shape: shape)

                                }
                                return true
                            }
                        }
                    }
                }

                case .close:
                    continue
                }
            }
        }

        return false
    }

    internal func directSelectWholeShape(at location: CGPoint) -> Bool {
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            if layer.isLocked { continue }

            let shapes = document.getShapesForLayer(layerIndex)
            for shape in shapes.reversed() {
                if !shape.isVisible { continue }


                var isHit = false

                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")

                if isBackgroundShape {
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                } else if shape.isGroupContainer {
                    for groupedShape in shape.groupedShapes {
                        if !groupedShape.isVisible { continue }

                        let isStrokeOnly = groupedShape.fillStyle?.color == .clear || groupedShape.fillStyle == nil

                        if isStrokeOnly && groupedShape.strokeStyle != nil {
                            let strokeWidth = groupedShape.strokeStyle?.width ?? 1.0
                            let strokeTolerance = max(15.0, strokeWidth + 10.0)
                            if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: strokeTolerance) {
                                isHit = true
                                break
                            }
                        } else {
                            let basePathTolerance: Double = 8.0
                            let pathTolerance = max(2.0, basePathTolerance / document.zoomLevel)

                            if PathOperations.hitTest(groupedShape.transformedPath, point: location, tolerance: pathTolerance) {
                                isHit = true
                                break
                            }
                        }
                    }
                } else {
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil

                    if isStrokeOnly && shape.strokeStyle != nil {
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    } else {
                        let basePathTolerance: Double = 8.0
                        let pathTolerance = max(2.0, basePathTolerance / document.zoomLevel)

                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: pathTolerance)
                    }
                }

                if isHit {
                    if layer.isLocked || shape.isLocked {

                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        syncDirectSelectionWithDocument()
                        return true
                    }

                    directSelectedShapeIDs.removeAll()
                    directSelectedShapeIDs.insert(shape.id)
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    syncDirectSelectionWithDocument()

                    return true
                }
            }
        }

        return false
    }

    internal func handleDirectSelectionTap(at location: CGPoint) {


        let screenTolerance: Double = 15.0
        let tolerance: Double = screenTolerance / document.zoomLevel
        var foundSelection = false

        if !directSelectedShapeIDs.isEmpty {
            foundSelection = selectIndividualAnchorPointOrHandle(at: location, tolerance: tolerance)
        }

        if !foundSelection {
            foundSelection = directSelectWholeShape(at: location)
        }

        if !foundSelection {
            Log.error("❌ Clicked empty space - clearing all direct selections", category: .error)
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            visibleHandles.removeAll()
            directSelectedShapeIDs.removeAll()
            syncDirectSelectionWithDocument()
        }
    }


    private func selectCoincidentHandles(for handleID: HandleID, shape: VectorShape) {
        let anchorPoint: CGPoint?
        let pointIndex: Int

        if handleID.handleType == .control1 {
            pointIndex = handleID.elementIndex - 1
            if pointIndex >= 0 && pointIndex < shape.path.elements.count {
                switch shape.path.elements[pointIndex] {
                case .move(let to), .line(let to):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .close:
                    anchorPoint = nil
                }
            } else {
                return
            }
        } else if handleID.handleType == .control2 {
            pointIndex = handleID.elementIndex
            if pointIndex < shape.path.elements.count {
                switch shape.path.elements[pointIndex] {
                case .curve(let to, _, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                case .quadCurve(let to, _):
                    anchorPoint = CGPoint(x: to.x, y: to.y)
                default:
                    anchorPoint = nil
                }
            } else {
                return
            }
        } else {
            return
        }

        guard let anchor = anchorPoint else { return }

        let tolerance = 1.0
        for (index, element) in shape.path.elements.enumerated() {
            if index == pointIndex { continue }

            let elementPoint: CGPoint?
            switch element {
            case .move(let to), .line(let to):
                elementPoint = CGPoint(x: to.x, y: to.y)
            case .curve(let to, _, _), .quadCurve(let to, _):
                elementPoint = CGPoint(x: to.x, y: to.y)
            case .close:
                elementPoint = nil
            }

            if let point = elementPoint {
                let distance = sqrt(pow(anchor.x - point.x, 2) + pow(anchor.y - point.y, 2))
                if distance <= tolerance {

                    if case .curve(_, _, let control2) = element {
                        let handle2Collapsed = (abs(control2.x - point.x) < 0.1 && abs(control2.y - point.y) < 0.1)
                        if !handle2Collapsed {
                            let coincidentHandleID = HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: index,
                                handleType: .control2
                            )
                            if coincidentHandleID != handleID {
                                visibleHandles.insert(coincidentHandleID)
                            }
                        }
                    }

                    let nextIndex = index + 1
                    if nextIndex < shape.path.elements.count {
                        if case .curve(_, let control1, _) = shape.path.elements[nextIndex] {
                            let handle1Collapsed = (abs(control1.x - point.x) < 0.1 && abs(control1.y - point.y) < 0.1)
                            if !handle1Collapsed {
                                let coincidentHandleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: nextIndex,
                                    handleType: .control1
                                )
                                if coincidentHandleID != handleID {
                                    visibleHandles.insert(coincidentHandleID)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
