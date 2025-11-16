import SwiftUI
import AppKit

extension DrawingCanvas {

    internal func handleDoubleClick(at location: CGPoint, geometry: GeometryProxy) {

        let canvasLocation = screenToCanvas(location, geometry: geometry)

        if let textID = findTextAt(location: canvasLocation) {
            document.viewState.currentTool = .font

            startEditingText(textID: textID, at: canvasLocation)

            isTextEditingMode = true
            NSCursor.iBeam.set()
        }
    }

    internal func handleUnifiedTap(at location: CGPoint, geometry: GeometryProxy) {
        // Update modifier key states at tap time
        let modifierFlags = NSEvent.modifierFlags
        isShiftPressed = modifierFlags.contains(.shift)
        isOptionPressed = modifierFlags.contains(.option)
        isCommandPressed = modifierFlags.contains(.command)
        isControlPressed = modifierFlags.contains(.control)

        let canvasLocation = screenToCanvas(location, geometry: geometry)
        let currentTime = Date()
        let timeSinceLastClick = currentTime.timeIntervalSince(lastClickTime)
        let distanceFromLastClick = distance(location, lastClickLocation)
        let isDoubleClick = timeSinceLastClick < doubleClickTimeout && distanceFromLastClick < 10.0

        lastClickTime = currentTime
        lastClickLocation = location

        if isDoubleClick {
            handleDoubleClick(at: location, geometry: geometry)
            return
        }

        if document.viewState.currentTool != .bezierPen && isBezierDrawing {
            cancelBezierDrawing()
        }

        switch document.viewState.currentTool {
        case .selection, .scale, .rotate, .shear, .warp:
            handleSelectionTap(at: canvasLocation)

        case .directSelection:
            handleDirectSelectionTap(at: canvasLocation)

        case .convertAnchorPoint:
            handleConvertAnchorPointTap(at: canvasLocation)

        case .penPlusMinus:
            handlePenPlusMinusTap(at: canvasLocation)

        case .bezierPen:
            handleBezierPenTap(at: canvasLocation)

        case .font:
            // print("🟢 Font tool tap at \(canvasLocation)")
            // Same pattern as square tool - clear selection if no modifiers
            if !isShiftPressed && !isCommandPressed {
                // print("🟢 No modifiers pressed, checking for text...")
                if let existingTextID = findTextAt(location: canvasLocation) {
                    // print("🟢 Found text at location: \(existingTextID)")
                    startEditingText(textID: existingTextID, at: canvasLocation)
                } else {
                    // print("🟢 No text found at location, clearing selection")
                    // Click on empty canvas - deselect all text
                    document.viewState.selectedObjectIDs = []
                    handleAggressiveBackgroundTap(at: canvasLocation)
                }
            } else {
                // print("🟢 Modifiers pressed: shift=\(isShiftPressed), command=\(isCommandPressed)")
            }

        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            if !isShiftPressed && !isCommandPressed {
                document.viewState.selectedObjectIDs = []
            }

        case .zoom:
            MagnifyingGlassCursor.set()
            let focalPoint = location
            let currentZoom = CGFloat(zoomLevel)
            let targetZoom: CGFloat
            if isOptionPressed {
                targetZoom = nextAllowedStepDown(from: currentZoom)
            } else {
                targetZoom = nextAllowedStepUp(from: currentZoom)
            }
            handleZoomAtPoint(newZoomLevel: targetZoom, focalPoint: focalPoint, geometry: geometry)
            if isCanvasHovering && document.viewState.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            DispatchQueue.main.async {
                if isCanvasHovering && document.viewState.currentTool == .zoom {
                    MagnifyingGlassCursor.set()
                }
            }

        case .eyedropper:
            startEyedropperColorPick()

        case .selectSameColor:
            selectSameColorAt(canvasLocation)

        default:
            break
        }
    }

