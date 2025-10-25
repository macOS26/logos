import SwiftUI

struct ProfessionalDirectSelectionView: View {
    let document: VectorDocument
    let selectedPoints: Set<PointID>
    let selectedHandles: Set<HandleID>
    let visibleHandles: Set<HandleID>
    let selectedObjectIDs: Set<UUID>
    let geometry: GeometryProxy
    let coincidentPointTolerance: Double
    let dragPreviewDelta: CGPoint

    var body: some View {
        Canvas { context, size in
            let zoom = document.viewState.zoomLevel
            let offset = document.viewState.canvasOffset

            // Hide overlay during drag
            guard dragPreviewDelta == .zero else { return }

            // Apply canvas transform GLOBALLY (EXACT same as LayerCanvasView)
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: offset.x, y: offset.y)
                .scaledBy(x: zoom, y: zoom)

            context.transform = baseTransform

            // Draw outlines and ALL anchor points for selected shapes
            for objectID in selectedObjectIDs {
                guard let object = document.snapshot.objects[objectID],
                      case .shape(let shape) = object.objectType else { continue }

                drawOutline(shape, context: &context, zoom: zoom)

                // Draw ALL anchor points for this shape
                // Transform position but NOT the point size
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    if let point = extractPoint(element) {
                        let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                        let isSelected = selectedPoints.contains(pointID)

                        // Transform position only
                        let transformed = CGPoint(x: point.x, y: point.y).applying(shape.transform)

                        // Fixed document-space size - scales with zoom
                        let pointSize: CGFloat = 0.6
                        let rect = CGRect(x: transformed.x - pointSize/2, y: transformed.y - pointSize/2, width: pointSize, height: pointSize)
                        context.fill(Path(rect), with: .color(isSelected ? .blue : .white))
                        context.stroke(Path(rect), with: .color(.blue), lineWidth: 0.1)
                    }
                }
            }

            // Draw selected handles
            for handleID in selectedHandles {
                guard let object = document.snapshot.objects[handleID.shapeID],
                      case .shape(let shape) = object.objectType,
                      handleID.elementIndex < shape.path.elements.count else { continue }

                drawHandle(handleID, shape: shape, context: &context, zoom: zoom, isSelected: true)
            }

            // Draw visible handles
            for handleID in visibleHandles where !selectedHandles.contains(handleID) {
                guard let object = document.snapshot.objects[handleID.shapeID],
                      case .shape(let shape) = object.objectType,
                      handleID.elementIndex < shape.path.elements.count else { continue }

                drawHandle(handleID, shape: shape, context: &context, zoom: zoom, isSelected: false)
            }
        }
    }

    private func drawOutline(_ shape: VectorShape, context: inout GraphicsContext, zoom: CGFloat) {
        var outlinePath = Path()

        // Build path in local coordinates
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

        // Apply shape transform and draw (canvas transform already applied)
        var ctx = context
        ctx.concatenate(shape.transform)
        ctx.stroke(outlinePath, with: .color(.blue), lineWidth: 0.1)
    }

    private func drawHandle(_ handleID: HandleID, shape: VectorShape, context: inout GraphicsContext, zoom: CGFloat, isSelected: Bool) {
        let element = shape.path.elements[handleID.elementIndex]

        var anchorPoint: CGPoint?
        var handlePoint: CGPoint?

        switch element {
        case .curve(let to, let c1, let c2):
            if handleID.handleType == .control2 {
                anchorPoint = CGPoint(x: to.x, y: to.y)
                handlePoint = CGPoint(x: c2.x, y: c2.y)
            } else if handleID.handleType == .control1, handleID.elementIndex > 0 {
                let prevElement = shape.path.elements[handleID.elementIndex - 1]
                anchorPoint = extractPoint(prevElement).map { CGPoint(x: $0.x, y: $0.y) }
                handlePoint = CGPoint(x: c1.x, y: c1.y)
            }
        case .quadCurve(let to, let control):
            anchorPoint = CGPoint(x: to.x, y: to.y)
            handlePoint = CGPoint(x: control.x, y: control.y)
        default:
            break
        }

        guard let anchor = anchorPoint, let handle = handlePoint else { return }

        // Transform positions only, not the handle size
        let transformedAnchor = anchor.applying(shape.transform)
        let transformedHandle = handle.applying(shape.transform)

        var linePath = Path()
        linePath.move(to: transformedAnchor)
        linePath.addLine(to: transformedHandle)
        context.stroke(linePath, with: .color(.blue), lineWidth: 0.1)

        // Fixed document-space size - scales with zoom
        let handleSize: CGFloat = 0.4
        let circle = Circle().path(in: CGRect(x: transformedHandle.x - handleSize/2, y: transformedHandle.y - handleSize/2, width: handleSize, height: handleSize))
        context.fill(circle, with: .color(isSelected ? .orange : .blue))
        context.stroke(circle, with: .color(.white), lineWidth: 0.05)
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
