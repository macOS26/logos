//
//  DrawingCanvas+ViewComposition.swift
//  logos inkpen.io
//
//  View composition functionality
//

import SwiftUI

extension DrawingCanvas {
    @ViewBuilder
    internal func canvasOverlays(geometry: GeometryProxy) -> some View {
        // Current drawing path (while drawing)
        if let currentPath = currentPath {
            Path { path in
                addPathElements(currentPath.elements, to: &path)
            }
            .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel)
            .scaleEffect(document.zoomLevel, anchor: .topLeading)  // ✅ FIXED: Added missing anchor
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            
            // REAL-TIME SIZE DISPLAY WHILE DRAWING
            drawingDimensionsOverlay(for: currentPath)
        }
        
        // Bounding box visualization for triangle drift verification
        if let boundingBoxPath = tempBoundingBoxPath {
            Path { path in
                addPathElements(boundingBoxPath.elements, to: &path)
            }
            .stroke(Color.red, style: SwiftUI.StrokeStyle(lineWidth: 1.0, dash: [5, 5]))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }

        // Show the actual polygon bounds (tight fit) with subtle blue styling
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

        // PROFESSIONAL REAL-TIME BEZIER PATH (Professional style - shows actual path with real colors)
        // Note: Real bezier shapes are now shown as actual VectorShapes in the document
        
        // PROFESSIONAL RUBBER BAND PREVIEW (Professional Standards)
        rubberBandPreview(geometry: geometry)
        
