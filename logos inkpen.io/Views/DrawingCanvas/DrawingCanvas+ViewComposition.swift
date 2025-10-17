import SwiftUI

extension DrawingCanvas {
    @ViewBuilder
    internal func canvasOverlays(geometry: GeometryProxy) -> some View {
        if let currentPath = currentPath {
            Path { path in
                addPathElements(currentPath.elements, to: &path)
            }
            .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel)
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            drawingDimensionsOverlay(for: currentPath)
        }

        if let boundingBoxPath = tempBoundingBoxPath {
            Path { path in
                addPathElements(boundingBoxPath.elements, to: &path)
            }
            .stroke(Color.red, style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [5, 5]))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }

        if let currentPath = currentPath,
           (document.currentTool == .polygon || document.currentTool == .pentagon ||
            document.currentTool == .hexagon || document.currentTool == .heptagon ||
            document.currentTool == .octagon || document.currentTool == .nonagon ||
            document.currentTool == .star) {
            let actualBounds = currentPath.cgPath.boundingBoxOfPath
            Path { path in
                path.addRect(actualBounds)
            }
            .stroke(Color.blue.opacity(0.3), style: SwiftUI.StrokeStyle(lineWidth: 1.0 / document.zoomLevel, dash: [4 / document.zoomLevel, 2 / document.zoomLevel]))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }

        rubberBandPreview(geometry: geometry)

        if let preview = brushPreviewPath {
            if appState.brushPreviewStyle == .fill {
                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .fill(document.defaultFillColor.color)
                .opacity(document.defaultFillOpacity)
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            } else {
                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .stroke(Color.blue, lineWidth: max(1.0, 1.0 / document.zoomLevel))
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            }
        }

        if let preview = freehandPreviewPath {
            Path { path in
                addPathElements(preview.elements, to: &path)
            }
            .modifier(FreehandPreviewStyleModifier(appState: appState, document: document, preview: preview))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }

        if let preview = markerPreviewPath {
            let markerFillColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let markerStrokeColor = document.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let showStroke = !document.markerApplyNoStroke

            if showStroke {
                let baseStrokeWidth = getCurrentStrokeWidth()
                let strokeWidth = (document.defaultStrokePlacement == .center) ? baseStrokeWidth : baseStrokeWidth * 2.0
                let lineCap: CGLineCap = .round
                let lineJoin: CGLineJoin = .round

                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .fill(markerFillColor.color)
                .opacity(document.currentMarkerOpacity)
                .overlay(
                    Path { path in
                        addPathElements(preview.elements, to: &path)
                    }
                    .stroke(markerStrokeColor.color, style: SwiftUI.StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: lineCap,
                        lineJoin: lineJoin,
                        miterLimit: document.defaultStrokeMiterLimit
                    ))
                    .opacity(document.currentMarkerOpacity)
                )
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            } else {
                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .fill(markerFillColor.color)
                .opacity(document.currentMarkerOpacity)
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            }
        }

        bezierAnchorPoints()
        bezierControlHandles()
        bezierClosePathHint()
        bezierContinuePathHint()

        if !(document.currentTool == .bezierPen && isBezierDrawing) &&
           !isCornerRadiusEditMode {
            SelectionHandlesView(
                document: document,
                geometry: geometry,
                isShiftPressed: self.isShiftPressed,
                isOptionPressed: self.isOptionPressed,
                isCommandPressed: self.isCommandPressed,
                isTemporarySelectionViaCommand: self.isTemporarySelectionViaCommand,
                dragPreviewDelta: currentDragDelta
            )
        }

        if isBezierDrawing && document.currentTool == .bezierPen {
            bezierDrawingDimensionsOverlay()
        }

        if document.currentTool == .directSelection || document.currentTool == .convertAnchorPoint || document.currentTool == .penPlusMinus {
            ProfessionalDirectSelectionView(
                document: document,
                selectedPoints: selectedPoints,
                selectedHandles: selectedHandles,
                visibleHandles: visibleHandles,
                directSelectedShapeIDs: directSelectedShapeIDs,
                geometry: geometry,
                coincidentPointTolerance: coincidentPointTolerance
            )
        }

        if document.currentTool == .gradient {
            gradientCenterPointOverlay(geometry: geometry)
        }

        if document.currentTool == .cornerRadius {
            cornerRadiusTool(geometry: geometry)
        }

        if document.currentTool == .selection && isCornerRadiusEditMode {
            cornerRadiusEditTool(geometry: geometry)
        }
    }

    @ViewBuilder
    internal func canvasBaseContent(geometry: GeometryProxy) -> some View {
        ZStack {

            PasteboardBackgroundView(
                document: document,
                zoomLevel: document.zoomLevel,
                canvasOffset: document.canvasOffset,
                selectedObjectIDs: document.selectedObjectIDs,
                viewMode: document.viewMode,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger
            )

            CanvasBackgroundView(
                document: document,
                zoomLevel: document.zoomLevel,
                canvasOffset: document.canvasOffset,
                selectedObjectIDs: document.selectedObjectIDs,
                viewMode: document.viewMode,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger
            )

            if document.showGrid {
                GridView(document: document, geometry: geometry)
                    .allowsHitTesting(false)
            }

            NonBackgroundObjectsView(
                document: document,
                zoomLevel: document.zoomLevel,
                canvasOffset: document.canvasOffset,
                selectedObjectIDs: document.selectedObjectIDs,
                viewMode: document.viewMode,
                isShiftPressed: self.isShiftPressed,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger,
                layerPreviewOpacities: $layerPreviewOpacities
            )

            canvasOverlays(geometry: geometry)
        }
    }

    @ViewBuilder
    internal func drawingDimensionsOverlay(for path: VectorPath) -> some View {
        if isDrawing {
            let bounds = path.cgPath.boundingBoxOfPath
            let width = bounds.width
            let height = bounds.height
            let labelPosition = CGPoint(
                x: bounds.maxX + 10,
                y: bounds.minY - 30
            )

            let widthText = width == floor(width) ? String(format: "%.0f", width) : String(format: "%.1f", width)
            let heightText = height == floor(height) ? String(format: "%.0f", height) : String(format: "%.1f", height)

            Text("W: \(widthText)pt\nH: \(heightText)pt")
                .font(.caption)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.8))
                .cornerRadius(4)
                .position(labelPosition)
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }

    @ViewBuilder
    internal func bezierDrawingDimensionsOverlay() -> some View {
        if let bezierPath = bezierPath, bezierPoints.count >= 2 {
            let bounds = bezierPath.cgPath.boundingBoxOfPath
            let width = bounds.width
            let height = bounds.height
            let labelPosition = CGPoint(
                x: bounds.maxX + 10,
                y: bounds.minY - 30
            )

            let widthText = width == floor(width) ? String(format: "%.0f", width) : String(format: "%.1f", width)
            let heightText = height == floor(height) ? String(format: "%.0f", height) : String(format: "%.1f", height)

            Text("W: \(widthText)pt\nH: \(heightText)pt")
                .font(.caption)
                .foregroundColor(.white)
                .padding(4)
                .background(Color.black.opacity(0.8))
                .cornerRadius(4)
                .position(labelPosition)
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }

    @ViewBuilder
    internal func canvasMainContent(geometry: GeometryProxy) -> some View {
        ZStack {
            canvasBaseContent(geometry: geometry)

            pressureSensitiveOverlay(geometry: geometry)

			if appState.showInAppPerformanceHUD {
				VStack {
					HStack {
						Spacer()
						hudOverlay
							.offset(x: appState.inAppHUDOffsetX, y: appState.inAppHUDOffsetY)
					}
					Spacer()
				}
			}
        }
        .onAppear {
            setupCanvas()
            setupKeyEventMonitoring()
            setupToolKeyboardShortcuts()
            previousTool = document.currentTool
        }
            .onDisappear {
                teardownKeyEventMonitoring()
            }
            .onChange(of: document.currentTool) { oldTool, newTool in
                handleToolChange(oldTool: oldTool, newTool: newTool)
            }
            .onHover { isHovering in
                isCanvasHovering = isHovering
            }
            .onContinuousHover { phase in
                handleHover(phase: phase, geometry: geometry)
            }
            .onTapGesture { location in
                handleUnifiedTap(at: location, geometry: geometry)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        handleUnifiedDragChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleUnifiedDragEnded(value: value, geometry: geometry)
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        handleZoomGestureChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleZoomGestureEnded(value: value, geometry: geometry)
                    }
            )
            .onChange(of: document.zoomRequest) {
                if let request = document.zoomRequest {
                    handleZoomRequest(request, geometry: geometry)
                }
            }

            .contextMenu {
                directSelectionContextMenu
            }
    }

    @ViewBuilder
    internal func gradientCenterPointOverlay(geometry: GeometryProxy) -> some View {
        gradientEditTool(geometry: geometry)
    }

    @ViewBuilder
    internal func pressureSensitiveOverlay(geometry: GeometryProxy) -> some View {
        if document.currentTool == .brush || document.currentTool == .freehand || document.currentTool == .marker {
            PressureSensitiveCanvasRepresentable(
                                            onPressureEvent: { location, pressure, eventType, isTabletEvent in
                                handlePressureEvent(location: location, pressure: pressure, eventType: eventType, isTabletEvent: isTabletEvent, geometry: geometry)
                            },
                hasPressureSupport: .constant(PressureManager.shared.hasRealPressureInput)
            )
            .allowsHitTesting(true)
            .background(Color.clear)
        }
    }

    private func handlePressureEvent(
        location: CGPoint,
        pressure: Double,
        eventType: PressureSensitiveCanvasView.PressureEventType,
        isTabletEvent: Bool,
        geometry: GeometryProxy
    ) {

        let canvasLocation = screenToCanvas(location, geometry: geometry)

        PressureManager.shared.processRealPressure(pressure, at: canvasLocation, isTabletEvent: isTabletEvent)

        switch eventType {
        case .began:
            handlePressureDrawingStart(at: canvasLocation)
        case .changed:
            handlePressureDrawingUpdate(at: canvasLocation)
        case .ended:
            handlePressureDrawingEnd(at: canvasLocation)
        }
    }

    private func handlePressureDrawingStart(at location: CGPoint) {

        switch document.currentTool {
        case .brush:
            if !isBrushDrawing {
                handleBrushDragStart(at: location)
            }
        case .freehand:
            if !isFreehandDrawing {
                handleFreehandDragStart(at: location)
            }
        case .marker:
            if !isMarkerDrawing {
                handleMarkerDragStart(at: location)
            }
        default:
            break
        }
    }

    private func handlePressureDrawingUpdate(at location: CGPoint) {

        let currentPressure = PressureManager.shared.currentPressure

        switch document.currentTool {
        case .brush:
            if isBrushDrawing {
                handleBrushDragUpdate(at: location)
            }
        case .freehand:
            if isFreehandDrawing {
                handleFreehandDragUpdate(at: location)
            }
        case .marker:
            if isMarkerDrawing {
                handleMarkerDragUpdate(at: location, pressure: currentPressure)
            }
        default:
            break
        }
    }

    private func handlePressureDrawingEnd(at location: CGPoint) {
        switch document.currentTool {
        case .brush:
            if isBrushDrawing {
                handleBrushDragEnd()
            }
        case .freehand:
            if isFreehandDrawing {
                handleFreehandDragEnd()
            }
        case .marker:
            if isMarkerDrawing {
                handleMarkerDragEnd()
            }
        default:
            break
        }
    }

    private var hudOverlay: some View {
        let monitor = OptimizedPerformanceMonitor.shared
        return LightweightPerformanceOverlay(monitor: monitor)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        AppState.shared.inAppHUDOffsetX = value.translation.width + AppState.shared.inAppHUDOffsetX
                        AppState.shared.inAppHUDOffsetY = value.translation.height + AppState.shared.inAppHUDOffsetY
                    }
            )
    }

}

