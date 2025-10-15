import SwiftUI

extension DrawingCanvas {
    @ViewBuilder
    internal func fillClosePreview(geometry: GeometryProxy) -> some View {
        if showClosePathHint && bezierPoints.count >= 3,
           let currentBezierPath = bezierPath {
            let lastPointIndex = bezierPoints.count - 1
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            let lastPointHandles = bezierHandles[lastPointIndex]
            let firstPointHandles = bezierHandles[0]

            Path { path in
                addPathElements(currentBezierPath.elements, to: &path)

                let lastPoint = bezierPoints[lastPointIndex]
                let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)

                if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                    path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                } else if let lastControl2 = lastPointHandles?.control2 {
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                } else if let firstControl1 = firstPointHandles?.control1 {
                    let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                    path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
                } else {
                    path.addLine(to: firstPointLocation)
                }

                path.closeSubpath()
            }
            .fill(document.defaultFillColor.color.opacity(0.3))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }

    @ViewBuilder
    internal func rubberBandFillPreview(geometry: GeometryProxy) -> some View {
        if let mouseLocation = currentMouseLocation,
           let currentBezierPath = bezierPath,
           bezierPoints.count >= 2 {

            let rawCanvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let lastPoint = bezierPoints[lastPointIndex]
            let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            let canvasMouseLocation = isShiftPressed ?
                constrainToAngle(from: lastPointLocation, to: rawCanvasMouseLocation) :
                rawCanvasMouseLocation

            Path { path in
                addPathElements(currentBezierPath.elements, to: &path)

                if let lastPointHandles = bezierHandles[lastPointIndex],
                   let lastControl2 = lastPointHandles.control2 {
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    path.addCurve(
                        to: canvasMouseLocation,
                        control1: lastControl2Location,
                        control2: canvasMouseLocation
                    )
                } else {
                    path.addLine(to: canvasMouseLocation)
                }

                path.addLine(to: firstPointLocation)

                path.closeSubpath()
            }
            .fill(document.defaultFillColor.color.opacity(0.15))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }

    @ViewBuilder
    internal func rubberBandPreview(geometry: GeometryProxy) -> some View {
        if isBezierDrawing && document.currentTool == .bezierPen,
           let mouseLocation = currentMouseLocation,
           bezierPoints.count > 0 {
            let rawCanvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let lastPoint = bezierPoints[lastPointIndex]
            let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
            let canvasMouseLocation = isShiftPressed ?
                constrainToAngle(from: lastPointLocation, to: rawCanvasMouseLocation) :
                rawCanvasMouseLocation

            if isShiftPressed && bezierPoints.count >= 1 {
                if let snapPoint = findBestIntersectionPoint(from: lastPointLocation, toward: rawCanvasMouseLocation) {
                    Circle()
                        .fill(Color.purple.opacity(0.3))
                        .frame(width: 16 / document.zoomLevel, height: 16 / document.zoomLevel)
                        .overlay(
                            Circle()
                                .stroke(Color.purple, lineWidth: 2 / document.zoomLevel)
                        )
                        .position(
                            x: snapPoint.x * document.zoomLevel + document.canvasOffset.x,
                            y: snapPoint.y * document.zoomLevel + document.canvasOffset.y
                        )

                    Path { path in
                        path.move(to: lastPointLocation)
                        path.addLine(to: snapPoint)
                    }
                    .stroke(Color.purple.opacity(0.5), style: SwiftUI.StrokeStyle(
                        lineWidth: 1 / document.zoomLevel,
                        lineCap: .round,
                        dash: [4, 2]
                    ))
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

                    let firstPoint = bezierPoints[0]
                    let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                    Path { path in
                        path.move(to: snapPoint)
                        path.addLine(to: firstPointLocation)
                    }
                    .stroke(Color.purple.opacity(0.5), style: SwiftUI.StrokeStyle(
                        lineWidth: 1 / document.zoomLevel,
                        lineCap: .round,
                        dash: [4, 2]
                    ))
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                }
            }

            let strokeWidth = 2.0 / document.zoomLevel
            let rubberBandWidth = 1.0 / document.zoomLevel

            if bezierPoints.count >= 2 && !showClosePathHint {
                rubberBandFillPreview(geometry: geometry)
            }

            if showClosePathHint && bezierPoints.count >= 3 {
                fillClosePreview(geometry: geometry)
            }

            if showClosePathHint && bezierPoints.count >= 3 {
                let firstPoint = bezierPoints[0]
                let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                let lastPointHandles = bezierHandles[lastPointIndex]
                let firstPointHandles = bezierHandles[0]

                Path { path in
                    path.move(to: lastPointLocation)

                    if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                    } else if let lastControl2 = lastPointHandles?.control2 {
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                    } else if let firstControl1 = firstPointHandles?.control1 {
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
                    } else {
                        path.addLine(to: firstPointLocation)
                    }
                }
                .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            } else {
                Path { path in
                    path.move(to: lastPointLocation)

                    if let lastPointHandles = bezierHandles[lastPointIndex],
                       let lastControl2 = lastPointHandles.control2 {
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)

                        path.addCurve(
                            to: canvasMouseLocation,
                            control1: lastControl2Location,
                            control2: canvasMouseLocation
                        )

                    } else {
                        path.addLine(to: canvasMouseLocation)
                    }
                }
                .stroke(Color.blue.opacity(0.8), style: SwiftUI.StrokeStyle(lineWidth: rubberBandWidth, lineCap: .round, dash: [4, 2]))
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

            }
        }
    }

    @ViewBuilder
    internal func bezierClosePathHint() -> some View {
        if showClosePathHint {
            ZStack {
                Circle()
                    .stroke(Color.green, lineWidth: 2.0)
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 16, height: 16)
                    .position(CGPoint(
                        x: closePathHintLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: closePathHintLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))

                Image(systemName: "multiply.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12))
                    .position(CGPoint(
                        x: closePathHintLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: closePathHintLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))
            }
            .animation(.easeInOut(duration: 0.2), value: showClosePathHint)
        }
    }

    @ViewBuilder
    internal func bezierContinuePathHint() -> some View {
        if showContinuePathHint {
            ZStack {
                Circle()
                    .stroke(Color.blue, lineWidth: 2.0)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 16, height: 16)
                    .position(CGPoint(
                        x: continuePathHintLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: continuePathHintLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))

                Image(systemName: "arrow.right.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 12))
                    .position(CGPoint(
                        x: continuePathHintLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: continuePathHintLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))
            }
            .animation(.easeInOut(duration: 0.2), value: showContinuePathHint)
        }
    }

    @ViewBuilder
    internal func bezierControlHandles() -> some View {
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                if let handleInfo = bezierHandles[index], handleInfo.hasHandles {
                    let pointLocation = CGPoint(x: bezierPoints[index].x, y: bezierPoints[index].y)

                    if let control1 = handleInfo.control1 {
                        let control1Location = CGPoint(x: control1.x, y: control1.y)
                        Path { path in
                            path.move(to: pointLocation)
                            path.addLine(to: control1Location)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel)
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .position(CGPoint(
                                x: control1Location.x * document.zoomLevel + document.canvasOffset.x,
                                y: control1Location.y * document.zoomLevel + document.canvasOffset.y
                            ))
                    }

                    if let control2 = handleInfo.control2 {
                        let control2Location = CGPoint(x: control2.x, y: control2.y)
                        Path { path in
                            path.move(to: pointLocation)
                            path.addLine(to: control2Location)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel)
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

                        Circle()
                            .fill(Color.blue)
                            .frame(width: 6, height: 6)
                            .position(CGPoint(
                                x: control2Location.x * document.zoomLevel + document.canvasOffset.x,
                                y: control2Location.y * document.zoomLevel + document.canvasOffset.y
                            ))
                    }
                }
            }
        }
    }

    @ViewBuilder
    internal func bezierAnchorPoints() -> some View {
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                let point = bezierPoints[index]
                let pointLocation = CGPoint(x: point.x, y: point.y)
                let isActive = activeBezierPointIndex == index

                Rectangle()
                    .fill(isActive ? Color.black : Color.white)
                    .overlay(
                        Rectangle()
                            .stroke(isActive ? Color.white : Color.black, lineWidth: 1.0)
                    )
                    .frame(width: 8, height: 8)
                    .position(CGPoint(
                        x: pointLocation.x * document.zoomLevel + document.canvasOffset.x,
                        y: pointLocation.y * document.zoomLevel + document.canvasOffset.y
                    ))
            }
        }
    }

    private func constrainToAngle(from reference: CGPoint, to target: CGPoint) -> CGPoint {
        return GeometryUtils.constrainToAngle(from: reference, to: target, constraintAngles: constraintAngles)
    }
}
