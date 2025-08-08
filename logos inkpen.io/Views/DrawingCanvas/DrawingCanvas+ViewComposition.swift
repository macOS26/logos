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
            .stroke(Color.blue, lineWidth: 1.0)
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
        
        // PROFESSIONAL REAL-TIME BEZIER PATH (Adobe Illustrator style - shows actual path with real colors)
        // Note: Real bezier shapes are now shown as actual VectorShapes in the document
        
        // PROFESSIONAL RUBBER BAND PREVIEW (Adobe Illustrator Standards)
        rubberBandPreview(geometry: geometry)
        
        bezierAnchorPoints()
        bezierControlHandles()
        bezierClosePathHint()
        
        // Selection handles for selected shapes (EXCEPT during pen tool drawing or selection dragging)
        // PROFESSIONAL UX: Hide selection dots during movement (Adobe Illustrator standard)
        // CORNER TOOL FIX: Hide bounding box and selection handles when in corner radius edit mode
        if !(document.currentTool == .bezierPen && isBezierDrawing) && 
           !(document.currentTool == .selection && isDrawing) &&
           !isCornerRadiusEditMode {
            SelectionHandlesView(
                document: document,
                geometry: geometry,
                isShiftPressed: self.isShiftPressed,
                isOptionPressed: self.isOptionPressed
            )
        }
        
        // Real-time dimensions for Bezier tool
        if isBezierDrawing && document.currentTool == .bezierPen {
            bezierDrawingDimensionsOverlay()
        }
        
        // Direct selection points and handles
        // Show direct selection UI for both Direct Selection tool AND Convert Point tool
        if document.currentTool == .directSelection || document.currentTool == .convertAnchorPoint {
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
            
            // Grid (if enabled)
            if document.snapToGrid {
                GridView(document: document, geometry: geometry)
            }
            
            // Render all layers and shapes (including the canvas layer!)
            ForEach(document.layers.indices, id: \.self) { layerIndex in
                if document.layers[layerIndex].isVisible {
                    LayerView(
                        layer: document.layers[layerIndex],
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        selectedShapeIDs: document.selectedShapeIDs,
                        viewMode: document.viewMode,
                        isShiftPressed: self.isShiftPressed,
                        dragPreviewDelta: currentDragDelta,
                        dragPreviewTrigger: dragPreviewUpdateTrigger
                    )
                }
            }
            
            // RENDER TEXT OBJECTS using STABLE view model lifecycle
            ForEach(document.textObjects.indices, id: \.self) { textIndex in
                let textObj = document.textObjects[textIndex]
                if textObj.isVisible {
                    StableProfessionalTextCanvas(
                        document: document,
                        textObjectID: textObj.id,
                        dragPreviewDelta: currentDragDelta,
                        dragPreviewTrigger: dragPreviewUpdateTrigger
                    )
                        .id(textObj.id) // Important: Use the text object ID as the view ID
                        .allowsHitTesting(true) // CRITICAL: Ensure hit testing for resize handles
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
            }
            .onChange(of: document.currentTool) { oldTool, newTool in
                handleToolChange(oldTool: oldTool, newTool: newTool)
            }
            .onHover { isHovering in
                // Enable mouse tracking for rubber band preview
            }
            .onContinuousHover { phase in
                handleHover(phase: phase, geometry: geometry)
            }
            .onTapGesture { location in
                // CRITICAL: Single-click selection (was missing!)
                print("🎯 SINGLE CLICK DETECTED at: \(location)")
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
        if document.currentTool == .brush || document.currentTool == .marker {
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
        print("🎨 PRESSURE EVENT: Received event type: \(eventType)")
        print("🎨 PRESSURE EVENT: Pressure: \(pressure)")
        print("🎨 PRESSURE EVENT: Is tablet event: \(isTabletEvent)")
        print("🎨 PRESSURE EVENT: Current tool: \(document.currentTool)")
        
        // Convert to canvas coordinates
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        print("🎨 PRESSURE EVENT: Screen location: (\(location.x), \(location.y))")
        print("🎨 PRESSURE EVENT: Canvas location: (\(canvasLocation.x), \(canvasLocation.y))")
        
        // Update pressure manager with real pressure data
        PressureManager.shared.processRealPressure(pressure, at: canvasLocation, isTabletEvent: isTabletEvent)
        PressureManager.shared.updatePressureSupport(true)
        
        print("🎨 PRESSURE EVENT: Updated PressureManager")
        print("🎨 PRESSURE EVENT: Has real pressure input: \(PressureManager.shared.hasRealPressureInput)")
        print("🎨 PRESSURE EVENT: Current pressure: \(PressureManager.shared.currentPressure)")
        
        // Route to appropriate tool based on event type and current tool
        switch eventType {
        case .began:
            print("🎨 PRESSURE EVENT: Routing to handlePressureDrawingStart")
            handlePressureDrawingStart(at: canvasLocation)
        case .changed:
            print("🎨 PRESSURE EVENT: Routing to handlePressureDrawingUpdate")
            handlePressureDrawingUpdate(at: canvasLocation)
        case .ended:
            print("🎨 PRESSURE EVENT: Routing to handlePressureDrawingEnd")
            handlePressureDrawingEnd(at: canvasLocation)
        }
    }
    
    private func handlePressureDrawingStart(at location: CGPoint) {
        print("🎨 PRESSURE DRAWING START: Called for tool: \(document.currentTool)")
        print("🎨 PRESSURE DRAWING START: Is brush drawing: \(isBrushDrawing)")
        print("🎨 PRESSURE DRAWING START: Is marker drawing: \(isMarkerDrawing)")
        
        switch document.currentTool {
        case .brush:
            if !isBrushDrawing {
                print("🎨 PRESSURE DRAWING START: Starting brush drawing")
                handleBrushDragStart(at: location)
            } else {
                print("🎨 PRESSURE DRAWING START: Brush already drawing, skipping start")
            }
        case .marker:
            if !isMarkerDrawing {
                print("🎨 PRESSURE DRAWING START: Starting marker drawing")
                handleMarkerDragStart(at: location)
            } else {
                print("🎨 PRESSURE DRAWING START: Marker already drawing, skipping start")
            }
        default:
            print("🎨 PRESSURE DRAWING START: Unknown tool, skipping")
            break
        }
    }
    
    private func handlePressureDrawingUpdate(at location: CGPoint) {
        print("🎨 PRESSURE DRAWING UPDATE: Called for tool: \(document.currentTool)")
        print("🎨 PRESSURE DRAWING UPDATE: Is brush drawing: \(isBrushDrawing)")
        print("🎨 PRESSURE DRAWING UPDATE: Is marker drawing: \(isMarkerDrawing)")
        
        switch document.currentTool {
        case .brush:
            if isBrushDrawing {
                print("🎨 PRESSURE DRAWING UPDATE: Calling handleBrushDragUpdate")
                handleBrushDragUpdate(at: location)
            } else {
                print("🎨 PRESSURE DRAWING UPDATE: Brush not drawing, skipping update")
            }
        case .marker:
            if isMarkerDrawing {
                print("🎨 PRESSURE DRAWING UPDATE: Calling handleMarkerDragUpdate")
                handleMarkerDragUpdate(at: location)
            } else {
                print("🎨 PRESSURE DRAWING UPDATE: Marker not drawing, skipping update")
            }
        default:
            print("🎨 PRESSURE DRAWING UPDATE: Unknown tool, skipping")
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
        default:
            break
        }
    }

} 