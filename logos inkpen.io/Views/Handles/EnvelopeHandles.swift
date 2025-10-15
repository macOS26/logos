import SwiftUI
import SwiftUI
import Combine

struct EnvelopeHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint

    @State private var isWarping = false
    @State private var warpingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewPath: VectorPath? = nil
    @State private var isShiftPressed = false
    @State private var originalCorners: [CGPoint] = []
    @State private var warpedCorners: [CGPoint] = []
    @State private var draggingCornerIndex: Int? = nil

    private let handleSize: CGFloat = 10
    private let handleHitAreaSize: CGFloat = 15

    var body: some View {
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds

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
                    cachedPath
                        .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(groupedShape.transform)
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
                cachedPath
                    .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }

            envelopeCornerHandles()

            if document.currentTool == .warp && warpedCorners.count == 4 {
                envelopeGridPreview()
            }

            if previewPath != nil {
                warpedShapePreview()
            }
        }
        .onAppear {
            initialBounds = bounds
            initialTransform = shape.transform
            setupEnvelopeKeyEventMonitoring()
            initializeEnvelopeCorners()
        }
        .onDisappear {
            teardownEnvelopeKeyEventMonitoring()
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            if !isWarping && !warpingStarted && warpedCorners.isEmpty && oldBounds != newBounds {
                initializeEnvelopeCorners()
            }
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            if oldTool == .warp && newTool != .warp {
                if previewPath != nil {
                    commitEnvelopeWarp()
                }

            }

            if oldTool != .warp && newTool == .warp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }
            }
        }
        .onChange(of: document.selectedShapeIDs) { oldSelection, newSelection in
            if document.currentTool == .warp && oldSelection != newSelection {
                if previewPath != nil {
                    commitEnvelopeWarp()
                }

                previewPath = nil

                originalCorners.removeAll()
                warpedCorners.removeAll()

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }

            }
        }
        .onChange(of: shape.warpEnvelope) { _, newEnvelope in
            if document.currentTool == .warp && !newEnvelope.isEmpty && newEnvelope != warpedCorners {
                initializeEnvelopeCorners()
            }
        }
        .onChange(of: document.unifiedObjects) { _, _ in
            if document.currentTool == .warp && !isWarping {
                if let updatedShape = document.unifiedObjects.first(where: { obj in
                    if case .shape(let s) = obj.objectType {
                        return s.id == shape.id
                    }
                    return false
                }), case .shape(let s) = updatedShape.objectType {
                    if s.isWarpObject && !s.warpEnvelope.isEmpty {
                        warpedCorners = s.warpEnvelope
                    } else {
                        let bounds = s.bounds
                        let resetCorners = [
                            CGPoint(x: bounds.minX, y: bounds.minY),
                            CGPoint(x: bounds.maxX, y: bounds.minY),
                            CGPoint(x: bounds.maxX, y: bounds.maxY),
                            CGPoint(x: bounds.minX, y: bounds.maxY)
                        ]
                        warpedCorners = resetCorners
                        originalCorners = resetCorners
                        previewPath = nil
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func envelopeCornerHandles() -> some View {
        if warpedCorners.count == 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = warpedCorners[cornerIndex]

                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize + 2, height: handleSize + 2)

                    Circle()
                        .fill(Color.blue)
                        .frame(width: handleSize, height: handleSize)

                    Circle()
                        .fill(Color.clear)
                        .frame(width: handleHitAreaSize, height: handleHitAreaSize)
                        .contentShape(Circle())
                }
            .position(CGPoint(x: cornerPos.x * zoomLevel + canvasOffset.x,
                              y: cornerPos.y * zoomLevel + canvasOffset.y))
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleEnvelopeWarp(cornerIndex: cornerIndex, dragValue: value)
                    }
                    .onEnded { _ in
                        finishEnvelopeWarp()
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func envelopeGridPreview() -> some View {
        let gridLines = 4

        ForEach(0..<4) { row in
            let t = CGFloat(row) / CGFloat(gridLines - 1)
            Path { path in
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: 0.0, v: t
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: 1.0, v: t
                )
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .opacity(0.6)
        }

        ForEach(0..<4) { col in
            let u = CGFloat(col) / CGFloat(gridLines - 1)
            Path { path in
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 0.0
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 1.0
                )
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .opacity(0.6)
        }
    }

    @ViewBuilder
    private func warpedShapePreview() -> some View {
        if let warpedPath = previewPath {
            Path { path in
                for element in warpedPath.elements {
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
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .opacity(0.8)
        }
    }

    private func initializeEnvelopeCorners() {
        if shape.isWarpObject && !shape.warpEnvelope.isEmpty, let originalPath = shape.originalPath {
            let originalBounds = originalPath.cgPath.boundingBoxOfPath
            originalCorners = [
                CGPoint(x: originalBounds.minX, y: originalBounds.minY),
                CGPoint(x: originalBounds.maxX, y: originalBounds.minY),
                CGPoint(x: originalBounds.maxX, y: originalBounds.maxY),
                CGPoint(x: originalBounds.minX, y: originalBounds.maxY)
            ]
            warpedCorners = shape.warpEnvelope

            previewPath = shape.path

            return
        }

        if let storedCorners = document.warpEnvelopeCorners[shape.id], storedCorners.count == 4 {
            originalCorners = storedCorners
            warpedCorners = storedCorners
            return
        }

        if shape.path.elements.count <= 4 || shape.isGroup {
            let newOriginalCorners = calculateOrientedBoundingBox(for: shape)
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners

            if document.warpBounds[shape.id] == nil {
                let minX = newOriginalCorners.map { $0.x }.min() ?? 0
                let maxX = newOriginalCorners.map { $0.x }.max() ?? 0
                let minY = newOriginalCorners.map { $0.y }.min() ?? 0
                let maxY = newOriginalCorners.map { $0.y }.max() ?? 0
                let newBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                Log.warning("⚠️ INITIALIZING NEW WARP BOUNDS (4-point shape): \(newBounds)", category: .general)
                document.warpBounds[shape.id] = newBounds
                document.warpEnvelopeCorners[shape.id] = newOriginalCorners
            }
        } else {
            let bounds = shape.bounds
            let newOriginalCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners

            if document.warpBounds[shape.id] == nil {
                Log.warning("⚠️ INITIALIZING NEW WARP BOUNDS (regular shape): \(bounds)", category: .general)
                document.warpBounds[shape.id] = bounds
                document.warpEnvelopeCorners[shape.id] = newOriginalCorners
            }
        }

    }

    private func cornersHaveChangedSignificantly(from oldCorners: [CGPoint], to newCorners: [CGPoint]) -> Bool {
        guard oldCorners.count == 4 && newCorners.count == 4 else { return true }

        let threshold: CGFloat = 1.0
        for i in 0..<4 {
            let oldCorner = oldCorners[i]
            let newCorner = newCorners[i]
            if abs(oldCorner.x - newCorner.x) > threshold || abs(oldCorner.y - newCorner.y) > threshold {
                return true
            }
        }
        return false
    }

    private func handleEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        if !warpingStarted {
            startEnvelopeWarp(cornerIndex: cornerIndex, dragValue: dragValue)
        }

        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        let canvasLocation = CGPoint(
            x: (currentLocation.x - canvasOffset.x) / preciseZoom,
            y: (currentLocation.y - canvasOffset.y) / preciseZoom
        )

        warpedCorners[cornerIndex] = canvasLocation

        document.warpEnvelopeCorners[shape.id] = warpedCorners

        let minX = warpedCorners.map { $0.x }.min() ?? 0
        let maxX = warpedCorners.map { $0.x }.max() ?? 0
        let minY = warpedCorners.map { $0.y }.min() ?? 0
        let maxY = warpedCorners.map { $0.y }.max() ?? 0
        document.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)

        calculateEnvelopeWarpPreview()
    }

    private func startEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        warpingStarted = true
        isWarping = true
        document.isHandleScalingActive = true

        if shape.isWarpObject && originalCorners.count == 4 {
            let minX = min(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let maxX = max(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let minY = min(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            let maxY = max(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            initialBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        } else if shape.isWarpObject, let originalPath = shape.originalPath {
            initialBounds = originalPath.cgPath.boundingBoxOfPath
        } else {
            initialBounds = shape.bounds
        }

        initialTransform = shape.transform
        startLocation = dragValue.startLocation
        draggingCornerIndex = cornerIndex

        if warpedCorners.count == 4 {
            document.warpEnvelopeCorners[shape.id] = warpedCorners
            let minX = warpedCorners.map { $0.x }.min() ?? 0
            let maxX = warpedCorners.map { $0.x }.max() ?? 0
            let minY = warpedCorners.map { $0.y }.min() ?? 0
            let maxY = warpedCorners.map { $0.y }.max() ?? 0
            document.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }

    }

    private func calculateEnvelopeWarpPreview() {
        guard originalCorners.count == 4 && warpedCorners.count == 4 else { return }

        if shape.isWarpObject, let originalPath = shape.originalPath {
            let warpedElements = warpPathElements(originalPath.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: originalPath.isClosed)
        } else if shape.isGroup && !shape.groupedShapes.isEmpty {
            var allWarpedElements: [PathElement] = []

            for groupedShape in shape.groupedShapes {
                let warpedElements = warpPathElements(groupedShape.path.elements)
                allWarpedElements.append(contentsOf: warpedElements)

                if !allWarpedElements.isEmpty && groupedShape != shape.groupedShapes.last {
                }
            }

            previewPath = VectorPath(elements: allWarpedElements, isClosed: false)
        } else {
            let warpedElements = warpPathElements(shape.path.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: shape.path.isClosed)
        }

    }

    private func warpPathElements(_ elements: [PathElement]) -> [PathElement] {
        var warpedElements: [PathElement] = []

        for element in elements {
            switch element {
            case .move(let to):
                let warpedPoint = warpPoint(CGPoint(x: to.x, y: to.y))
                warpedElements.append(.move(to: VectorPoint(warpedPoint)))

            case .line(let to):
                let warpedPoint = warpPoint(CGPoint(x: to.x, y: to.y))
                warpedElements.append(.line(to: VectorPoint(warpedPoint)))

            case .curve(let to, let control1, let control2):
                let warpedTo = warpPoint(CGPoint(x: to.x, y: to.y))
                let warpedControl1 = warpPoint(CGPoint(x: control1.x, y: control1.y))
                let warpedControl2 = warpPoint(CGPoint(x: control2.x, y: control2.y))
                warpedElements.append(.curve(
                    to: VectorPoint(warpedTo),
                    control1: VectorPoint(warpedControl1),
                    control2: VectorPoint(warpedControl2)
                ))

            case .quadCurve(let to, let control):
                let warpedTo = warpPoint(CGPoint(x: to.x, y: to.y))
                let warpedControl = warpPoint(CGPoint(x: control.x, y: control.y))
                warpedElements.append(.quadCurve(
                    to: VectorPoint(warpedTo),
                    control: VectorPoint(warpedControl)
                ))

            case .close:
                warpedElements.append(.close)
            }
        }

        return warpedElements
    }

    private func warpPoint(_ point: CGPoint) -> CGPoint {
        guard originalCorners.count == 4 else {
            let bounds = initialBounds
            let u = (point.x - bounds.minX) / bounds.width
            let v = (point.y - bounds.minY) / bounds.height

            return bilinearInterpolation(
                topLeft: warpedCorners[0],
                topRight: warpedCorners[1],
                bottomLeft: warpedCorners[3],
                bottomRight: warpedCorners[2],
                u: u, v: v
            )
        }

        let (u, v) = inverseBilinearInterpolation(
            point: point,
            topLeft: originalCorners[0],
            topRight: originalCorners[1],
            bottomLeft: originalCorners[3],
            bottomRight: originalCorners[2]
        )

        return bilinearInterpolation(
            topLeft: warpedCorners[0],
            topRight: warpedCorners[1],
            bottomLeft: warpedCorners[3],
            bottomRight: warpedCorners[2],
            u: u, v: v
        )
    }

    private func bilinearInterpolation(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        let top = CGPoint(
            x: topLeft.x * (1 - u) + topRight.x * u,
            y: topLeft.y * (1 - u) + topRight.y * u
        )
        let bottom = CGPoint(
            x: bottomLeft.x * (1 - u) + bottomRight.x * u,
            y: bottomLeft.y * (1 - u) + bottomRight.y * u
        )

        return CGPoint(
            x: top.x * (1 - v) + bottom.x * v,
            y: top.y * (1 - v) + bottom.y * v
        )
    }

    private func inverseBilinearInterpolation(point: CGPoint, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> (u: CGFloat, v: CGFloat) {

        let rightVector = CGPoint(x: topRight.x - topLeft.x, y: topRight.y - topLeft.y)
        let downVector = CGPoint(x: bottomLeft.x - topLeft.x, y: bottomLeft.y - topLeft.y)
        let pointVector = CGPoint(x: point.x - topLeft.x, y: point.y - topLeft.y)
        let det = rightVector.x * downVector.y - rightVector.y * downVector.x

        if abs(det) < 1e-10 {
            let rightLength = sqrt(rightVector.x * rightVector.x + rightVector.y * rightVector.y)
            let downLength = sqrt(downVector.x * downVector.x + downVector.y * downVector.y)
            let u: CGFloat = rightLength > 0 ?
            (pointVector.x * rightVector.x + pointVector.y * rightVector.y) / (rightLength * rightLength) : 0
            let v: CGFloat = downLength > 0 ?
            (pointVector.x * downVector.x + pointVector.y * downVector.y) / (downLength * downLength) : 0

            return (u: max(0, min(1, u)), v: max(0, min(1, v)))
        }

        let u = (pointVector.x * downVector.y - pointVector.y * downVector.x) / det
        let v = (rightVector.x * pointVector.y - rightVector.y * pointVector.x) / det

        return (u: max(0, min(1, u)), v: max(0, min(1, v)))
    }

    private func finishEnvelopeWarp() {
        warpingStarted = false
        isWarping = false
        document.isHandleScalingActive = false
        draggingCornerIndex = nil

        var oldShapes: [UUID: VectorShape] = [:]
        if case .shape(let oldShape) = document.findObject(by: shape.id)?.objectType {
            oldShapes[shape.id] = oldShape
        }

        if warpedCorners.count == 4 {
            let minX = warpedCorners.map { $0.x }.min() ?? 0
            let maxX = warpedCorners.map { $0.x }.max() ?? 0
            let minY = warpedCorners.map { $0.y }.min() ?? 0
            let maxY = warpedCorners.map { $0.y }.max() ?? 0
            document.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            document.warpEnvelopeCorners[shape.id] = warpedCorners
        }

        updateShapeWithCurrentWarp()
        calculateEnvelopeWarpPreview()

        var newShapes: [UUID: VectorShape] = [:]
        if let warpedShape = document.findShape(by: shape.id) {
            newShapes[shape.id] = warpedShape
        }

        if !oldShapes.isEmpty && !newShapes.isEmpty {
            let command = ShapeModificationCommand(
                objectIDs: [shape.id],
                oldShapes: oldShapes,
                newShapes: newShapes
            )
            document.executeCommand(command)
        }
    }

    private func updateShapeWithCurrentWarp() {
        guard let unifiedObject = document.findObject(by: shape.id),
        let layerIndex = unifiedObject.layerIndex < document.layers.count ? unifiedObject.layerIndex : nil else { return }
        let shapes = document.getShapesForLayer(layerIndex)
        guard let shapeIndex = shapes.firstIndex(where: { $0.id == shape.id }) else { return }

        guard let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }

        if currentShape.isWarpObject {
            var updatedWarpObject = currentShape

            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                var warpedGroupedShapes: [VectorShape] = []

                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)
                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    warpedGrouped.updateBounds()
                    warpedGroupedShapes.append(warpedGrouped)
                }

                updatedWarpObject.groupedShapes = warpedGroupedShapes
            } else if let finalWarpedPath = previewPath {
                updatedWarpObject.path = finalWarpedPath
            }

            updatedWarpObject.warpEnvelope = warpedCorners
            updatedWarpObject.updateBounds()

            if let objectIndex = document.unifiedObjects.firstIndex(where: { obj in
                if case .shape(let shape) = obj.objectType {
                    return shape.id == updatedWarpObject.id
                }
                return false
            }) {
                document.unifiedObjects[objectIndex] = VectorObject(
                    shape: updatedWarpObject,
                    layerIndex: document.unifiedObjects[objectIndex].layerIndex,
                    orderID: document.unifiedObjects[objectIndex].orderID
                )
                document.syncShapeToLayer(updatedWarpObject, at: document.unifiedObjects[objectIndex].layerIndex)
            }
        } else {
            var warpObject = currentShape
            warpObject.id = UUID()
            warpObject.name = "Warped " + currentShape.name
            warpObject.isWarpObject = true
            warpObject.warpEnvelope = warpedCorners
            warpObject.transform = .identity

            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                warpObject.originalPath = nil

                var warpedGroupedShapes: [VectorShape] = []

                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)
                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    warpedGrouped.updateBounds()
                    warpedGroupedShapes.append(warpedGrouped)
                }

                warpObject.groupedShapes = warpedGroupedShapes
            } else if let finalWarpedPath = previewPath {
                warpObject.originalPath = currentShape.path
                warpObject.path = finalWarpedPath
            }

            warpObject.updateBounds()

            document.updateShapePathUnified(id: warpObject.id, path: warpObject.path)

        document.selectedObjectIDs.remove(currentShape.id)
        document.selectedObjectIDs.insert(warpObject.id)

        if let unifiedObjectIndex = document.unifiedObjects.firstIndex(where: { unifiedObject in
            if case .shape(let targetShape) = unifiedObject.objectType {
                return targetShape.id == currentShape.id
            }
            return false
        }) {
            document.unifiedObjects[unifiedObjectIndex] = VectorObject(
                shape: warpObject,
                layerIndex: unifiedObject.layerIndex,
                orderID: unifiedObject.orderID
            )
        } else {
            document.addShapeToUnifiedSystem(warpObject, layerIndex: layerIndex)
        }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                if let objectIndex = self.document.unifiedObjects.firstIndex(where: { obj in
                    if case .shape(let s) = obj.objectType {
                        return s.id == warpObject.id
                    }
                    return false
                }) {
                    if case .shape(var shape) = self.document.unifiedObjects[objectIndex].objectType {
                        let wasVisible = shape.isVisible
                        shape.isVisible = !wasVisible
                        self.document.unifiedObjects[objectIndex] = VectorObject(
                            shape: shape,
                            layerIndex: self.document.unifiedObjects[objectIndex].layerIndex,
                            orderID: self.document.unifiedObjects[objectIndex].orderID
                        )
                        shape.isVisible = wasVisible
                        self.document.unifiedObjects[objectIndex] = VectorObject(
                            shape: shape,
                            layerIndex: self.document.unifiedObjects[objectIndex].layerIndex,
                            orderID: self.document.unifiedObjects[objectIndex].orderID
                        )
                    }
                }
            }
        }
    }

    private func commitEnvelopeWarp() {
        if warpedCorners.count == 4 {
            let minX = warpedCorners.map { $0.x }.min() ?? 0
            let maxX = warpedCorners.map { $0.x }.max() ?? 0
            let minY = warpedCorners.map { $0.y }.min() ?? 0
            let maxY = warpedCorners.map { $0.y }.max() ?? 0
            document.warpBounds[shape.id] = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            document.warpEnvelopeCorners[shape.id] = warpedCorners
        }

    }

    @State private var envelopeKeyEventMonitor: Any?

    private func setupEnvelopeKeyEventMonitoring() {
    }

    private func teardownEnvelopeKeyEventMonitoring() {
        if let monitor = envelopeKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            envelopeKeyEventMonitor = nil
        }
    }
}
