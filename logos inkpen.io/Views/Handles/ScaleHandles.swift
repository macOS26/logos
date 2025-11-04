import SwiftUI
import Combine

struct ScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool
    @Binding var liveScaleTransform: CGAffineTransform
    @State var isScaling = false
    @State var scalingStarted = false
    @State var initialBounds: CGRect = .zero
    @State var initialTransform: CGAffineTransform = .identity
    @State var startLocation: CGPoint = .zero
    @State var previewTransform: CGAffineTransform = .identity
    @State var scalingAnchorPoint: CGPoint = .zero
    @State var finalMarqueeBounds: CGRect = .zero
    @State var isCapsLockPressed = false
    @State var lockedPinPointIndex: Int? = nil
    @State var pathPoints: [VectorPoint] = []
    @State var centerPoint: VectorPoint = VectorPoint(CGPoint.zero)
    @State var pointsRefreshTrigger: Int = 0
    let handleSize: CGFloat = 10

    private var calculatedBounds: CGRect {
        if ImageContentRegistry.containsImage(shape, in: document) {
            let pathBounds = shape.path.cgPath.boundingBoxOfPath
            return pathBounds.applying(shape.transform)
        } else {
            return shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }
    }

    private var calculatedCenter: CGPoint {
        return shape.calculateCentroid()
    }

    var body: some View {
        let bounds = calculatedBounds
        let center = calculatedCenter

        ZStack {
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                ForEach(shape.groupedShapes.indices, id: \.self) { index in
                    let groupedShape = shape.groupedShapes[index]
                    let cachedPath = Path { path in
                        for element in groupedShape.path.elements {
                            switch element {
                            case .move(let to):
                                path.move(to: to.cgPoint)
                            case .line(let to):
                                path.addLine(to: to.cgPoint)
                            case .curve(let to, let control1, let control2):
                                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
                            case .quadCurve(let to, let control):
                                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                    }
                    ZStack {
                        cachedPath
                            .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0], dashPhase: 2.0))
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                            .transformEffect(groupedShape.transform)
                        cachedPath
                            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0]))
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                            .transformEffect(groupedShape.transform)
                    }
                }
            } else {
                let cachedPath = Path { path in
                    for element in shape.path.elements {
                        switch element {
                        case .move(let to):
                            path.move(to: to.cgPoint)
                        case .line(let to):
                            path.addLine(to: to.cgPoint)
                        case .curve(let to, let control1, let control2):
                            path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
                        case .quadCurve(let to, let control):
                            path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
                        case .close:
                            path.closeSubpath()
                        }
                    }
                }
                ZStack {
                    cachedPath
                        .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0], dashPhase: 2.0))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(shape.transform)
                    cachedPath
                        .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0]))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(shape.transform)
                }
            }

            pathPointsView()

            if shape.isGroup && !shape.groupedShapes.isEmpty {
                Rectangle()
                    .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [3.0 / zoomLevel, 3.0 / zoomLevel]))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(center)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)

                ForEach(0..<4) { i in
                    let cornerPos = cornerPosition(for: i, in: bounds, center: center)
                    let cornerIndex = pathPoints.count + i
                    let isLockedPin = lockedPinPointIndex == cornerIndex

                    Circle()
                        .fill(isLockedPin ? Color.red : Color.green)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize)
                        .offset(
                            x: cornerPos.x * zoomLevel + canvasOffset.x - (handleSize) / 2,
                            y: cornerPos.y * zoomLevel + canvasOffset.y - (handleSize) / 2
                        )
                        .onTapGesture {
                            if !isScaling {
                                setLockedPinPoint(cornerIndex)
                            }
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    handleScalingFromPoint(draggedPointIndex: cornerIndex, dragValue: value, bounds: bounds, center: center)
                                }
                                .onEnded { _ in
                                    finishScaling()
                                }
                        )
                }
            }

            let isCenterLockedPin = (lockedPinPointIndex == nil)
            Circle()
                .fill(isCenterLockedPin ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: center.y * zoomLevel + canvasOffset.y
                ))
                .zIndex(100)
                .onTapGesture {
                    if !isScaling {
                        setLockedPinPoint(nil)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            if !scalingStarted {
                                scalingStarted = true
                                isScaling = true
                                document.isHandleScalingActive = true
                                initialBounds = bounds
                                initialTransform = shape.transform
                                startLocation = value.startLocation
                                scalingAnchorPoint = center
                            }

                            let translation = CGSize(
                                width: value.location.x - value.startLocation.x,
                                height: value.location.y - value.startLocation.y
                            )

                            let sensitivity: CGFloat = 0.005 / zoomLevel
                            var scaleX = 1.0 + (translation.width * sensitivity)
                            var scaleY = 1.0 + (translation.height * sensitivity)

                            scaleX = min(max(scaleX, 0.1), 10.0)
                            scaleY = min(max(scaleY, 0.1), 10.0)

                            if isShiftPressed {
                                let avgScale = (scaleX + scaleY) / 2.0
                                scaleX = avgScale
                                scaleY = avgScale
                            }

                            calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: center)
                        }
                        .onEnded { _ in
                            finishScaling()
                        }
                )

            if isScaling && !previewTransform.isIdentity {
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    ForEach(shape.groupedShapes.indices, id: \.self) { index in
                        let groupedShape = shape.groupedShapes[index]
                        Path { path in
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.move(to: transformedPoint)
                                case .line(let to):
                                    let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.addLine(to: transformedPoint)
                                case .curve(let to, let control1, let control2):
                                    let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                                    let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                                    path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                                case .quadCurve(let to, let control):
                                    let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                                    path.addQuadCurve(to: transformedTo, control: transformedControl)
                                case .close:
                                    path.closeSubpath()
                                }
                            }
                        }
                        .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .opacity(0.8)
                    }
                } else {
                    Path { path in
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.move(to: transformedPoint)
                            case .line(let to):
                                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.addLine(to: transformedPoint)
                            case .curve(let to, let control1, let control2):
                                let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                                path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                            case .quadCurve(let to, let control):
                                let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                                path.addQuadCurve(to: transformedTo, control: transformedControl)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                    }
                    .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .opacity(0.8)
                }

                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    let transformedBounds = bounds.applying(previewTransform)
                    let transformedCenter = CGPoint(x: transformedBounds.midX, y: transformedBounds.midY)

                    Rectangle()
                        .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: 1.5 / zoomLevel, dash: [3.0 / zoomLevel, 3.0 / zoomLevel]))
                        .frame(width: transformedBounds.width, height: transformedBounds.height)
                        .position(transformedCenter)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .opacity(0.6)
                }

            }
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            extractPathPoints()

            if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
                setLockedPinPoint(nil)
            }
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            if !isScaling && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
            }
        }
        .id("scale-handles-\(pointsRefreshTrigger)")
    }

    @State var keyEventMonitor: Any?
}
