import SwiftUI
import SwiftUI

struct ShearHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool

    @State private var isShearing = false
    @State private var shearStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var shearAnchorPoint: CGPoint = .zero
    @State private var isCapsLockPressed = false

    @State private var lockedPinPointIndex: Int? = nil
    @State private var pathPoints: [VectorPoint] = []
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero)
    @State private var pointsRefreshTrigger: Int = 0

    private let handleSize: CGFloat = 10

    private var calculatedBounds: CGRect {
        if ImageContentRegistry.containsImage(shape) && !shape.transform.isIdentity {
            let baseBounds = shape.bounds
            let t = shape.transform
            let corners = [
                CGPoint(x: baseBounds.minX, y: baseBounds.minY).applying(t),
                CGPoint(x: baseBounds.maxX, y: baseBounds.minY).applying(t),
                CGPoint(x: baseBounds.maxX, y: baseBounds.maxY).applying(t),
                CGPoint(x: baseBounds.minX, y: baseBounds.maxY).applying(t)
            ]
            let minX = corners.map { $0.x }.min() ?? baseBounds.minX
            let minY = corners.map { $0.y }.min() ?? baseBounds.minY
            let maxX = corners.map { $0.x }.max() ?? baseBounds.maxX
            let maxY = corners.map { $0.y }.max() ?? baseBounds.maxY
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        } else {
            return shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }
    }

    private var calculatedCenter: CGPoint {
        return shape.calculateCentroid()
    }

    var body: some View {

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

            let isCenterLockedPin = (lockedPinPointIndex == nil)
            let shapeCenter = shape.calculateCentroid()
            Circle()
                .fill(isCenterLockedPin ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: shapeCenter.x * zoomLevel + canvasOffset.x,
                    y: shapeCenter.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isShearing {
                        setLockedPinPoint(nil)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            let actualBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                            let actualCenter = shape.calculateCentroid()
                            handleShearingFromPoint(draggedPointIndex: nil, dragValue: value, bounds: actualBounds, center: actualCenter)
                        }
                        .onEnded { _ in
                            finishShear()
                        }
                )

            if isShearing && !previewTransform.isIdentity {
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

                let anchorScreenX = shearAnchorPoint.x * zoomLevel + canvasOffset.x
                let anchorScreenY = shearAnchorPoint.y * zoomLevel + canvasOffset.y
                let isCenterPinned = document.shearAnchor == .center
                Circle()
                    .fill(isCenterPinned ? Color.red : Color.green)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: anchorScreenX, y: anchorScreenY)
            }

        }
        .onAppear {
            initialBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
            initialTransform = shape.transform
            extractPathPoints()

            if lockedPinPointIndex == nil && shearAnchorPoint == .zero {
                setLockedPinPoint(nil)
            }
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            if !isShearing && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
            }
        }
        .id("shear-handles-\(pointsRefreshTrigger)")
    }

    private func calculatePreviewShear(shearX: CGFloat, shearY: CGFloat, anchor: CGPoint) {

        let baseShearTransform = CGAffineTransform(a: 1, b: shearY, c: shearX, d: 1, tx: 0, ty: 0)
        let sheared_anchor = anchor.applying(baseShearTransform)

        let compensationTranslation = CGAffineTransform(translationX: anchor.x - sheared_anchor.x, y: anchor.y - sheared_anchor.y)
        let pinPointShearTransform = baseShearTransform.concatenating(compensationTranslation)

        previewTransform = initialTransform.concatenating(pinPointShearTransform)

        isShearing = true

    }

    private func finishShear() {
        shearStarted = false
        isShearing = false
        document.isHandleScalingActive = false

        // Capture old shape for undo
        var oldShapes: [UUID: VectorShape] = [:]
        if case .shape(let oldShape) = document.findObject(by: shape.id)?.objectType {
            oldShapes[shape.id] = oldShape
        }

        if let unifiedObject = document.findObject(by: shape.id),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil {
        let shapes = document.getShapesForLayer(layerIndex)
        if let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) {

            if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                var updatedShape = currentShape
                updatedShape.transform = initialTransform
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
            }

            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)

            document.updateTransformPanelValues()

            // Capture new shape after transformation
            var newShapes: [UUID: VectorShape] = [:]
            if let transformedShape = document.findShape(by: shape.id) {
                newShapes[shape.id] = transformedShape
            }

            // Execute undo command
            if !oldShapes.isEmpty && !newShapes.isEmpty {
                let command = ShapeModificationCommand(
                    objectIDs: [shape.id],
                    oldShapes: oldShapes,
                    newShapes: newShapes
                )
                document.executeCommand(command)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterShear()
            }
        }
        } else {
            Log.error("❌ SHEAR FAILED: Could not find shape in unified objects system", category: .error)
        }

        previewTransform = .identity
    }

    private func extractPathPoints() {
        pathPoints.removeAll()

        if shape.isGroup && !shape.groupedShapes.isEmpty {
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue
                    }
                }
            }
        } else {
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue
                }
            }
        }

        let centroid = shape.calculateCentroid()
        centerPoint = VectorPoint(centroid)

    }

    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index

            Circle()
                .fill(isLockedPin ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0 / zoomLevel)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(CGPoint(x: point.x, y: point.y))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isShearing {
                        setLockedPinPoint(index)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            let actualBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                            let actualCenter = shape.calculateCentroid()
                            handleShearingFromPoint(draggedPointIndex: index, dragValue: value, bounds: actualBounds, center: actualCenter)
                        }
                        .onEnded { _ in
                            finishShear()
                        }
                )
        }
    }

    private func setLockedPinPoint(_ pointIndex: Int?) {
        lockedPinPointIndex = pointIndex

        if let index = pointIndex {
            if index < pathPoints.count {
                let point = pathPoints[index]
                shearAnchorPoint = CGPoint(x: point.x, y: point.y)
            } else {
                let bounds: CGRect
                if ImageContentRegistry.containsImage(shape) && !shape.transform.isIdentity {
                    let baseBounds = shape.bounds
                    let t = shape.transform
                    let corners = [
                        CGPoint(x: baseBounds.minX, y: baseBounds.minY).applying(t),
                        CGPoint(x: baseBounds.maxX, y: baseBounds.minY).applying(t),
                        CGPoint(x: baseBounds.maxX, y: baseBounds.maxY).applying(t),
                        CGPoint(x: baseBounds.minX, y: baseBounds.maxY).applying(t)
                    ]
                    let minX = corners.map { $0.x }.min() ?? baseBounds.minX
                    let minY = corners.map { $0.y }.min() ?? baseBounds.minY
                    let maxX = corners.map { $0.x }.max() ?? baseBounds.maxX
                    let maxY = corners.map { $0.y }.max() ?? baseBounds.maxY
                    bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                } else {
                    bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                }
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                shearAnchorPoint = center
            }
        } else {
            shearAnchorPoint = calculatedCenter
        }
    }

    private func handleShearingFromPoint(draggedPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !shearStarted {
            startShearingFromPoint(draggedPointIndex: draggedPointIndex, bounds: bounds, dragValue: dragValue)
        }

        if isCapsLockPressed && draggedPointIndex != lockedPinPointIndex {
        }

        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        let anchorScreenX = shearAnchorPoint.x * preciseZoom + canvasOffset.x
        let anchorScreenY = shearAnchorPoint.y * preciseZoom + canvasOffset.y
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )

        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )

        let sensitivity: CGFloat = 0.002
        let deltaX = currentDistance.x - startDistance.x
        let deltaY = currentDistance.y - startDistance.y
        let shearFactorX = deltaY * sensitivity
        let shearFactorY = deltaX * sensitivity
        var finalShearX = shearFactorX
        var finalShearY = shearFactorY

        if isShiftPressed {
            if abs(shearFactorX) > abs(shearFactorY) {
                finalShearY = 0
            } else {
                finalShearX = 0
            }
        } else {
        }

        calculatePreviewShear(shearX: finalShearX, shearY: finalShearY, anchor: shearAnchorPoint)
    }

    private func startShearingFromPoint(draggedPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        shearStarted = true
        isShearing = true
        document.isHandleScalingActive = true
        initialBounds = bounds
        initialTransform = shape.transform
        startLocation = dragValue.location
        // Undo will be handled in finishShear()

        if lockedPinPointIndex == nil && shearAnchorPoint == .zero {
            setLockedPinPoint(nil)
        }

    }

    private func updatePathPointsAfterShear() {
        pathPoints.removeAll()

        if shape.isGroup && !shape.groupedShapes.isEmpty {
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue
                    }
                }
            }
        } else {
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue
                }
            }
        }

        let newBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))

        pointsRefreshTrigger += 1

    }

    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }

    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        guard let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let currentTransform = transform ?? shape.transform

        if currentTransform.isIdentity {
            return
        }

        var transformedElements: [PathElement] = []

        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))

            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))

            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))

            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))

            case .close:
                transformedElements.append(.close)
            }
        }

        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        var updatedShape = shape
        updatedShape.path = transformedPath
        updatedShape.transform = .identity
        updatedShape.updateBounds()
        document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)

    }
}