private struct BrushPreviewStyleModifier: ViewModifier {
    @Environment(AppState.self) var appState
    let appStateRef: AppState?
    let document: VectorDocument
    let preview: VectorPath

    init(appState: AppState, document: VectorDocument, preview: VectorPath) {
        self.document = document
        self.preview = preview
        self.appStateRef = appState
    }

    func body(content: Content) -> some View {
        switch appStateRef?.brushPreviewStyle ?? .outline {
        case .outline:
            ZStack {
                content.opacity(0.001)
                Path { p in addPathElements(preview.elements, to: &p) }
                    .stroke(Color.blue, lineWidth: max(1.0, 1.0 / document.zoomLevel))
            }
        case .fill:
            Path { p in addPathElements(preview.elements, to: &p) }
                .fill(document.defaultFillColor.color)
                .opacity(document.defaultFillOpacity)
        }
    }

    @ViewBuilder
    internal func draggedObjectPreview(geometry: GeometryProxy, dragDelta: CGPoint) -> some View {
        if dragDelta != .zero && !document.selectedObjectIDs.isEmpty {
            let draggedObjects = document.unifiedObjects.filter { document.selectedObjectIDs.contains($0.id) }
            ForEach(draggedObjects, id: \.id) { unifiedObject in
                draggedObjectView(unifiedObject, dragDelta: dragDelta)
            }
        }
    }