        // Brush live preview (SwiftUI overlay; avoids document mutations during drag)
        if let preview = brushPreviewPath {
            Path { path in
                addPathElements(preview.elements, to: &path)
            }
            .modifier(BrushPreviewStyleModifier(appState: appState, document: document, preview: preview))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
        
        // Marker live preview (SwiftUI overlay; avoids document mutations during drag)
        if let preview = markerPreviewPath {
            Path { path in
                addPathElements(preview.elements, to: &path)
            }
            .modifier(MarkerPreviewStyleModifier(appState: appState, document: document, preview: preview))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
        
        // Freehand live preview (SwiftUI overlay; avoids document mutations during drag)
        if let preview = freehandPreviewPath {
            Path { path in
                addPathElements(preview.elements, to: &path)
            }
            .modifier(FreehandPreviewStyleModifier(appState: appState, document: document, preview: preview))
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }

        bezierAnchorPoints()
        bezierControlHandles()
        bezierClosePathHint()
        bezierContinuePathHint()
        
        // Selection handles for selected shapes (EXCEPT during pen tool drawing or selection dragging)
        // PROFESSIONAL UX: Hide selection dots during movement (professional standard)
        // CORNER TOOL FIX: Hide bounding box and selection handles when in corner radius edit mode
        if !(document.currentTool == .bezierPen && isBezierDrawing) && 
           !(document.currentTool == .selection && isDrawing) &&
           !isCornerRadiusEditMode {
            SelectionHandlesView(
                document: document,
                geometry: geometry,
                isShiftPressed: self.isShiftPressed,
                isOptionPressed: self.isOptionPressed,
                isCommandPressed: self.isCommandPressed,
                dragPreviewDelta: currentDragDelta
            )
        }
        
        // Real-time dimensions for Bezier tool
        if isBezierDrawing && document.currentTool == .bezierPen {
            bezierDrawingDimensionsOverlay()
        }
        
        // Direct selection points and handles
        // Show direct selection UI for Direct Selection, Convert Point, and Pen +/- tools
        if document.currentTool == .directSelection || document.currentTool == .convertAnchorPoint || document.currentTool == .penPlusMinus {
            ProfessionalDirectSelectionView(
                document: document,
                selectedPoints: selectedPoints,
                selectedHandles: selectedHandles,
                directSelectedShapeIDs: directSelectedShapeIDs,
                geometry: geometry
            )
        }
        
        // Gradient center point visualization and editing - only when gradient tool is selected
        if document.currentTool == .gradient {
            gradientCenterPointOverlay(geometry: geometry)
        }
        
        // Corner radius tool - when corner radius tool is selected
        if document.currentTool == .cornerRadius {
            cornerRadiusTool(geometry: geometry)
        }
        
        // Corner radius editing - ONLY when in corner radius mode (Control-Click to activate)
        if document.currentTool == .selection && isCornerRadiusEditMode {
            cornerRadiusEditTool(geometry: geometry)
        }
    }
    
    @ViewBuilder
    internal func canvasBaseContent(geometry: GeometryProxy) -> some View {
        ZStack {
            // BRILLIANT USER SOLUTION: No more manual background!
            // Canvas is now a regular layer/shape that auto-syncs with everything else

            // First: Render the Pasteboard Background (behind everything)
            PasteboardBackgroundView(
                document: document,
                zoomLevel: document.zoomLevel,
                canvasOffset: document.canvasOffset,
                selectedObjectIDs: document.selectedObjectIDs,
                viewMode: document.viewMode,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger
            )

            // Second: Render the Canvas Background (on top of pasteboard)
            CanvasBackgroundView(
                document: document,
                zoomLevel: document.zoomLevel,
                canvasOffset: document.canvasOffset,
                selectedObjectIDs: document.selectedObjectIDs,
                viewMode: document.viewMode,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger
            )

            // Third: Grid (if enabled) - Renders on top of canvas background but below graphics
            if document.showGrid {
                GridView(document: document, geometry: geometry)
                    .allowsHitTesting(false) // Grid should not intercept mouse events
            }

            // Fourth: Render all other graphics (excluding Canvas and Pasteboard backgrounds)
            NonBackgroundObjectsView(
                document: document,
                zoomLevel: document.zoomLevel,
                canvasOffset: document.canvasOffset,
                selectedObjectIDs: document.selectedObjectIDs,
                viewMode: document.viewMode,
                isShiftPressed: self.isShiftPressed,
                dragPreviewDelta: currentDragDelta,
                dragPreviewTrigger: dragPreviewUpdateTrigger
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
            
            // Position the label above the top-right of the shape being drawn
            let labelPosition = CGPoint(
                x: bounds.maxX + 10,
                y: bounds.minY - 30
            )
            
            // Format dimensions (same as status bar)
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
            
            // Position the label above the top-right of the bezier path being drawn
            let labelPosition = CGPoint(
                x: bounds.maxX + 10,
                y: bounds.minY - 30
            )
            
            // Format dimensions (same as status bar)
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
            
            // Pressure-sensitive overlay for real Apple Pencil pressure detection
            pressureSensitiveOverlay(geometry: geometry)
			
			// In-App Performance HUD (draggable, independent of Apple's HUD)
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
        // CRITICAL FIX: NO CLIPPING to allow pasteboard area gestures
        .onAppear {
            setupCanvas(geometry: geometry)
            setupKeyEventMonitoring()
            setupToolKeyboardShortcuts()
            previousTool = document.currentTool
        }
            .onDisappear {
                teardownKeyEventMonitoring()
                // No cursor management
            }
            .onChange(of: document.currentTool) { oldTool, newTool in
                handleToolChange(oldTool: oldTool, newTool: newTool)
                // No cursor management
            }
            .onHover { isHovering in
                // Track enter/exit and update cursor only within the drawing area
                isCanvasHovering = isHovering
                // No cursor management
            }
            .onContinuousHover { phase in
                handleHover(phase: phase, geometry: geometry)
            }
            .onTapGesture { location in
                // CRITICAL: Single-click selection (was missing!)
                Log.info("🎯 SINGLE CLICK DETECTED at: \(location)", category: .selection)
                handleUnifiedTap(at: location, geometry: geometry)
            }
            .simultaneousGesture(
                // UNIFIED DRAG GESTURE - FIXED: Use reasonable minimum distance 
                // This prevents tiny movements from interrupting real drags
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        handleUnifiedDragChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleUnifiedDragEnded(value: value, geometry: geometry)
                    }
            )
            .simultaneousGesture(
                // PROFESSIONAL ZOOM GESTURE - Separate from drag to avoid conflicts
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
            // REMOVED: FitCanvasToPage notification - unused dead code (never posted)
    }
    
    // MARK: - Gradient Edit Tool Overlay
    
    @ViewBuilder
    internal func gradientCenterPointOverlay(geometry: GeometryProxy) -> some View {
        // Use the new isolated gradient edit tool
        gradientEditTool(geometry: geometry)
    }
    
    // MARK: - Pressure-Sensitive Overlay
    
    @ViewBuilder
    internal func pressureSensitiveOverlay(geometry: GeometryProxy) -> some View {
        // Only show pressure overlay for drawing tools that use pressure
        if document.currentTool == .brush || document.currentTool == .marker || document.currentTool == .freehand {
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
    
    // MARK: - Pressure Event Handling
    
    private func handlePressureEvent(
        location: CGPoint, 
        pressure: Double, 
        eventType: PressureSensitiveCanvasView.PressureEventType,
        isTabletEvent: Bool,
        geometry: GeometryProxy
    ) {
        Log.info("🎨 PRESSURE EVENT: Received event type: \(eventType)", category: .pressure)
        Log.info("🎨 PRESSURE EVENT: Pressure: \(pressure)", category: .pressure)
        Log.info("🎨 PRESSURE EVENT: Is tablet event: \(isTabletEvent)", category: .pressure)
        Log.info("🎨 PRESSURE EVENT: Current tool: \(document.currentTool)", category: .pressure)
        
        // Convert to canvas coordinates
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        Log.info("🎨 PRESSURE EVENT: Screen location: (\(location.x), \(location.y))", category: .pressure)
        Log.info("🎨 PRESSURE EVENT: Canvas location: (\(canvasLocation.x), \(canvasLocation.y))", category: .pressure)
        
        // Update pressure manager with real pressure data
        PressureManager.shared.processRealPressure(pressure, at: canvasLocation, isTabletEvent: isTabletEvent)
        PressureManager.shared.updatePressureSupport(true)
        
        Log.info("🎨 PRESSURE EVENT: Updated PressureManager", category: .pressure)
        Log.info("🎨 PRESSURE EVENT: Has real pressure input: \(PressureManager.shared.hasRealPressureInput)", category: .pressure)
        Log.info("🎨 PRESSURE EVENT: Current pressure: \(PressureManager.shared.currentPressure)", category: .pressure)
        
        // Route to appropriate tool based on event type and current tool
        switch eventType {
        case .began:
            Log.info("🎨 PRESSURE EVENT: Routing to handlePressureDrawingStart", category: .pressure)
            handlePressureDrawingStart(at: canvasLocation)
        case .changed:
            Log.info("🎨 PRESSURE EVENT: Routing to handlePressureDrawingUpdate", category: .pressure)
            handlePressureDrawingUpdate(at: canvasLocation)
        case .ended:
            Log.info("🎨 PRESSURE EVENT: Routing to handlePressureDrawingEnd", category: .pressure)
            handlePressureDrawingEnd(at: canvasLocation)
        }
    }
    
    private func handlePressureDrawingStart(at location: CGPoint) {
        Log.info("🎨 PRESSURE DRAWING START: Called for tool: \(document.currentTool)", category: .pressure)
        Log.info("🎨 PRESSURE DRAWING START: Is brush drawing: \(isBrushDrawing)", category: .pressure)
        Log.info("🎨 PRESSURE DRAWING START: Is marker drawing: \(isMarkerDrawing)", category: .pressure)
        
        switch document.currentTool {
        case .brush:
            if !isBrushDrawing {
                Log.info("🎨 PRESSURE DRAWING START: Starting brush drawing", category: .pressure)
                handleBrushDragStart(at: location)
            } else {
                Log.info("🎨 PRESSURE DRAWING START: Brush already drawing, skipping start", category: .pressure)
            }
        case .marker:
            if !isMarkerDrawing {
                Log.info("🎨 PRESSURE DRAWING START: Starting marker drawing", category: .pressure)
                handleMarkerDragStart(at: location)
            } else {
                Log.info("🎨 PRESSURE DRAWING START: Marker already drawing, skipping start", category: .pressure)
            }
        case .freehand:
            if !isFreehandDrawing {
                Log.info("🎨 PRESSURE DRAWING START: Starting freehand drawing", category: .pressure)
                handleFreehandDragStart(at: location)
            } else {
                Log.info("🎨 PRESSURE DRAWING START: Freehand already drawing, skipping start", category: .pressure)
            }
        default:
            Log.info("🎨 PRESSURE DRAWING START: Unknown tool, skipping", category: .pressure)
            break
        }
    }
    
    private func handlePressureDrawingUpdate(at location: CGPoint) {
        Log.info("🎨 PRESSURE DRAWING UPDATE: Called for tool: \(document.currentTool)", category: .pressure)
        Log.info("🎨 PRESSURE DRAWING UPDATE: Is brush drawing: \(isBrushDrawing)", category: .pressure)
        Log.info("🎨 PRESSURE DRAWING UPDATE: Is marker drawing: \(isMarkerDrawing)", category: .pressure)
        
        switch document.currentTool {
        case .brush:
            if isBrushDrawing {
                // Brush drag update - logging removed for performance
                handleBrushDragUpdate(at: location)
            } else {
                Log.info("🎨 PRESSURE DRAWING UPDATE: Brush not drawing, skipping update", category: .pressure)
            }
        case .marker:
            if isMarkerDrawing {
                // Marker drag update - logging removed for performance
                handleMarkerDragUpdate(at: location)
            } else {
                Log.info("🎨 PRESSURE DRAWING UPDATE: Marker not drawing, skipping update", category: .pressure)
            }
        case .freehand:
            if isFreehandDrawing {
                // Freehand drag update - logging removed for performance
                handleFreehandDragUpdate(at: location)
            } else {
                Log.info("🎨 PRESSURE DRAWING UPDATE: Freehand not drawing, skipping update", category: .pressure)
            }
        default:
            Log.info("🎨 PRESSURE DRAWING UPDATE: Unknown tool, skipping", category: .pressure)
            break
        }
    }
    
    private func handlePressureDrawingEnd(at location: CGPoint) {
        switch document.currentTool {
        case .brush:
            if isBrushDrawing {
                handleBrushDragEnd()
            }
        case .marker:
            if isMarkerDrawing {
                handleMarkerDragEnd()
            }
        case .freehand:
            if isFreehandDrawing {
                handleFreehandDragEnd()
            }
        default:
            break
        }
    }

    // MARK: - In-App Performance HUD
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

// MARK: - Brush Preview Styling
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
    
    /// VECTOR APP OPTIMIZATION: Render only dragged objects as overlay (no full scene redraw)
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
        case .shape(let shape):
            draggedShapeView(shape, dragDelta: dragDelta)
            // Text handled as VectorShape
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
    
    /// Apply drag offset to shape coordinates without modifying the original
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

// MARK: - Marker Preview Style Modifier

private struct MarkerPreviewStyleModifier: ViewModifier {
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
        // Marker tool always uses fill preview with current marker colors and opacity
        let markerFillColor = document.markerUseFillAsStroke ? document.defaultFillColor.color : document.defaultStrokeColor.color
        let markerOpacity = document.currentMarkerOpacity
        
        Path { p in addPathElements(preview.elements, to: &p) }
            .fill(markerFillColor)
            .opacity(markerOpacity)
    }
}

// MARK: - Freehand Preview Style Modifier

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
        // Freehand tool uses stroke preview with current stroke color and settings
        // Always use round caps and joins for smooth appearance
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