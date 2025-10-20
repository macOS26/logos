import SwiftUI

extension DrawingCanvas {
    // Get visible layer indices
    private func visibleLayerIndices() -> [Int] {
        let allObjects = document.getObjectsInStackingOrder()
        let filtered = allObjects.filter { obj in
            guard obj.layerIndex < document.layers.count else { return false }
            guard document.layers[obj.layerIndex].isVisible else { return false }

            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.name != "Canvas Background" && shape.name != "Pasteboard Background"
            case .text:
                return true
            }
        }

        let objectsByLayer = Dictionary(grouping: filtered, by: { $0.layerIndex })
        return objectsByLayer.keys.sorted()
    }

    // Get objects for a specific layer
    private func objectsForLayer(_ layerIndex: Int) -> [VectorObject]? {
        let allObjects = document.getObjectsInStackingOrder()
        let filtered = allObjects.filter { obj in
            guard obj.layerIndex == layerIndex else { return false }
            guard obj.layerIndex < document.layers.count else { return false }
            guard document.layers[obj.layerIndex].isVisible else { return false }

            switch obj.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                return shape.name != "Canvas Background" && shape.name != "Pasteboard Background"
            case .text:
                return true
            }
        }

        return filtered.isEmpty ? nil : filtered
    }

    @ViewBuilder
    internal func canvasOverlays(geometry: GeometryProxy) -> some View {
        if let currentPath = currentPath {
            Path { path in
                addPathElements(currentPath.elements, to: &path)
            }
            .stroke(Color.blue, lineWidth: 1.0 / document.viewState.zoomLevel)
            .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
            .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
            drawingDimensionsOverlay(for: currentPath)
        }

        if let boundingBoxPath = tempBoundingBoxPath {
            Path { path in
                addPathElements(boundingBoxPath.elements, to: &path)
            }
            .stroke(Color.red, style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [5, 5]))
            .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
            .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
        }

        if let currentPath = currentPath,
           (document.viewState.currentTool == .polygon || document.viewState.currentTool == .pentagon ||
            document.viewState.currentTool == .hexagon || document.viewState.currentTool == .heptagon ||
            document.viewState.currentTool == .octagon || document.viewState.currentTool == .nonagon ||
            document.viewState.currentTool == .star) {
            let actualBounds = currentPath.cgPath.boundingBoxOfPath
            Path { path in
                path.addRect(actualBounds)
            }
            .stroke(Color.blue.opacity(0.3), style: SwiftUI.StrokeStyle(lineWidth: 1.0 / document.viewState.zoomLevel, dash: [4 / document.viewState.zoomLevel, 2 / document.viewState.zoomLevel]))
            .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
            .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
        }

        rubberBandPreview(geometry: geometry)

        if let preview = brushPreviewPath {
            if appState.brushPreviewStyle == .fill {
                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .fill(document.defaultFillColor.color)
                .opacity(document.defaultFillOpacity)
                .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
                .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
            } else {
                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .stroke(Color.blue, lineWidth: max(1.0, 1.0 / document.viewState.zoomLevel))
                .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
                .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
            }
        }

        if let preview = freehandPreviewPath {
            Path { path in
                addPathElements(preview.elements, to: &path)
            }
            .modifier(FreehandPreviewStyleModifier(appState: appState, document: document, preview: preview))
            .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
            .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
        }

        if let preview = markerPreviewPath {
            let markerFillColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let markerStrokeColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let showStroke = !ApplicationSettings.shared.markerApplyNoStroke

            if showStroke {
                let baseStrokeWidth = getCurrentStrokeWidth()
                let strokeWidth = (document.strokeDefaults.placement == .center) ? baseStrokeWidth : baseStrokeWidth * 2.0
                let lineCap: CGLineCap = .round
                let lineJoin: CGLineJoin = .round

                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .fill(markerFillColor.color)
                .opacity(ApplicationSettings.shared.currentMarkerOpacity)
                .overlay(
                    Path { path in
                        addPathElements(preview.elements, to: &path)
                    }
                    .stroke(markerStrokeColor.color, style: SwiftUI.StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: lineCap,
                        lineJoin: lineJoin,
                        miterLimit: document.strokeDefaults.miterLimit
                    ))
                    .opacity(ApplicationSettings.shared.currentMarkerOpacity)
                )
                .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
                .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
            } else {
                Path { path in
                    addPathElements(preview.elements, to: &path)
                }
                .fill(markerFillColor.color)
                .opacity(ApplicationSettings.shared.currentMarkerOpacity)
                .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
                .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
            }
        }

        bezierAnchorPoints()
        bezierControlHandles()
        bezierClosePathHint()
        bezierContinuePathHint()

        if !(document.viewState.currentTool == .bezierPen && isBezierDrawing) &&
           !isCornerRadiusEditMode {
            SelectionHandlesView(
                document: document,
                geometry: geometry,
                isShiftPressed: self.isShiftPressed,
                isOptionPressed: self.isOptionPressed,
                isCommandPressed: self.isCommandPressed,
                isTemporarySelectionViaCommand: self.isTemporarySelectionViaCommand,
                dragPreviewDelta: currentDragDelta,
                liveScaleTransform: $liveScaleTransform
            )
        }

        if isBezierDrawing && document.viewState.currentTool == .bezierPen {
            bezierDrawingDimensionsOverlay()
        }

        if document.viewState.currentTool == .directSelection || document.viewState.currentTool == .convertAnchorPoint || document.viewState.currentTool == .penPlusMinus {
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

        if document.viewState.currentTool == .gradient {
            gradientCenterPointOverlay(geometry: geometry)
        }

        if document.viewState.currentTool == .cornerRadius {
            cornerRadiusTool(geometry: geometry)
        }

        if document.viewState.currentTool == .selection && isCornerRadiusEditMode {
            cornerRadiusEditTool(geometry: geometry)
        }
    }

    @ViewBuilder
    internal func canvasBaseContent(geometry: GeometryProxy) -> some View {
        ZStack {

            PasteboardBackgroundView(
                document: document,
                zoomLevel: document.viewState.zoomLevel,
                canvasOffset: document.viewState.canvasOffset,
                selectedObjectIDs: document.viewState.selectedObjectIDs,
                viewMode: document.viewState.viewMode,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger
            )

            CanvasBackgroundView(
                document: document,
                zoomLevel: document.viewState.zoomLevel,
                canvasOffset: document.viewState.canvasOffset,
                selectedObjectIDs: document.viewState.selectedObjectIDs,
                viewMode: document.viewState.viewMode,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger
            )

            if document.gridSettings.showGrid, document.settings.gridSpacing > 0 {
                GridView(
                    gridSpacing: document.settings.gridSpacing,
                    canvasSize: document.settings.sizeInPoints,
                    unit: document.settings.unit,
                    zoomLevel: document.viewState.zoomLevel,
                    canvasOffset: document.viewState.canvasOffset
                )
                .equatable()
                .allowsHitTesting(false)
            }

            // Render layers directly without parent view to avoid @ObservedObject re-renders
            ForEach(visibleLayerIndices(), id: \.self) { layerIndex in
                if let objects = objectsForLayer(layerIndex) {
                    let isActiveLayer = document.activeLayerIndexDuringDrag == nil || document.activeLayerIndexDuringDrag == layerIndex

                    IsolatedLayerView(
                        objects: objects,
                        layerID: document.layers[layerIndex].id,
                        document: document,
                        zoomLevel: document.viewState.zoomLevel,
                        canvasOffset: document.viewState.canvasOffset,
                        selectedObjectIDs: document.viewState.selectedObjectIDs,
                        viewMode: document.viewState.viewMode,
                        dragPreviewDelta: isActiveLayer ? currentDragDelta : .zero,
                        dragPreviewTrigger: dragPreviewUpdateTrigger,
                        liveScaleTransform: liveScaleTransform,
                        layerOpacity: layerPreviewOpacities[document.layers[layerIndex].id] ?? document.layers[layerIndex].opacity,
                        layerBlendMode: document.layers[layerIndex].blendMode,
                        liveGradientOriginX: liveGradientOriginX,
                        liveGradientOriginY: liveGradientOriginY
                    )
                    .equatable()
                    .allowsHitTesting(isActiveLayer)
                }
            }

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
                .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
                .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
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
                .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
                .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
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
            previousTool = document.viewState.currentTool
        }
            .onDisappear {
                // teardownKeyEventMonitoring()
            }
            .onChange(of: document.viewState.currentTool) { oldTool, newTool in
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
            .onChange(of: document.viewState.zoomRequest) {
                if let request = document.viewState.zoomRequest {
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
        if document.viewState.currentTool == .brush || document.viewState.currentTool == .freehand || document.viewState.currentTool == .marker {
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

        switch document.viewState.currentTool {
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

        switch document.viewState.currentTool {
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
        switch document.viewState.currentTool {
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
                    .stroke(Color.blue, lineWidth: max(1.0, 1.0 / document.viewState.zoomLevel))
            }
        case .fill:
            Path { p in addPathElements(preview.elements, to: &p) }
                .fill(document.defaultFillColor.color)
                .opacity(document.defaultFillOpacity)
        }
    }

    @ViewBuilder
    internal func draggedObjectPreview(geometry: GeometryProxy, dragDelta: CGPoint) -> some View {
        if dragDelta != .zero && !document.viewState.selectedObjectIDs.isEmpty {
            let draggedObjects = document.unifiedObjects.filter { document.viewState.selectedObjectIDs.contains($0.id) }
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
        .scaleEffect(document.viewState.zoomLevel, anchor: .topLeading)
        .offset(x: document.viewState.canvasOffset.x, y: document.viewState.canvasOffset.y)
        .opacity(0.8)
    }

    @ViewBuilder
    private func draggedTextView(_ text: VectorText, dragDelta: CGPoint) -> some View {
        Text(text.content)
            .font(.system(size: text.typography.fontSize * document.viewState.zoomLevel))
            .foregroundColor(text.typography.fillColor.color)
            .position(
                x: (text.position.x + dragDelta.x) * document.viewState.zoomLevel + document.viewState.canvasOffset.x,
                y: (text.position.y + dragDelta.y) * document.viewState.zoomLevel + document.viewState.canvasOffset.y
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
