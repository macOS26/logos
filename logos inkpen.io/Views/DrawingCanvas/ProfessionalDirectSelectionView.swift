import SwiftUI

struct ProfessionalDirectSelectionView: View {
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedPoints: Set<PointID>
    let selectedHandles: Set<HandleID>
    let visibleHandles: Set<HandleID>
    let selectedObjectIDs: Set<UUID>
    let geometry: GeometryProxy
    let coincidentPointTolerance: Double
    let dragPreviewDelta: CGPoint
    let livePointPositions: [PointID: CGPoint]
    let liveHandlePositions: [HandleID: CGPoint]
    let draggedCurveSegment: (shapeID: UUID, elementIndex: Int)?

    // Helper method for curved scaling below 100% zoom
    private func scaleForZoom(_ baseSize: CGFloat, zoom: CGFloat) -> CGFloat {
        if zoom < 1.0 {
            return baseSize * pow(zoom, 0.25)
        }
        return baseSize
    }

    var body: some View {
        Canvas { context, size in
            let zoom = zoomLevel
            let offset = canvasOffset

            // Apply canvas transform GLOBALLY (EXACT same as LayerCanvasView)
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: offset.x, y: offset.y)
                .scaledBy(x: zoom, y: zoom)

            context.transform = baseTransform

            // Draw outlines for selected shapes
            for objectID in selectedObjectIDs {
                guard let object = document.snapshot.objects[objectID] else { continue }

                switch object.objectType {
                case .shape(let shape):
                    drawOutline(shape, context: &context, zoom: zoom)
                case .text(let shape):
                    drawTextOutline(shape, context: &context, zoom: zoom)
                default:
                    break
                }
            }

            // Draw ALL anchor points AFTER outlines (so blue line shows through)
            for objectID in selectedObjectIDs {
                guard let object = document.snapshot.objects[objectID],
                      case .shape(let shape) = object.objectType else { continue }

                for (elementIndex, element) in shape.path.elements.enumerated() {
                    if let point = extractPoint(element) {
                        let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                        let isSelected = selectedPoints.contains(pointID)

                        // Use live position if available, otherwise use original position
                        let pointPosition = if let livePos = livePointPositions[pointID] {
                            livePos
                        } else {
                            CGPoint(x: point.x, y: point.y)
                        }

                        // Transform position and apply drag preview offset
                        var shapeTransform = shape.transform
                        shapeTransform = shapeTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                        let transformed = pointPosition.applying(shapeTransform)

                        // Scale down below 100% zoom using curve
                        let pointSize = scaleForZoom(7.0, zoom: zoom) / zoom
                        let rect = CGRect(x: transformed.x - pointSize/2, y: transformed.y - pointSize/2, width: pointSize, height: pointSize)

                        // Selected points get orange fill, unselected get white fill
                        context.fill(Path(rect), with: .color(isSelected ? .orange : .white))
                        context.stroke(Path(rect), with: .color(.blue), lineWidth: scaleForZoom(1.4, zoom: zoom) / zoom)
                    }
                }
            }

            // Draw selected handles
            for handleID in selectedHandles {
                guard let object = document.snapshot.objects[handleID.shapeID],
                      case .shape(let shape) = object.objectType,
                      handleID.elementIndex < shape.path.elements.count else { continue }

                // Skip handles for corner anchor points
                let anchorElementIndex = handleID.handleType == .control2 ? handleID.elementIndex : handleID.elementIndex - 1
                if let anchorType = shape.anchorTypes[anchorElementIndex], anchorType == .corner {
                    continue  // Don't draw handles for corner points
                }
                // Check coincident point (element 0)
                if let anchorType = shape.anchorTypes[0], anchorType == .corner {
                    let isCoincidentHandle = (handleID.handleType == .control1 && handleID.elementIndex == 1) ||
                                            (handleID.handleType == .control2 && handleID.elementIndex == shape.path.elements.count - 1)
                    if isCoincidentHandle {
                        continue  // Don't draw handles for coincident corner point
                    }
                }

                drawHandle(handleID, shape: shape, context: &context, zoom: zoom, isSelected: true)
            }

            // Draw visible handles
            for handleID in visibleHandles where !selectedHandles.contains(handleID) {
                guard let object = document.snapshot.objects[handleID.shapeID],
                      case .shape(let shape) = object.objectType,
                      handleID.elementIndex < shape.path.elements.count else { continue }

                // Skip handles for corner anchor points
                let anchorElementIndex = handleID.handleType == .control2 ? handleID.elementIndex : handleID.elementIndex - 1
                if let anchorType = shape.anchorTypes[anchorElementIndex], anchorType == .corner {
                    continue  // Don't draw handles for corner points
                }
                // Check coincident point (element 0)
                if let anchorType = shape.anchorTypes[0], anchorType == .corner {
                    let isCoincidentHandle = (handleID.handleType == .control1 && handleID.elementIndex == 1) ||
                                            (handleID.handleType == .control2 && handleID.elementIndex == shape.path.elements.count - 1)
                    if isCoincidentHandle {
                        continue  // Don't draw handles for coincident corner point
                    }
                }

                drawHandle(handleID, shape: shape, context: &context, zoom: zoom, isSelected: false)
            }
        }
    }

    private func drawOutline(_ shape: VectorShape, context: inout GraphicsContext, zoom: CGFloat) {
        // Check if we're dragging a curve segment on this shape
        let isDraggingSegmentOnThisShape = draggedCurveSegment?.shapeID == shape.id

        // Build complete path in local coordinates, applying live positions
        var outlinePath = Path()
        var draggedSegmentPath: Path?
        var lastPoint: CGPoint?
        var firstPoint: CGPoint?

        for (elementIndex, element) in shape.path.elements.enumerated() {
            let isThisDraggedSegment = isDraggingSegmentOnThisShape && draggedCurveSegment?.elementIndex == elementIndex

            switch element {
            case .move(let to):
                let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                let point = livePointPositions[pointID] ?? to.cgPoint
                outlinePath.move(to: point)
                lastPoint = point
                firstPoint = point

            case .line(let to):
                let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                let point = livePointPositions[pointID] ?? to.cgPoint
                outlinePath.addLine(to: point)

                // If this is the dragged segment, also build it separately for orange overlay
                if isThisDraggedSegment {
                    var segPath = Path()
                    if let start = lastPoint {
                        segPath.move(to: start)
                    }
                    segPath.addLine(to: point)
                    draggedSegmentPath = segPath
                }
                lastPoint = point

            case .curve(let to, let c1, let c2):
                let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                let handleID1 = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control1)
                let handleID2 = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control2)

                let point = livePointPositions[pointID] ?? to.cgPoint
                let control1 = liveHandlePositions[handleID1] ?? CGPoint(x: c1.x, y: c1.y)
                let control2 = liveHandlePositions[handleID2] ?? CGPoint(x: c2.x, y: c2.y)

                outlinePath.addCurve(to: point, control1: control1, control2: control2)

                // If this is the dragged segment, also build it separately for orange overlay
                if isThisDraggedSegment {
                    var segPath = Path()
                    if let start = lastPoint {
                        segPath.move(to: start)
                    }
                    segPath.addCurve(to: point, control1: control1, control2: control2)
                    draggedSegmentPath = segPath
                }
                lastPoint = point

            case .quadCurve(let to, let control):
                let pointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                let handleID = HandleID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex, handleType: .control1)

                let point = livePointPositions[pointID] ?? to.cgPoint
                let controlPoint = liveHandlePositions[handleID] ?? control.cgPoint

                outlinePath.addQuadCurve(to: point, control: controlPoint)

                // If this is the dragged segment, also build it separately for orange overlay
                if isThisDraggedSegment {
                    var segPath = Path()
                    if let start = lastPoint {
                        segPath.move(to: start)
                    }
                    segPath.addQuadCurve(to: point, control: controlPoint)
                    draggedSegmentPath = segPath
                }
                lastPoint = point

            case .close:
                outlinePath.closeSubpath()

                // If this is the dragged segment, build it separately for orange overlay
                if isThisDraggedSegment, let last = lastPoint, let first = firstPoint {
                    var segPath = Path()
                    segPath.move(to: last)
                    segPath.addLine(to: first)
                    draggedSegmentPath = segPath
                }
            }
        }

        // Apply shape transform and drag preview offset
        var ctx = context
        var shapeTransform = shape.transform
        shapeTransform = shapeTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        ctx.concatenate(shapeTransform)

        // Draw complete path in blue
        ctx.stroke(outlinePath, with: .color(.blue), lineWidth: scaleForZoom(1.4, zoom: zoom) / zoom)

        // Draw dragged segment on top in orange (thicker)
        if let draggedPath = draggedSegmentPath {
            ctx.stroke(draggedPath, with: .color(.orange), lineWidth: scaleForZoom(2.0, zoom: zoom) / zoom)
        }
    }

    private func drawTextOutline(_ shape: VectorShape, context: inout GraphicsContext, zoom: CGFloat) {
        // Determine outline color based on view mode
        let isKeylineMode = document.viewState.viewMode == .keyline
        let outlineColor: Color = isKeylineMode ? .black : .red

        // Get text bounds from areaSize or bounds
        let textBounds: CGRect
        if let areaSize = shape.areaSize {
            textBounds = CGRect(origin: .zero, size: areaSize)
        } else {
            textBounds = shape.bounds
        }

        // Create rectangle path in local coordinates
        var outlinePath = Path()
        outlinePath.addRect(textBounds)

        // Apply shape transform and drag preview offset
        var ctx = context
        var shapeTransform = shape.transform
        shapeTransform = shapeTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        ctx.concatenate(shapeTransform)
        ctx.stroke(outlinePath, with: .color(outlineColor), lineWidth: scaleForZoom(1.4, zoom: zoom) / zoom)
    }

    private func drawHandle(_ handleID: HandleID, shape: VectorShape, context: inout GraphicsContext, zoom: CGFloat, isSelected: Bool) {
        let element = shape.path.elements[handleID.elementIndex]

        var anchorPoint: CGPoint?
        var handlePoint: CGPoint?
        var anchorPointID: PointID?

        switch element {
        case .curve(let to, let c1, let c2):
            if handleID.handleType == .control2 {
                anchorPoint = to.cgPoint
                anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: handleID.elementIndex)
                handlePoint = CGPoint(x: c2.x, y: c2.y)
            } else if handleID.handleType == .control1, handleID.elementIndex > 0 {
                let prevElement = shape.path.elements[handleID.elementIndex - 1]
                anchorPoint = extractPoint(prevElement).map { CGPoint(x: $0.x, y: $0.y) }
                anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: handleID.elementIndex - 1)
                handlePoint = CGPoint(x: c1.x, y: c1.y)
            }
        case .quadCurve(let to, let control):
            anchorPoint = to.cgPoint
            anchorPointID = PointID(shapeID: shape.id, pathIndex: 0, elementIndex: handleID.elementIndex)
            handlePoint = control.cgPoint
        default:
            break
        }

        guard var anchor = anchorPoint, var handle = handlePoint else { return }

        // Use live positions if available
        if let liveAnchor = anchorPointID, let livePos = livePointPositions[liveAnchor] {
            anchor = livePos
        }
        if let livePos = liveHandlePositions[handleID] {
            handle = livePos
        }

        // Skip drawing if handle is collapsed (at same position as anchor)
        // SIMD-optimized distance calculation: sqrt(dx² + dy²)
        let dx = handle.x - anchor.x
        let dy = handle.y - anchor.y
        let distance = sqrt(dx * dx + dy * dy)
        if distance < 0.5 {
            return  // Handle is collapsed, don't draw it
        }

        // Transform positions and apply drag preview offset
        var shapeTransform = shape.transform
        shapeTransform = shapeTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        let transformedAnchor = anchor.applying(shapeTransform)
        let transformedHandle = handle.applying(shapeTransform)

        var linePath = Path()
        linePath.move(to: transformedAnchor)
        linePath.addLine(to: transformedHandle)
        context.stroke(linePath, with: .color(.blue), lineWidth: scaleForZoom(1.4, zoom: zoom) / zoom)

        // Scale down below 100% zoom using curve
        let handleSize = scaleForZoom(5.6, zoom: zoom) / zoom
        let circle = Circle().path(in: CGRect(x: transformedHandle.x - handleSize/2, y: transformedHandle.y - handleSize/2, width: handleSize, height: handleSize))
        context.fill(circle, with: .color(isSelected ? .orange : .blue))
        context.stroke(circle, with: .color(.white), lineWidth: scaleForZoom(0.7, zoom: zoom) / zoom)
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
