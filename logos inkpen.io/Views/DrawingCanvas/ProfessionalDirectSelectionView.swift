import SwiftUI

struct ProfessionalDirectSelectionView: View {
    let document: VectorDocument
    let selectedPoints: Set<PointID>
    let selectedHandles: Set<HandleID>
    let visibleHandles: Set<HandleID>
    let selectedObjectIDs: Set<UUID>
    let geometry: GeometryProxy
    let coincidentPointTolerance: Double

    private var dragOffset: CGPoint {
        if document.currentDragOffset != .zero && !selectedObjectIDs.isEmpty && selectedPoints.isEmpty && selectedHandles.isEmpty {
            return document.currentDragOffset
        }
        return .zero
    }

    var body: some View {
        Canvas { context, size in
            let zoom = document.viewState.zoomLevel
            let offset = document.viewState.canvasOffset

            // Only iterate through selected objects (not all objects!)
            for objectID in selectedObjectIDs {
                guard let object = document.snapshot.objects[objectID],
                      case .shape(let shape) = object.objectType,
                      shape.isVisible else { continue }

                if shape.isGroupContainer {
                    for groupedShape in shape.groupedShapes where groupedShape.isVisible {
                        drawShape(groupedShape, context: context, zoom: zoom, offset: offset)
                    }
                } else {
                    drawShape(shape, context: context, zoom: zoom, offset: offset)
                }
            }
        }
    }