    @ViewBuilder
    private func draggedObjectView(_ unifiedObject: VectorObject, dragDelta: CGPoint) -> some View {
        switch unifiedObject.objectType {
        case .shape(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            draggedShapeView(shape, dragDelta: dragDelta)
        case .text:
            EmptyView()
        }
    }

    @ViewBuilder
    private func draggedShapeView(_ shape: VectorShape, dragDelta: CGPoint) -> some View {
        let offsetShape = applyDragOffsetToShape(shape, offset: dragDelta)
        Path { path in
            addPathElements(offsetShape.path.elements, to: &path)
        }
        .fill(shape.fillStyle?.color.color ?? .clear)
        .overlay(
            Path { path in
                addPathElements(offsetShape.path.elements, to: &path)
            }
            .stroke(shape.strokeStyle?.color.color ?? .clear, lineWidth: shape.strokeStyle?.width ?? 0)
        )
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        .opacity(0.8)
    }

    @ViewBuilder
    private func draggedTextView(_ text: VectorText, dragDelta: CGPoint) -> some View {
        Text(text.content)
            .font(.system(size: text.typography.fontSize * document.zoomLevel))
            .foregroundColor(text.typography.fillColor.color)
            .position(
                x: (text.position.x + dragDelta.x) * document.zoomLevel + document.canvasOffset.x,
                y: (text.position.y + dragDelta.y) * document.zoomLevel + document.canvasOffset.y
            )
            .opacity(0.8)
    }

    private func applyDragOffsetToShape(_ shape: VectorShape, offset: CGPoint) -> VectorShape {
        var offsetShape = shape
        offsetShape.path = VectorPath(elements: shape.path.elements.map { element in
            switch element {
            case .move(let to):
                return .move(to: VectorPoint(to.x + offset.x, to.y + offset.y))
            case .line(let to):
                return .line(to: VectorPoint(to.x + offset.x, to.y + offset.y))
            case .curve(let to, let cp1, let cp2):
                return .curve(
                    to: VectorPoint(to.x + offset.x, to.y + offset.y),
                    control1: VectorPoint(cp1.x + offset.x, cp1.y + offset.y),
                    control2: VectorPoint(cp2.x + offset.x, cp2.y + offset.y)
                )
            case .quadCurve(let to, let cp):
                return .quadCurve(
                    to: VectorPoint(to.x + offset.x, to.y + offset.y),
                    control: VectorPoint(cp.x + offset.x, cp.y + offset.y)
                )
            case .close:
                return .close
            }
        })
        return offsetShape
    }
}

private struct FreehandPreviewStyleModifier: ViewModifier {
    @Environment(AppState.self) var appState
    let appStateRef: AppState?
    let document: VectorDocument
    let preview: VectorPath

    init(appState: AppState, document: VectorDocument, preview: VectorPath) {
        self.document = document
        self.preview = preview
        self.appStateRef = appState
    }

    func body(content: Content) -> some View {
        Path { p in addPathElements(preview.elements, to: &p) }
            .stroke(document.defaultStrokeColor.color,
                    style: SwiftUI.StrokeStyle(
                        lineWidth: document.defaultStrokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
            )
            .opacity(document.defaultStrokeOpacity)
    }
}
