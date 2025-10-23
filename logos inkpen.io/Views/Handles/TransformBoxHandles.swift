import SwiftUI
import AppKit
import SwiftUI
import Combine

struct TransformBoxHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool
    let transformOrigin: TransformOrigin
    var strokeColor: Color = Color.black.opacity(0.5)

    @State private var isScaling: Bool = false
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity

    private let handleSize: CGFloat = 10
    private let handleHitAreaSize: CGFloat = 10

    var body: some View {
        let transformedBounds: CGRect = computeTransformedBounds()
        let isKeylineMode = document.viewState.viewMode == .keyline
        let effectiveStrokeColor = isKeylineMode ? Color.clear : strokeColor

        ZStack {
            if shape.typography != nil {
                Rectangle()
                    .stroke(effectiveStrokeColor, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0]))
                    .frame(width: transformedBounds.width, height: transformedBounds.height)
                    .position(x: transformedBounds.midX, y: transformedBounds.midY)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .allowsHitTesting(false)
            } else {
                Path(transformedBounds)
                    .stroke(effectiveStrokeColor, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0, 2.0]))
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .allowsHitTesting(false)
            }

            if isScaling && !previewTransform.isIdentity {
                if shape.isGroupContainer {
                    ForEach(shape.groupedShapes.indices, id: \.self) { index in
                        let groupedShape = shape.groupedShapes[index]
                        Path { path in
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.move(to: p)
                                case .line(let to):
                                    let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.addLine(to: p)
                                case .curve(let to, let c1, let c2):
                                    let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let tc1 = CGPoint(x: c1.x, y: c1.y).applying(previewTransform)
                                    let tc2 = CGPoint(x: c2.x, y: c2.y).applying(previewTransform)
                                    path.addCurve(to: tp, control1: tc1, control2: tc2)
                                case .quadCurve(let to, let c):
                                    let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let tc = CGPoint(x: c.x, y: c.y).applying(previewTransform)
                                    path.addQuadCurve(to: tp, control: tc)
                                case .close:
                                    path.closeSubpath()
                                }
                            }
                        }
                        .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .allowsHitTesting(false)
                    }
                } else if shape.typography != nil {
                    if let originalPosition = shape.textPosition, let originalAreaSize = shape.areaSize {
                        let originalBounds = CGRect(x: originalPosition.x, y: originalPosition.y, width: originalAreaSize.width, height: originalAreaSize.height)
                        let transformedBounds = originalBounds.applying(previewTransform)

                        Rectangle()
                            .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                            .frame(width: transformedBounds.width, height: transformedBounds.height)
                            .position(x: transformedBounds.midX, y: transformedBounds.midY)
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                            .allowsHitTesting(false)
                    }
                } else {
                    Path { path in
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.move(to: p)
                            case .line(let to):
                                let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.addLine(to: p)
                            case .curve(let to, let c1, let c2):
                                let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let tc1 = CGPoint(x: c1.x, y: c1.y).applying(previewTransform)
                                let tc2 = CGPoint(x: c2.x, y: c2.y).applying(previewTransform)
                                path.addCurve(to: tp, control1: tc1, control2: tc2)
                            case .quadCurve(let to, let c):
                                let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let tc = CGPoint(x: c.x, y: c.y).applying(previewTransform)
                                path.addQuadCurve(to: tp, control: tc)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                    }
                    .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .allowsHitTesting(false)
                }
            }

            if !isKeylineMode {
                ForEach(0..<9) { index in
                    let pt = handlePosition(index: index, in: transformedBounds)
                    let isAnchorPoint = isHandleTheAnchor(index: index)
                    let isAdjacentToAnchor = isHandleAdjacentToAnchor(index: index)
                    let isDisabled = isAnchorPoint || isAdjacentToAnchor

                    ZStack {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: handleHitAreaSize, height: handleHitAreaSize)
                            .contentShape(Circle())
                            .allowsHitTesting(true)

                        Circle()
                            .fill(isAnchorPoint ? Color.red : (isDisabled ? Color.orange : Color.blue))
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.0))
                            .frame(width: handleSize, height: handleSize)
                            .allowsHitTesting(false)
                    }
                .position(
                    (shape.typography != nil || containsTextBoxInGroup()) ?
                    CGPoint(
                        x: (transformedBounds.midX + (pt.x - transformedBounds.midX)) * zoomLevel + canvasOffset.x,
                        y: (transformedBounds.midY + (pt.y - transformedBounds.midY)) * zoomLevel + canvasOffset.y
                    )
                    :
                    CGPoint(x: pt.x * zoomLevel + canvasOffset.x, y: pt.y * zoomLevel + canvasOffset.y)
                )
                .onTapGesture {
                    setAnchorPoint(forHandle: index)
                }
                .simultaneousGesture(
                    isDisabled ? nil :
                    DragGesture(minimumDistance: 0.5)
                        .onChanged { value in
                            if !isScaling {
                                beginScaling(startValue: value)
                            }
                            updateScaling(forHandle: index, dragValue: value, bounds: transformedBounds)
                        }
                        .onEnded { _ in
                            endScaling()
                        }
                )
                }
            }
        }
        .onAppear {
        initialTransform = .identity
    }
    }

    private func computeTransformedBounds() -> CGRect {
        let baseBounds: CGRect
        if shape.typography != nil, let areaSize = shape.areaSize, let textPosition = shape.textPosition {
            baseBounds = CGRect(x: textPosition.x, y: textPosition.y, width: areaSize.width, height: areaSize.height)
        } else {
            baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        }

        if shape.typography != nil {
            return baseBounds
        }

        var strokeExpandedBounds = baseBounds
        let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)
        if isStrokeOnly && shape.strokeStyle != nil {
            let strokeWidth = shape.strokeStyle?.width ?? 1.0
            let strokeExpansion = strokeWidth / 2.0
            strokeExpandedBounds = baseBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
        }

        let t = shape.transform

        if t.isIdentity {
            return strokeExpandedBounds
        }

        return strokeExpandedBounds.applying(t)
    }

    private func containsTextBoxInGroup() -> Bool {
        guard shape.isGroupContainer else { return false }
        return shape.groupedShapes.contains { $0.typography != nil }
    }

    private func handlePosition(index: Int, in rect: CGRect) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: rect.minX, y: rect.minY)
        case 1: return CGPoint(x: rect.midX, y: rect.minY)
        case 2: return CGPoint(x: rect.maxX, y: rect.minY)
        case 3: return CGPoint(x: rect.maxX, y: rect.midY)
        case 4: return CGPoint(x: rect.maxX, y: rect.maxY)
        case 5: return CGPoint(x: rect.midX, y: rect.maxY)
        case 6: return CGPoint(x: rect.minX, y: rect.maxY)
        case 7: return CGPoint(x: rect.minX, y: rect.midY)
        default: return CGPoint(x: rect.midX, y: rect.midY)
        }
    }

    private func isHandleTheAnchor(index: Int) -> Bool {
        let handleToOrigin: [TransformOrigin] = [
            .topLeft, .topCenter, .topRight,
            .middleRight, .bottomRight, .bottomCenter,
            .bottomLeft, .middleLeft, .center
        ]
        return index < handleToOrigin.count && handleToOrigin[index] == transformOrigin
    }

    private func isHandleAdjacentToAnchor(index: Int) -> Bool {
        switch transformOrigin {
        case .topLeft:      return index == 1 || index == 7
        case .topRight:     return index == 1 || index == 3
        case .bottomRight:  return index == 3 || index == 5
        case .bottomLeft:   return index == 5 || index == 7

        case .topCenter:    return index == 0 || index == 2
        case .middleRight:  return index == 2 || index == 4
        case .bottomCenter: return index == 4 || index == 6
        case .middleLeft:   return index == 0 || index == 6

        case .center:       return false
        }
    }

    private func getTransformAnchor(in rect: CGRect) -> CGPoint {
        let origin = transformOrigin.point
        return CGPoint(
            x: rect.minX + rect.width * origin.x,
            y: rect.minY + rect.height * origin.y
        )
    }

    private func setAnchorPoint(forHandle index: Int) {
        let handleToOrigin: [TransformOrigin] = [
            .topLeft, .topCenter, .topRight,
            .middleRight, .bottomRight, .bottomCenter,
            .bottomLeft, .middleLeft, .center
        ]

        if index < handleToOrigin.count {
            document.viewState.transformOrigin = handleToOrigin[index]
        }
    }

    private func beginScaling(startValue: DragGesture.Value) {
        isScaling = true
        startLocation = startValue.startLocation
        initialTransform = .identity
        document.isHandleScalingActive = true
    }

    private func updateScaling(forHandle index: Int, dragValue: DragGesture.Value, bounds: CGRect) {
        if index == 8 {
            let anchor = getTransformAnchor(in: bounds)
            let preciseZoom = CGFloat(zoomLevel)
            let dxCanvas = (dragValue.location.x - startLocation.x) / preciseZoom
            let dyCanvas = (dragValue.location.y - startLocation.y) / preciseZoom
            let denomX = max(20.0, bounds.width)
            let denomY = max(20.0, bounds.height)
            var sx = 1.0 + (dxCanvas / denomX)
            var sy = 1.0 + (dyCanvas / denomY)

            if isShiftPressed {
                let ux = dxCanvas / denomX
                let uy = dyCanvas / denomY
                let useX = abs(ux) >= abs(uy)
                let u = useX ? ux : uy
                sx = 1.0 + u
                sy = 1.0 + u
            }

            let maxScale: CGFloat = 10.0
            let minScale: CGFloat = 0.1
            sx = min(max(sx, minScale), maxScale)
            sy = min(max(sy, minScale), maxScale)

            let scaleTransform = CGAffineTransform.identity
                .translatedBy(x: anchor.x, y: anchor.y)
                .scaledBy(x: sx, y: sy)
                .translatedBy(x: -anchor.x, y: -anchor.y)

            previewTransform = scaleTransform
            document.isHandleScalingActive = true
            return
        }

        let anchor = getTransformAnchor(in: bounds)
        let anchorScreenX = anchor.x * zoomLevel + canvasOffset.x
        let anchorScreenY = anchor.y * zoomLevel + canvasOffset.y
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )

        let currentDistance = CGPoint(
            x: dragValue.location.x - anchorScreenX,
            y: dragValue.location.y - anchorScreenY
        )

        let baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let adaptiveMinDistanceX = min(20.0, max(2.0, abs(baseBounds.width) * 0.05))
        let adaptiveMinDistanceY = min(20.0, max(2.0, abs(baseBounds.height) * 0.05))
        let maxScale: CGFloat = 10.0
        let minScale: CGFloat = 0.1
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        let isCorner = [0,2,4,6].contains(index)
        let isTopBottom = [1,5].contains(index)
        let isLeftRight = [3,7].contains(index)

        if isCorner {
            scaleX = abs(startDistance.x) > adaptiveMinDistanceX ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
            scaleY = abs(startDistance.y) > adaptiveMinDistanceY ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
            if isShiftPressed {
                let uniformScale = max(scaleX, scaleY)
                scaleX = uniformScale
                scaleY = uniformScale
            }
        } else if isTopBottom {
            scaleY = abs(startDistance.y) > adaptiveMinDistanceY ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
        } else if isLeftRight {
            scaleX = abs(startDistance.x) > adaptiveMinDistanceX ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
        }

        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)

        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        previewTransform = scaleTransform
        document.isHandleScalingActive = true

        let currentBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let newBounds = currentBounds.applying(scaleTransform)
        document.viewState.scalePreviewDimensions = CGSize(width: newBounds.width, height: newBounds.height)
    }

    private func endScaling() {
        print("🟢 END SCALING for shape \(shape.id)")
        isScaling = false
        document.isHandleScalingActive = false
        document.viewState.scalePreviewDimensions = .zero

        guard let oldObj = document.snapshot.objects[shape.id] else {
            print("🔴 Cannot find shape \(shape.id) in snapshot.objects")
            return
        }
        let oldShape = oldObj.shape
        print("🟢 Found old shape in snapshot, transform: \(oldShape.transform)")

        if oldShape.typography != nil {
            print("🟢 Processing text box transform")
            // Text boxes: resize areaSize and textPosition
            let scaleX = sqrt(previewTransform.a * previewTransform.a + previewTransform.c * previewTransform.c)
            let scaleY = sqrt(previewTransform.b * previewTransform.b + previewTransform.d * previewTransform.d)

            if let originalAreaSize = oldShape.areaSize, let originalPosition = oldShape.textPosition {
                let newWidth = originalAreaSize.width * scaleX
                let newHeight = originalAreaSize.height * scaleY

                let originalBounds = CGRect(x: originalPosition.x, y: originalPosition.y, width: originalAreaSize.width, height: originalAreaSize.height)
                let transformedBounds = originalBounds.applying(previewTransform)
                let newPosition = CGPoint(x: transformedBounds.minX, y: transformedBounds.minY)

                document.updateTextAreaSizeInUnified(id: oldShape.id, areaSize: CGSize(width: newWidth, height: newHeight))
                document.updateTextBoundsInUnified(id: oldShape.id, bounds: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                document.updateTextPositionInUnified(id: oldShape.id, position: newPosition)
            }
        } else {
            print("🟢 Processing regular shape transform, previewTransform: \(previewTransform)")
            // Regular shapes: apply transform to path coordinates
            applyTransformToPath(shapeID: shape.id, transform: previewTransform)
            print("🟢 Applied transform to path")
        }
        previewTransform = .identity

        document.updateTransformPanelValues()

        guard let newObj = document.snapshot.objects[shape.id] else {
            print("🔴 Cannot find updated shape \(shape.id) in snapshot.objects")
            return
        }
        let newShape = newObj.shape
        print("🟢 Found new shape in snapshot, transform: \(newShape.transform)")

        print("🟢 Creating undo command")
        let command = ShapeModificationCommand(
            objectIDs: [shape.id],
            oldShapes: [shape.id: oldShape],
            newShapes: [shape.id: newShape]
        )
        document.executeCommand(command)
        print("🟢 Executed undo command")
    }

    private func applyTransformToPath(shapeID: UUID, transform: CGAffineTransform) {
        print("🔵 applyTransformToPath for \(shapeID), transform: \(transform)")
        let t = transform
        if t.isIdentity {
            print("🔵 Transform is identity, skipping")
            return
        }

        guard let targetObj = document.snapshot.objects[shapeID] else {
            print("🔴 Cannot find shape \(shapeID) in snapshot for path transform")
            return
        }
        let targetShape = targetObj.shape
        print("🔵 Found target shape in snapshot")

        if targetShape.typography != nil {
            print("🔵 Text object, skipping path transform")
            // Text objects don't use path transforms
            return
        }

        if targetShape.isGroupContainer {
            print("🔵 Group container, transforming grouped shapes")
            var updatedShape = targetShape
            var transformedGroupedShapes: [VectorShape] = []
            for var groupedShape in updatedShape.groupedShapes {
                var transformedElements: [PathElement] = []
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to):
                        transformedElements.append(.move(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                    case .line(let to):
                        transformedElements.append(.line(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                    case .curve(let to, let c1, let c2):
                        transformedElements.append(.curve(
                            to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                            control1: VectorPoint(CGPoint(x: c1.x, y: c1.y).applying(t)),
                            control2: VectorPoint(CGPoint(x: c2.x, y: c2.y).applying(t))
                        ))
                    case .quadCurve(let to, let c):
                        transformedElements.append(.quadCurve(
                            to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                            control: VectorPoint(CGPoint(x: c.x, y: c.y).applying(t))
                        ))
                    case .close:
                        transformedElements.append(.close)
                    }
                }
                groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.updateBounds()
                transformedGroupedShapes.append(groupedShape)
            }
            updatedShape.groupedShapes = transformedGroupedShapes
            updatedShape.transform = .identity

            let updatedObject = VectorObject(id: shapeID, layerIndex: targetObj.layerIndex, objectType: VectorObject.determineType(for: updatedShape))
            document.snapshot.objects[shapeID] = updatedObject
            print("🔵 Finished group transform")
        } else {
            print("🔵 Regular shape, transforming path elements")
            var transformedElements: [PathElement] = []
            for element in targetShape.path.elements {
                switch element {
                case .move(let to):
                    transformedElements.append(.move(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                case .line(let to):
                    transformedElements.append(.line(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
                case .curve(let to, let c1, let c2):
                    transformedElements.append(.curve(
                        to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                        control1: VectorPoint(CGPoint(x: c1.x, y: c1.y).applying(t)),
                        control2: VectorPoint(CGPoint(x: c2.x, y: c2.y).applying(t))
                    ))
                case .quadCurve(let to, let c):
                    transformedElements.append(.quadCurve(
                        to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                        control: VectorPoint(CGPoint(x: c.x, y: c.y).applying(t))
                    ))
                case .close:
                    transformedElements.append(.close)
                }
            }

            var updatedShape = targetShape
            updatedShape.path = VectorPath(elements: transformedElements, isClosed: targetShape.path.isClosed)
            updatedShape.transform = .identity
            updatedShape.updateBounds()

            print("🔵 Updating shape with new path, \(transformedElements.count) elements")
            let updatedObject = VectorObject(id: shapeID, layerIndex: targetObj.layerIndex, objectType: VectorObject.determineType(for: updatedShape))
            document.snapshot.objects[shapeID] = updatedObject
            print("🔵 Finished regular shape transform")
        }
    }
}
