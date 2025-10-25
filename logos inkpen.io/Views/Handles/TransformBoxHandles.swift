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
    @Binding var liveScaleTransform: CGAffineTransform

    @State private var isScaling: Bool = false
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @ObservedObject private var settings = ApplicationSettings.shared

    private let handleSize: CGFloat = 10
    private let handleHitAreaSize: CGFloat = 10

    var body: some View {
        let transformedBounds: CGRect = computeTransformedBounds()
        let isKeylineMode = document.viewState.viewMode == .keyline

        ZStack {
            // Render transform box outline using Canvas (like direct selection)
            Canvas { context, size in
                let zoom = zoomLevel
                let offset = canvasOffset

                guard !isKeylineMode else { return }

                // Apply preview transform to bounds if scaling
                let displayBounds = (isScaling && !previewTransform.isIdentity)
                    ? transformedBounds.applying(previewTransform)
                    : transformedBounds

                // Convert bounds to screen coordinates
                let screenRect = CGRect(
                    x: displayBounds.origin.x * zoom + offset.x,
                    y: displayBounds.origin.y * zoom + offset.y,
                    width: displayBounds.width * zoom,
                    height: displayBounds.height * zoom
                )

                let path = Path(screenRect)
                context.stroke(path, with: .color(strokeColor), style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [2.0, 2.0]))
            }
            .allowsHitTesting(false)

            // Only show red preview lines if live preview is disabled
            if isScaling && !previewTransform.isIdentity && !settings.liveScalingPreview {
                // Check if this is multi-selection (Combined Selection)
                if shape.name == "Combined Selection" {
                    // Render preview for all selected objects
                    ForEach(Array(document.viewState.selectedObjectIDs), id: \.self) { objectID in
                        if let obj = document.snapshot.objects[objectID] {
                            let objShape = obj.shape

                            if objShape.typography != nil {
                                // Text object preview
                                if let originalPosition = objShape.textPosition, let originalAreaSize = objShape.areaSize {
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
                                // Regular shape preview - apply existing transform then preview
                                let combinedTransform = objShape.transform.concatenating(previewTransform)

                                Path { path in
                                    for element in objShape.path.elements {
                                        switch element {
                                        case .move(let to):
                                            let p = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                                            path.move(to: p)
                                        case .line(let to):
                                            let p = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                                            path.addLine(to: p)
                                        case .curve(let to, let c1, let c2):
                                            let tp = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                                            let tc1 = CGPoint(x: c1.x, y: c1.y).applying(combinedTransform)
                                            let tc2 = CGPoint(x: c2.x, y: c2.y).applying(combinedTransform)
                                            path.addCurve(to: tp, control1: tc1, control2: tc2)
                                        case .quadCurve(let to, let c):
                                            let tp = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                                            let tc = CGPoint(x: c.x, y: c.y).applying(combinedTransform)
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
                    }
                } else if shape.isGroupContainer {
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
                                // Apply shape transform first, then preview transform
                                let p = CGPoint(x: to.x, y: to.y).applying(shape.transform).applying(previewTransform)
                                path.move(to: p)
                            case .line(let to):
                                let p = CGPoint(x: to.x, y: to.y).applying(shape.transform).applying(previewTransform)
                                path.addLine(to: p)
                            case .curve(let to, let c1, let c2):
                                let tp = CGPoint(x: to.x, y: to.y).applying(shape.transform).applying(previewTransform)
                                let tc1 = CGPoint(x: c1.x, y: c1.y).applying(shape.transform).applying(previewTransform)
                                let tc2 = CGPoint(x: c2.x, y: c2.y).applying(shape.transform).applying(previewTransform)
                                path.addCurve(to: tp, control1: tc1, control2: tc2)
                            case .quadCurve(let to, let c):
                                let tp = CGPoint(x: to.x, y: to.y).applying(shape.transform).applying(previewTransform)
                                let tc = CGPoint(x: c.x, y: c.y).applying(shape.transform).applying(previewTransform)
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
                // Apply preview transform to bounds for handle positioning if scaling
                let displayBounds = (isScaling && !previewTransform.isIdentity)
                    ? transformedBounds.applying(previewTransform)
                    : transformedBounds

                ForEach(0..<9) { index in
                    let pt = handlePosition(index: index, in: displayBounds)
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
                        x: (displayBounds.midX + (pt.x - displayBounds.midX)) * zoomLevel + canvasOffset.x,
                        y: (displayBounds.midY + (pt.y - displayBounds.midY)) * zoomLevel + canvasOffset.y
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

        // Reset live scale transform when live preview is enabled
        if settings.liveScalingPreview {
            liveScaleTransform = .identity
        }
    }

    private func updateScaling(forHandle index: Int, dragValue: DragGesture.Value, bounds: CGRect) {
        if index == 8 {
            let anchor = getTransformAnchor(in: bounds)
            let preciseZoom = CGFloat(zoomLevel)
            let dxCanvas = (dragValue.location.x - startLocation.x) / preciseZoom
            let dyCanvas = (dragValue.location.y - startLocation.y) / preciseZoom
            let denomX = abs(bounds.width) > 0 ? bounds.width : 1.0
            let denomY = abs(bounds.height) > 0 ? bounds.height : 1.0
            var sx = 1.0 + (dxCanvas / denomX)
            var sy = 1.0 + (dyCanvas / denomY)

            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                let ux = dxCanvas / denomX
                let uy = dyCanvas / denomY
                let useX = abs(ux) >= abs(uy)
                let u = useX ? ux : uy
                sx = 1.0 + u
                sy = 1.0 + u
            }

            // No min/max constraints - allow free scaling

            let scaleTransform = CGAffineTransform.identity
                .translatedBy(x: anchor.x, y: anchor.y)
                .scaledBy(x: sx, y: sy)
                .translatedBy(x: -anchor.x, y: -anchor.y)

            previewTransform = scaleTransform
            document.isHandleScalingActive = true

            // Update live scale transform when live preview is enabled
            if settings.liveScalingPreview {
                liveScaleTransform = scaleTransform

                // Trigger layer updates for all selected objects
                var affectedLayers = Set<Int>()
                for objectID in document.viewState.selectedObjectIDs {
                    if let obj = document.snapshot.objects[objectID] {
                        affectedLayers.insert(obj.layerIndex)
                    }
                }
                document.triggerLayerUpdates(for: affectedLayers)
            }
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

        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        let isCorner = [0,2,4,6].contains(index)
        let isTopBottom = [1,5].contains(index)
        let isLeftRight = [3,7].contains(index)

        if isCorner {
            // Allow negative scale for flipping/mirroring
            scaleX = abs(startDistance.x) > 0 ? currentDistance.x / startDistance.x : 1.0
            scaleY = abs(startDistance.y) > 0 ? currentDistance.y / startDistance.y : 1.0
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                // For uniform scaling, use the one with larger absolute value but preserve sign
                let absScaleX = abs(scaleX)
                let absScaleY = abs(scaleY)
                let uniformScale = absScaleX >= absScaleY ? scaleX : scaleY
                scaleX = uniformScale
                scaleY = uniformScale
            }
        } else if isTopBottom {
            scaleY = abs(startDistance.y) > 0 ? currentDistance.y / startDistance.y : 1.0
        } else if isLeftRight {
            scaleX = abs(startDistance.x) > 0 ? currentDistance.x / startDistance.x : 1.0
        }

        // No min/max constraints - allow free scaling

        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        previewTransform = scaleTransform
        document.isHandleScalingActive = true

        // Update live scale transform when live preview is enabled
        if settings.liveScalingPreview {
            liveScaleTransform = scaleTransform

            // Trigger layer updates for all selected objects
            var affectedLayers = Set<Int>()
            for objectID in document.viewState.selectedObjectIDs {
                if let obj = document.snapshot.objects[objectID] {
                    affectedLayers.insert(obj.layerIndex)
                }
            }
            document.triggerLayerUpdates(for: affectedLayers)
        }

        let currentBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let newBounds = currentBounds.applying(scaleTransform)
        document.viewState.scalePreviewDimensions = CGSize(width: newBounds.width, height: newBounds.height)
    }

    private func endScaling() {
        print("🟢 END SCALING for shape \(shape.id)")
        isScaling = false
        document.isHandleScalingActive = false
        document.viewState.scalePreviewDimensions = .zero

        // Reset live scale transform
        if settings.liveScalingPreview {
            liveScaleTransform = .identity
        }

        // Check if this is multi-selection (virtual combined shape)
        if shape.name == "Combined Selection" {
            applyMultiSelectionScaling()
            previewTransform = .identity
            document.updateTransformPanelValues()
            return
        }

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
            updatedShape.updateBounds()

            // Update snapshot directly
            let updatedObject = VectorObject(shape: updatedShape, layerIndex: targetObj.layerIndex)
            document.snapshot.objects[shapeID] = updatedObject
            print("🔵 Updated snapshot with transformed group")
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

            let newPath = VectorPath(elements: transformedElements, isClosed: targetShape.path.isClosed)
            print("🔵 Updating shape with new path, \(transformedElements.count) elements")

            var updatedShape = targetShape
            updatedShape.path = newPath
            updatedShape.transform = .identity
            updatedShape.updateBounds()

            // Update snapshot directly
            let updatedObject = VectorObject(shape: updatedShape, layerIndex: targetObj.layerIndex)
            document.snapshot.objects[shapeID] = updatedObject
            print("🔵 Updated snapshot with transformed shape")
            print("🔵 Finished regular shape transform")
        }
    }

    private func applyMultiSelectionScaling() {
        print("🟣 MULTI-SELECTION SCALING")

        var oldShapes: [UUID: VectorShape] = [:]
        var newShapes: [UUID: VectorShape] = [:]
        var affectedLayers = Set<Int>()

        for objectID in document.viewState.selectedObjectIDs {
            guard let oldObj = document.snapshot.objects[objectID] else {
                print("🔴 Cannot find object \(objectID) in snapshot")
                continue
            }

            let oldShape = oldObj.shape
            oldShapes[objectID] = oldShape
            affectedLayers.insert(oldObj.layerIndex)

            if oldShape.typography != nil {
                // Text objects: transform areaSize and textPosition
                if let originalAreaSize = oldShape.areaSize, let originalPosition = oldShape.textPosition {
                    let originalBounds = CGRect(
                        x: originalPosition.x,
                        y: originalPosition.y,
                        width: originalAreaSize.width,
                        height: originalAreaSize.height
                    )
                    let transformedBounds = originalBounds.applying(previewTransform)

                    let newWidth = transformedBounds.width
                    let newHeight = transformedBounds.height
                    let newPosition = CGPoint(x: transformedBounds.minX, y: transformedBounds.minY)

                    document.updateTextAreaSizeInUnified(id: oldShape.id, areaSize: CGSize(width: newWidth, height: newHeight))
                    document.updateTextBoundsInUnified(id: oldShape.id, bounds: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
                    document.updateTextPositionInUnified(id: oldShape.id, position: newPosition)
                }
            } else {
                // Regular shapes: apply existing transform first, then preview transform
                let combinedTransform = oldShape.transform.concatenating(previewTransform)

                // Apply combined transform to path
                if oldShape.isGroupContainer {
                    var updatedShape = oldShape
                    var transformedGroupedShapes: [VectorShape] = []
                    for var groupedShape in updatedShape.groupedShapes {
                        var transformedElements: [PathElement] = []
                        for element in groupedShape.path.elements {
                            switch element {
                            case .move(let to):
                                let p = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                                transformedElements.append(.move(to: VectorPoint(p)))
                            case .line(let to):
                                let p = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                                transformedElements.append(.line(to: VectorPoint(p)))
                            case .curve(let to, let c1, let c2):
                                transformedElements.append(.curve(
                                    to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(combinedTransform)),
                                    control1: VectorPoint(CGPoint(x: c1.x, y: c1.y).applying(combinedTransform)),
                                    control2: VectorPoint(CGPoint(x: c2.x, y: c2.y).applying(combinedTransform))
                                ))
                            case .quadCurve(let to, let c):
                                transformedElements.append(.quadCurve(
                                    to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(combinedTransform)),
                                    control: VectorPoint(CGPoint(x: c.x, y: c.y).applying(combinedTransform))
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
                    updatedShape.updateBounds()

                    let updatedObject = VectorObject(shape: updatedShape, layerIndex: oldObj.layerIndex)
                    document.snapshot.objects[objectID] = updatedObject
                } else {
                    var transformedElements: [PathElement] = []
                    for element in oldShape.path.elements {
                        switch element {
                        case .move(let to):
                            let p = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                            transformedElements.append(.move(to: VectorPoint(p)))
                        case .line(let to):
                            let p = CGPoint(x: to.x, y: to.y).applying(combinedTransform)
                            transformedElements.append(.line(to: VectorPoint(p)))
                        case .curve(let to, let c1, let c2):
                            transformedElements.append(.curve(
                                to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(combinedTransform)),
                                control1: VectorPoint(CGPoint(x: c1.x, y: c1.y).applying(combinedTransform)),
                                control2: VectorPoint(CGPoint(x: c2.x, y: c2.y).applying(combinedTransform))
                            ))
                        case .quadCurve(let to, let c):
                            transformedElements.append(.quadCurve(
                                to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(combinedTransform)),
                                control: VectorPoint(CGPoint(x: c.x, y: c.y).applying(combinedTransform))
                            ))
                        case .close:
                            transformedElements.append(.close)
                        }
                    }

                    let newPath = VectorPath(elements: transformedElements, isClosed: oldShape.path.isClosed)
                    var updatedShape = oldShape
                    updatedShape.path = newPath
                    updatedShape.transform = .identity
                    updatedShape.updateBounds()

                    let updatedObject = VectorObject(shape: updatedShape, layerIndex: oldObj.layerIndex)
                    document.snapshot.objects[objectID] = updatedObject
                }
            }

            // Get the updated shape for undo
            if let updatedObj = document.snapshot.objects[objectID] {
                newShapes[objectID] = updatedObj.shape
            }
        }

        // Create undo command for all modified objects
        let command = ShapeModificationCommand(
            objectIDs: Array(document.viewState.selectedObjectIDs),
            oldShapes: oldShapes,
            newShapes: newShapes
        )
        document.executeCommand(command)

        // Trigger layer updates
        document.triggerLayerUpdates(for: affectedLayers)

        print("🟣 Completed multi-selection scaling for \(document.viewState.selectedObjectIDs.count) objects")
    }
}
