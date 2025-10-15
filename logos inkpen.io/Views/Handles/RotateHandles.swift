import SwiftUI
import SwiftUI
import Combine

struct RotateHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool

    @State private var isRotating = false
    @State private var rotationStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var rotationAnchorPoint: CGPoint = .zero
    @State private var startAngle: CGFloat = 0.0
    @State private var finalMarqueeBounds: CGRect = .zero

    @State private var selectedAnchorPointIndex: Int? = nil
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
        let bounds = calculatedBounds
        let center = calculatedCenter

        ZStack {
            ZStack {
                Path { path in
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
                .stroke(Color.white, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0], dashPhase: 2.0))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)

                Path { path in
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
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
            }

            if isRotating && !previewTransform.isIdentity {
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

            pathPointsView()

            let isCenterSelected = selectedAnchorPointIndex == nil
            Circle()
                .fill(isCenterSelected ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: center.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = nil
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: nil, dragValue: value, bounds: bounds, center: center)
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            setupRotationKeyEventMonitoring()
            extractPathPoints()
        }
        .onDisappear {
            teardownRotationKeyEventMonitoring()
        }
        .id("rotation-handles-\(pointsRefreshTrigger)")
    }

    private func extractPathPoints() {
        pathPoints.removeAll()

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

        centerPoint = VectorPoint(shape.calculateCentroid())

    }

    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isSelected = selectedAnchorPointIndex == index

            let transformedPoint = CGPoint(x: point.x, y: point.y).applying(shape.transform)
            Circle()
                .fill(isSelected ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: transformedPoint.x * zoomLevel + canvasOffset.x,
                    y: transformedPoint.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = index
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
    }

    private func handlePointRotation(anchorPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !rotationStarted {
            startPointRotation(anchorPointIndex: anchorPointIndex, bounds: bounds, dragValue: dragValue)
        }

        let currentLocation = dragValue.location

        let anchorScreenX = rotationAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = rotationAnchorPoint.y * zoomLevel + canvasOffset.y
        let rotationCenter = CGPoint(x: anchorScreenX, y: anchorScreenY)

        let currentVector = CGPoint(x: currentLocation.x - rotationCenter.x, y: currentLocation.y - rotationCenter.y)
        let startVector = CGPoint(x: startLocation.x - rotationCenter.x, y: startLocation.y - rotationCenter.y)

        let currentAngle = atan2(currentVector.y, currentVector.x)
        let initialAngle = atan2(startVector.y, startVector.x)
        var rotationAngle = currentAngle - initialAngle

        if isShiftPressed {
            let increment: CGFloat = .pi / 12
            rotationAngle = round(rotationAngle / increment) * increment
        }

        calculatePreviewRotation(angle: rotationAngle, anchor: rotationAnchorPoint)
    }

    private func startPointRotation(anchorPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        // Undo will be handled in finishRotation()

        selectedAnchorPointIndex = anchorPointIndex

        if let pointIndex = anchorPointIndex {
            let point = pathPoints[pointIndex]
            rotationAnchorPoint = CGPoint(x: point.x, y: point.y)
        } else {
            rotationAnchorPoint = shape.calculateCentroid()
        }

    }

    private func updatePathPointsAfterRotation() {
        pathPoints.removeAll()

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

        centerPoint = VectorPoint(shape.calculateCentroid())

        pointsRefreshTrigger += 1

    }

    private func getRotationAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }

    private func isRotationPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.rotationAnchor {
        case .center:
            return false
        case .topLeft:
            return cornerIndex == 0
        case .topRight:
            return cornerIndex == 1
        case .bottomRight:
            return cornerIndex == 2
        case .bottomLeft:
            return cornerIndex == 3
        }
    }

    private func getRotationAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }

    private func rotationCornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }

    private func applyRotationTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
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

        guard let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }

        if !currentShape.cornerRadii.isEmpty && currentShape.isRoundedRectangle {
            var updatedShape = currentShape
            updatedShape.path = transformedPath
            updatedShape.transform = .identity
            applyTransformToCornerRadiiLocal(shape: &updatedShape, transform: currentTransform)

            document.updateShapeCornerRadiiInUnified(id: updatedShape.id, cornerRadii: updatedShape.cornerRadii, path: updatedShape.path)
        } else {
            document.updateShapeTransformAndPathInUnified(id: currentShape.id, path: transformedPath, transform: .identity)
        }

    }

    @State private var rotationKeyEventMonitor: Any?

    private func setupRotationKeyEventMonitoring() {
    }

    private func teardownRotationKeyEventMonitoring() {
        if let monitor = rotationKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            rotationKeyEventMonitor = nil
        }
    }

    private func startRotation(cornerIndex: Int, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        // Undo will be handled in finishRotation()

        let originalBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        rotationAnchorPoint = getRotationAnchorPoint(for: document.rotationAnchor, in: originalBounds, cornerIndex: cornerIndex)
    }

    private func calculatePreviewRotation(angle: CGFloat, anchor: CGPoint) {
        let rotationTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .rotated(by: angle)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        previewTransform = initialTransform.concatenating(rotationTransform)

        isRotating = true
    }

    private func finishRotation() {
        rotationStarted = false
        isRotating = false
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

            applyRotationTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)

            previewTransform = .identity
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
                self.updatePathPointsAfterRotation()
            }
        }
        } else {
            Log.error("❌ ROTATION FAILED: Could not find shape in unified objects system", category: .error)
        }

        previewTransform = .identity
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

    private func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.rotationAnchor {
        case .center: return false
        case .topLeft: return cornerIndex == 0
        case .topRight: return cornerIndex == 1
        case .bottomRight: return cornerIndex == 2
        case .bottomLeft: return cornerIndex == 3
        }
    }

    private func getAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }

    private func getAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center: return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft: return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft: return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight: return CGPoint(x: bounds.maxX, y: bounds.maxY)
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

    private func applyTransformToCornerRadiiLocal(shape: inout VectorShape, transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }

        let scaleX = sqrt(transform.a * transform.a + transform.c * transform.c)
        let scaleY = sqrt(transform.b * transform.b + transform.d * transform.d)

        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0

        if scaleRatio > maxReasonableRatio {
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            return
        }

        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0

            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius)
            }
        }
    }
}
