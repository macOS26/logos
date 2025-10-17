import SwiftUI
import AppKit

extension DrawingCanvas {

    internal func detectAdvancedClickTypes(at location: CGPoint, geometry: GeometryProxy, clickType: String) {
        screenToCanvas(location, geometry: geometry)
    }

    internal func handleDoubleClick(at location: CGPoint, geometry: GeometryProxy) {
        var clickType = "Double Click"
        if isOptionPressed && isCommandPressed {
            clickType = "Option+Command+Double Click"
        } else if isOptionPressed {
            clickType = "Option+Double Click"
        } else if isCommandPressed {
            clickType = "Command+Double Click"
        }

        detectAdvancedClickTypes(at: location, geometry: geometry, clickType: clickType)

        let canvasLocation = screenToCanvas(location, geometry: geometry)

        if let textID = findTextAt(location: canvasLocation) {
            document.currentTool = .font

            startEditingText(textID: textID, at: canvasLocation)

            isTextEditingMode = true
            NSCursor.iBeam.set()
        }
    }

    internal func handleUnifiedTap(at location: CGPoint, geometry: GeometryProxy) {
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        let currentTime = Date()
        let timeSinceLastClick = currentTime.timeIntervalSince(lastClickTime)
        let distanceFromLastClick = distance(location, lastClickLocation)
        let isDoubleClick = timeSinceLastClick < doubleClickTimeout && distanceFromLastClick < 10.0

        lastClickTime = currentTime
        lastClickLocation = location

        var clickType = "Single Click"
        if isDoubleClick {
            if isOptionPressed && isCommandPressed {
                clickType = "Option+Command+Double Click"
            } else if isOptionPressed {
                clickType = "Option+Double Click"
            } else if isCommandPressed {
                clickType = "Command+Double Click"
            } else {
                clickType = "Double Click"
            }

            handleDoubleClick(at: location, geometry: geometry)
            return
        } else {
            if isOptionPressed && isCommandPressed {
                clickType = "Option+Command+Click"
            } else if isOptionPressed {
                clickType = "Option+Click"
            } else if isCommandPressed {
                clickType = "Command+Click"
            }
        }

        detectAdvancedClickTypes(at: location, geometry: geometry, clickType: clickType)

        if document.currentTool != .bezierPen && isBezierDrawing {
            cancelBezierDrawing()
        }

        switch document.currentTool {
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
            if let existingTextID = findTextAt(location: canvasLocation) {
                startEditingText(textID: existingTextID, at: canvasLocation)
            }
            handleAggressiveBackgroundTap(at: canvasLocation)

        case .line, .rectangle, .square, .roundedRectangle, .pill, .circle, .ellipse, .oval, .egg, .cone, .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle:
            if !isShiftPressed && !isCommandPressed {
                document.selectedObjectIDs = []
                document.syncSelectionArrays()
            }

        case .zoom:
            MagnifyingGlassCursor.set()
            let focalPoint = location
            let currentZoom = CGFloat(document.zoomLevel)
            let targetZoom: CGFloat
            if isOptionPressed {
                targetZoom = nextAllowedStepDown(from: currentZoom)
            } else {
                targetZoom = nextAllowedStepUp(from: currentZoom)
            }
            handleZoomAtPoint(newZoomLevel: targetZoom, focalPoint: focalPoint, geometry: geometry)
            if isCanvasHovering && document.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            DispatchQueue.main.async {
                if isCanvasHovering && document.currentTool == .zoom {
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
        switch document.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)

        case .zoom:
            if zoomToolDragStartPoint == .zero {
                zoomToolDragStartPoint = value.startLocation
                zoomToolInitialZoomLevel = document.zoomLevel
            }
            MagnifyingGlassCursor.set()
            let deltaY = value.location.y - zoomToolDragStartPoint.y
            let sensitivity: CGFloat = 300.0
            var scaleChange = exp(-deltaY / sensitivity)
            if isOptionPressed { scaleChange = 1.0 / scaleChange }
            let continuousZoom = max(0.1, min(16.0, zoomToolInitialZoomLevel * scaleChange))
            handleZoomAtPoint(newZoomLevel: continuousZoom, focalPoint: value.startLocation, geometry: geometry)

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

        switch document.currentTool {
        case .hand:
            finishPanGesture()

        case .zoom:
            zoomToolDragStartPoint = .zero
            zoomToolInitialZoomLevel = document.zoomLevel

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
            for objectID in document.selectedObjectIDs {
                if let unifiedObject = document.findObject(by: objectID),
                   case .shape(let shape) = unifiedObject.objectType {
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
            if document.selectedObjectIDs.isEmpty || !isDraggingSelectedObject(at: startLocation) {
                selectObjectAt(startLocation)
            }

            if !document.selectedObjectIDs.isEmpty {
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

        if isCanvasHovering && document.currentTool == .hand {
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

        for unifiedObject in document.unifiedObjects.reversed() {
            if case .shape(let shape) = unifiedObject.objectType {
                let layerIndex = unifiedObject.layerIndex
                if layerIndex >= 0 && layerIndex < document.layers.count {
                    let layer = document.layers[layerIndex]
                    if !layer.isVisible || layer.isLocked {
                        continue
                    }
                }

                if !shape.isVisible { continue }

                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    continue
                }

                let transformedBounds = shape.bounds.applying(shape.transform)
                if transformedBounds.contains(location) {
                    tappedObject = unifiedObject
                    tappedShape = shape
                    break
                }
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

        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                let layerIndex = unifiedObject.layerIndex
                if layerIndex >= 0 && layerIndex < document.layers.count {
                    let layer = document.layers[layerIndex]
                    if !layer.isVisible || layer.isLocked {
                        continue
                    }
                }

                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    continue
                }

                let hasFillMatch = shape.fillStyle?.color == colorToMatch
                let hasStrokeMatch = shape.strokeStyle?.color == colorToMatch

                if hasFillMatch || hasStrokeMatch {
                    matchingObjectIDs.insert(unifiedObject.id)
                }
            }
        }

        if !matchingObjectIDs.isEmpty {
            document.selectedObjectIDs = matchingObjectIDs
            document.syncSelectionArrays()
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
