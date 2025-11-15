import SwiftUI

struct ProfessionalBezierView: View {
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let bezierPoints: [VectorPoint]
    let bezierHandles: [Int: BezierHandleInfo]
    let liveBezierHandles: [Int: BezierHandleInfo]
    let activeBezierPointIndex: Int?
    let showClosePathHint: Bool
    let showContinuePathHint: Bool
    let closePathHintLocation: CGPoint
    let continuePathHintLocation: CGPoint

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

            // Apply canvas transform GLOBALLY (EXACT same as DirectSelectionView)
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: offset.x, y: offset.y)
                .scaledBy(x: zoom, y: zoom)

            context.transform = baseTransform

            // Draw the path with live handles FIRST
            if bezierPoints.count >= 2 {
                var pathToDraw = Path()
                pathToDraw.move(to: CGPoint(x: bezierPoints[0].x, y: bezierPoints[0].y))

                for i in 1..<bezierPoints.count {
                    let currentPoint = bezierPoints[i]
                    let previousPoint = bezierPoints[i - 1]
                    let previousHandles = liveBezierHandles[i - 1] ?? bezierHandles[i - 1]
                    let currentHandles = liveBezierHandles[i] ?? bezierHandles[i]
                    let hasOutgoingHandle = previousHandles?.control2 != nil
                    let hasIncomingHandle = currentHandles?.control1 != nil

                    if hasOutgoingHandle || hasIncomingHandle {
                        let control1 = previousHandles?.control2 ?? VectorPoint(previousPoint.x, previousPoint.y)
                        let control2 = currentHandles?.control1 ?? VectorPoint(currentPoint.x, currentPoint.y)
                        pathToDraw.addCurve(
                            to: CGPoint(x: currentPoint.x, y: currentPoint.y),
                            control1: CGPoint(x: control1.x, y: control1.y),
                            control2: CGPoint(x: control2.x, y: control2.y)
                        )
                    } else {
                        pathToDraw.addLine(to: CGPoint(x: currentPoint.x, y: currentPoint.y))
                    }
                }

                // Draw blue preview line that accounts for stroke placement
                // If stroke placement is outside, the actual shape will appear offset
                // So we need to show the preview where the shape will actually render
                let strokeWidth = document.defaultStrokeWidth
                let strokePlacement = document.strokeDefaults.placement

                // Calculate offset based on stroke placement
                if strokePlacement == .outside && strokeWidth > 0 {
                    // For outside stroke, the fill will appear offset by half the stroke width
                    // We need to show the preview where the actual shape will be
                    context.stroke(pathToDraw, with: .color(.blue), lineWidth: 1.0 / zoom)

                    // Also show a dashed line where the fill edge will be
                    context.stroke(pathToDraw, with: .color(.blue.opacity(0.5)),
                                 style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoom, dash: [5.0 / zoom, 3.0 / zoom]))
                } else {
                    context.stroke(pathToDraw, with: .color(.blue), lineWidth: 1.0 / zoom)
                }
            }

            // Draw control handles AFTER path (so they appear on top)
            for index in bezierPoints.indices {
                // Use live handles if available, otherwise use actual handles
                let handleInfo = liveBezierHandles[index] ?? bezierHandles[index]

                if let handleInfo = handleInfo, handleInfo.hasHandles {
                    let anchorPoint = CGPoint(x: bezierPoints[index].x, y: bezierPoints[index].y)

                    if let control1 = handleInfo.control1 {
                        drawBezierHandle(control1, anchor: anchorPoint, context: &context, zoom: zoom)
                    }

                    if let control2 = handleInfo.control2 {
                        drawBezierHandle(control2, anchor: anchorPoint, context: &context, zoom: zoom)
                    }
                }
            }

            // Draw anchor points AFTER handles (so they appear on top)
            for index in bezierPoints.indices {
                let point = bezierPoints[index]
                let pointLocation = CGPoint(x: point.x, y: point.y)
                let isActive = activeBezierPointIndex == index

                // Scale down below 100% zoom using curve
                let pointSize = scaleForZoom(8.0, zoom: zoom) / zoom
                let rect = CGRect(
                    x: pointLocation.x - pointSize/2,
                    y: pointLocation.y - pointSize/2,
                    width: pointSize,
                    height: pointSize
                )

                // Active points get black fill, inactive get white fill
                context.fill(Path(rect), with: .color(isActive ? .black : .white))
                context.stroke(Path(rect), with: .color(isActive ? .white : .black), lineWidth: scaleForZoom(1.0, zoom: zoom) / zoom)
            }

            // Reset transform for screen-space overlays
            context.transform = .identity

            // Draw close path hint in screen space
            if showClosePathHint {
                let hintX = closePathHintLocation.x * zoom + offset.x
                let hintY = closePathHintLocation.y * zoom + offset.y
                let hintSize: CGFloat = 16

                // Draw circle background
                let circlePath = Circle().path(in: CGRect(
                    x: hintX - hintSize/2,
                    y: hintY - hintSize/2,
                    width: hintSize,
                    height: hintSize
                ))
                context.fill(circlePath, with: .color(.green.opacity(0.1)))
                context.stroke(circlePath, with: .color(.green), lineWidth: 2.0)

                // Draw X symbol
                var xPath = Path()
                let xSize: CGFloat = 6
                xPath.move(to: CGPoint(x: hintX - xSize/2, y: hintY - xSize/2))
                xPath.addLine(to: CGPoint(x: hintX + xSize/2, y: hintY + xSize/2))
                xPath.move(to: CGPoint(x: hintX + xSize/2, y: hintY - xSize/2))
                xPath.addLine(to: CGPoint(x: hintX - xSize/2, y: hintY + xSize/2))
                context.stroke(xPath, with: .color(.green), lineWidth: 2.0)
            }

            // Draw continue path hint in screen space
            if showContinuePathHint {
                let hintX = continuePathHintLocation.x * zoom + offset.x
                let hintY = continuePathHintLocation.y * zoom + offset.y
                let hintSize: CGFloat = 16

                // Draw circle background
                let circlePath = Circle().path(in: CGRect(
                    x: hintX - hintSize/2,
                    y: hintY - hintSize/2,
                    width: hintSize,
                    height: hintSize
                ))
                context.fill(circlePath, with: .color(.blue.opacity(0.1)))
                context.stroke(circlePath, with: .color(.blue), lineWidth: 2.0)

                // Draw arrow symbol
                var arrowPath = Path()
                let arrowSize: CGFloat = 6
                arrowPath.move(to: CGPoint(x: hintX - arrowSize/2, y: hintY))
                arrowPath.addLine(to: CGPoint(x: hintX + arrowSize/2, y: hintY))
                arrowPath.move(to: CGPoint(x: hintX + arrowSize/2 - 3, y: hintY - 3))
                arrowPath.addLine(to: CGPoint(x: hintX + arrowSize/2, y: hintY))
                arrowPath.addLine(to: CGPoint(x: hintX + arrowSize/2 - 3, y: hintY + 3))
                context.stroke(arrowPath, with: .color(.blue), lineWidth: 2.0)
            }
        }
    }

    private func drawBezierHandle(_ handlePoint: VectorPoint, anchor: CGPoint, context: inout GraphicsContext, zoom: CGFloat) {
        let handleLocation = CGPoint(x: handlePoint.x, y: handlePoint.y)

        // Draw line from anchor to handle
        var linePath = Path()
        linePath.move(to: anchor)
        linePath.addLine(to: handleLocation)
        context.stroke(linePath, with: .color(.blue), lineWidth: scaleForZoom(1.0, zoom: zoom) / zoom)

        // Draw handle circle
        let handleSize = scaleForZoom(6.0, zoom: zoom) / zoom
        let circle = Circle().path(in: CGRect(
            x: handleLocation.x - handleSize/2,
            y: handleLocation.y - handleSize/2,
            width: handleSize,
            height: handleSize
        ))
        context.fill(circle, with: .color(.blue))
    }
}