    internal func handleUnifiedDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        switch document.viewState.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)

        case .zoom:
            if zoomToolDragStartPoint == .zero {
                zoomToolDragStartPoint = value.startLocation
                zoomToolInitialZoomLevel = zoomLevel
                isActivelyZooming = true
            }
            MagnifyingGlassCursor.set()
            let deltaY = value.location.y - zoomToolDragStartPoint.y
            let sensitivity: CGFloat = 300.0
            var scaleChange = exp(-deltaY / sensitivity)
            if isOptionPressed { scaleChange = 1.0 / scaleChange }
            let continuousZoom = max(0.1, min(16.0, zoomToolInitialZoomLevel * scaleChange))
            handleZoomAtPoint(newZoomLevel: continuousZoom, focalPoint: value.startLocation, geometry: geometry, isLive: true)

        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            handleShapeDrawing(value: value, geometry: geometry)

        case .font:
            handleTextBoxDrawing(value: value, geometry: geometry)

        case .selection:
            handleUnifiedSelectionDrag(value: value, geometry: geometry)

        case .directSelection:
            handleDirectSelectionDrag(value: value, geometry: geometry)

        case .bezierPen:
            handleBezierPenDrag(value: value, geometry: geometry)

        case .freehand:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isFreehandDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleFreehandDragStart(at: startLocation)
            }
            handleFreehandDragUpdate(at: currentLocation)

        case .brush:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isBrushDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleBrushDragStart(at: startLocation)
            }
            handleBrushDragUpdate(at: currentLocation)

        case .marker:
            break

        case .scale, .rotate, .shear, .warp:
            break

        default:
            break
        }
    }

    internal func handleUnifiedDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {

        switch document.viewState.currentTool {
        case .hand:
            finishPanGesture()

        case .zoom:
            // Bake deltas into real zoom/pan values
            if isActivelyZooming {
                let finalZoom = zoomLevel * liveZoomDelta
                let finalOffset = CGPoint(
                    x: canvasOffset.x + livePanDelta.x,
                    y: canvasOffset.y + livePanDelta.y
                )
                zoomLevel = finalZoom
                canvasOffset = finalOffset

                // Reset deltas
                liveZoomDelta = 1.0
                livePanDelta = .zero
                isActivelyZooming = false
            }
            zoomToolDragStartPoint = .zero
            zoomToolInitialZoomLevel = zoomLevel

        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            finishShapeDrawing(value: value, geometry: geometry)
            resetShapeDrawingState()

        case .font:
            finishTextBoxDrawing(value: value, geometry: geometry)
            resetTextBoxDrawingState()

        case .selection:
            finishSelectionDrag()
            isDrawing = false
            if document.isHandleScalingActive {
                document.isHandleScalingActive = false
            }

        case .directSelection:
            finishDirectSelectionDrag()

        case .bezierPen:
            finishBezierPenDrag()

        case .freehand:
            handleFreehandDragEnd()

        case .brush:
            handleBrushDragEnd()

        case .marker:
            break

        default:
            break
        }
    }

    private func handleUnifiedSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        if !isDrawing && !document.isHandleScalingActive {
            for objectID in document.viewState.selectedObjectIDs {
                if let vectorObject = document.findObject(by: objectID),
                   case .shape(let shape) = vectorObject.objectType {
                    if shape.name != "Canvas Background" && shape.name != "Pasteboard Background" {
                    }
                }
            }
        }

        if document.isHandleScalingActive {
            return
        }
        if isCornerRadiusEditMode {
            return
        }

        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)

        if !isDrawing {
            // DON'T re-read NSEvent.modifierFlags here - it's unreliable in SwiftUI gesture handlers
            // Trust the values set during the tap gesture in handleUnifiedTap

            // Don't change selection if shift-clicking to add to selection
            let shouldPreserveSelection = isShiftPressed || isCommandPressed

            if document.viewState.selectedObjectIDs.isEmpty || !isDraggingSelectedObject(at: startLocation) {
                // Only call selectObjectAt if not preserving selection, or if selection is empty
                if !shouldPreserveSelection || document.viewState.selectedObjectIDs.isEmpty {
                    selectObjectAt(startLocation)
                }
            }

            if !document.viewState.selectedObjectIDs.isEmpty {
                selectionDragStart = value.startLocation
                startSelectionDrag()
                isDrawing = true
            }
        }

        if isDrawing {
            handleSelectionDrag(value: value, geometry: geometry)
        }
    }

    private func finishPanGesture() {
        initialCanvasOffset = CGPoint.zero
        handToolDragStart = CGPoint.zero
        isPanGestureActive = false

        if isCanvasHovering && document.viewState.currentTool == .hand {
            NSCursor.openHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }

    private func resetShapeDrawingState() {
        isDrawing = false
        currentPath = nil
        tempBoundingBoxPath = nil
        currentDrawingPoints.removeAll()
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
    }

    private func startEyedropperColorPick() {
        let sampler = NSColorSampler()
        sampler.show { pickedColor in
            guard let nsColor = pickedColor?.usingColorSpace(.displayP3) else { return }
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            let rgb = RGBColor(red: Double(r), green: Double(g), blue: Double(b), alpha: Double(a))
            let vectorColor = VectorColor.rgb(rgb)
            document.setActiveColor(vectorColor)
        }
    }

    private func selectSameColorAt(_ location: CGPoint) {
        var tappedObject: VectorObject?
        var tappedShape: VectorShape?

        // O(1) iteration: layers from top to bottom
        for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
            let layer = document.snapshot.layers[layerIndex]

            // Check layer visibility/lock using legacy layers array
            if layerIndex < document.snapshot.layers.count {
                let legacyLayer = document.snapshot.layers[layerIndex]
                if !legacyLayer.isVisible || legacyLayer.isLocked {
                    continue
                }
            }

            // Iterate objects from top to bottom
            for objectID in layer.objectIDs.reversed() {
                guard let object = document.snapshot.objects[objectID] else { continue }

                if case .shape(let shape) = object.objectType {
                    if !shape.isVisible { continue }

                    if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                        continue
                    }

                    let transformedBounds = shape.bounds.applying(shape.transform)
                    if transformedBounds.contains(location) {
                        tappedObject = object
                        tappedShape = shape
                        break
                    }
                }
            }

            if tappedObject != nil {
                break
            }
        }

        guard let _ = tappedObject, let tappedShape = tappedShape else {
            return
        }

        let targetColor: VectorColor?

        if let fillColor = tappedShape.fillStyle?.color {
            targetColor = fillColor
        } else if let strokeColor = tappedShape.strokeStyle?.color {
            targetColor = strokeColor
        } else {
            return
        }

        guard let colorToMatch = targetColor else { return }

        var matchingObjectIDs = Set<UUID>()

        // O(1) iteration: through all layers
        for layerIndex in 0..<document.snapshot.layers.count {
            let layer = document.snapshot.layers[layerIndex]

            // Check layer visibility/lock using legacy layers array
            if layerIndex < document.snapshot.layers.count {
                let legacyLayer = document.snapshot.layers[layerIndex]
                if !legacyLayer.isVisible || legacyLayer.isLocked {
                    continue
                }
            }

            // Check all objects in layer
            for objectID in layer.objectIDs {
                guard let object = document.snapshot.objects[objectID] else { continue }

                if case .shape(let shape) = object.objectType {
                    if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                        continue
                    }

                    let hasFillMatch = shape.fillStyle?.color == colorToMatch
                    let hasStrokeMatch = shape.strokeStyle?.color == colorToMatch

                    if hasFillMatch || hasStrokeMatch {
                        matchingObjectIDs.insert(object.id)
                    }
                }
            }
        }

        if !matchingObjectIDs.isEmpty {
            document.viewState.selectedObjectIDs = matchingObjectIDs
        }
    }

    private func validateCanvasLocation(_ location: CGPoint) -> CGPoint {
        if location.x.isNaN || location.y.isNaN || location.x.isInfinite || location.y.isInfinite {
            Log.error("❌ INVALID CANVAS COORDINATES: \(location) - using zero point", category: .error)
            return .zero
        }

        let maxReasonableValue: CGFloat = 1000000.0
        if abs(location.x) > maxReasonableValue || abs(location.y) > maxReasonableValue {
            Log.error("❌ EXTREME CANVAS COORDINATES: \(location) - using zero point", category: .error)
            return .zero
        }

        return location
    }
}
