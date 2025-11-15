import SwiftUI

extension DrawingCanvas {
    @ViewBuilder
    internal func canvasOverlays(geometry: GeometryProxy) -> some View {
        if let currentPath = currentPath {
            Path { path in
                addPathElements(currentPath.elements, to: &path)
            }
            .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            drawingDimensionsOverlay(for: currentPath)
        }

        if let boundingBoxPath = tempBoundingBoxPath {
            Path { path in
                addPathElements(boundingBoxPath.elements, to: &path)
            }
            .stroke(Color.red, style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [5, 5]))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
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
            .stroke(Color.blue.opacity(0.3), style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4 / zoomLevel, 2 / zoomLevel]))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
        }

        rubberBandPreview(geometry: geometry)

        // Brush preview using Canvas
        if let preview = brushPreviewPath {
            Canvas { context, size in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)

                let path = Path { path in
                    addPathElements(preview.elements, to: &path)
                }

                if appState.brushPreviewStyle == .fill {
                    context.fill(
                        path,
                        with: .color(document.defaultFillColor.color.opacity(document.defaultFillOpacity))
                    )
                } else {
                    context.stroke(
                        path,
                        with: .color(Color.blue),
                        lineWidth: max(1.0, 1.0 / zoomLevel)
                    )
                }
            }
        }

        // Freehand preview using Canvas
        if let preview = freehandPreviewPath {
            Canvas { context, size in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)

                let path = Path { path in
                    addPathElements(preview.elements, to: &path)
                }

                context.stroke(
                    path,
                    with: .color(document.defaultStrokeColor.color.opacity(document.defaultStrokeOpacity)),
                    style: SwiftUI.StrokeStyle(
                        lineWidth: document.defaultStrokeWidth,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
            }
        }

        // Marker preview using Canvas
        if let preview = markerPreviewPath {
            let markerFillColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let markerStrokeColor = ApplicationSettings.shared.markerUseFillAsStroke ? getCurrentFillColor() : getCurrentStrokeColor()
            let showStroke = !ApplicationSettings.shared.markerApplyNoStroke
            let markerOpacity = ApplicationSettings.shared.currentMarkerOpacity

            Canvas { context, size in
                context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
                context.scaleBy(x: zoomLevel, y: zoomLevel)

                let path = Path { path in
                    addPathElements(preview.elements, to: &path)
                }

                // Fill the path
                context.fill(
                    path,
                    with: .color(markerFillColor.color.opacity(markerOpacity))
                )

                // Add stroke if needed
                if showStroke {
                    let baseStrokeWidth = getCurrentStrokeWidth()
                    let strokeWidth = (document.strokeDefaults.placement == .center) ? baseStrokeWidth : baseStrokeWidth * 2.0

                    context.stroke(
                        path,
                        with: .color(markerStrokeColor.color.opacity(markerOpacity)),
                        style: SwiftUI.StrokeStyle(
                            lineWidth: strokeWidth,
                            lineCap: .round,
                            lineJoin: .round,
                            miterLimit: document.strokeDefaults.miterLimit
                        )
                    )
                }
            }
        }

        if isBezierDrawing && document.viewState.currentTool == .bezierPen {
            ProfessionalBezierView(
                document: document,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                bezierPoints: bezierPoints,
                bezierHandles: bezierHandles,
                liveBezierHandles: liveBezierHandles,
                activeBezierPointIndex: activeBezierPointIndex,
                showClosePathHint: showClosePathHint,
                showContinuePathHint: showContinuePathHint,
                closePathHintLocation: closePathHintLocation,
                continuePathHintLocation: continuePathHintLocation
            )
            bezierDrawingDimensionsOverlay()
        }

        if !(document.viewState.currentTool == .bezierPen && isBezierDrawing) &&
           !isCornerRadiusEditMode {
            SelectionHandlesView(
                document: document,
                geometry: geometry,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                isShiftPressed: self.isShiftPressed,
                isOptionPressed: self.isOptionPressed,
                isCommandPressed: self.isCommandPressed,
                isTemporarySelectionViaCommand: self.isTemporarySelectionViaCommand,
                dragPreviewDelta: currentDragDelta,
                liveScaleTransform: $liveScaleTransform,
                liveScaleDimensions: $liveScaleDimensions
            )
        }

        if document.viewState.currentTool == .directSelection || document.viewState.currentTool == .convertAnchorPoint || document.viewState.currentTool == .penPlusMinus {
            ProfessionalDirectSelectionView(
                document: document,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedPoints: selectedPoints,
                selectedHandles: selectedHandles,
                visibleHandles: visibleHandles,
                selectedObjectIDs: selectedObjectIDs,
                geometry: geometry,
                coincidentPointTolerance: coincidentPointTolerance,
                dragPreviewDelta: currentDragDelta,
                livePointPositions: livePointPositions,
                liveHandlePositions: liveHandlePositions,
                draggedCurveSegment: draggedCurveSegment
            )
        }

        if document.viewState.currentTool == .gradient {
            gradientEditTool(geometry: geometry)
        }

        if document.viewState.currentTool == .cornerRadius {
            cornerRadiusTool(geometry: geometry)
        }

        if document.viewState.currentTool == .selection && isCornerRadiusEditMode {
            cornerRadiusEditTool(geometry: geometry)
        }

        // DEBUG: Show spatial index bounds (disabled for Metal spatial index)
        // Metal spatial index stores bounds on GPU, not accessible for debug visualization
        if false && appState.showSpatialIndexBounds {
            // let cachedBounds = spatialIndex.getAllCachedBounds()
            ForEach([], id: \.self) { (objectID: UUID) in
                if true {
                    Path { path in
                        // path.addRect(bounds)
                    }
                    .stroke(Color.red, style: SwiftUI.StrokeStyle(lineWidth: 2.0 / zoomLevel, dash: [10 / zoomLevel, 5 / zoomLevel]))
                    // .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                }
            }
        }
    }

    @ViewBuilder
    private func renderLayer(layerIndex: Int, layer: Layer, geometry: GeometryProxy, fontSizeDelta: Double?, lineSpacingDelta: Double?, lineHeightDelta: Double?, letterSpacingDelta: Double?, imagePreviewQuality: Double, imageTileSize: Int) -> some View {
        let layerOpacity = layerPreviewOpacities[layer.id] ?? layer.opacity
        let layerBlendMode = layer.blendMode

        if layer.name == "Pasteboard" {
            PasteboardBackgroundView(
                pasteboardSize: CGSize(
                    width: document.settings.sizeInPoints.width * 10,
                    height: document.settings.sizeInPoints.height * 10
                ),
                pasteboardOrigin: CGPoint(
                    x: -(document.settings.sizeInPoints.width * 10 - document.settings.sizeInPoints.width) / 2,
                    y: -(document.settings.sizeInPoints.height * 10 - document.settings.sizeInPoints.height) / 2
                ),
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
            )
            .opacity(layerOpacity)
            .blendMode(layerBlendMode.swiftUIBlendMode)
        } else if layer.name == "Canvas" {
            ZStack {
                CanvasBackgroundView(
                    canvasSize: document.settings.sizeInPoints,
                    backgroundColor: document.settings.backgroundColor.color,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset
                )

                if document.gridSettings.showGrid, document.settings.gridSpacing > 0 {
                    OptimizedGridView(
                        gridSpacing: document.settings.gridSpacing,
                        canvasSize: document.settings.sizeInPoints,
                        unit: document.settings.unit,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset
                    )
                    .allowsHitTesting(false)
                }
            }
            .opacity(layerOpacity)
            .blendMode(layerBlendMode.swiftUIBlendMode)
        }

        // Pass objectIDs so IsolatedLayerView can fetch fresh objects on every render
        if !layer.objectIDs.isEmpty {
            let isActiveLayer = document.activeLayerIndexDuringDrag == nil || document.activeLayerIndexDuringDrag == layerIndex

            // Only pass selectedObjectIDs that are actually in this layer to avoid unnecessary redraws
            let layerObjectIDsSet = Set(layer.objectIDs)
            let selectedInThisLayer = document.viewState.selectedObjectIDs.intersection(layerObjectIDsSet)

            // Only pass selectedShapeIDForCornerRadius if the shape is in this layer
            let selectedRectShape = getSelectedRectangleShape()
            let selectedShapeInThisLayer: UUID? = {
                if let shapeID = selectedRectShape?.id, layerObjectIDsSet.contains(shapeID) {
                    return shapeID
                }
                return nil
            }()

            IsolatedLayerView(
                objectIDs: layer.objectIDs,
                document: document,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedObjectIDs: selectedInThisLayer,
                viewMode: document.viewState.viewMode,
                dragPreviewDelta: isActiveLayer ? currentDragDelta : .zero,
                dragPreviewTrigger: dragPreviewUpdateTrigger,
                liveScaleTransform: liveScaleTransform,
                layerOpacity: layerOpacity,
                layerBlendMode: layerBlendMode,
                livePointPositions: livePointPositions,
                liveHandlePositions: liveHandlePositions,
                fillDeltaOpacity: fillDeltaOpacity,
                strokeDeltaOpacity: strokeDeltaOpacity,
                strokeDeltaWidth: strokeDeltaWidth,
                colorDeltaColor: colorDeltaColor,
                colorDeltaOpacity: colorDeltaOpacity,
                activeGradientDelta: $activeGradientDelta,
                activeColorTarget: document.viewState.activeColorTarget,
                fontSizeDelta: fontSizeDelta,
                lineSpacingDelta: lineSpacingDelta,
                lineHeightDelta: lineHeightDelta,
                letterSpacingDelta: letterSpacingDelta,
                imagePreviewQuality: imagePreviewQuality,
                imageTileSize: imageTileSize,
                liveCornerRadii: liveCornerRadii,
                selectedShapeIDForCornerRadius: selectedShapeInThisLayer,
                layerUpdateTrigger: document.viewState.layerUpdateTriggers[layer.id] ?? 0
            )
            // .scaleEffect(liveZoomDelta, anchor: .topLeading)
            // .offset(x: livePanDelta.x, y: livePanDelta.y)
            // Use only layer.id for view identity - trigger passed as parameter will cause redraw
            .id(layer.id)
           // .allowsHitTesting(isActiveLayer)
        }
    }

    @ViewBuilder
    internal func canvasBaseContent(geometry: GeometryProxy, imagePreviewQuality: Double, imageTileSize: Int) -> some View {
        // Render layers with background fills for special layers
        ForEach(Array(document.snapshot.layers.enumerated()), id: \.offset) { layerIndex, layer in
            if layer.isVisible {
                renderLayer(layerIndex: layerIndex, layer: layer, geometry: geometry, fontSizeDelta: fontSizeDelta, lineSpacingDelta: lineSpacingDelta, lineHeightDelta: lineHeightDelta, letterSpacingDelta: letterSpacingDelta, imagePreviewQuality: imagePreviewQuality, imageTileSize: imageTileSize)
            }
        }
    }

    @ViewBuilder
    internal func drawingDimensionsOverlay(for path: VectorPath) -> some View {
        if isDrawing {
            let bounds = path.cgPath.boundingBoxOfPath
            let width = bounds.width
            let height = bounds.height

            // Convert canvas coordinates to screen coordinates
            let canvasLabelPosition = CGPoint(
                x: bounds.maxX + 10,
                y: bounds.minY - 30
            )
            let screenPosition = CGPoint(
                x: canvasLabelPosition.x * zoomLevel + canvasOffset.x,
                y: canvasLabelPosition.y * zoomLevel + canvasOffset.y
            )

            let widthText = width == floor(width) ? String(format: "%.0f", width) : String(format: "%.1f", width)
            let heightText = height == floor(height) ? String(format: "%.0f", height) : String(format: "%.1f", height)

            Text("W: \(widthText) pt\nH: \(heightText) pt")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.75))
                .cornerRadius(4)
                .fixedSize()
                .position(screenPosition)
        }
    }

    @ViewBuilder
    internal func bezierDrawingDimensionsOverlay() -> some View {
        if let bezierPath = bezierPath, bezierPoints.count >= 2 {
            let bounds = bezierPath.cgPath.boundingBoxOfPath
            let width = bounds.width
            let height = bounds.height

            // Convert canvas coordinates to screen coordinates
            let canvasLabelPosition = CGPoint(
                x: bounds.maxX + 10,
                y: bounds.minY - 30
            )
            let screenPosition = CGPoint(
                x: canvasLabelPosition.x * zoomLevel + canvasOffset.x,
                y: canvasLabelPosition.y * zoomLevel + canvasOffset.y
            )

            let widthText = width == floor(width) ? String(format: "%.0f", width) : String(format: "%.1f", width)
            let heightText = height == floor(height) ? String(format: "%.0f", height) : String(format: "%.1f", height)

            Text("W: \(widthText) pt\nH: \(heightText) pt")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.75))
                .cornerRadius(4)
                .fixedSize()
                .position(screenPosition)
        }
    }

    @ViewBuilder
    internal func canvasMainContent(geometry: GeometryProxy) -> some View {
        ZStack {
            canvasBaseContent(geometry: geometry, imagePreviewQuality: imagePreviewQuality, imageTileSize: imageTileSize)

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
    internal func pressureSensitiveOverlay(geometry: GeometryProxy) -> some View {
        if document.viewState.currentTool == .brush || document.viewState.currentTool == .freehand || document.viewState.currentTool == .marker {
            PressureSensitiveCanvasRepresentable(
                                            onPressureEvent: { location, pressure, eventType, isTabletEvent in
                                handlePressureEvent(location: location, pressure: pressure, eventType: eventType, isTabletEvent: isTabletEvent, geometry: geometry)
                            },
                hasPressureSupport: .constant(PressureManager.shared.hasRealPressureInput)
            )
            //.allowsHitTesting(true)
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

extension DrawingCanvas {
    @ViewBuilder
    internal func draggedObjectPreview(geometry: GeometryProxy, dragDelta: CGPoint) -> some View {
        if dragDelta != .zero && !document.viewState.selectedObjectIDs.isEmpty {
            let draggedObjects = document.snapshot.objects.values.filter { document.viewState.selectedObjectIDs.contains($0.id) }
            ForEach(draggedObjects, id: \.id) { object in
                draggedObjectView(object, dragDelta: dragDelta)
            }
        }
    }

    @ViewBuilder
    private func draggedObjectView(_ object: VectorObject, dragDelta: CGPoint) -> some View {
        switch object.objectType {
        case .shape(let shape),
             .image(let shape),
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
        // .scaleEffect(currentZoom, anchor: .topLeading)
        // .offset(x: currentOffset.x, y: currentOffset.y)
        .opacity(0.8)
    }

    @ViewBuilder
    private func draggedTextView(_ text: VectorText, dragDelta: CGPoint) -> some View {
        let currentZoom = zoomLevel
        let currentOffset = canvasOffset
        Text(text.content)
            .font(.system(size: text.typography.fontSize * currentZoom))
            .foregroundColor(text.typography.fillColor.color)
            .position(
                x: (text.position.x + dragDelta.x) * currentZoom + currentOffset.x,
                y: (text.position.y + dragDelta.y) * currentZoom + currentOffset.y
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