    private func drawShape(_ shape: VectorShape, context: GraphicsContext, zoom: CGFloat, offset: CGPoint) {
        var ctx = context

        // Draw blue outline
        var outlinePath = Path()
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                outlinePath.move(to: CGPoint(x: to.x, y: to.y))
            case .line(let to):
                outlinePath.addLine(to: CGPoint(x: to.x, y: to.y))
            case .curve(let to, let c1, let c2):
                outlinePath.addCurve(to: CGPoint(x: to.x, y: to.y), control1: CGPoint(x: c1.x, y: c1.y), control2: CGPoint(x: c2.x, y: c2.y))
            case .quadCurve(let to, let control):
                outlinePath.addQuadCurve(to: CGPoint(x: to.x, y: to.y), control: CGPoint(x: control.x, y: control.y))
            case .close:
                outlinePath.closeSubpath()
            }
        }

        ctx.concatenate(shape.transform)
        ctx.scaleBy(x: zoom, y: zoom)
        ctx.translateBy(x: offset.x / zoom, y: offset.y / zoom)
        ctx.stroke(outlinePath, with: .color(.blue), lineWidth: 1.0 / zoom)

        // Draw all points and handles
        for (elementIndex, element) in shape.path.elements.enumerated() {
            let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)

            // Draw anchor point
            if let point = extractPoint(element) {
                let rawLoc = CGPoint(x: point.x + dragOffset.x, y: point.y + dragOffset.y)
                let transformed = rawLoc.applying(shape.transform)
                let screenPos = CGPoint(x: transformed.x * zoom + offset.x, y: transformed.y * zoom + offset.y)

                let isSelected = selectedPoints.contains(pointID)
                let hasCoincident = !findCoincidentPoints(to: pointID, in: document, tolerance: coincidentPointTolerance).isEmpty

                let rect = CGRect(x: screenPos.x - 4, y: screenPos.y - 4, width: 8, height: 8)
                context.fill(Path(rect), with: .color(isSelected ? .blue : .white))
                context.stroke(Path(rect), with: .color(hasCoincident ? .orange : .blue), lineWidth: hasCoincident ? 2.0 : 1.0)
            }

            // Draw handles for curves
            switch element {
            case .curve(let to, _, let control2):
                let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                let isPointSelected = selectedPoints.contains(pointID)
                let coincidentPoints = findCoincidentPoints(to: pointID, in: document, tolerance: coincidentPointTolerance)
                let anyCoincidentSelected = !coincidentPoints.isEmpty && coincidentPoints.contains { selectedPoints.contains($0) }

                let incomingHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control2)
                let isIncomingVisible = selectedHandles.contains(incomingHandleID) || visibleHandles.contains(incomingHandleID)

                var outgoingHandleID: HandleID?
                var isOutgoingVisible = false
                if elementIndex + 1 < shape.path.elements.count, case .curve = shape.path.elements[elementIndex + 1] {
                    outgoingHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex + 1, handleType: .control1)
                    isOutgoingVisible = selectedHandles.contains(outgoingHandleID!) || visibleHandles.contains(outgoingHandleID!)
                }

                let shouldShow = isPointSelected || anyCoincidentSelected || isIncomingVisible || isOutgoingVisible

                if shouldShow {
                    let anchorLoc = CGPoint(x: to.x, y: to.y)
                    let control2Loc = CGPoint(x: control2.x, y: control2.y)

                    // Incoming handle
                    if abs(control2.x - to.x) >= 0.1 || abs(control2.y - to.y) >= 0.1 {
                        drawHandle(from: anchorLoc, to: control2Loc, shape: shape, isSelected: selectedHandles.contains(incomingHandleID), context: context, zoom: zoom, offset: offset)
                    }

                    // Outgoing handle
                    if elementIndex + 1 < shape.path.elements.count, case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                        if abs(nextControl1.x - to.x) >= 0.1 || abs(nextControl1.y - to.y) >= 0.1 {
                            let control1Loc = CGPoint(x: nextControl1.x, y: nextControl1.y)
                            drawHandle(from: anchorLoc, to: control1Loc, shape: shape, isSelected: selectedHandles.contains(outgoingHandleID!), context: context, zoom: zoom, offset: offset)
                        }
                    }
                }

            case .move(let to), .line(let to):
                let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                let isPointSelected = selectedPoints.contains(pointID)
                let coincidentPoints = findCoincidentPoints(to: pointID, in: document, tolerance: coincidentPointTolerance)
                let anyCoincidentSelected = !coincidentPoints.isEmpty && coincidentPoints.contains { selectedPoints.contains($0) }

                var outgoingHandleID: HandleID?
                var isOutgoingVisible = false
                if elementIndex + 1 < shape.path.elements.count, case .curve = shape.path.elements[elementIndex + 1] {
                    outgoingHandleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex + 1, handleType: .control1)
                    isOutgoingVisible = selectedHandles.contains(outgoingHandleID!) || visibleHandles.contains(outgoingHandleID!)
                }

                let shouldShow = isPointSelected || anyCoincidentSelected || isOutgoingVisible

                if shouldShow, elementIndex + 1 < shape.path.elements.count, case .curve(_, let nextControl1, _) = shape.path.elements[elementIndex + 1] {
                    let anchorLoc = CGPoint(x: to.x, y: to.y)
                    let control1Loc = CGPoint(x: nextControl1.x, y: nextControl1.y)
                    if abs(nextControl1.x - to.x) >= 0.1 || abs(nextControl1.y - to.y) >= 0.1 {
                        drawHandle(from: anchorLoc, to: control1Loc, shape: shape, isSelected: selectedHandles.contains(outgoingHandleID!), context: context, zoom: zoom, offset: offset)
                    }
                }

            default:
                break
            }
        }
    }

    private func drawHandle(from: CGPoint, to: CGPoint, shape: VectorShape, isSelected: Bool, context: GraphicsContext, zoom: CGFloat, offset: CGPoint) {
        let offsetFrom = CGPoint(x: from.x + dragOffset.x, y: from.y + dragOffset.y)
        let offsetTo = CGPoint(x: to.x + dragOffset.x, y: to.y + dragOffset.y)

        let transformedFrom = offsetFrom.applying(shape.transform)
        let transformedTo = offsetTo.applying(shape.transform)

        let screenFrom = CGPoint(x: transformedFrom.x * zoom + offset.x, y: transformedFrom.y * zoom + offset.y)
        let screenTo = CGPoint(x: transformedTo.x * zoom + offset.x, y: transformedTo.y * zoom + offset.y)

        var linePath = Path()
        linePath.move(to: screenFrom)
        linePath.addLine(to: screenTo)
        context.stroke(linePath, with: .color(.blue), lineWidth: 1.0)

        let circle = Circle().path(in: CGRect(x: screenTo.x - 3, y: screenTo.y - 3, width: 6, height: 6))
        context.fill(circle, with: .color(isSelected ? .orange : .blue))
        context.stroke(circle, with: .color(.white), lineWidth: 0.5)
    }

    private func extractPoint(_ element: PathElement) -> VectorPoint? {
        switch element {
        case .move(let to), .line(let to):
            return to
        case .curve(let to, _, _), .quadCurve(let to, _):
            return to
        case .close:
            return nil
        }
    }
}
