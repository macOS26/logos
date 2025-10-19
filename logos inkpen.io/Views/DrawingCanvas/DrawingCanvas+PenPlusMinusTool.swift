import SwiftUI
import Combine

extension DrawingCanvas {

    func handlePenPlusMinusTap(at location: CGPoint) {
        let tolerance: Double = 8.0 / document.viewState.zoomLevel

        if let pointToDelete = findAnchorPointAt(location: location, tolerance: tolerance) {
            deletePointWithCurvePreservation(pointID: pointToDelete)
            return
        }

        if let segmentHit = findCurveSegmentAt(location: location, tolerance: tolerance) {
            insertPointOnCurve(
                layerIndex: segmentHit.layerIndex,
                shapeIndex: segmentHit.shapeIndex,
                elementIndex: segmentHit.elementIndex,
                at: location
            )
            return
        }

    }

    private func insertPointOnCurve(layerIndex: Int, shapeIndex: Int, elementIndex: Int, at location: CGPoint) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.getShapeCount(layerIndex: layerIndex),
              let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex),
              elementIndex < shape.path.elements.count else { return }

        let element = shape.path.elements[elementIndex]

        guard case .curve(let to, let control1, let control2) = element else {
            return
        }

        let oldPath = shape.path
        var startPoint: VectorPoint
        if elementIndex > 0 {
            let prevElement = shape.path.elements[elementIndex - 1]
            switch prevElement {
            case .move(let point), .line(let point), .curve(let point, _, _), .quadCurve(let point, _):
                startPoint = point
            default:
                return
            }
        } else {
            return
        }

        let t = findParametricValueOnCurve(
            start: CGPoint(x: startPoint.x, y: startPoint.y),
            control1: CGPoint(x: control1.x, y: control1.y),
            control2: CGPoint(x: control2.x, y: control2.y),
            end: CGPoint(x: to.x, y: to.y),
            targetPoint: location
        )

        let splitResult = splitCubicBezierAt(
            p0: CGPoint(x: startPoint.x, y: startPoint.y),
            p1: CGPoint(x: control1.x, y: control1.y),
            p2: CGPoint(x: control2.x, y: control2.y),
            p3: CGPoint(x: to.x, y: to.y),
            t: t
        )

        let firstCurve = PathElement.curve(
            to: VectorPoint(splitResult.splitPoint),
            control1: VectorPoint(splitResult.leftControl1),
            control2: VectorPoint(splitResult.leftControl2)
        )

        let secondCurve = PathElement.curve(
            to: to,
            control1: VectorPoint(splitResult.rightControl1),
            control2: VectorPoint(splitResult.rightControl2)
        )

        var modifiedShape = shape
        var elements = modifiedShape.path.elements
        elements[elementIndex] = firstCurve
        elements.insert(secondCurve, at: elementIndex + 1)

        modifiedShape.path.elements = elements
        modifiedShape.updateBounds()

        let newPath = VectorPath(elements: elements, isClosed: shape.path.isClosed)
        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: modifiedShape)

        let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
        document.commandManager.execute(command)
    }

    private func deletePointWithCurvePreservation(pointID: PointID) {
        guard let unifiedObject = document.findObject(by: pointID.shapeID),
              case .shape(let shape) = unifiedObject.objectType else { return }

        let layerIndex = unifiedObject.layerIndex
        let shapes = document.getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == pointID.shapeID }) else { return }
        let elements = shape.path.elements

        guard pointID.elementIndex < elements.count else { return }

        let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
        if !closedPathEndpoints.isEmpty {
            NSSound.beep()
            return
        }

        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
        if !coincidentPoints.isEmpty {
            NSSound.beep()
            return
        }

        let oldPath = shape.path
        let pathPointCount = elements.filter { element in
            switch element {
            case .move, .line, .curve, .quadCurve: return true
            case .close: return false
            }
        }.count

        if pathPointCount <= 2 {
            document.removeShapeFromUnifiedSystem(id: shape.id)
        } else {
            let updatedElements = deletePointWithCurveMerging(
                elements: elements,
                pointIndex: pointID.elementIndex
            )

            var modifiedShape = shape
            modifiedShape.path.elements = updatedElements
            modifiedShape.updateBounds()

            let newPath = VectorPath(elements: updatedElements, isClosed: shape.path.isClosed)
            document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: modifiedShape)

            let command = ModifyPathCommand(objectID: shape.id, oldPath: oldPath, newPath: newPath)
            document.commandManager.execute(command)
            return
        }
    }

    private func findAnchorPointAt(location: CGPoint, tolerance: Double) -> PointID? {
        for unifiedObject in document.unifiedObjects.reversed() {
            if case .shape(let shape) = unifiedObject.objectType {
                if !shape.isVisible || shape.isLocked { continue }

            for (elementIndex, element) in shape.path.elements.enumerated() {
                switch element {
                case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                    let rawPointLocation = CGPoint(x: to.x, y: to.y)
                    let pointLocation = rawPointLocation.applying(shape.transform)

                    if distance(location, pointLocation) <= tolerance {
                        return PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                    }
                default:
                    break
                }
            }
            }
        }
        return nil
    }

    private func findCurveSegmentAt(location: CGPoint, tolerance: Double) -> (layerIndex: Int, shapeIndex: Int, elementIndex: Int)? {
        for unifiedObject in document.unifiedObjects.reversed() {
            if case .shape(let shape) = unifiedObject.objectType {
                if !shape.isVisible || shape.isLocked { continue }

                let layerIndex = unifiedObject.layerIndex
                let shapesInLayer = document.getShapesForLayer(layerIndex)
                guard let shapeIndex = shapesInLayer.firstIndex(where: { $0.id == shape.id }) else { continue }

                var previousPoint: VectorPoint?

                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .move(let to):
                        previousPoint = to
                    case .line(let to):
                        if let prev = previousPoint {
                            let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                            let end = CGPoint(x: to.x, y: to.y).applying(shape.transform)

                            if isPointNearLineSegment(point: location, start: start, end: end, tolerance: tolerance) {
                                return (layerIndex, shapeIndex, elementIndex)
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
                                return (layerIndex, shapeIndex, elementIndex)
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
        }
        return nil
    }

    private func findParametricValueOnCurve(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, targetPoint: CGPoint) -> Double {
        var bestT: Double = 0.5
        var bestDistance: Double = Double.infinity

        for i in 0...100 {
            let t = Double(i) / 100.0
            let curvePoint = evaluateCubicBezier(p0: start, p1: control1, p2: control2, p3: end, t: t)
            let dist = distance(targetPoint, curvePoint)

            if dist < bestDistance {
                bestDistance = dist
                bestT = t
            }
        }

        return bestT
    }

    private func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> CGPoint {
        let oneMinusT = 1.0 - t
        let oneMinusT2 = oneMinusT * oneMinusT
        let oneMinusT3 = oneMinusT2 * oneMinusT
        let t2 = t * t
        let t3 = t2 * t

        return CGPoint(
            x: oneMinusT3 * p0.x + 3 * oneMinusT2 * t * p1.x + 3 * oneMinusT * t2 * p2.x + t3 * p3.x,
            y: oneMinusT3 * p0.y + 3 * oneMinusT2 * t * p1.y + 3 * oneMinusT * t2 * p2.y + t3 * p3.y
        )
    }

    private func splitCubicBezierAt(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> (
        leftControl1: CGPoint, leftControl2: CGPoint,
        splitPoint: CGPoint,
        rightControl1: CGPoint, rightControl2: CGPoint
    ) {
        let p01 = lerp(p0, p1, t)
        let p12 = lerp(p1, p2, t)
        let p23 = lerp(p2, p3, t)
        let p012 = lerp(p01, p12, t)
        let p123 = lerp(p12, p23, t)
        let splitPoint = lerp(p012, p123, t)

        return (
            leftControl1: p01,
            leftControl2: p012,
            splitPoint: splitPoint,
            rightControl1: p123,
            rightControl2: p23
        )
    }

    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        return CGPoint(
            x: a.x + (b.x - a.x) * t,
            y: a.y + (b.y - a.y) * t
        )
    }

    private func isPointNearLineSegment(point: CGPoint, start: CGPoint, end: CGPoint, tolerance: Double) -> Bool {
        let A = point.x - start.x
        let B = point.y - start.y
        let C = end.x - start.x
        let D = end.y - start.y
        let dot = A * C + B * D
        let lenSq = C * C + D * D

        if lenSq == 0 {
            return sqrt(A * A + B * B) <= tolerance
        }

        let param = dot / lenSq
        let xx, yy: Double
        if param < 0 {
            xx = start.x
            yy = start.y
        } else if param > 1 {
            xx = end.x
            yy = end.y
        } else {
            xx = start.x + param * C
            yy = start.y + param * D
        }

        let dx = point.x - xx
        let dy = point.y - yy
        return sqrt(dx * dx + dy * dy) <= tolerance
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

    private func deletePointWithCurveMerging(elements: [PathElement], pointIndex: Int) -> [PathElement] {
        var newElements = elements

        newElements.remove(at: pointIndex)

        if pointIndex > 0 && pointIndex < elements.count {
        }

        return newElements
    }

}
