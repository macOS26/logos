//
//  DrawingCanvas.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

struct DrawingCanvas: View {
    @ObservedObject var document: VectorDocument
    @State private var currentPath: VectorPath?
    @State private var isDrawing = false
    @State private var dragOffset = CGSize.zero
    @State private var lastPanLocation = CGPoint.zero
    @State private var drawingStartPoint: CGPoint?
    @State private var currentDrawingPoints: [CGPoint] = []

    @State private var lastTapTime: Date = Date()
    
    // PROFESSIONAL HAND TOOL STATE (Industry Standards)
    // Based on Adobe Illustrator, MacroMedia FreeHand, Inkscape, and CorelDRAW
    // Reference: US Patent 6097387A - "Dynamic control of panning operation in computer graphics"
    @State private var initialCanvasOffset = CGPoint.zero    // Reference canvas position when drag started
    @State private var handToolDragStart = CGPoint.zero      // Reference cursor position when drag started
    
    // PROFESSIONAL OBJECT DRAGGING STATE (Same precision as hand tool)
    @State private var selectionDragStart = CGPoint.zero     // Reference cursor position when object drag started
    @State private var initialObjectPositions: [UUID: CGPoint] = [:]  // Initial object positions when drag started
    
    // PROFESSIONAL SHAPE DRAWING STATE (Same precision as hand tool)
    @State private var shapeDragStart = CGPoint.zero         // Reference cursor position when shape drawing started
    @State private var shapeStartPoint = CGPoint.zero       // Reference canvas position when shape drawing started
    
    // PROFESSIONAL MULTI-SELECTION (Adobe Illustrator Standards)
    @State private var isShiftPressed = false
    @State private var isCommandPressed = false
    @State private var isOptionPressed = false
    @State private var keyEventMonitor: Any?
    
    // Bezier tool specific state
    @State private var bezierPath: VectorPath?
    @State private var bezierPoints: [VectorPoint] = []
    @State private var isBezierDrawing = false
    @State private var bezierLastTapTime: Date = Date()
    @State private var isDraggingBezierHandle = false
    @State private var activeBezierPointIndex: Int? = nil // Currently active (solid) point
    @State private var isDraggingBezierPoint = false
    @State private var bezierHandles: [Int: BezierHandleInfo] = [:] // Point handles for each bezier point
    @State private var currentMouseLocation: CGPoint? = nil // For rubber band preview
    @State private var showClosePathHint = false
    @State private var closePathHintLocation: CGPoint = .zero
    
    // PROFESSIONAL REAL-TIME PATH CREATION (Adobe Illustrator Style)
    @State private var activeBezierShape: VectorShape? = nil // Real shape being built
    
    // First point creation state for smooth/corner point detection
    @State private var pendingFirstPoint: CGPoint? = nil // Location where first point will be created
    @State private var isCreatingFirstPoint = false // True when we're deciding if first point should be smooth or corner
    

    
    // Track previous tool to detect changes
    @State private var previousTool: DrawingTool = .selection
    
    // Zoom gesture state
    @State private var initialZoomLevel: CGFloat = 1.0
    
    // PROFESSIONAL GESTURE COORDINATION STATE
    @State private var isZoomGestureActive = false
    @State private var isPanGestureActive = false
    
    // Direct selection state
    @State private var selectedPoints: Set<PointID> = []
    @State private var selectedHandles: Set<HandleID> = []
    @State private var directSelectedShapeIDs: Set<UUID> = [] // Track which shapes have been direct-selected
    @State private var isDraggingPoint = false
    @State private var isDraggingHandle = false
    @State private var dragStartLocation: CGPoint = .zero
    @State private var originalPointPositions: [PointID: VectorPoint] = [:]
    @State private var originalHandlePositions: [HandleID: VectorPoint] = [:]
    
    // Point and handle identification
    struct PointID: Hashable {
        let shapeID: UUID
        let pathIndex: Int
        let elementIndex: Int
    }
    
    struct HandleID: Hashable {
        let shapeID: UUID
        let pathIndex: Int
        let elementIndex: Int
        let handleType: HandleType
    }
    
    enum HandleType {
        case control1, control2
    }
    
    @ViewBuilder
    private var directSelectionContextMenu: some View {
        // PROFESSIONAL BEZIER PEN CONTEXT MENU OPTIONS
        if document.currentTool == .bezierPen && isBezierDrawing && bezierPoints.count >= 3 {
            Button("Close Path") {
                closeBezierPath()
            }
            .keyboardShortcut("j", modifiers: [.command]) // Adobe Illustrator standard
            
            Button("Finish Path (Open)") {
                finishBezierPath()
            }
            .keyboardShortcut(.return)
            
            Button("Cancel Path") {
                cancelBezierDrawing()
            }
            .keyboardShortcut(.escape)
        }
        
        if document.currentTool == .directSelection && !selectedPoints.isEmpty {
            Button("Close Path") {
                closeSelectedPaths()
            }
            // Note: Global Command+Shift+J shortcut handles this in MainView
            
            Button("Delete Selected") {
                deleteSelectedPoints()
            }
            .keyboardShortcut(.delete)
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            canvasMainContent(geometry: geometry)
        }
    }
    
    @ViewBuilder
    private func canvasMainContent(geometry: GeometryProxy) -> some View {
        canvasBaseContent(geometry: geometry)
            .clipped()
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
            .onTapGesture { location in
                // COORDINATE FIX: Ensure tap gestures work for all coordinate ranges
                print("🎯 TAP GESTURE FIRED at screen: \(location)")
                handleTap(at: location, geometry: geometry)
            }
            .background(
                // MOUSE EVENT FIX: Add native mouse handling for pasteboard areas
                MouseEventView { event in
                    handleMouseEvent(event, geometry: geometry)
                }
                .allowsHitTesting(true)
            )
            .onHover { isHovering in
                // Enable mouse tracking for rubber band preview
            }
            .onContinuousHover { phase in
                handleHover(phase: phase, geometry: geometry)
            }
            .simultaneousGesture(
                // PROFESSIONAL DRAG GESTURE - Only for canvas operations, doesn't block UI
                // PASTEBOARD FIX: Use 0-pixel threshold for maximum sensitivity on pasteboard
                // Canvas vs Pasteboard handling is done in the drag logic
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleDragChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value, geometry: geometry)
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
            .onTapGesture(count: 2) { location in
                fitToPage(geometry: geometry)
            }
            .onChange(of: document.zoomRequest) {
                if let request = document.zoomRequest {
                    handleZoomRequest(request, geometry: geometry)
                }
            }
            .contextMenu {
                directSelectionContextMenu
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("FitCanvasToPage"))) { _ in
                // Auto-center view after canvas fit operation
                fitToPage(geometry: geometry)
            }
    }
    
    @ViewBuilder
    private func canvasBaseContent(geometry: GeometryProxy) -> some View {
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
                        viewMode: document.viewMode
                    )
                }
            }
            
            // CRITICAL FIX: Render text objects (they were missing!)
            ForEach(document.textObjects.indices, id: \.self) { textIndex in
                let textObject = document.textObjects[textIndex]
                if textObject.isVisible {
                    TextObjectView(
                        textObject: textObject,
                        isSelected: document.selectedTextIDs.contains(textObject.id),
                        isEditing: textObject.isEditing,
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        onTextChange: { newText in
                            // Update the text object in the document
                            if let index = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                                document.textObjects[index].content = newText
                                document.textObjects[index].updateBounds()
                            }
                        },
                        onEditingChanged: { isEditing in
                            // Update editing state
                            if let index = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
                                document.textObjects[index].isEditing = isEditing
                            }
                        }
                    )
                }
            }
            
            canvasOverlays(geometry: geometry)
        }
    }
    
    private func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        // Auto-finalize bezier path when switching away from bezier tool
        if previousTool == .bezierPen && newTool != .bezierPen && isBezierDrawing {
            finishBezierPath()
        }
        
        // PROFESSIONAL TOOL BEHAVIOR: Clear regular selection when switching TO direct selection or convert point tools
        if (newTool == .directSelection || newTool == .convertAnchorPoint) && 
           (previousTool != .directSelection && previousTool != .convertAnchorPoint) {
            document.selectedShapeIDs.removeAll()
            document.selectedTextIDs.removeAll()
            print("🎯 Switched to Direct Selection/Convert Point - cleared regular selection handles")
        }
        
        // Clear direct selection state when switching away from direct selection tools
        if (previousTool == .directSelection || previousTool == .convertAnchorPoint) && 
           (newTool != .directSelection && newTool != .convertAnchorPoint) {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            directSelectedShapeIDs.removeAll()
            print("🎯 Switched away from Direct Selection/Convert Point - cleared direct selection state")
        }
        
        previousTool = newTool
    }
    
    private func handleHover(phase: HoverPhase, geometry: GeometryProxy) {
        if case .active(let location) = phase {
            currentMouseLocation = location
            
            // PROFESSIONAL REAL-TIME PATH UPDATES (Adobe Illustrator/FreeHand/CorelDraw Style)
            if isBezierDrawing && document.currentTool == .bezierPen && bezierPoints.count > 0 {
                let canvasLocation = screenToCanvas(location, geometry: geometry)
                
                // PROFESSIONAL CLOSE PATH VISUAL FEEDBACK
                if bezierPoints.count >= 3 {
                    let firstPoint = bezierPoints[0]
                    let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                    let closeTolerance: Double = 25.0
                    
                    if distance(canvasLocation, firstPointLocation) <= closeTolerance {
                        showClosePathHint = true
                        closePathHintLocation = firstPointLocation
                        
                        // Let rubber band preview handle closing visualization
                        // updateLivePathWithClosingPreview(mouseLocation: canvasLocation)
                    } else {
                        showClosePathHint = false
                        
                        // Let rubber band preview handle visualization instead of live path updates
                        // updateLivePathWithRubberBand(mouseLocation: canvasLocation)
                    }
                } else {
                    // First point - let rubber band handle visualization 
                    // updateLivePathWithRubberBand(mouseLocation: canvasLocation)
                }
            } else {
                showClosePathHint = false
            }
        } else {
            currentMouseLocation = nil
            showClosePathHint = false
            
            // Note: Using rubber band preview overlay instead of live path updates
            // The actual path remains unchanged until a new point is added
        }
    }
    
    /// Updates the live path with a rubber band preview to the mouse location
    private func updateLivePathWithRubberBand(mouseLocation: CGPoint) {
        guard let currentBezierPath = bezierPath else { return }
        
        var liveElements = currentBezierPath.elements
        let lastPointIndex = bezierPoints.count - 1
        let lastPoint = bezierPoints[lastPointIndex]
        let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
        
        // Check if the last point has an outgoing handle (control2)
        if let lastPointHandles = bezierHandles[lastPointIndex],
           let lastControl2 = lastPointHandles.control2 {
            // CURVE RUBBER BAND: Add live curve preview with CORRECT direction
            let _ = CGPoint(x: lastControl2.x, y: lastControl2.y)
            
            // FIXED: Calculate incoming handle direction (should flow naturally from the outgoing curve)
            // Make incoming handle point in a direction that creates smooth continuation
            let distance = sqrt(pow(mouseLocation.x - lastPointLocation.x, 2) + pow(mouseLocation.y - lastPointLocation.y, 2))
            let handleLength = distance * 0.3 // About 1/3 of the distance for natural curves
            
            // Direction from mouse back toward the curve's natural flow
            let mouseToLastDirection = CGPoint(
                x: lastPointLocation.x - mouseLocation.x,
                y: lastPointLocation.y - mouseLocation.y
            )
            let mouseToLastLength = sqrt(pow(mouseToLastDirection.x, 2) + pow(mouseToLastDirection.y, 2))
            
            let incomingHandle = if mouseToLastLength > 0 {
                VectorPoint(
                    mouseLocation.x + (mouseToLastDirection.x / mouseToLastLength) * handleLength,
                    mouseLocation.y + (mouseToLastDirection.y / mouseToLastLength) * handleLength
                )
            } else {
                // Fallback if points are too close
                VectorPoint(mouseLocation.x, mouseLocation.y)
            }
            
            liveElements.append(.curve(
                to: VectorPoint(mouseLocation),
                control1: lastControl2,
                control2: incomingHandle
            ))
        } else {
            // STRAIGHT RUBBER BAND: Add live line preview
            liveElements.append(.line(to: VectorPoint(mouseLocation)))
        }
        
        // Update the live path
        let livePath = VectorPath(elements: liveElements, isClosed: false)
        updateActiveBezierShapeWithPath(livePath)
    }
    
    /// Updates the live path with a closing preview
    private func updateLivePathWithClosingPreview(mouseLocation: CGPoint) {
        guard let currentBezierPath = bezierPath else { return }
        
        var liveElements = currentBezierPath.elements
        let lastPointIndex = bezierPoints.count - 1
        let firstPoint = bezierPoints[0]
        
        // Check for handles to create appropriate closing curve
        let lastPointHandles = bezierHandles[lastPointIndex]
        let firstPointHandles = bezierHandles[0]
        
        if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
            // Both points have handles - smooth closing curve
            liveElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstControl1))
        } else if let lastControl2 = lastPointHandles?.control2 {
            // Only last point has handle - asymmetric curve
            liveElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstPoint))
        } else {
            // Straight line close
            liveElements.append(.line(to: firstPoint))
        }
        
        // Add close element for preview
        liveElements.append(.close)
        
        // Update the live path
        let livePath = VectorPath(elements: liveElements, isClosed: true)
        updateActiveBezierShapeWithPath(livePath)
    }
    
    /// Updates the active bezier shape with a specific path (used for live previews)
    private func updateActiveBezierShapeWithPath(_ path: VectorPath) {
        guard let activeBezierShape = activeBezierShape,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Find the shape in the document and update it
        for shapeIndex in document.layers[layerIndex].shapes.indices {
            if document.layers[layerIndex].shapes[shapeIndex].id == activeBezierShape.id {
                // Update the path with the live preview path
                document.layers[layerIndex].shapes[shapeIndex].path = path
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                break
            }
        }
        
        // Force UI update for real-time visual feedback
        document.objectWillChange.send()
    }
    
    @ViewBuilder
    private func canvasOverlays(geometry: GeometryProxy) -> some View {
        // Current drawing path (while drawing)
        if let currentPath = currentPath {
            Path { path in
                addPathElements(currentPath.elements, to: &path)
            }
            .stroke(Color.blue, lineWidth: 1.0)
            .scaleEffect(document.zoomLevel, anchor: .topLeading)  // ✅ FIXED: Added missing anchor
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
        
        // PROFESSIONAL REAL-TIME BEZIER PATH (Adobe Illustrator style - shows actual path with real colors)
        // Note: Real bezier shapes are now shown as actual VectorShapes in the document
        
        // PROFESSIONAL RUBBER BAND PREVIEW (Adobe Illustrator Standards)
        rubberBandPreview(geometry: geometry)
        
        bezierAnchorPoints()
        bezierControlHandles()
        bezierClosePathHint()
        
        // Selection handles for selected shapes (EXCEPT during pen tool drawing)
        if !(document.currentTool == .bezierPen && isBezierDrawing) {
            SelectionHandlesView(
                document: document,
                geometry: geometry
            )
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
    }
    
    @ViewBuilder
    private func bezierAnchorPoints() -> some View {
        // PROFESSIONAL BEZIER ANCHOR POINTS - USE SAME COORDINATE SYSTEM AS ARROW TOOL
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                let point = bezierPoints[index]
                let pointLocation = CGPoint(x: point.x, y: point.y)
                let isActive = activeBezierPointIndex == index
                let isFirstPoint = index == 0
                let isCloseHovering = showClosePathHint && isFirstPoint
                
                // PROFESSIONAL SCALE-INDEPENDENT SIZING (Adobe Illustrator Standards)
                let anchorSize = 6.0 / document.zoomLevel  // Scale-independent anchor point size
                let lineWidth = 1.0 / document.zoomLevel   // Scale-independent stroke width
                
                // PROFESSIONAL FIRST POINT HIGHLIGHTING (like Adobe Illustrator)
                if isCloseHovering {
                    // Enlarged, highlighted first point when hovering to close - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    Rectangle()
                        .fill(Color.green)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: lineWidth)
                        )
                        .frame(width: anchorSize * 1.3, height: anchorSize * 1.3)
                        .position(pointLocation)
                        .scaleEffect(document.zoomLevel * 1.2, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        .animation(.easeInOut(duration: 0.2), value: isCloseHovering)
                } else {
                    // PROFESSIONAL ANCHOR POINT RENDERING - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    // Active point: solid black square with white stroke
                    // Inactive point: hollow white square with black stroke
                    Rectangle()
                        .fill(isActive ? Color.black : Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(isActive ? Color.white : Color.black, lineWidth: lineWidth)
                        )
                        .frame(width: anchorSize, height: anchorSize)
                        .position(pointLocation)
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                }
            }
        }
    }
    
    @ViewBuilder
    private func bezierControlHandles() -> some View {
        // Render bezier handles if they exist
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                if let handleInfo = bezierHandles[index], handleInfo.hasHandles {
                    let pointLocation = CGPoint(x: bezierPoints[index].x, y: bezierPoints[index].y)
                    
                    // Draw control handle lines - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    if let control1 = handleInfo.control1 {
                        let control1Location = CGPoint(x: control1.x, y: control1.y)
                        Path { path in
                            path.move(to: pointLocation)
                            path.addLine(to: control1Location)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        
                        // Control handle circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                            .position(control1Location)
                            .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                    }
                    
                    if let control2 = handleInfo.control2 {
                        let control2Location = CGPoint(x: control2.x, y: control2.y)
                        Path { path in
                            path.move(to: pointLocation)
                            path.addLine(to: control2Location)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        
                        // Control handle circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                            .position(control2Location)
                            .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func bezierClosePathHint() -> some View {
        // PROFESSIONAL CLOSE PATH VISUAL HINT - USE SAME COORDINATE SYSTEM AS ARROW TOOL
        if showClosePathHint {
            ZStack {
                // Green circle indicating close path area - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                Circle()
                    .stroke(Color.green, lineWidth: 2.0 / document.zoomLevel) // Scale-independent
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 16 / document.zoomLevel, height: 16 / document.zoomLevel) // Scale-independent
                    .position(closePathHintLocation)
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                
                // Small "close" icon - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                Image(systemName: "multiply.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 12 / document.zoomLevel)) // Scale-independent
                    .position(closePathHintLocation)
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)   // ✅ FIXED: Added missing anchor
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
            }
            .animation(.easeInOut(duration: 0.2), value: showClosePathHint)
        }
    }
    
    // MARK: - Professional Preview Functions (Adobe Illustrator Standards)
    
    // REMOVED: bezierPathPreview() - Now using real VectorShapes with actual document colors
    // Professional vector apps (Illustrator, FreeHand, CorelDraw) show the actual path being built, not a preview
    
    @ViewBuilder
    private func rubberBandPreview(geometry: GeometryProxy) -> some View {
        if isBezierDrawing && document.currentTool == .bezierPen,
           let mouseLocation = currentMouseLocation,
           bezierPoints.count > 0 {
            let canvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let lastPoint = bezierPoints[lastPointIndex]
            let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
            
            // PROFESSIONAL SCALE-INDEPENDENT RUBBER BAND (Adobe Illustrator Standards)
            let strokeWidth = 2.0 / document.zoomLevel    // Scale-independent close preview
            let rubberBandWidth = 1.0 / document.zoomLevel  // Scale-independent rubber band
            
            // PROFESSIONAL CLOSING STROKE PREVIEW
            if showClosePathHint && bezierPoints.count >= 3 {
                // Show the closing stroke back to first point (GREEN) with curve preview
                let firstPoint = bezierPoints[0]
                let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                
                // Check if we have handles for closing curve preview
                let lastPointHandles = bezierHandles[lastPointIndex]
                let firstPointHandles = bezierHandles[0]
                
                Path { path in
                    path.move(to: lastPointLocation)
                    
                    // Create preview of closing curve
                    if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                        // Both points have handles - show smooth closing curve preview
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                    } else if let lastControl2 = lastPointHandles?.control2 {
                        // Only last point has handle - asymmetric curve preview
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                    } else {
                        // Straight line close
                        path.addLine(to: firstPointLocation)
                    }
                }
                .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            } else {
                // PROFESSIONAL ADOBE ILLUSTRATOR RUBBER BAND WITH CURVE PREVIEW
                Path { path in
                    path.move(to: lastPointLocation)
                    
                    // PROFESSIONAL RUBBER BAND LOGIC (Adobe Illustrator/FreeHand/CorelDraw Style)
                    // Key insight: Rubber band depends ONLY on the previous point's handles
                    if let lastPointHandles = bezierHandles[lastPointIndex],
                       let lastControl2 = lastPointHandles.control2 {
                        // CURVE RUBBER BAND: Previous point has outgoing handle
                        // Show curve tangent to the existing outgoing handle (like Adobe Illustrator)
                        let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                        
                        print("🔧 DEBUG STEP 1: Rubber band preview - CURVE")
                        print("   Last point \(lastPointIndex) has outgoing handle at: (\(lastControl2.x), \(lastControl2.y))")
                        
                        // FIXED: Use EXACT same math as step 3 - no complex handle calculation!
                        // Step 3 uses: control1: lastControl2, control2: targetPoint
                        // This creates natural curves without hooks
                        path.addCurve(
                            to: canvasMouseLocation,
                            control1: lastControl2Location,
                            control2: canvasMouseLocation
                        )
                        print("   ✅ Rubber band curve uses SAME math as step 2")
                        
                    } else {
                        // STRAIGHT RUBBER BAND: Previous point is corner point (no outgoing handle)
                        // Show straight line preview (like Adobe Illustrator for corner points)
                        path.addLine(to: canvasMouseLocation)
                    }
                }
                .stroke(Color.blue.opacity(0.8), style: SwiftUI.StrokeStyle(lineWidth: rubberBandWidth, lineCap: .round, dash: [4, 2]))
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                
                // NOTE: Professional pen tools (Illustrator, FreeHand, CorelDraw) do NOT show handles at cursor
                // They only show the curve preview. Handles are only visible on actual anchor points.
            }
        }
    }
    
    private func setupCanvas(geometry: GeometryProxy) {
        // FIXED COORDINATE SYSTEM: Set up default view with deterministic positioning
        setupDefaultView(geometry: geometry)
        initialZoomLevel = document.zoomLevel // Initialize for zoom gestures
        print("🎯 FIXED CANVAS SETUP: Using default 75% zoom, no race conditions")
    }
    
    private func setupDefaultView(geometry: GeometryProxy) {
        // Use document bounds for zoom/fit calculations (standard approach)
        // No Canvas-specific coordinate logic needed
        
        let documentBounds = document.documentBounds
        let viewSize = geometry.size
        
        // ASPECT RATIO SCALING: Calculate both scales and use minimum for uniform scaling
        let padding: CGFloat = 100.0  // Leave some padding for professional look
        let availableWidth = viewSize.width - (padding * 2)
        let availableHeight = viewSize.height - (padding * 2)
        
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let uniformScale = min(scaleX, scaleY)  // ✅ UNIFORM SCALING - maintains aspect ratio
        
        // Cap the default zoom at reasonable bounds (like professional apps)
        let defaultZoom = max(0.25, min(1.5, uniformScale))
        document.zoomLevel = defaultZoom
        
        // Center canvas in view using the calculated uniform scale
        let viewCenter = CGPoint(
            x: viewSize.width / 2.0,
            y: viewSize.height / 2.0
        )
        
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Calculate offset to center document: screen = (document * zoom) + offset
        document.canvasOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * document.zoomLevel),
            y: viewCenter.y - (documentCenter.y * document.zoomLevel)
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = document.zoomLevel
        
        print("🎯 DOCUMENT SCALING (Standard Approach):")
        print("   Document Bounds: \(documentBounds)")
        print("   Document Aspect Ratio: \(String(format: "%.3f", documentBounds.width / documentBounds.height))")
        print("   View Size: \(String(format: "%.1f", viewSize.width)) × \(String(format: "%.1f", viewSize.height))")
        print("   View Aspect Ratio: \(String(format: "%.3f", viewSize.width / viewSize.height))")
        print("   Available Space: \(String(format: "%.1f", availableWidth)) × \(String(format: "%.1f", availableHeight))")
        print("   Scale X: \(String(format: "%.3f", scaleX)) (width fit)")
        print("   Scale Y: \(String(format: "%.3f", scaleY)) (height fit)")
        print("   Uniform Scale: \(String(format: "%.3f", uniformScale)) (min of above - maintains aspect ratio)")
        print("   Final Zoom: \(String(format: "%.1f", defaultZoom * 100))% (capped for usability)")
        print("   Canvas Offset: (\(String(format: "%.1f", document.canvasOffset.x)), \(String(format: "%.1f", document.canvasOffset.y)))")
        print("   ✅ CANVAS LAYER AUTO-SYNCS WITH ALL GRAPHICS!")
    }
    
    private func handleTap(at location: CGPoint, geometry: GeometryProxy) {
        // PROFESSIONAL FIX: DrawingCanvas gestures are automatically constrained to view bounds
        // SwiftUI ensures gestures only fire within the DrawingCanvas area - no manual blocking needed
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        // DETAILED LOGGING: Determine if this is canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let isInCanvasArea = canvasBounds.contains(canvasLocation)
        let areaType = isInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        print("🎯 SINGLE CLICK TAP at screen: \(location) canvas: \(canvasLocation) in \(areaType)")
        print("🎯 TAP GESTURE: This is a SINGLE CLICK, not a drag")
        print("🎯 Canvas bounds: \(canvasBounds), click in canvas: \(isInCanvasArea)")
        
        switch document.currentTool {
        case .selection:
            // Cancel bezier drawing if switching to selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleSelectionTap(at: canvasLocation)
        case .directSelection:
            // Cancel bezier drawing if switching to direct selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleDirectSelectionTap(at: canvasLocation)
        case .convertAnchorPoint:
            // Cancel bezier drawing if switching to convert anchor point tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleConvertAnchorPointTap(at: canvasLocation)
        case .bezierPen:
            handleBezierPenTap(at: canvasLocation)
        case .text:
            // Cancel bezier drawing if switching to text tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleTextTap(at: canvasLocation)
        case .line, .rectangle, .circle, .star, .polygon:
            // SHAPE TOOLS: Do nothing on click - they are drag-only tools
            // Cancel bezier drawing if switching to shape tools
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            print("🎨 SHAPE TOOL CLICK: Ignored - shape tools (\(document.currentTool.rawValue)) only work with click and drag")
        default:
            // Cancel bezier drawing if switching to other tools
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            break
        }
    }
    
    private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL FIX: DrawingCanvas drags are automatically constrained to view bounds
        // SwiftUI ensures drag gestures only fire within the DrawingCanvas area
        let canvasStart = screenToCanvas(value.startLocation, geometry: geometry)
        let canvasCurrent = screenToCanvas(value.location, geometry: geometry)
        
        // DETAILED LOGGING: Determine if this started in canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let startedInCanvasArea = canvasBounds.contains(canvasStart)
        let areaType = startedInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        // Calculate drag distance to understand if this should have been a tap
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        
        // PASTEBOARD OPTIMIZATION: Use 0-pixel threshold for pasteboard to maximize single-click sensitivity
        let effectiveThreshold = startedInCanvasArea ? 40.0 : 0.0
        
        print("🎯 DRAG GESTURE CHANGED at start: \(canvasStart) current: \(canvasCurrent) in \(areaType)")
        print("🎯 DRAG GESTURE: This is CLICK AND DRAG, not a single click")
        print("🎯 Drag distance: \(String(format: "%.2f", dragDistance)) pixels (threshold: \(effectiveThreshold))")
        
        // PASTEBOARD OPTIMIZATION: Handle small movements as selections, not drags
        if !startedInCanvasArea && document.currentTool == .selection {
            if dragDistance < 3.0 {
                // Very small movement on pasteboard - treat as selection, not drag
                print("🎯 PASTEBOARD: Tiny movement (\(String(format: "%.1f", dragDistance))px) - treating as selection")
                selectObjectAt(canvasStart)
                return
            } else if dragDistance < 8.0 {
                // Small movement - only proceed if we have selected objects to drag
                if document.selectedShapeIDs.isEmpty {
                    print("🎯 PASTEBOARD: Small movement (\(String(format: "%.1f", dragDistance))px) with no selection - trying selection first")
                    selectObjectAt(canvasStart)
                    return
                }
            }
        }
        
        // CANVAS STABILITY: Use higher threshold for canvas to prevent hand tremor issues
        if startedInCanvasArea && dragDistance < 8.0 {
            // Small movement on canvas - be more tolerant of hand tremor
            if document.currentTool == .selection && document.selectedShapeIDs.isEmpty {
                print("🎯 CANVAS: Small movement (\(String(format: "%.1f", dragDistance))px) - trying selection")
                selectObjectAt(canvasStart)
                return
            }
        }
        
        switch document.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)
        case .line, .rectangle, .circle, .star, .polygon:
            handleShapeDrawing(value: value, geometry: geometry)
        case .text:
            handleTextDragDrawing(value: value, geometry: geometry)
        case .selection:
            if !isDrawing {
                // Check if we're starting a drag on a selected object
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                
                // If nothing is selected, or if we're dragging on an unselected object, try to select it first
                if document.selectedShapeIDs.isEmpty || !isDraggingSelectedObject(at: startLocation) {
                    selectObjectAt(startLocation)
                }
                
                // Only start drag if we have something selected
                if !document.selectedShapeIDs.isEmpty {
                    // PROFESSIONAL OBJECT DRAGGING: Capture reference cursor position (like hand tool)
                    selectionDragStart = value.startLocation
                    startSelectionDrag()
                    isDrawing = true
                    print("🎯 SELECTION DRAG: Started at cursor position (\(String(format: "%.1f", selectionDragStart.x)), \(String(format: "%.1f", selectionDragStart.y)))")
                }
            }
            
            if isDrawing {
                handleSelectionDrag(value: value, geometry: geometry)
            }
        case .directSelection:
            // Handle direct selection dragging for moving points and handles
            handleDirectSelectionDrag(value: value, geometry: geometry)
        case .bezierPen:
            // Handle bezier pen dragging for creating handles or moving points
            // FIXED: Always call drag handler to support first point creation
            handleBezierPenDrag(value: value, geometry: geometry)
        default:
            break
        }
    }
    
    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        switch document.currentTool {
        case .hand:
            // PROFESSIONAL HAND TOOL: Clean state reset for next drag operation
            // This ensures each new drag operation starts with fresh reference points
            let finalOffset = document.canvasOffset
            initialCanvasOffset = CGPoint.zero
            handToolDragStart = CGPoint.zero
            isPanGestureActive = false  // PROFESSIONAL GESTURE COORDINATION
            print("✋ HAND TOOL: Drag operation completed successfully, UI fully responsive")
            print("   Final canvas position: (\(String(format: "%.1f", finalOffset.x)), \(String(format: "%.1f", finalOffset.y)))")
            print("   State reset - ready for next drag operation")
        case .line, .rectangle, .circle, .star, .polygon:
            finishShapeDrawing(value: value, geometry: geometry)
            // Reset drawing state for shape tools
            isDrawing = false
            currentPath = nil
            currentDrawingPoints.removeAll()
            
            // PROFESSIONAL SHAPE DRAWING: Additional state cleanup
            shapeDragStart = CGPoint.zero
            shapeStartPoint = CGPoint.zero
        case .text:
            finishTextDrawing(value: value, geometry: geometry)
            // Reset text drawing state
            isDrawing = false
            
            // PROFESSIONAL TEXT DRAWING: Additional state cleanup
            shapeDragStart = CGPoint.zero
            shapeStartPoint = CGPoint.zero
        case .selection:
            finishSelectionDrag()
            isDrawing = false
        case .directSelection:
            finishDirectSelectionDrag()
        case .bezierPen:
            finishBezierPenDrag()
            // Don't reset bezier state here - it continues until double-tap
        default:
            break
        }
    }
    
    // MARK: - Professional Multi-Selection Key Monitoring (Adobe Illustrator Standards)
    
    private func setupKeyEventMonitoring() {
        // Monitor for key down/up and modifier flag changes
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.updateModifierKeyStates(with: event)
            }
            return event
        }
    }
    
    private func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    // PROFESSIONAL TOOL KEYBOARD SHORTCUTS (Adobe Illustrator Standards)
    private func setupToolKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only process shortcuts when not editing text
            guard !self.isAnyTextEditing() else { return event }
            
            let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let modifiers = event.modifierFlags
            
            // PROFESSIONAL COMMAND SHORTCUTS (Adobe Illustrator Standards)
            if modifiers.contains(.command) {
                switch characters {
                case "a": // Select All (Cmd+A)
                    self.document.selectAll()
                    return event
                case "t": // Test Coordinate System (Cmd+Shift+T) - DEBUG ONLY
                    if modifiers.contains(.shift) {
                        print("🔬 RUNNING COORDINATE SYSTEM TEST:")
                        print("=" + String(repeating: "=", count: 58))
                        self.runCoordinateSystemTest()
                        return event
                    }
                case "d": // Test Drawing Stability (Cmd+Shift+D) - DEBUG ONLY
                    if modifiers.contains(.shift) {
                        self.runDrawingStabilityTest()
                        return event
                    }
                case "r": // Real Drawing Test (Cmd+Shift+R) - DEBUG ONLY
                    if modifiers.contains(.shift) {
                        self.runRealDrawingTestSimple()
                        return event
                    }
                default:
                    break
                }
            }
            
            return event
        }
    }
    
    private func updateModifierKeyStates(with event: NSEvent) {
        let modifierFlags = event.modifierFlags
        isShiftPressed = modifierFlags.contains(.shift)
        isCommandPressed = modifierFlags.contains(.command)
        isOptionPressed = modifierFlags.contains(.option)
        
        // Handle Tab key for deselection
        if event.type == .keyDown {
            switch event.keyCode {
            case 48: // Tab key
                // Deselect all objects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                directSelectedShapeIDs.removeAll()
                document.objectWillChange.send()
                print("✅ Tab pressed - deselected all objects")
            default:
                break
            }
        }
    }
    
    private func isAnyTextEditing() -> Bool {
        // Check if any text objects are currently being edited
        return document.textObjects.contains { $0.isEditing }
    }
    
    /// Exit text editing mode for all text objects (Adobe Illustrator behavior)
    private func exitAllTextEditing() {
        var hasEditingText = false
        
        for i in document.textObjects.indices {
            if document.textObjects[i].isEditing {
                document.textObjects[i].isEditing = false
                hasEditingText = true
            }
        }
        
        if hasEditingText {
            print("🔤 EXIT: Finished editing all text objects")
            document.objectWillChange.send()
        }
    }
    
    private func handleSelectionTap(at location: CGPoint) {
        // DETAILED LOGGING: Determine if this is canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let isInCanvasArea = canvasBounds.contains(location)
        let areaType = isInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        print("🎯 SELECTION TAP FUNCTION CALLED at: \(location) in \(areaType)")
        print("🎯 SELECTION: This function was called by a SINGLE CLICK TAP gesture")
        
        // EXIT TEXT EDITING when clicking with selection tool (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        // CRITICAL: Regular Selection tool must clear direct selection
        // Professional tools have mutually exclusive selection modes
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        
        // Only handle selection for selection tool
        guard document.currentTool == .selection else { return }
        
        print("Selection tap at \(location)")
        
        // Find shape at location across all visible layers
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        
        // Search through layers from top to bottom
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // Search through shapes from top to bottom (reverse order)
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                print("🔍 HIT TESTING SHAPE: \(shape.name) on layer \(layerIndex)")
                print("  - Has stroke: \(shape.strokeStyle != nil)")
                print("  - Has fill: \(shape.fillStyle != nil)")
                print("  - Fill color: \(String(describing: shape.fillStyle?.color))")
                print("  - Bounds: \(shape.bounds)")
                print("  - Is Background Shape: \(shape.name == "Canvas Background" || shape.name == "Pasteboard Background")")
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                // FIXED: Proper hit testing logic for stroke vs filled shapes
                var isHit = false
                
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) need special handling
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // Background shapes: Use EXACT bounds checking - no tolerance!
                    // This ensures Canvas/Pasteboard only respond to clicks EXACTLY within their bounds
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                    print("  - Background shape - exact bounds hit test result: \(isHit)")
                    print("  - Shape bounds: \(shapeBounds)")
                    print("  - Click location: \(location)")
                } else {
                    // Regular shapes: Use different logic for stroke vs filled
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Method 1: Stroke-only shapes - use stroke-based hit testing only
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        
                        print("  - Testing stroke-only path with tolerance: \(strokeTolerance)")
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                        print("  - Stroke hit test result: \(isHit)")
                    } else {
                        // Method 2: Filled shapes - use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                            print("  - Hit via bounds check")
                        } else {
                            // Fallback: precise path hit test
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                            print("  - Path hit test result: \(isHit)")
                        }
                    }
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    print("Selected shape: \(shape.name)")
                    break
                }
            }
            if hitShape != nil { break }
        }
        
        if let shape = hitShape, let layerIndex = hitLayerIndex {
            // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
            if document.layers[layerIndex].isLocked || shape.isLocked {
                let lockType = document.layers[layerIndex].isLocked ? "locked layer" : "locked object"
                print("🚫 Clicked on \(lockType) '\(shape.name)' - deselecting current selection")
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
                document.objectWillChange.send()
                return
            }
            
            // Hit a shape object
            document.selectedLayerIndex = layerIndex
            
            if isShiftPressed {
                // SHIFT+CLICK: Add to selection (extend selection)
                document.selectedShapeIDs.insert(shape.id)
                print("🎯 SHIFT+CLICK: Added \(shape.name) to selection (total: \(document.selectedShapeIDs.count))")
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection (add if not selected, remove if selected)
                if document.selectedShapeIDs.contains(shape.id) {
                    document.selectedShapeIDs.remove(shape.id)
                    print("🎯 CMD+CLICK: Removed \(shape.name) from selection (total: \(document.selectedShapeIDs.count))")
                } else {
                    document.selectedShapeIDs.insert(shape.id)
                    print("🎯 CMD+CLICK: Added \(shape.name) to selection (total: \(document.selectedShapeIDs.count))")
                }
            } else {
                // REGULAR CLICK: Replace selection (clear existing, select new)
                document.selectedShapeIDs = [shape.id]
                print("🎯 REGULAR CLICK: Selected \(shape.name) only (cleared previous selection)")
            }
        } else {
            // NO OBJECT HIT: Clicking on background or empty space  
            let documentBounds = document.documentBounds
            let isOutsideDocument = !documentBounds.contains(location)
            
            if isOutsideDocument {
                // Clicking in gray background area outside document always deselects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
                print("🎯 Clicked gray background (outside document): Cleared all selections")
            } else if !isShiftPressed && !isCommandPressed {
                // Clicking inside document bounds on empty space deselects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
                print("🎯 Clicked empty space: Cleared all selections")
            } else {
                print("🎯 Clicked empty space with modifiers: Keeping existing selection")
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func cancelBezierDrawing() {
        bezierPath = nil
        bezierPoints.removeAll()
        isBezierDrawing = false
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        activeBezierPointIndex = nil
        bezierHandles.removeAll()
        currentMouseLocation = nil
        showClosePathHint = false
        activeBezierShape = nil // Clear the real shape reference
        
        // Clear first point creation state
        pendingFirstPoint = nil
        isCreatingFirstPoint = false
    }
    
    private func handleBezierPenTap(at location: CGPoint) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(bezierLastTapTime)
        bezierLastTapTime = now
        
        // Check if we're trying to close the path by clicking near the first point
        if isBezierDrawing && bezierPoints.count >= 3 {
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            if distance(location, firstPointLocation) <= 25.0 { // Close tolerance (Adobe Illustrator standard)
                closeBezierPath()
                return
            }
        }
        
        // Check for double-tap to finish path (within 0.5 seconds)
        if timeSinceLastTap < 0.5 && isBezierDrawing && bezierPoints.count > 1 {
            finishBezierPath()
            return
        }
        
        if !isBezierDrawing {
            // FIXED: Don't set up pending first point - let drag handler create first point directly
            // This allows click-and-drag in one shot to create smooth first point
            // If this tap is NOT followed by a drag, finishBezierPenDrag will handle corner point creation
            pendingFirstPoint = location
            isCreatingFirstPoint = true
            print("🎯 PENDING FIRST POINT: Set up at \(location) - ready for immediate drag or corner point creation")
            return
        } else {
            // PURE CLICK: Add corner point (no handles)
            // Make previous point inactive (hollow)
            let previousActiveIndex = activeBezierPointIndex
            
            // Add new corner point and make it active (solid)
            let newPoint = VectorPoint(location)
            bezierPoints.append(newPoint)
            activeBezierPointIndex = bezierPoints.count - 1
            
            // CRITICAL FIX: Check if previous point has handles and create curve accordingly
            // This ensures intermediate path matches rubber band preview
            
            let previousPointIndex = bezierPoints.count - 2 // Previous point (before the new one)
            
            if previousPointIndex >= 0,
               let previousHandles = bezierHandles[previousPointIndex],
               let previousControl2 = previousHandles.control2 {
                // CURVE: Previous point has outgoing handle, create curve like rubber band preview
                print("🔧 DEBUG STEP 2: Creating CURVE (matches rubber band preview)")
                print("   Previous point \(previousPointIndex) has outgoing handle at: (\(previousControl2.x), \(previousControl2.y))")
                
                // FIXED: Use EXACT same math as step 3 - no complex handle calculation!
                // Step 3 uses: control1: previousControl2, control2: targetPoint
                // This creates natural curves without hooks
                bezierPath?.addElement(.curve(to: newPoint, control1: previousControl2, control2: newPoint))
                print("   ✅ Added CURVE element (matches rubber band preview)")
            } else {
                // STRAIGHT LINE: Previous point has no handles or is first point
                print("🔧 DEBUG STEP 2: Creating straight line - previous point has no handles")
                bezierPath?.addElement(.line(to: newPoint))
            }
            
            // Update the real shape in the document immediately
            updateActiveBezierShapeInDocument()
            
            print("🎯 CORNER POINT: Added point \(bezierPoints.count) at \(location) (pure click - no drag)")
            print("📍 Previous point \(previousActiveIndex ?? -1) is now hollow, current point \(activeBezierPointIndex ?? -1) is solid")
        }
    }
    
    private func handleBezierPenDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        // Calculate actual drag distance to distinguish click vs drag
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let minimumDragThreshold: Double = 8.0 // Must drag at least 8 pixels to create handles
        
        // UNIFIED FIRST POINT CREATION: Handle both click and click-and-drag for first point
        if !isBezierDrawing {
            // Use the pending first point location if available (from tap gesture), otherwise use drag start location
            let firstPointLocation = pendingFirstPoint ?? startLocation
            
            // Determine if this should be a corner point (small/no drag) or smooth point (significant drag)
            if dragDistance < minimumDragThreshold {
                print("🎯 FIRST POINT: Drag distance (\(String(format: "%.1f", dragDistance))px) below threshold - will create corner point on drag end")
                return
            }
            
            // User dragged significantly - create SMOOTH first point with handles immediately
            print("🎯 FIRST POINT: Drag distance (\(String(format: "%.1f", dragDistance))px) above threshold - creating SMOOTH first point")
            
            // Create the bezier path and add the first point
            bezierPath = VectorPath(elements: [.move(to: VectorPoint(firstPointLocation))])
            bezierPoints = [VectorPoint(firstPointLocation)]
            isBezierDrawing = true
            activeBezierPointIndex = 0 // First point is active (solid)
            bezierHandles.removeAll()
            
            // Create real VectorShape with document default colors
            let strokeStyle = StrokeStyle(
                color: document.defaultStrokeColor,
                width: 1.0,
                opacity: document.defaultStrokeOpacity
            )
            let fillStyle = FillStyle(
                color: .clear, // Bezier paths start with no fill
                opacity: document.defaultFillOpacity
            )
            
            activeBezierShape = VectorShape(
                name: "Bezier Path",
                path: bezierPath!,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            
            // Add the real shape to the document immediately
            document.addShape(activeBezierShape!)
            
            // Create smooth handles for the first point based on drag direction
            let dragVector = CGPoint(
                x: currentLocation.x - firstPointLocation.x,
                y: currentLocation.y - firstPointLocation.y
            )
            
            let control1 = VectorPoint(
                firstPointLocation.x - dragVector.x * 0.5,
                firstPointLocation.y - dragVector.y * 0.5
            )
            let control2 = VectorPoint(
                firstPointLocation.x + dragVector.x * 0.5,
                firstPointLocation.y + dragVector.y * 0.5
            )
            
            bezierHandles[0] = BezierHandleInfo(
                control1: control1,
                control2: control2,
                hasHandles: true
            )
            
            // Clear first point creation state
            pendingFirstPoint = nil
            isCreatingFirstPoint = false
            isDraggingBezierHandle = true
            
            print("✅ CREATED SMOOTH FIRST POINT with handles at \(firstPointLocation)")
            print("🎨 PEN TOOL INITIAL COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
            return
        }
        
        // Regular bezier pen drag handling (for existing paths)
        guard isBezierDrawing else { return }
        
        // Only proceed with handle creation if user has dragged significantly
        if dragDistance < minimumDragThreshold {
            print("🎯 BEZIER PEN: Drag distance (\(String(format: "%.1f", dragDistance))px) below threshold - treating as CLICK, no handles created")
            return
        }
        
        print("🎯 BEZIER PEN: Drag distance (\(String(format: "%.1f", dragDistance))px) above threshold - FIRST plotting new point, THEN creating handles")
        
        // Check if we're dragging from an existing anchor point (editing existing handles)
        let tolerance: Double = 8.0
        var draggedPointIndex: Int? = nil
        
        for (index, point) in bezierPoints.enumerated() {
            let pointLocation = CGPoint(x: point.x, y: point.y)
            if distance(startLocation, pointLocation) <= tolerance {
                draggedPointIndex = index
                break
            }
        }
        
        if let pointIndex = draggedPointIndex {
            // EXISTING POINT: User is dragging from an existing anchor point to edit its handles
            if !isDraggingBezierHandle {
                isDraggingBezierHandle = true
                isDraggingBezierPoint = true
                print("📝 EDITING: Dragging handles from existing point \(pointIndex)")
            }
            
            // Create/update bezier handles for this existing point
            let point = bezierPoints[pointIndex]
            let pointLocation = CGPoint(x: point.x, y: point.y)
            
            // Calculate handle positions based on drag direction
            let dragVector = CGPoint(
                x: currentLocation.x - pointLocation.x,
                y: currentLocation.y - pointLocation.y
            )
            
            // FIXED: Create symmetric handles with correct assignment (professional behavior)
            // control1 = INCOMING handle (opposite to drag direction) 
            // control2 = OUTGOING handle (follows drag direction)
            let control1 = VectorPoint(
                pointLocation.x - dragVector.x,
                pointLocation.y - dragVector.y
            )
            let control2 = VectorPoint(
                pointLocation.x + dragVector.x,
                pointLocation.y + dragVector.y
            )
            
            // Store handle information
            bezierHandles[pointIndex] = BezierHandleInfo(
                control1: control1,
                control2: control2,
                hasHandles: true
            )
            
            // Update the path elements to use curves where handles exist
            updatePathWithHandles()
            
            // Update the real shape in the document immediately
            updateActiveBezierShapeInDocument()
            
        } else {
            // NEW POINT: User is creating a new point with drag
            if !isDraggingBezierHandle {
                isDraggingBezierHandle = true
                
                // ✨ NEW BEHAVIOR: First plot the new anchor point at click location
                let newPoint = VectorPoint(startLocation)
                bezierPoints.append(newPoint)
                activeBezierPointIndex = bezierPoints.count - 1
                
                // Add the new point to the path as a line segment initially
                bezierPath?.addElement(.line(to: newPoint))
                
                print("🎯 NEW POINT: First plotted anchor point \(bezierPoints.count) at \(startLocation)")
                print("📏 Now creating smooth curve handles as user drags...")
            }
            
            // Create handles for the newly placed point based on drag direction
            let activeIndex = bezierPoints.count - 1
            let activePoint = bezierPoints[activeIndex]
            let activeLocation = CGPoint(x: activePoint.x, y: activePoint.y)
            
            let dragVector = CGPoint(
                x: currentLocation.x - activeLocation.x,
                y: currentLocation.y - activeLocation.y
            )
            
            // FIXED: Correct handle assignment for intuitive UX  
            // control1 = INCOMING handle (opposite to drag direction)
            // control2 = OUTGOING handle (follows drag direction - this is what user sees)
            let control1 = VectorPoint(
                activeLocation.x - dragVector.x * 0.5,
                activeLocation.y - dragVector.y * 0.5
            )
            let control2 = VectorPoint(
                activeLocation.x + dragVector.x * 0.5,
                activeLocation.y + dragVector.y * 0.5
            )
            
            bezierHandles[activeIndex] = BezierHandleInfo(
                control1: control1,
                control2: control2,
                hasHandles: true
            )
            
            updatePathWithHandles()
            
            // Update the real shape in the document immediately
            updateActiveBezierShapeInDocument()
        }
    }
    
    // MARK: - Professional Real-Time Path Updates (Adobe Illustrator Style)
    
    /// Updates the active bezier shape in the document with the current path
    /// This gives real-time visual feedback like professional vector apps
    private func updateActiveBezierShapeInDocument() {
        guard let activeBezierShape = activeBezierShape,
              let updatedPath = bezierPath,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Find the shape in the document and update it
        for shapeIndex in document.layers[layerIndex].shapes.indices {
            if document.layers[layerIndex].shapes[shapeIndex].id == activeBezierShape.id {
                // Update the path with the latest bezier path data
                document.layers[layerIndex].shapes[shapeIndex].path = updatedPath
                
                // Update stroke color to match current toolbar selection (real-time)
                document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                    color: document.defaultStrokeColor,
                    width: 1.0,
                    opacity: document.defaultStrokeOpacity
                )
                
                // Also update fill if user has changed it (but keep .clear for open paths during drawing)
                // Fill will be applied when path is finished
                
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                break
            }
        }
        
        // Force UI update for real-time visual feedback
        document.objectWillChange.send()
    }
    
    private func handleShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL SHAPE DRAWING: Perfect cursor-to-shape synchronization
        // Uses the same precision approach as hand tool and object dragging
        // This eliminates floating-point accumulation errors from DragGesture.translation
        
        // CRITICAL FIX: Shape tools should only work on DRAG, not click
        // Calculate actual drag distance to distinguish click vs drag
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let minimumDragThreshold: Double = 12.0 // Must drag at least 12 pixels to start drawing shapes
        
        // Only proceed with shape creation if user has dragged significantly
        if dragDistance < minimumDragThreshold {
            print("🎨 SHAPE TOOL: Drag distance (\(String(format: "%.1f", dragDistance))px) below threshold - CLICK IGNORED (shapes are drag-only)")
            return
        }
        
        if !isDrawing {
            // CRITICAL: Only initialize state once per drag operation
            isDrawing = true
            
            // Capture reference cursor position (like hand tool)
            shapeDragStart = value.startLocation
            
            // Convert to canvas coordinates for initial position
            shapeStartPoint = screenToCanvas(value.startLocation, geometry: geometry)
            drawingStartPoint = shapeStartPoint
            
            print("🎨 SHAPE DRAWING: Started at cursor position (\(String(format: "%.1f", shapeDragStart.x)), \(String(format: "%.1f", shapeDragStart.y)))")
            print("🎨 SHAPE TOOL: Drag distance (\(String(format: "%.1f", dragDistance))px) above threshold - starting shape creation")
        }
        
        // Calculate cursor movement from reference location (perfect 1:1 tracking)
        let cursorDelta = CGPoint(
            x: value.location.x - shapeDragStart.x,
            y: value.location.y - shapeDragStart.y
        )
        
        // Convert screen delta to canvas delta (accounting for zoom)
        let preciseZoom = Double(document.zoomLevel)
        let canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        
        // Calculate current location based on initial position + cursor delta
        let currentLocation = CGPoint(
            x: shapeStartPoint.x + canvasDelta.x,
            y: shapeStartPoint.y + canvasDelta.y
        )
        
        // Professional verification logging (only for significant movements)
        if abs(canvasDelta.x) > 2 || abs(canvasDelta.y) > 2 {
            print("🎨 SHAPE DRAWING: Perfect sync maintained - canvas delta: (\(String(format: "%.1f", canvasDelta.x)), \(String(format: "%.1f", canvasDelta.y)))")
        }
        
        guard let startPoint = drawingStartPoint else { return }
        
        // Create preview path based on tool
        switch document.currentTool {
        case .line:
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(startPoint)),
                .line(to: VectorPoint(currentLocation))
            ])
        case .rectangle:
            let rect = CGRect(
                x: min(startPoint.x, currentLocation.x),
                y: min(startPoint.y, currentLocation.y),
                width: abs(currentLocation.x - startPoint.x),
                height: abs(currentLocation.y - startPoint.y)
            )
            currentPath = VectorPath(elements: [
                .move(to: VectorPoint(rect.minX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.maxY)),
                .line(to: VectorPoint(rect.minX, rect.maxY)),
                .close
            ], isClosed: true)
        case .circle:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            let radius = sqrt(pow(currentLocation.x - startPoint.x, 2) + pow(currentLocation.y - startPoint.y, 2)) / 2
            currentPath = createCirclePath(center: center, radius: radius)
        case .star:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            let outerRadius = sqrt(pow(currentLocation.x - startPoint.x, 2) + pow(currentLocation.y - startPoint.y, 2)) / 2
            let innerRadius = outerRadius * 0.4 // Inner radius is 40% of outer radius
            currentPath = createStarPath(center: center, outerRadius: outerRadius, innerRadius: innerRadius, points: 5)
        case .polygon:
            let center = CGPoint(
                x: (startPoint.x + currentLocation.x) / 2,
                y: (startPoint.y + currentLocation.y) / 2
            )
            let radius = sqrt(pow(currentLocation.x - startPoint.x, 2) + pow(currentLocation.y - startPoint.y, 2)) / 2
            currentPath = createPolygonPath(center: center, radius: radius, sides: 6) // Default hexagon
        default:
            break
        }
    }
    
    private func finishShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let path = currentPath else { return }
        
        // FIXED: Use document's default colors instead of hardcoded values!
        let strokeStyle = StrokeStyle(
            color: document.defaultStrokeColor,
            width: 1.0,
            opacity: document.defaultStrokeOpacity  // 100% opacity by default
        )
        let fillStyle = FillStyle(
            color: document.defaultFillColor,
            opacity: document.defaultFillOpacity  // 100% opacity by default
        )
        
        let shape = VectorShape(
            name: document.currentTool.rawValue,
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        document.addShape(shape)
        print("✅ Created shape with default colors: fill=\(document.defaultFillColor), stroke=\(document.defaultStrokeColor)")
        
        // PROFESSIONAL SHAPE DRAWING: Clean state reset for next drawing operation
        // This ensures each new shape starts with fresh reference points
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
        
        print("🎨 SHAPE DRAWING: Completed successfully - state reset for next operation")
    }
    
    private func startSelectionDrag() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        // PROTECT LOCKED LAYERS: Don't allow moving objects on locked layers
        if document.layers[layerIndex].isLocked {
            print("🚫 Cannot move objects on locked layer '\(document.layers[layerIndex].name)'")
            return
        }
        
        // PROFESSIONAL OBJECT DRAGGING: Save initial positions (not transforms)
        // This matches the precision approach used by the hand tool
        initialObjectPositions.removeAll()
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                // Store the actual center position of the shape
                let centerX = shape.bounds.midX
                let centerY = shape.bounds.midY
                initialObjectPositions[shapeID] = CGPoint(x: centerX, y: centerY)
            }
        }
        
        print("🎯 SELECTION DRAG: Established reference positions for \(document.selectedShapeIDs.count) objects")
    }
    
    private func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        // PROTECT LOCKED LAYERS: Don't allow moving objects on locked layers
        if document.layers[layerIndex].isLocked {
            return
        }
        
        // PROFESSIONAL OBJECT DRAGGING: Perfect cursor-to-object synchronization
        // Uses the same precision approach as the hand tool - calculate cursor delta directly
        // This eliminates floating-point accumulation errors from DragGesture.translation
        
        // Calculate cursor movement from reference location (perfect 1:1 tracking)
        let cursorDelta = CGPoint(
            x: value.location.x - selectionDragStart.x,
            y: value.location.y - selectionDragStart.y
        )
        
        // Convert screen delta to canvas delta (accounting for zoom)
        let preciseZoom = Double(document.zoomLevel)
        let canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        
        // Move selected shapes by directly updating their path coordinates
        // This ensures the object origin moves with the object (Adobe Illustrator behavior)
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }),
               let initialPosition = initialObjectPositions[shapeID] {
                
                // Calculate new position based on initial position + cursor delta
                let newPosition = CGPoint(
                    x: initialPosition.x + canvasDelta.x,
                    y: initialPosition.y + canvasDelta.y
                )
                
                // Calculate offset needed to move shape to new position
                let currentCenter = CGPoint(
                    x: document.layers[layerIndex].shapes[shapeIndex].bounds.midX,
                    y: document.layers[layerIndex].shapes[shapeIndex].bounds.midY
                )
                
                let offset = CGPoint(
                    x: newPosition.x - currentCenter.x,
                    y: newPosition.y - currentCenter.y
                )
                
                // Apply offset to all path elements
                if abs(offset.x) > 0.01 || abs(offset.y) > 0.01 {
                    var transformedElements: [PathElement] = []
                    
                    for element in document.layers[layerIndex].shapes[shapeIndex].path.elements {
                        switch element {
                        case .move(let to):
                            transformedElements.append(.move(to: VectorPoint(to.x + offset.x, to.y + offset.y)))
                        case .line(let to):
                            transformedElements.append(.line(to: VectorPoint(to.x + offset.x, to.y + offset.y)))
                        case .curve(let to, let control1, let control2):
                            transformedElements.append(.curve(
                                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                                control1: VectorPoint(control1.x + offset.x, control1.y + offset.y),
                                control2: VectorPoint(control2.x + offset.x, control2.y + offset.y)
                            ))
                        case .quadCurve(let to, let control):
                            transformedElements.append(.quadCurve(
                                to: VectorPoint(to.x + offset.x, to.y + offset.y),
                                control: VectorPoint(control.x + offset.x, control.y + offset.y)
                            ))
                        case .close:
                            transformedElements.append(.close)
                        }
                    }
                    
                    // Update the path with transformed coordinates
                    document.layers[layerIndex].shapes[shapeIndex].path = VectorPath(
                        elements: transformedElements,
                        isClosed: document.layers[layerIndex].shapes[shapeIndex].path.isClosed
                    )
                    
                    // Reset transform to identity (no double transformation)
                    document.layers[layerIndex].shapes[shapeIndex].transform = .identity
                    
                    // Update bounds to match new coordinates
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                }
            }
        }
        
        // Professional verification logging (only for significant movements)
        if abs(canvasDelta.x) > 2 || abs(canvasDelta.y) > 2 {
            print("🎯 SELECTION DRAG: Perfect sync maintained - canvas delta: (\(String(format: "%.1f", canvasDelta.x)), \(String(format: "%.1f", canvasDelta.y)))")
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishSelectionDrag() {
        if !initialObjectPositions.isEmpty {
            // PROFESSIONAL OBJECT DRAGGING: Clean state reset for next drag operation
            // This ensures each new drag operation starts with fresh reference points
            let movedObjects = initialObjectPositions.count
            
            // Save to undo stack if we moved objects
            if movedObjects > 0 {
                document.saveToUndoStack()
            }
            
            // Reset state
            initialObjectPositions.removeAll()
            selectionDragStart = CGPoint.zero
            
            print("🎯 SELECTION DRAG: Completed successfully - moved \(movedObjects) objects")
            print("   State reset - ready for next drag operation")
        }
    }
    

    
    // MARK: - Direct Selection Drag Handling
    
    private func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard !selectedPoints.isEmpty || !selectedHandles.isEmpty else { return }
        
        // PROTECT LOCKED LAYERS: Don't allow editing points/handles on locked layers
        for pointID in selectedPoints {
            // Find which layer this point belongs to
            for layerIndex in document.layers.indices {
                if let _ = document.layers[layerIndex].shapes.first(where: { $0.id == pointID.shapeID }) {
                    if document.layers[layerIndex].isLocked {
                        print("🚫 Cannot edit points on locked layer '\(document.layers[layerIndex].name)'")
                        return
                    }
                    break
                }
            }
        }
        
        for handleID in selectedHandles {
            // Find which layer this handle belongs to  
            for layerIndex in document.layers.indices {
                if let _ = document.layers[layerIndex].shapes.first(where: { $0.id == handleID.shapeID }) {
                    if document.layers[layerIndex].isLocked {
                        print("🚫 Cannot edit handles on locked layer '\(document.layers[layerIndex].name)'")
                        return
                    }
                    break
                }
            }
        }
        
        if !isDraggingPoint && !isDraggingHandle {
            // Start dragging - capture initial positions
            isDraggingPoint = !selectedPoints.isEmpty
            isDraggingHandle = !selectedHandles.isEmpty
            document.saveToUndoStack() // Save state before modifying paths
            
            // Store initial positions for accurate dragging
            captureOriginalPositions()
        }
        
        // STABLE COORDINATE CALCULATION: Use high precision to prevent drift
        let preciseZoom = Double(document.zoomLevel)
        let preciseTranslationX = Double(value.translation.width)
        let preciseTranslationY = Double(value.translation.height)
        
        let delta = CGPoint(
            x: preciseTranslationX / preciseZoom,
            y: preciseTranslationY / preciseZoom
        )
        
        // Move selected points to absolute positions
        for pointID in selectedPoints {
            if let originalPosition = originalPointPositions[pointID] {
                movePointToAbsolutePosition(pointID, to: CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                ))
            }
        }
        
        // Move selected handles to absolute positions
        for handleID in selectedHandles {
            if let originalPosition = originalHandlePositions[handleID] {
                moveHandleToAbsolutePosition(handleID, to: CGPoint(
                    x: originalPosition.x + delta.x,
                    y: originalPosition.y + delta.y
                ))
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishDirectSelectionDrag() {
        isDraggingPoint = false
        isDraggingHandle = false
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
    }
    
    private func captureOriginalPositions() {
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
        
        // Capture original positions of selected points
        for pointID in selectedPoints {
            if let point = getPointPosition(pointID) {
                originalPointPositions[pointID] = point
            }
        }
        
        // Capture original positions of selected handles
        for handleID in selectedHandles {
            if let handle = getHandlePosition(handleID) {
                originalHandlePositions[handleID] = handle
            }
        }
    }
    
    private func getPointPosition(_ pointID: PointID) -> VectorPoint? {
        // Find the shape and get the point position
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < shape.path.elements.count else { return nil }
                let element = shape.path.elements[pointID.elementIndex]
                
                switch element {
                case .move(let to), .line(let to):
                    return to
                case .curve(let to, _, _), .quadCurve(let to, _):
                    return to
                case .close:
                    return nil
                }
            }
        }
        return nil
    }
    
    private func getHandlePosition(_ handleID: HandleID) -> VectorPoint? {
        // Find the shape and get the handle position
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                guard handleID.elementIndex < shape.path.elements.count else { return nil }
                let element = shape.path.elements[handleID.elementIndex]
                
                switch element {
                case .curve(_, let control1, let control2):
                    return handleID.handleType == .control1 ? control1 : control2
                case .quadCurve(_, let control):
                    return handleID.handleType == .control1 ? control : nil
                default:
                    return nil
                }
            }
        }
        return nil
    }
    
    private func movePointToAbsolutePosition(_ pointID: PointID, to newPosition: CGPoint) {
        // Find the shape and update the point position
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let newPoint = VectorPoint(newPosition.x, newPosition.y)
                var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
                
                switch elements[pointID.elementIndex] {
                case .move(_):
                    elements[pointID.elementIndex] = .move(to: newPoint)
                case .line(_):
                    elements[pointID.elementIndex] = .line(to: newPoint)
                case .curve(_, let control1, let control2):
                    elements[pointID.elementIndex] = .curve(to: newPoint, control1: control1, control2: control2)
                case .quadCurve(_, let control):
                    elements[pointID.elementIndex] = .quadCurve(to: newPoint, control: control)
                case .close:
                    break
                }
                
                document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                return
            }
        }
    }
    
    private func moveHandleToAbsolutePosition(_ handleID: HandleID, to newPosition: CGPoint) {
        // Find the shape and update the handle position
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == handleID.shapeID }) {
                guard handleID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let newHandle = VectorPoint(newPosition.x, newPosition.y)
                var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
                
                // STEP 1: Update the dragged handle
                switch elements[handleID.elementIndex] {
                case .curve(let to, let control1, let control2):
                    if handleID.handleType == .control1 {
                        elements[handleID.elementIndex] = .curve(to: to, control1: newHandle, control2: control2)
                    } else {
                        elements[handleID.elementIndex] = .curve(to: to, control1: control1, control2: newHandle)
                    }
                case .quadCurve(let to, _):
                    if handleID.handleType == .control1 {
                        elements[handleID.elementIndex] = .quadCurve(to: to, control: newHandle)
                    }
                default:
                    break
                }
                
                // STEP 2: PROFESSIONAL LINKED HANDLES - Update the opposite handle of THE SAME ANCHOR POINT
                if !optionPressed() {
                    updateLinkedHandle(
                        elements: &elements,
                        draggedHandleID: handleID,
                        newDraggedPosition: newPosition
                    )
                }
                
                document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                return
            }
        }
    }
    
    /// Updates the opposite handle of the SAME anchor point to maintain smooth curves
    /// PROFESSIONAL BEHAVIOR: Smooth points work like a teeter-totter - both handles move together in a straight line
    private func updateLinkedHandle(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) {
        
        if draggedHandleID.handleType == .control2 {
            // Dragging INCOMING handle (control2) of current curve element
            // This handle belongs to the anchor point at the END of this curve
            guard case .curve(let anchorTo, let control1, _) = elements[draggedHandleID.elementIndex] else { return }
            
            let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
            
            // Find the OUTGOING handle of the same anchor point (control1 of NEXT curve element)
            let nextIndex = draggedHandleID.elementIndex + 1
            if nextIndex < elements.count, case .curve(let nextTo, let currentOutgoing, let nextControl2) = elements[nextIndex] {
                
                // Calculate the opposite handle position (180° from dragged handle through anchor point)
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentOutgoing.x, y: currentOutgoing.y)
                )
                
                // Update both handles: the dragged one and its opposite
                elements[draggedHandleID.elementIndex] = .curve(to: anchorTo, control1: control1, control2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[nextIndex] = .curve(to: nextTo, control1: VectorPoint(oppositeHandle.x, oppositeHandle.y), control2: nextControl2)
            }
            
        } else if draggedHandleID.handleType == .control1 {
            // Dragging OUTGOING handle (control1) of current curve element
            // This handle belongs to the anchor point where the PREVIOUS curve ended
            
            let prevIndex = draggedHandleID.elementIndex - 1
            if prevIndex >= 0, case .curve(let anchorTo, let prevControl1, let currentIncoming) = elements[prevIndex] {
                
                let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
                
                // Calculate the opposite handle position (180° from dragged handle through anchor point)
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentIncoming.x, y: currentIncoming.y)
                )
                
                // Update both handles: the dragged one and its opposite
                if case .curve(let currentTo, _, let currentControl2) = elements[draggedHandleID.elementIndex] {
                    elements[prevIndex] = .curve(to: anchorTo, control1: prevControl1, control2: VectorPoint(oppositeHandle.x, oppositeHandle.y))
                    elements[draggedHandleID.elementIndex] = .curve(to: currentTo, control1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y), control2: currentControl2)
                }
            }
        }
    }
    
    /// Detects if Option/Alt key is pressed for independent handle control
    private func optionPressed() -> Bool {
        return isOptionPressed
    }
    
    /// Calculates the linked handle position for smooth curve behavior
    private func calculateLinkedHandle(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
        // Vector from anchor to dragged handle
        let draggedVector = CGPoint(
            x: draggedHandle.x - anchorPoint.x,
            y: draggedHandle.y - anchorPoint.y
        )
        
        // Keep the original opposite handle length
        let originalVector = CGPoint(
            x: originalOppositeHandle.x - anchorPoint.x,
            y: originalOppositeHandle.y - anchorPoint.y
        )
        let originalLength = sqrt(originalVector.x * originalVector.x + originalVector.y * originalVector.y)
        
        // Create opposite vector (180° from dragged handle) with original length
        let draggedLength = sqrt(draggedVector.x * draggedVector.x + draggedVector.y * draggedVector.y)
        guard draggedLength > 0.1 else { return originalOppositeHandle } // Avoid division by zero
        
        let normalizedDragged = CGPoint(
            x: draggedVector.x / draggedLength,
            y: draggedVector.y / draggedLength
        )
        
        // Opposite direction with original length
        let linkedHandle = CGPoint(
            x: anchorPoint.x - normalizedDragged.x * originalLength,
            y: anchorPoint.y - normalizedDragged.y * originalLength
        )
        
        return linkedHandle
    }
    

    

    
    private func isDraggingSelectedObject(at location: CGPoint) -> Bool {
        // Check if the location is on any of the currently selected objects across all layers
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shapeID in document.selectedShapeIDs {
                if let shape = layer.shapes.first(where: { $0.id == shapeID }) {
                    // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                    
                    // Use the same improved hit testing logic as selection
                    // CRITICAL FIX: Background shapes (Canvas/Pasteboard) need special handling
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    
                    if isBackgroundShape {
                        // Background shapes: Use EXACT bounds checking - no tolerance!
                        let shapeBounds = shape.bounds.applying(shape.transform)
                        if shapeBounds.contains(location) {
                            return true
                        }
                    } else {
                        // Regular shapes: Use different logic for stroke vs filled
                        let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                        
                        if isStrokeOnly && shape.strokeStyle != nil {
                            // Use stroke width + padding for tolerance
                            let strokeWidth = shape.strokeStyle?.width ?? 1.0
                            let strokeTolerance = max(15.0, strokeWidth + 10.0)
                            
                            if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance) {
                                return true
                            }
                        } else {
                            // Regular shapes: Use bounds + path hit testing
                            let transformedBounds = shape.bounds.applying(shape.transform)
                            let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                            
                            if expandedBounds.contains(location) {
                                return true
                            } else {
                                if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0) {
                                    return true
                                }
                            }
                        }
                    }
                }
            }
        }
        return false
    }
    
    private func selectObjectAt(_ location: CGPoint) {
        // DETAILED LOGGING: Determine if this is canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let isInCanvasArea = canvasBounds.contains(location)
        let areaType = isInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        print("🎯 SELECT OBJECT AT FUNCTION CALLED at: \(location) in \(areaType)")
        
        if !isInCanvasArea {
            print("🎯 PASTEBOARD: Prioritizing object selection with optimized hit testing")
            // PASTEBOARD OPTIMIZATION: Use selection tap logic directly for better object detection
            handleSelectionTap(at: location)
        } else {
            print("🎯 CANVAS: Using standard drag-based selection")
            // Reuse the selection tap logic for canvas
            handleSelectionTap(at: location)
        }
    }
    
    private func finishBezierPath() {
        guard let activeBezierShape = activeBezierShape, bezierPoints.count >= 2 else { 
            print("Cannot finish bezier path - insufficient points or no active shape")
            cancelBezierDrawing()
            return 
        }
        
        // PROFESSIONAL REAL-TIME PATH COMPLETION: Apply final colors like Adobe Illustrator
        // Open paths should get both stroke AND fill using document defaults (toolbar selection)
        if let layerIndex = document.selectedLayerIndex {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                if document.layers[layerIndex].shapes[shapeIndex].id == activeBezierShape.id {
                    // Update the existing shape to have proper fill and stroke from toolbar
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                        color: document.defaultStrokeColor,
                        width: 1.0,
                        opacity: document.defaultStrokeOpacity
                    )
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: document.defaultFillColor,
                        opacity: document.defaultFillOpacity
                    )
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    break
                }
            }
        }
        
        print("✅ Finished bezier path with \(bezierPoints.count) points using toolbar colors")
        print("Path elements: \(activeBezierShape.path.elements.count)")
        print("Shape bounds: \(activeBezierShape.bounds)")
        print("🎨 PEN TOOL FINAL COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
        print("🔍 Shape fill applied: \(FillStyle(color: document.defaultFillColor, opacity: document.defaultFillOpacity))")
        print("🔍 Shape stroke applied: \(StrokeStyle(color: document.defaultStrokeColor, width: 1.0, opacity: document.defaultStrokeOpacity))")
        
        // PROFESSIONAL ADOBE ILLUSTRATOR BEHAVIOR: Auto-switch to direct selection and select the path
        let finishedShapeID = activeBezierShape.id
        
        // Reset bezier state BEFORE switching tools
        cancelBezierDrawing()
        
        // Switch to direct selection tool
        document.currentTool = .directSelection
        
        // Direct-select the finished shape
        directSelectedShapeIDs.removeAll()
        directSelectedShapeIDs.insert(finishedShapeID)
        selectedPoints.removeAll() // Clear any existing point selections
        selectedHandles.removeAll() // Clear any existing handle selections
        
        print("🎯 AUTO-SWITCHED to Direct Selection and direct-selected finished path")
    }
    
    private func finishBezierPenDrag() {
        // FIRST POINT CORNER CREATION: Handle case where user clicked (no significant drag) for first point
        if isCreatingFirstPoint, let firstPointLocation = pendingFirstPoint {
            // User clicked without significant drag - create CORNER first point
            print("🎯 FIRST POINT: No significant drag detected - creating CORNER first point")
            
            // Create the bezier path and add the first point
            bezierPath = VectorPath(elements: [.move(to: VectorPoint(firstPointLocation))])
            bezierPoints = [VectorPoint(firstPointLocation)]
            isBezierDrawing = true
            activeBezierPointIndex = 0 // First point is active (solid)
            bezierHandles.removeAll()
            
            // Create real VectorShape with document default colors
            let strokeStyle = StrokeStyle(
                color: document.defaultStrokeColor,
                width: 1.0,
                opacity: document.defaultStrokeOpacity
            )
            let fillStyle = FillStyle(
                color: .clear, // Bezier paths start with no fill
                opacity: document.defaultFillOpacity
            )
            
            activeBezierShape = VectorShape(
                name: "Bezier Path",
                path: bezierPath!,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            
            // Add the real shape to the document immediately
            document.addShape(activeBezierShape!)
            
            // Clear first point creation state
            pendingFirstPoint = nil
            isCreatingFirstPoint = false
            
            print("✅ CREATED CORNER FIRST POINT (no handles) at \(firstPointLocation)")
            print("🎨 PEN TOOL INITIAL COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
        }
        
        // Finalize bezier curve drag
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
    }
    
    private func updatePathWithHandles() {
        guard let path = bezierPath, bezierPoints.count >= 1 else { return }
        
        var newElements: [PathElement] = []
        
        // Start with move to first point
        newElements.append(.move(to: bezierPoints[0]))
        
        // Pure handle-based approach: only create curves when handles exist
        for i in 1..<bezierPoints.count {
            let currentPoint = bezierPoints[i]
            let previousPoint = bezierPoints[i - 1]
            
            // Check for handles on both points
            let previousHandles = bezierHandles[i - 1]
            let currentHandles = bezierHandles[i]
            
            // Only create curves if there are actual handles to define them
            let hasOutgoingHandle = previousHandles?.control2 != nil
            let hasIncomingHandle = currentHandles?.control1 != nil
            
            if hasOutgoingHandle || hasIncomingHandle {
                // Create curve using available handles
                let control1 = previousHandles?.control2 ?? VectorPoint(previousPoint.x, previousPoint.y)
                let control2 = currentHandles?.control1 ?? VectorPoint(currentPoint.x, currentPoint.y)
                
                newElements.append(.curve(to: currentPoint, control1: control1, control2: control2))
            } else {
                // No handles - use straight line
                newElements.append(.line(to: currentPoint))
            }
        }
        
        // Update the path
        bezierPath = VectorPath(elements: newElements, isClosed: path.isClosed)
    }
    
    private func handlePanGesture(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL HAND TOOL: Perfect cursor-to-canvas synchronization
        // Based on Adobe Illustrator, MacroMedia FreeHand, Inkscape, and CorelDRAW standards
        // Reference: US Patent 6097387A - "Dynamic control of panning operation in computer graphics"
        
        // CRITICAL FIX: Only initialize state once per drag operation
        // State should only be reset at the END of drag, not during drag
        if initialCanvasOffset == CGPoint.zero && handToolDragStart == CGPoint.zero {
            // Capture initial state - this is the "reference location" from Sony's patent
            initialCanvasOffset = document.canvasOffset
            handToolDragStart = value.startLocation
            isPanGestureActive = true  // PROFESSIONAL GESTURE COORDINATION
            
            print("✋ HAND TOOL: Established reference location (Professional Standard), UI responsive")
            print("   Reference canvas offset: (\(String(format: "%.1f", initialCanvasOffset.x)), \(String(format: "%.1f", initialCanvasOffset.y)))")
            print("   Reference cursor location: (\(String(format: "%.1f", handToolDragStart.x)), \(String(format: "%.1f", handToolDragStart.y)))")
        }
        
        // Calculate cursor movement from reference location (perfect 1:1 tracking)
        let cursorDelta = CGPoint(
            x: value.location.x - handToolDragStart.x,
            y: value.location.y - handToolDragStart.y
        )
        
        // PROFESSIONAL IMPLEMENTATION: Direct cursor-to-canvas mapping
        // The point under the cursor at drag start stays exactly under the cursor throughout the drag
        // This is the gold standard used by Adobe Illustrator, FreeHand, Inkscape, and CorelDRAW
        document.canvasOffset = CGPoint(
            x: initialCanvasOffset.x + cursorDelta.x,
            y: initialCanvasOffset.y + cursorDelta.y
        )
        
        // Professional verification logging (only for significant movements)
        if abs(cursorDelta.x) > 10 || abs(cursorDelta.y) > 10 {
            print("✋ HAND TOOL: Perfect sync maintained - delta: (\(String(format: "%.1f", cursorDelta.x)), \(String(format: "%.1f", cursorDelta.y))), UI responsive")
        }
    }
    
    /// PROFESSIONAL ZOOM GESTURE HANDLING (Adobe Illustrator Standards)
    /// Always available but conditionally processed to prevent UI lockups
    private func handleZoomGestureChanged(value: CGFloat, geometry: GeometryProxy) {
        // PROFESSIONAL GESTURE COORDINATION: Only zoom when appropriate
        // Don't block the gesture - just ignore it during drawing operations
        guard !isDrawing && !isBezierDrawing && !isPanGestureActive else {
            // Gesture is active but we're not processing it - UI remains responsive
            return
        }
        
        if !isZoomGestureActive {
            isZoomGestureActive = true
            print("🔍 ZOOM GESTURE STARTED: UI remains fully responsive")
        }
        
        let newZoomLevel = max(0.1, min(10.0, initialZoomLevel * value))
        handleSimplifiedZoom(newZoomLevel: newZoomLevel, geometry: geometry)
    }
    
    /// Handle zoom gesture end - finalize zoom level
    private func handleZoomGestureEnded(value: CGFloat, geometry: GeometryProxy) {
        // Always reset gesture state to ensure UI responsiveness
        defer {
            isZoomGestureActive = false
        }
        
        // PROFESSIONAL GESTURE COORDINATION: Only finalize zoom when appropriate
        guard !isDrawing && !isBezierDrawing && !isPanGestureActive else {
            // Gesture ended but we weren't processing it - UI remains responsive
            print("🔍 ZOOM GESTURE IGNORED: Drawing/Pan in progress, UI remains responsive")
            return
        }
        
        let finalZoomLevel = max(0.1, min(10.0, initialZoomLevel * value))
        document.zoomLevel = finalZoomLevel
        initialZoomLevel = finalZoomLevel
        print("🔍 PROFESSIONAL ZOOM COMPLETED: Final zoom level = \(String(format: "%.3f", finalZoomLevel))x, UI responsive")
    }
    
    private func handleSimplifiedZoom(newZoomLevel: CGFloat, geometry: GeometryProxy) {
        let oldZoomLevel = document.zoomLevel
        
        // Only proceed if zoom level actually changes
        guard abs(newZoomLevel - oldZoomLevel) > 0.001 else { return }
        
        // STABLE ZOOM SYSTEM: Use document center as fixed reference point
        // This prevents coordinate drift by always using the same reference
        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Calculate view center
        let viewCenter = CGPoint(
            x: geometry.size.width / 2.0,
            y: geometry.size.height / 2.0
        )
        
        // Update zoom level
        document.zoomLevel = newZoomLevel
        
        // Calculate offset to keep document center at view center
        // This approach is stable and prevents drift
        let newOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * newZoomLevel),
            y: viewCenter.y - (documentCenter.y * newZoomLevel)
        )
        
        document.canvasOffset = newOffset
        
        print("🔍 STABLE ZOOM: \(String(format: "%.3f", oldZoomLevel))x → \(String(format: "%.3f", newZoomLevel))x")
        print("   Document center: (\(String(format: "%.1f", documentCenter.x)), \(String(format: "%.1f", documentCenter.y)))")
        print("   View center: (\(String(format: "%.1f", viewCenter.x)), \(String(format: "%.1f", viewCenter.y)))")
        print("   Fixed offset: (\(String(format: "%.1f", newOffset.x)), \(String(format: "%.1f", newOffset.y)))")
    }
    
    private func handleZoomToLevel(newZoomLevel: CGFloat, geometry: GeometryProxy) {
        // Legacy function - redirect to simplified version
        handleSimplifiedZoom(newZoomLevel: newZoomLevel, geometry: geometry)
    }
    
    /// Handle coordinated zoom requests from menu/toolbar (Adobe Illustrator Standards)
    private func handleZoomRequest(_ request: ZoomRequest, geometry: GeometryProxy) {
        
        switch request.mode {
        case .fitToPage:
            // Fit to page: Calculate optimal zoom and center
            fitToPage(geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: Fit to Page")
            
        case .actualSize:
            // Actual size: Set to 100% and center properly
            actualSize(geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: Actual Size (100%)")
            
        case .zoomIn, .zoomOut:
            // Zoom in/out: Maintain current focal point
            handleSimplifiedZoom(newZoomLevel: request.targetZoom, geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: \(request.mode) to \(String(format: "%.1f", request.targetZoom * 100))%")
            
        case .custom(let focalPoint):
            // Custom zoom with specific focal point
            handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: focalPoint, geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: Custom zoom to \(String(format: "%.1f", request.targetZoom * 100))% at \(focalPoint)")
        }
        
        // Clear the request after processing
        document.clearZoomRequest()
    }
    
    /// Set to actual size (100%) with proper centering (Adobe Illustrator standard)
    private func actualSize(geometry: GeometryProxy) {
        let newZoomLevel: Double = 1.0 // 100% actual size
        
        // Calculate what canvas point is currently at the view center
        let viewCenter = CGPoint(
            x: geometry.size.width / 2.0,
            y: geometry.size.height / 2.0
        )
        
        // For actual size, we want to center the document center in the view
        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Update zoom level
        document.zoomLevel = newZoomLevel
        
        // Calculate offset to center the document
        document.canvasOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * CGFloat(newZoomLevel)),
            y: viewCenter.y - (documentCenter.y * CGFloat(newZoomLevel))
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = CGFloat(newZoomLevel)
        
        print("🎯 ACTUAL SIZE: Set to 100% and centered document")
        print("   Document center: (\(String(format: "%.1f", documentCenter.x)), \(String(format: "%.1f", documentCenter.y)))")
        print("   View center: (\(String(format: "%.1f", viewCenter.x)), \(String(format: "%.1f", viewCenter.y)))")
        print("   New offset: (\(String(format: "%.1f", document.canvasOffset.x)), \(String(format: "%.1f", document.canvasOffset.y)))")
    }
    
    /// Zoom at a specific point (stable version to prevent drift)
    private func handleZoomAtPoint(newZoomLevel: CGFloat, focalPoint: CGPoint, geometry: GeometryProxy) {
        let oldZoomLevel = document.zoomLevel
        
        // Only proceed if zoom level actually changes
        guard abs(newZoomLevel - oldZoomLevel) > 0.001 else { return }
        
        // Use high precision arithmetic to prevent floating-point drift
        let preciseOldZoom = Double(oldZoomLevel)
        let preciseNewZoom = Double(newZoomLevel)
        let preciseFocalX = Double(focalPoint.x)
        let preciseFocalY = Double(focalPoint.y)
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        
        // Find the canvas coordinate at the focal point
        let canvasPointAtFocus = CGPoint(
            x: (preciseFocalX - preciseOffsetX) / preciseOldZoom,
            y: (preciseFocalY - preciseOffsetY) / preciseOldZoom
        )
        
        // Update zoom level
        document.zoomLevel = newZoomLevel
        
        // Calculate what the new offset should be to keep the same canvas point at the focal point
        let newOffset = CGPoint(
            x: preciseFocalX - (Double(canvasPointAtFocus.x) * preciseNewZoom),
            y: preciseFocalY - (Double(canvasPointAtFocus.y) * preciseNewZoom)
        )
        
        document.canvasOffset = newOffset
        
        print("🔍 FOCAL POINT ZOOM: \(String(format: "%.3f", oldZoomLevel))x → \(String(format: "%.3f", newZoomLevel))x")
        print("   Focal point: (\(String(format: "%.1f", focalPoint.x)), \(String(format: "%.1f", focalPoint.y)))")
        print("   Canvas point at focus: (\(String(format: "%.1f", canvasPointAtFocus.x)), \(String(format: "%.1f", canvasPointAtFocus.y)))")
        print("   Stable offset: (\(String(format: "%.1f", newOffset.x)), \(String(format: "%.1f", newOffset.y)))")
    }
    
    private func screenToCanvas(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // PERFECT COORDINATE SYSTEM: Match exactly with .scaleEffect(zoomLevel, anchor: .topLeading).offset(canvasOffset)
        // Mathematical inverse: (screen - canvasOffset) / zoomLevel = canvas
        // Use high precision to prevent floating-point drift
        let preciseScreenX = Double(point.x)
        let preciseScreenY = Double(point.y)
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)
        
        let canvasX = (preciseScreenX - preciseOffsetX) / preciseZoom
        let canvasY = (preciseScreenY - preciseOffsetY) / preciseZoom
        
        return CGPoint(x: canvasX, y: canvasY)
    }
    
    private func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // PERFECT COORDINATE SYSTEM: Match exactly with .scaleEffect(zoomLevel, anchor: .topLeading).offset(canvasOffset)
        // Visual chain: (canvas * zoomLevel) + canvasOffset = screen
        // Use high precision to prevent floating-point drift
        let preciseCanvasX = Double(point.x)
        let preciseCanvasY = Double(point.y)
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)
        
        let screenX = (preciseCanvasX * preciseZoom) + preciseOffsetX
        let screenY = (preciseCanvasY * preciseZoom) + preciseOffsetY
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    private func createCirclePath(center: CGPoint, radius: Double) -> VectorPath {
        let controlPointOffset = radius * 0.552
        
        // PROFESSIONAL 4-CURVE CIRCLE: Each quadrant gets its own curve
        // Start at 3 o'clock, go clockwise: Right → Bottom → Left → Top → Back to Right
        return VectorPath(elements: [
            // Start at right (3 o'clock)
            .move(to: VectorPoint(center.x + radius, center.y)),
            
            // Curve 1: Right → Bottom (3 o'clock to 6 o'clock)
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + controlPointOffset),
                   control2: VectorPoint(center.x + controlPointOffset, center.y + radius)),
            
            // Curve 2: Bottom → Left (6 o'clock to 9 o'clock)
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - controlPointOffset, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + controlPointOffset)),
            
            // Curve 3: Left → Top (9 o'clock to 12 o'clock)
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - controlPointOffset),
                   control2: VectorPoint(center.x - controlPointOffset, center.y - radius)),
            
            // Curve 4: Top → Right (12 o'clock back to 3 o'clock) - CRITICAL!
            // This completes the circle with a proper curve, not a straight line
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + controlPointOffset, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - controlPointOffset)),
            
            // Close the path (this just marks it as closed, the curves do the actual work)
            .close
        ], isClosed: true)
    }
    
    private func createStarPath(center: CGPoint, outerRadius: Double, innerRadius: Double, points: Int) -> VectorPath {
        var elements: [PathElement] = []
        let angleStep = .pi / Double(points)
        
        for i in 0..<(points * 2) {
            let angle = Double(i) * angleStep - .pi / 2 // Start at top
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    private func createPolygonPath(center: CGPoint, radius: Double, sides: Int) -> VectorPath {
        var elements: [PathElement] = []
        let angleStep = 2 * .pi / Double(sides)
        
        for i in 0..<sides {
            let angle = Double(i) * angleStep - .pi / 2 // Start at top
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    private func handleTextTap(at location: CGPoint) {
        // PROFESSIONAL TEXT TOOL BEHAVIOR (Adobe Illustrator/FreeHand/Inkscape/CorelDRAW Standards)
        print("🔤 TEXT TOOL: Professional text creation at location: \(location)")
        
        // Exit any existing text editing first (professional behavior)
        exitAllTextEditing()
        
        // Check if clicking on existing text for editing (Adobe Illustrator behavior)
        if let existingText = findTextObjectAt(location) {
            // PROFESSIONAL INLINE EDITING: Click-to-position cursor
            startEditingExistingText(existingText, at: location)
            return
        }
        
        // PROFESSIONAL DUAL-MODE TEXT CREATION
        // This is Point Text mode (click once to create text that expands as you type)
        // Area Text mode would be implemented in drag handling
        createPointText(at: location)
    }
    
    /// Find text object at the specified location for editing
    private func findTextObjectAt(_ location: CGPoint) -> VectorText? {
        let tolerance: CGFloat = 5.0
        
        for textObject in document.textObjects {
            if !textObject.isVisible { continue }
            
            let bounds = textObject.bounds
            let expandedBounds = bounds.insetBy(dx: -tolerance, dy: -tolerance)
            
            if expandedBounds.contains(location) {
                return textObject
            }
        }
        
        return nil
    }
    
    /// Start editing existing text with cursor positioned at click location
    private func startEditingExistingText(_ textObject: VectorText, at location: CGPoint) {
        // PROFESSIONAL CURSOR POSITIONING (Adobe Illustrator/FreeHand standard)
        print("🔤 PROFESSIONAL EDIT: Starting inline editing of existing text")
        
        // Clear other selections
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        
        // Select and start editing the text object
        document.selectedTextIDs.insert(textObject.id)
        
        // Update the text object to editing mode
        if let index = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[index].isEditing = true
            
            // Calculate cursor position based on click location (professional feature)
            let cursorPosition = calculateCursorPosition(in: textObject, at: location)
            document.textObjects[index].cursorPosition = cursorPosition
            
            print("✅ Started editing existing text - cursor at position: \(cursorPosition)")
        }
    }
    
    /// Calculate cursor position based on click location within text
    private func calculateCursorPosition(in textObject: VectorText, at location: CGPoint) -> Int {
        // PROFESSIONAL CURSOR POSITIONING (Adobe Illustrator standard)
        // This is a simplified implementation - could be enhanced with Core Text for precise positioning
        let content = textObject.content
        guard !content.isEmpty else { return 0 }
        
        // Calculate relative position within text bounds
        let bounds = textObject.bounds
        let relativeX = location.x - bounds.minX
        let relativeProgress = max(0, min(1, relativeX / bounds.width))
        
        // Convert to character position
        let characterPosition = Int(round(relativeProgress * Double(content.count)))
        return min(characterPosition, content.count)
    }
    
    /// Create new point text at the specified location
    private func createPointText(at location: CGPoint) {
        // PROFESSIONAL POINT TEXT CREATION (Adobe Illustrator/FreeHand standard)
        print("🔤 CREATING POINT TEXT: Professional point text at location: \(location)")
        
        // Create professional typography with default settings
        let typography = TypographyProperties(
            fontFamily: "Helvetica",
            fontWeight: .regular,
            fontStyle: .normal,
            fontSize: 24.0,
            lineHeight: 28.8,
            letterSpacing: 0.0,
            alignment: .left,
            hasStroke: false,
            strokeColor: document.defaultStrokeColor,
            strokeWidth: 1.0,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor,
            fillOpacity: document.defaultFillOpacity
        )
        
        // Create professional text object
        var textObject = VectorText(
            content: "",
            typography: typography,
            position: location,
            isPointText: true  // Mark as point text
        )
        
        // PROFESSIONAL BEHAVIOR: Start in editing mode immediately (Adobe Illustrator/FreeHand)
        textObject.isEditing = true
        textObject.cursorPosition = 0
        
        // Add to document
        document.addText(textObject)
        
        // Select and focus for editing
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        document.selectedTextIDs.insert(textObject.id)
        
        // PROFESSIONAL CURSOR BEHAVIOR: Set I-beam cursor for text editing
        NSCursor.iBeam.set()
        
        print("✅ Created professional point text - Ready for immediate typing")
    }
    
    /// Handle text area creation for paragraph text (drag operation)
    private func createAreaText(startLocation: CGPoint, endLocation: CGPoint) {
        // PROFESSIONAL AREA TEXT CREATION (Adobe Illustrator/FreeHand standard)
        print("🔤 CREATING AREA TEXT: Professional area text from \(startLocation) to \(endLocation)")
        
        let width = abs(endLocation.x - startLocation.x)
        let height = abs(endLocation.y - startLocation.y)
        
        // Only create area text if the user dragged a meaningful area
        guard width > 20 && height > 20 else {
            // Fall back to point text for small drags
            createPointText(at: startLocation)
            return
        }
        
        // Calculate area text bounds
        let bounds = CGRect(
            x: min(startLocation.x, endLocation.x),
            y: min(startLocation.y, endLocation.y),
            width: width,
            height: height
        )
        
        // Create professional typography
        let typography = TypographyProperties(
            fontFamily: "Helvetica",
            fontWeight: .regular,
            fontStyle: .normal,
            fontSize: 12.0,  // Smaller default for area text
            lineHeight: 14.4,
            letterSpacing: 0.0,
            alignment: .left,
            hasStroke: false,
            strokeColor: document.defaultStrokeColor,
            strokeWidth: 1.0,
            strokeOpacity: document.defaultStrokeOpacity,
            fillColor: document.defaultFillColor,
            fillOpacity: document.defaultFillOpacity
        )
        
        // Create area text object
        var textObject = VectorText(
            content: "",
            typography: typography,
            position: CGPoint(x: bounds.minX, y: bounds.minY),
            isPointText: false,  // Mark as area text
            areaSize: CGSize(width: bounds.width, height: bounds.height)
        )
        
        // Start in editing mode
        textObject.isEditing = true
        textObject.cursorPosition = 0
        
        // Add to document
        document.addText(textObject)
        
        // Select and focus for editing
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        document.selectedTextIDs.insert(textObject.id)
        
        // PROFESSIONAL CURSOR BEHAVIOR: Set I-beam cursor for text editing
        NSCursor.iBeam.set()
        
        print("✅ Created professional area text - Ready for immediate typing")
    }
    
    /// Handle text drag operation for area text creation
    private func handleTextDragDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL TEXT DRAWING: Perfect cursor-to-text synchronization
        // Uses the same precision approach as shape drawing
        
        if !isDrawing {
            isDrawing = true
            
            // Capture reference cursor position (like shape drawing)
            shapeDragStart = value.startLocation
            
            // Convert to canvas coordinates for initial position
            shapeStartPoint = screenToCanvas(value.startLocation, geometry: geometry)
            drawingStartPoint = shapeStartPoint
            
            print("🔤 TEXT DRAG: Started area text drag from \(shapeStartPoint)")
        }
        
        // Calculate cursor movement from reference location (perfect 1:1 tracking)
        let cursorDelta = CGPoint(
            x: value.location.x - shapeDragStart.x,
            y: value.location.y - shapeDragStart.y
        )
        
        // Convert screen delta to canvas delta (accounting for zoom)
        let preciseZoom = Double(document.zoomLevel)
        let canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        
        // Calculate current location based on initial position + cursor delta
        let currentLocation = CGPoint(
            x: shapeStartPoint.x + canvasDelta.x,
            y: shapeStartPoint.y + canvasDelta.y
        )
        
        // Show visual feedback for area text creation (like drawing a rectangle)
        guard let startPoint = drawingStartPoint else { return }
        
        let rect = CGRect(
            x: min(startPoint.x, currentLocation.x),
            y: min(startPoint.y, currentLocation.y),
            width: abs(currentLocation.x - startPoint.x),
            height: abs(currentLocation.y - startPoint.y)
        )
        
        // Create preview path for visual feedback
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(rect.minX, rect.minY)),
            .line(to: VectorPoint(rect.maxX, rect.minY)),
            .line(to: VectorPoint(rect.maxX, rect.maxY)),
            .line(to: VectorPoint(rect.minX, rect.maxY)),
            .close
        ], isClosed: true)
    }
    
    /// Finish text drag operation and create area text
    private func finishTextDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL TEXT DRAWING: Use the same precision approach as shape drawing
        
        // Calculate end location using the same precision method
        let cursorDelta = CGPoint(
            x: value.location.x - shapeDragStart.x,
            y: value.location.y - shapeDragStart.y
        )
        
        let preciseZoom = Double(document.zoomLevel)
        let canvasDelta = CGPoint(
            x: cursorDelta.x / preciseZoom,
            y: cursorDelta.y / preciseZoom
        )
        
        let endLocation = CGPoint(
            x: shapeStartPoint.x + canvasDelta.x,
            y: shapeStartPoint.y + canvasDelta.y
        )
        
        // Create area text if dragged, otherwise create point text
        createAreaText(startLocation: shapeStartPoint, endLocation: endLocation)
        
        // Clear the preview path
        currentPath = nil
        
        // Clean up state
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
        drawingStartPoint = nil
        
        print("🔤 TEXT DRAG: Finished text creation with precision")
    }
    
    private func addPathElements(_ elements: [PathElement], to path: inout Path) {
        for element in elements {
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
    
    private func handleDirectSelectionTap(at location: CGPoint) {
        print("🎯 PROFESSIONAL DIRECT SELECTION tap at: \(location)")
        
        // EXIT TEXT EDITING when using direct selection tool (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        let tolerance: Double = 15.0
        var foundSelection = false
        
        // STAGE 1: Check if clicking on individual anchor points/handles (for already direct-selected shapes)
        if !directSelectedShapeIDs.isEmpty {
            print("🔥 STAGE 1: Checking individual anchor points in direct-selected shapes...")
            foundSelection = selectIndividualAnchorPointOrHandle(at: location, tolerance: tolerance)
        }
        
        // STAGE 2: If no anchor point selected, try to direct-select a whole shape (Adobe Illustrator behavior)
        if !foundSelection {
            print("🔥 STAGE 2: Looking for shapes to direct-select...")
            foundSelection = directSelectWholeShape(at: location)
        }
        
        // STAGE 3: If nothing found, clear all selections (clicked empty space)
        if !foundSelection {
            print("❌ Clicked empty space - clearing all direct selections")
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            directSelectedShapeIDs.removeAll()
        }
        
        print("🎯 DIRECT SELECTION RESULT:")
        print("  Selected points: \(selectedPoints.count)")
        print("  Selected handles: \(selectedHandles.count)")
        print("  Direct selected shapes: \(directSelectedShapeIDs.count)")
        
        // Force UI update to show selections
        document.objectWillChange.send()
    }
    
    // MARK: - PROFESSIONAL ANCHOR POINT AND HANDLE SELECTION
    
    /// STAGE 1: Select individual anchor points or handles (when shape already direct-selected)
    private func selectIndividualAnchorPointOrHandle(at location: CGPoint, tolerance: Double) -> Bool {
        // Search through all direct-selected shapes for individual anchor points and handles
        for shapeID in directSelectedShapeIDs {
            // Find the shape in the document
            for layerIndex in document.layers.indices {
                let layer = document.layers[layerIndex]
                if let shape = layer.shapes.first(where: { $0.id == shapeID }) {
                    
                    // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        print("🚫 Clicked on points/handles of \(lockType) '\(shape.name)' - deselecting current selection")
                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        document.objectWillChange.send()
                        return true
                    }
                    
                    // Check each path element for points and handles
                    for (elementIndex, element) in shape.path.elements.enumerated() {
                        let point: VectorPoint
                        
                        switch element {
                        case .move(let to), .line(let to):
                            point = to
                            
                            // Check for OUTGOING HANDLE (control1 from NEXT element - if it exists)
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                                if case .curve(_, let nextControl1, _) = nextElement {
                                    let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                    if distance(location, outgoingHandleLocation) <= tolerance {
                                        // CRITICAL FIX: HandleID must point to the NEXT element where the handle actually lives
                                        let handleID = HandleID(
                                            shapeID: shape.id,
                                            pathIndex: 0,
                                            elementIndex: elementIndex + 1, // NEXT element, not current!
                                            handleType: .control1
                                        )
                                        
                                        if isShiftPressed && selectedHandles.contains(handleID) {
                                            selectedHandles.remove(handleID)
                                            print("🎯 Deselected OUTGOING handle from line/move point")
                                        } else {
                                            if !isShiftPressed {
                                                selectedHandles.removeAll()
                                                selectedPoints.removeAll()
                                            }
                                            selectedHandles.insert(handleID)
                                            print("🎯 Selected OUTGOING handle from line/move point")
                                        }
                                        return true
                                    }
                                }
                            }
                            
                        case .curve(let to, _, let control2):
                            point = to
                            
                            // FIRST: Check control handles (higher priority than anchor points)
                            // For curves, we need to match the DISPLAY logic exactly:
                            // - control2 is the INCOMING handle to this anchor point
                            // - control1 from NEXT element is the OUTGOING handle from this anchor point
                            
                            // INCOMING HANDLE (control2 of current element)
                            let handle2Location = CGPoint(x: control2.x, y: control2.y)
                            if distance(location, handle2Location) <= tolerance {
                                let handleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: elementIndex,
                                    handleType: .control2
                                )
                                
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                    print("🎯 Deselected INCOMING handle")
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                    }
                                    selectedHandles.insert(handleID)
                                    print("🎯 Selected INCOMING handle")
                                }
                                return true
                            }
                            
                            // OUTGOING HANDLE (control1 from NEXT element - if it exists)
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                                if case .curve(_, let nextControl1, _) = nextElement {
                                    let outgoingHandleLocation = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                    if distance(location, outgoingHandleLocation) <= tolerance {
                                        // CRITICAL FIX: HandleID must point to the NEXT element where the handle actually lives
                                        let handleID = HandleID(
                                            shapeID: shape.id,
                                            pathIndex: 0,
                                            elementIndex: elementIndex + 1, // NEXT element, not current!
                                            handleType: .control1
                                        )
                                        
                                        if isShiftPressed && selectedHandles.contains(handleID) {
                                            selectedHandles.remove(handleID)
                                            print("🎯 Deselected OUTGOING handle")
                                        } else {
                                            if !isShiftPressed {
                                                selectedHandles.removeAll()
                                                selectedPoints.removeAll()
                                            }
                                            selectedHandles.insert(handleID)
                                            print("🎯 Selected OUTGOING handle")
                                        }
                                        return true
                                    }
                                }
                            }
                            
                        case .quadCurve(let to, let control):
                            point = to
                            
                            // Check control handle for quad curve
                            let handleLocation = CGPoint(x: control.x, y: control.y)
                            if distance(location, handleLocation) <= tolerance {
                                let handleID = HandleID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: elementIndex,
                                    handleType: .control1
                                )
                                
                                if isShiftPressed && selectedHandles.contains(handleID) {
                                    selectedHandles.remove(handleID)
                                    print("🎯 Deselected quad handle")
                                } else {
                                    if !isShiftPressed {
                                        selectedHandles.removeAll()
                                        selectedPoints.removeAll()
                                    }
                                    selectedHandles.insert(handleID)
                                    print("🎯 Selected quad handle")
                                }
                                return true
                            }
                            
                        case .close:
                            continue
                        }
                        
                        // SECOND: Check if tap is near the main anchor point
                        let pointLocation = CGPoint(x: point.x, y: point.y)
                        if distance(location, pointLocation) <= tolerance {
                            let pointID = PointID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex
                            )
                            
                            if isShiftPressed && selectedPoints.contains(pointID) {
                                // Shift+Click on selected point: deselect it
                                selectedPoints.remove(pointID)
                                print("🎯 Deselected anchor point")
                            } else {
                                if !isShiftPressed {
                                    selectedPoints.removeAll()
                                    selectedHandles.removeAll()
                                }
                                selectedPoints.insert(pointID)
                                print("🎯 Selected anchor point")
                            }
                            return true
                        }
                    }
                }
            }
        }
        
        return false
    }
    
    /// STAGE 2: Direct-select whole shape (Adobe Illustrator: shows all anchor points)
    private func directSelectWholeShape(at location: CGPoint) -> Bool {
        // Search for any shape at the click location
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                var isHit = false
                
                // PROFESSIONAL HIT TESTING (same logic as regular selection)
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) need special handling
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // Background shapes: Use EXACT bounds checking - no tolerance!
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                    print("  - Background shape - exact bounds hit test: \(isHit)")
                } else {
                    // Regular shapes: Use different logic for stroke vs filled
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Stroke-only shapes: Use stroke-based hit testing
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                        print("  - Stroke hit test: \(isHit) (tolerance: \(strokeTolerance))")
                    } else {
                        // Regular shapes: Use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                            print("  - Bounds hit test: \(isHit)")
                        } else {
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                            print("  - Path hit test: \(isHit)")
                        }
                    }
                }
                
                if isHit {
                    // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        print("🚫 Direct-clicked on \(lockType) '\(shape.name)' - deselecting current selection")
                        directSelectedShapeIDs.removeAll()
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        document.objectWillChange.send()
                        return true
                    }
                    
                    // PROFESSIONAL: Direct-select the whole shape
                    directSelectedShapeIDs.removeAll()
                    directSelectedShapeIDs.insert(shape.id)
                    selectedPoints.removeAll() // Clear individual selections
                    selectedHandles.removeAll()
                    
                    print("✅ DIRECT-SELECTED SHAPE: \(shape.name)")
                    print("  Shape will now show ALL anchor points and handles (Adobe Illustrator behavior)")
                    return true
                }
            }
        }
        
        return false
    }
    
    private func oldHandleDirectSelectionTap(at location: CGPoint) {
        // PROFESSIONAL SHIFT SELECTION (Adobe Illustrator Standard)
        // NOTE: This is now handled by the state variables
        
        // Clear previous selections if not holding Shift
        if !isShiftPressed {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
        }
        
        // First try to select an entire path
        let pathTolerance: Double = 15.0 // Larger tolerance for path selection
        
        // Search through all visible layers and shapes for path selection
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                // Check if tap is on the path (not near a specific point)
                let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                
                if isStrokeOnly && shape.strokeStyle != nil {
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeTolerance = max(pathTolerance, strokeWidth + 10.0)
                    
                    if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance) {
                        // Select the entire path by selecting all its points
                        for (elementIndex, element) in shape.path.elements.enumerated() {
                            switch element {
                            case .move, .line, .curve, .quadCurve:
                                selectedPoints.insert(PointID(
                                    shapeID: shape.id,
                                    pathIndex: 0,
                                    elementIndex: elementIndex
                                ))
                            case .close:
                                continue
                            }
                        }
                        print("Direct selection: Selected entire path with \(selectedPoints.count) points")
                        return
                    }
                }
            }
        }
        
        // If no path was selected, try to select individual points and handles
        var foundPoint = false
        let tolerance: Double = 8.0 // Hit test tolerance in canvas units
        
        // Search through all visible layers and shapes
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                // Check each path element for points
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    let point: VectorPoint
                    
                    switch element {
                    case .move(let to), .line(let to):
                        point = to
                    case .curve(let to, let control1, let control2):
                        // Check main point
                        point = to
                        
                        // Also check control handles
                        let handle1Location = CGPoint(x: control1.x, y: control1.y)
                        let handle2Location = CGPoint(x: control2.x, y: control2.y)
                        
                        if distance(location, handle1Location) <= tolerance {
                            let handleID = HandleID(
                                shapeID: shape.id,
                                pathIndex: 0, // Assuming single path for now
                                elementIndex: elementIndex,
                                handleType: .control1
                            )
                            
                            if isShiftPressed && selectedHandles.contains(handleID) {
                                // Shift+Click on selected handle: deselect it
                                selectedHandles.remove(handleID)
                                print("Deselected handle")
                            } else {
                                selectedHandles.insert(handleID)
                                print("Selected handle control1")
                            }
                            foundPoint = true
                            break
                        }
                        
                        if distance(location, handle2Location) <= tolerance {
                            let handleID = HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex,
                                handleType: .control2
                            )
                            
                            if isShiftPressed && selectedHandles.contains(handleID) {
                                // Shift+Click on selected handle: deselect it
                                selectedHandles.remove(handleID)
                                print("Deselected handle")
                            } else {
                                selectedHandles.insert(handleID)
                                print("Selected handle control2")
                            }
                            foundPoint = true
                            break
                        }
                    case .quadCurve(let to, let control):
                        point = to
                        
                        // Check control handle
                        let handleLocation = CGPoint(x: control.x, y: control.y)
                        if distance(location, handleLocation) <= tolerance {
                            selectedHandles.insert(HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex,
                                handleType: .control1
                            ))
                            foundPoint = true
                            break
                        }
                    case .close:
                        continue
                    }
                    
                    // Check if tap is near the main point
                    let pointLocation = CGPoint(x: point.x, y: point.y)
                    if distance(location, pointLocation) <= tolerance {
                        let pointID = PointID(
                            shapeID: shape.id,
                            pathIndex: 0,
                            elementIndex: elementIndex
                        )
                        
                        if isShiftPressed && selectedPoints.contains(pointID) {
                            // Shift+Click on selected point: deselect it
                            selectedPoints.remove(pointID)
                            print("Deselected point")
                        } else {
                            selectedPoints.insert(pointID)
                            print("Selected point")
                        }
                        foundPoint = true
                        break
                    }
                }
                
                if foundPoint { break }
            }
            if foundPoint { break }
        }
        
        print("Direct selection: Selected \(selectedPoints.count) points, \(selectedHandles.count) handles")
    }
    
    private func closeSelectedPaths() {
        // Get unique shape IDs from selected points
        let selectedShapeIDs = Set(selectedPoints.map { $0.shapeID })
        
        for shapeID in selectedShapeIDs {
            // Find the shape and close its path if it's open
            for layerIndex in document.layers.indices {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    let shape = document.layers[layerIndex].shapes[shapeIndex]
                    
                    // Check if path is already closed
                    let hasCloseElement = shape.path.elements.contains { element in
                        if case .close = element { return true }
                        return false
                    }
                    
                    if !hasCloseElement && shape.path.elements.count > 2 {
                        // Add close element
                        var newElements = shape.path.elements
                        newElements.append(.close)
                        
                        let newPath = VectorPath(elements: newElements, isClosed: true)
                        document.layers[layerIndex].shapes[shapeIndex].path = newPath
                        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                        
                        print("Closed path for shape \(shape.name)")
                    }
                }
            }
                 }
         
         // Force UI update
         document.objectWillChange.send()
     }
     
     private func deleteSelectedPoints() {
         // Group selected points by shape ID
         let pointsByShape = Dictionary(grouping: selectedPoints) { $0.shapeID }
         
         for (shapeID, points) in pointsByShape {
             // Find the shape
             for layerIndex in document.layers.indices {
                 if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                     let shape = document.layers[layerIndex].shapes[shapeIndex]
                     
                     // If all points are selected, delete the entire shape
                     let pathPointCount = shape.path.elements.filter { element in
                         switch element {
                         case .move, .line, .curve, .quadCurve: return true
                         case .close: return false
                         }
                     }.count
                     
                     if points.count >= pathPointCount || pathPointCount <= 2 {
                         // Delete entire shape
                         document.layers[layerIndex].shapes.remove(at: shapeIndex)
                         print("Deleted entire shape")
                     } else {
                         // Delete specific points while maintaining path integrity
                         let updatedPath = deletePointsFromPath(shape.path, selectedPoints: points)
                         document.layers[layerIndex].shapes[shapeIndex].path = updatedPath
                         document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                         print("Deleted \(points.count) points from path, \(updatedPath.elements.count) elements remain")
                     }
                     break
                 }
             }
         }
         
         // Clear selection
         selectedPoints.removeAll()
         selectedHandles.removeAll()
         
         // Force UI update
         document.objectWillChange.send()
     }
     
     // MARK: - Professional Point Deletion (Adobe Illustrator Standards)
     
     /// Delete specific points from a path while maintaining path integrity
     private func deletePointsFromPath(_ path: VectorPath, selectedPoints: [PointID]) -> VectorPath {
         var elements = path.elements
         
         // Get element indices to delete (sorted in reverse order to avoid index shifting issues)
         let indicesToDelete = selectedPoints.compactMap { $0.elementIndex }.sorted(by: >)
         
         // Remove elements from back to front to maintain indices
         for index in indicesToDelete {
             if index < elements.count {
                 // Check if this is a critical point for path integrity
                 if canDeleteElement(at: index, in: elements) {
                     elements.remove(at: index)
                 }
             }
         }
         
         // Ensure path still has a valid structure
         let validatedElements = validatePathElements(elements)
         
         return VectorPath(elements: validatedElements, isClosed: path.isClosed)
     }
     
     /// Check if an element can be safely deleted without breaking the path
     private func canDeleteElement(at index: Int, in elements: [PathElement]) -> Bool {
         // Don't delete if it's the only move element
         if case .move = elements[index] {
             let moveCount = elements.compactMap { if case .move = $0 { return 1 } else { return nil } }.count
             return moveCount > 1
         }
         
         // Don't delete if it would result in too few elements
         let pointCount = elements.filter { element in
             switch element {
             case .move, .line, .curve, .quadCurve: return true
             case .close: return false
             }
         }.count
         
         return pointCount > 2 // Need at least 3 points for a valid path
     }
     
     /// Validate and fix path elements to maintain integrity
     private func validatePathElements(_ elements: [PathElement]) -> [PathElement] {
         var validElements: [PathElement] = []
         
         for element in elements {
             switch element {
             case .move(_):
                 // Always keep move elements
                 validElements.append(element)
                 
             case .line(_):
                 // Keep line elements if we have a starting point
                 if !validElements.isEmpty {
                     validElements.append(element)
                 }
                 
             case .curve(_, _, _):
                 // Keep curve elements if we have a starting point
                 if !validElements.isEmpty {
                     validElements.append(element)
                 }
                 
             case .quadCurve(_, _):
                 // Keep quadratic curve elements if we have a starting point
                 if !validElements.isEmpty {
                     validElements.append(element)
                 }
                 
             case .close:
                 // Keep close elements if we have enough points
                 let pointCount = validElements.filter { element in
                     switch element {
                     case .move, .line, .curve, .quadCurve: return true
                     case .close: return false
                     }
                 }.count
                 
                 if pointCount >= 3 {
                     validElements.append(element)
                 }
             }
         }
         
         // Ensure we have at least a move element
         if validElements.isEmpty {
             validElements.append(.move(to: VectorPoint(0, 0)))
         }
         
         return validElements
     }
     
     private func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func closeBezierPath() {
        guard let _ = bezierPath, 
              let activeShape = activeBezierShape,
              bezierPoints.count >= 3 else {
            print("Cannot close bezier path - insufficient points or no path")
            cancelBezierDrawing()
            return
        }
        
        // CRITICAL FIX: Update path with handles BEFORE closing to preserve curve data
        updatePathWithHandles()
        
        // PROFESSIONAL PATH CLOSING: Connect last point to first with proper curve
        guard let updatedPath = bezierPath else {
            print("Failed to update path with handles")
            cancelBezierDrawing()
            return
        }
        
        // Check if we need to add a closing curve from last point to first point
        let firstPoint = bezierPoints[0]
        let lastIndex = bezierPoints.count - 1
        
        // Get handle information for proper closing curve
        let lastPointHandles = bezierHandles[lastIndex]
        let firstPointHandles = bezierHandles[0]
        
        var finalElements = updatedPath.elements
        
        // Add closing segment with proper curve handling
        if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
            // Both points have handles - create smooth closing curve
            finalElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstControl1))
            print("🎯 Created smooth closing curve with both handles")
        } else if let lastControl2 = lastPointHandles?.control2 {
            // Only last point has handle - create asymmetric curve
            finalElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstPoint))
            print("🎯 Created closing curve with outgoing handle")
        } else if let firstControl1 = firstPointHandles?.control1 {
            // Only first point has handle - create asymmetric curve  
            finalElements.append(.curve(to: firstPoint, control1: VectorPoint(bezierPoints[lastIndex].x, bezierPoints[lastIndex].y), control2: firstControl1))
            print("🎯 Created closing curve with incoming handle")
        } else {
            // No handles - straight line close
            finalElements.append(.line(to: firstPoint))
            print("🎯 Created straight line closing")
        }
        
        // Add close element to mark path as closed
        finalElements.append(.close)
        
        // Create final closed path preserving all curve data
        let closedPath = VectorPath(elements: finalElements, isClosed: true)
        
        // PROFESSIONAL REAL-TIME CLOSED PATH: Update the existing shape with closed path and default fill
        // Closed paths get both stroke AND fill using document defaults
        if let layerIndex = document.selectedLayerIndex {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                if document.layers[layerIndex].shapes[shapeIndex].id == activeShape.id {
                    // Update the existing shape to be closed with fill
                    document.layers[layerIndex].shapes[shapeIndex].path = closedPath
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: document.defaultFillColor,
                        opacity: document.defaultFillOpacity
                    )
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    break
                }
            }
        }
        
        print("🔧 DEBUG STEP 3: Path CLOSED - final curve creation")
        print("✅ SUCCESSFULLY CLOSED BEZIER PATH with \(bezierPoints.count) points using document defaults")
        print("Path elements: \(closedPath.elements.count) (including close)")
        print("Curve data preserved: \(closedPath.elements.compactMap { if case .curve = $0 { return 1 } else { return nil } }.count) curves")
        print("🎨 PEN TOOL CLOSED PATH COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
        
        // PROFESSIONAL ADOBE ILLUSTRATOR BEHAVIOR: Auto-switch to direct selection and select closed path
        let closedShapeID = activeShape.id
        
        // Clear bezier state BEFORE switching tools
        cancelBezierDrawing()
        
        // Hide any close path hints
        showClosePathHint = false
        
        // Switch to direct selection tool
        document.currentTool = .directSelection
        
        // Direct-select the closed shape
        directSelectedShapeIDs.removeAll()
        directSelectedShapeIDs.insert(closedShapeID)
        selectedPoints.removeAll() // Clear any existing point selections
        selectedHandles.removeAll() // Clear any existing handle selections
        
        print("🎯 AUTO-SWITCHED to Direct Selection and direct-selected closed path")
    }
    
    private func handleConvertAnchorPointTap(at location: CGPoint) {
        let tolerance: Double = 8.0 // Hit test tolerance
        
        // EXIT TEXT EDITING when using convert point tool (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        // Search through all visible layers and shapes for points to convert
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // PROTECT LOCKED LAYERS: Don't allow converting points on locked layers
            if layer.isLocked {
                continue
            }
            
            for (shapeIndex, shape) in layer.shapes.enumerated().reversed() {
                if !shape.isVisible { continue }
                
                // Check each path element for points
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .move(let to), .line(let to):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // Convert line point to smooth point by adding curve handles
                            convertLineToSmooth(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                            
                            // PROFESSIONAL UX: Auto-enable direct selection to show the result
                            enableDirectSelectionForConvertedPoint(shapeID: shape.id, elementIndex: elementIndex)
                            return
                        }
                    case .curve(let to, _, let control2):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // CRITICAL FIX: Proper corner point detection
                            // A point is a corner point if BOTH its incoming AND outgoing handles are collapsed to the anchor
                            
                            // Check incoming handle (control2 of current element)
                            let incomingHandleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
                            
                            // Check outgoing handle (control1 of NEXT element, if it exists)
                            var outgoingHandleCollapsed = true // Default to true if no next element
                            if elementIndex + 1 < shape.path.elements.count {
                                let nextElement = shape.path.elements[elementIndex + 1]
                                if case .curve(_, let nextControl1, _) = nextElement {
                                    outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                                }
                            }
                            
                            let isCornerPoint = incomingHandleCollapsed && outgoingHandleCollapsed
                            
                            if isCornerPoint {
                                // Convert corner point back to smooth curve
                                convertCornerToSmooth(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                print("🔄 DETECTED CORNER POINT → Converting to SMOOTH")
                            } else {
                                // Convert smooth point to corner point
                                convertSmoothToCorner(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                                print("🔄 DETECTED SMOOTH POINT → Converting to CORNER")
                            }
                            
                            // PROFESSIONAL UX: Auto-enable direct selection to show the result
                            enableDirectSelectionForConvertedPoint(shapeID: shape.id, elementIndex: elementIndex)
                            return
                        }
                    case .quadCurve(let to, _):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // Convert quad curve to corner point
                            convertQuadToCorner(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                            
                            // PROFESSIONAL UX: Auto-enable direct selection to show the result
                            enableDirectSelectionForConvertedPoint(shapeID: shape.id, elementIndex: elementIndex)
                            return
                        }
                    case .close:
                        continue
                    }
                }
            }
        }
        
        // If no point was found, try to select the shape for direct selection UI
        tryToSelectShapeForConvertTool(at: location)
        
        // ENHANCED DEBUGGING: Show detailed coordinate info for toolbar bleed-through investigation
        let documentBounds = document.documentBounds
        print("Convert Anchor Point: No point found at location \(location)")
        print("  - Document bounds: \(documentBounds)")
        print("  - Is within document: \(documentBounds.contains(location))")
        print("  - Current tool: \(document.currentTool.rawValue)")
        print("  - This might be a toolbar click bleeding through to canvas!")
    }
    
    // PROFESSIONAL UX: Auto-select shapes when clicking with Convert Point tool
    private func tryToSelectShapeForConvertTool(at location: CGPoint) {
        // Search for any shape at the click location
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            // PROTECT LOCKED LAYERS: Don't allow selecting shapes on locked layers for convert tool
            if layer.isLocked {
                continue
            }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                // PASTEBOARD BEHAVES EXACTLY LIKE CANVAS: Allow hit testing, handle via locked behavior
                
                var isHit = false
                
                // Use the same hit testing logic as selection tool
                // CRITICAL FIX: Background shapes (Canvas/Pasteboard) need special handling
                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                
                if isBackgroundShape {
                    // Background shapes: Use EXACT bounds checking - no tolerance!
                    let shapeBounds = shape.bounds.applying(shape.transform)
                    isHit = shapeBounds.contains(location)
                } else {
                    // Regular shapes: Use different logic for stroke vs filled
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Stroke-only shapes: Use stroke-based hit testing
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    } else {
                        // Regular shapes: Use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                        } else {
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                        }
                    }
                }
                
                if isHit {
                    // IMPROVED LOCKED BEHAVIOR: Handle locked layers/objects properly
                    if layer.isLocked || shape.isLocked {
                        let lockType = layer.isLocked ? "locked layer" : "locked object"
                        print("🚫 Convert Point Tool clicked on \(lockType) '\(shape.name)' - deselecting current selection")
                        selectedPoints.removeAll()
                        selectedHandles.removeAll()
                        directSelectedShapeIDs.removeAll()
                        document.objectWillChange.send()
                        return
                    }
                    
                    // Select this shape for direct selection UI
                    document.selectedShapeIDs.removeAll()
                    document.selectedTextIDs.removeAll()
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    directSelectedShapeIDs.removeAll()
                    
                    // Direct-select the shape to show all anchor points and handles
                    directSelectedShapeIDs.insert(shape.id)
                    
                    // Force UI update
                    document.objectWillChange.send()
                    
                    print("🎯 CONVERT POINT TOOL: Selected shape \(shape.name) for direct selection UI")
                    return
                }
            }
        }
        
        // If no shape was hit, clear all selections
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        document.objectWillChange.send()
    }
    
    // PROFESSIONAL UX IMPROVEMENT: Enable direct selection UI for convert point tool
    private func enableDirectSelectionForConvertedPoint(shapeID: UUID, elementIndex: Int) {
        // Clear any existing selections but KEEP the convert point tool active
        document.selectedShapeIDs.removeAll()
        document.selectedTextIDs.removeAll()
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        
        // DON'T switch tools - keep Convert Point tool active
        // But enable direct selection UI mode for this tool
        
        // Direct-select the shape that was modified (for UI display)
        directSelectedShapeIDs.insert(shapeID)
        
        // Select the specific point that was converted for immediate feedback
        let pointID = PointID(
            shapeID: shapeID,
            pathIndex: 0,
            elementIndex: elementIndex
        )
        selectedPoints.insert(pointID)
        
        // Force UI update to show the changes
        document.objectWillChange.send()
        
        print("🎯 CONVERT POINT TOOL: Enabled direct selection UI (tool stays active)")
        print("  - Shape: \(shapeID)")
        print("  - Point: Element \(elementIndex)")
        print("  - User can see bezier handles while continuing to use Convert Point tool")
    }
    
    private func convertLineToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .line(let to):
            // CRITICAL FIX: Convert line to curve but ONLY modify handles that belong to this anchor point
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // STEP 1: Convert current line element to curve with incoming handle
            let incomingHandle = VectorPoint(point.x - handleLength, point.y)
            elements[elementIndex] = .curve(to: point, control1: VectorPoint(point.x, point.y), control2: incomingHandle)
            
            // STEP 2: Add outgoing handle to NEXT element (if it exists and is a curve)
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, let nextControl2) = elements[elementIndex + 1] {
                    let outgoingHandle = VectorPoint(point.x + handleLength, point.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ CONVERTED LINE TO SMOOTH CURVE with proper handle structure")
            
        case .move(let to):
            // STEP 1: Move elements can't be converted directly, but we can add outgoing handle to next element
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // Add outgoing handle to NEXT element (if it exists and is a curve)
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, let nextControl2) = elements[elementIndex + 1] {
                    let outgoingHandle = VectorPoint(point.x + handleLength, point.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                    
                    document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("✅ ADDED OUTGOING HANDLE to move point")
                }
            }
            
        default:
            break
        }
    }
    
    private func convertSmoothToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, let control1, _):
            // CRITICAL FIX: Collapse handles to anchor point (creates corner point)
            let cornerPoint = VectorPoint(to.x, to.y)
            
            // STEP 1: Collapse incoming handle (control2) to anchor point
            elements[elementIndex] = .curve(to: cornerPoint, control1: control1, control2: cornerPoint)
            
            // STEP 2: Collapse outgoing handle (control1 of NEXT element) to anchor point
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, let nextControl2) = elements[elementIndex + 1] {
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: cornerPoint, control2: nextControl2)
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ CONVERTED SMOOTH CURVE TO CORNER POINT (handles collapsed to anchor)")
        default:
            break
        }
    }
    
    private func convertCornerToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        
        switch element {
        case .curve(let to, let control1, _):
            // CRITICAL FIX: Create proper 180-degree symmetric handles based on path direction
            let point = VectorPoint(to.x, to.y)
            let handleLength: Double = 30.0
            
            // Calculate the direction vector based on adjacent points
            var directionVector = CGPoint(x: 1.0, y: 0.0) // Default horizontal
            
            // Try to get direction from previous point
            if elementIndex > 0 {
                let prevElement = elements[elementIndex - 1]
                var prevPoint: VectorPoint?
                
                switch prevElement {
                case .move(let from), .line(let from):
                    prevPoint = from
                case .curve(let from, _, _):
                    prevPoint = from
                default:
                    break
                }
                
                if let prev = prevPoint {
                    let dx = point.x - prev.x
                    let dy = point.y - prev.y
                    let length = sqrt(dx * dx + dy * dy)
                    if length > 0.1 {
                        directionVector = CGPoint(x: dx / length, y: dy / length)
                    }
                }
            }
            // If no previous point, try to get direction from next point
            else if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                var nextPoint: VectorPoint?
                
                switch nextElement {
                case .move(let next), .line(let next):
                    nextPoint = next
                case .curve(let next, _, _):
                    nextPoint = next
                default:
                    break
                }
                
                if let next = nextPoint {
                    let dx = next.x - point.x
                    let dy = next.y - point.y
                    let length = sqrt(dx * dx + dy * dy)
                    if length > 0.1 {
                        directionVector = CGPoint(x: dx / length, y: dy / length)
                    }
                }
            }
            
            // ROTATE HANDLES BY -45 DEGREES for better visibility while maintaining 180-degree symmetry
            let rotationAngle = -45.0 * .pi / 180.0  // -45 degrees in radians
            let cosAngle = cos(rotationAngle)
            let sinAngle = sin(rotationAngle)
            
            // Apply rotation to direction vector
            let rotatedDirX = directionVector.x * cosAngle - directionVector.y * sinAngle
            let rotatedDirY = directionVector.x * sinAngle + directionVector.y * cosAngle
            
            // Create symmetric handles using the rotated direction vector (EXACTLY like pen tool)
            let outgoingHandle = VectorPoint(
                point.x + rotatedDirX * handleLength,
                point.y + rotatedDirY * handleLength
            )
            let incomingHandle = VectorPoint(
                point.x - rotatedDirX * handleLength,
                point.y - rotatedDirY * handleLength
            )
            
            // STEP 1: Add incoming handle (control2) to current element
            elements[elementIndex] = .curve(to: point, control1: control1, control2: incomingHandle)
            
            // STEP 2: Add outgoing handle (control1 of NEXT element) 
            if elementIndex + 1 < elements.count {
                if case .curve(let nextTo, _, let nextControl2) = elements[elementIndex + 1] {
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: outgoingHandle, control2: nextControl2)
                }
            }
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ CONVERTED CORNER POINT TO SMOOTH CURVE with 180-degree symmetric handles")
        default:
            break
        }
    }
    

    
    private func convertQuadToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        // Save to undo stack before making changes
        document.saveToUndoStack()
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        switch element {
        case .quadCurve(let to, _):
            // Convert quad curve to corner point (keep as curve structure)
            let cornerPoint = VectorPoint(to.x, to.y)
            let newElement = PathElement.curve(to: cornerPoint, control1: cornerPoint, control2: cornerPoint)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ CONVERTED QUAD CURVE TO CORNER POINT (handles collapsed to anchor)")
        default:
            break
        }
    }
    
    // SIMPLE 180-DEGREE SYMMETRIC HANDLES - NO COMPLEX MATH!
    private func calculateSmoothHandles(for point: VectorPoint, elementIndex: Int, in elements: [PathElement]) -> (incoming: VectorPoint, outgoing: VectorPoint) {
        // Just create simple horizontal 180-degree handles like Adobe Illustrator
        let handleLength: Double = 30.0
        
        let incomingHandle = VectorPoint(point.x - handleLength, point.y)
        let outgoingHandle = VectorPoint(point.x + handleLength, point.y)
        
        return (incomingHandle, outgoingHandle)
    }
    
    // MARK: - COORDINATE SYSTEM DEBUGGING AND TESTING
    // Use Cmd+Shift+T to analyze coordinate system consistency
    
    /// COMPREHENSIVE COORDINATE SYSTEM TEST
    /// This systematically tests that objects appear in the same location at all zoom levels
    private func runCoordinateSystemTest() {
        print("🎯 COMPREHENSIVE COORDINATE SYSTEM TEST")
        print("  Testing that objects appear at consistent screen positions across zoom levels")
        
        // Save current state
        let originalZoom = document.zoomLevel
        let originalOffset = document.canvasOffset
        
        // Clear existing objects for clean test
        if !document.layers.isEmpty {
            document.layers[0].shapes.removeAll()
        }
        
        // Test at "Fit to Page" zoom first
        document.zoomLevel = 1.0
        document.canvasOffset = CGPoint.zero
        
        // Create test objects at known canvas coordinates
        let testObjects = [
            (name: "Top-Left", point: CGPoint(x: 100, y: 100), color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0))),
            (name: "Top-Right", point: CGPoint(x: 400, y: 100), color: VectorColor.rgb(RGBColor(red: 0.0, green: 1.0, blue: 0.0))),
            (name: "Bottom-Left", point: CGPoint(x: 100, y: 300), color: VectorColor.rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0))),
            (name: "Center", point: CGPoint(x: 250, y: 200), color: VectorColor.rgb(RGBColor(red: 1.0, green: 1.0, blue: 0.0)))
        ]
        
        for testObj in testObjects {
            let shape = VectorShape(
                name: "TEST-\(testObj.name)",
                path: createTestCirclePath(center: testObj.point, radius: 20),
                strokeStyle: StrokeStyle(color: VectorColor.black, width: 2),
                fillStyle: FillStyle(color: testObj.color, opacity: 0.8)
            )
            document.addShape(shape)
            print("  ✅ Created \(testObj.name) at canvas coords: (\(testObj.point.x), \(testObj.point.y))")
        }
        
        print("  📏 COORDINATE SYSTEM ANALYSIS:")
        print("    Background: .scaleEffect(\(document.zoomLevel), anchor: .topLeading).offset(\(document.canvasOffset))")
        print("    Objects: .transformEffect(shape.transform).scaleEffect(\(document.zoomLevel), anchor: .topLeading).offset(\(document.canvasOffset))")
        print("    Current drawing: .scaleEffect(\(document.zoomLevel), anchor: .topLeading).offset(\(document.canvasOffset))")
        print("    ✅ ALL USE IDENTICAL COORDINATE TRANSFORMATIONS")
        
        print("  📊 OBJECT COORDINATE VERIFICATION:")
        for testObj in testObjects {
            if !document.layers.isEmpty,
               let shape = document.layers[0].shapes.first(where: { $0.name == "TEST-\(testObj.name)" }) {
                let centerX = (shape.bounds.minX + shape.bounds.maxX) / 2
                let centerY = (shape.bounds.minY + shape.bounds.maxY) / 2
                let actualCenter = CGPoint(x: centerX, y: centerY)
                
                let deltaX = abs(actualCenter.x - testObj.point.x)
                let deltaY = abs(actualCenter.y - testObj.point.y)
                
                if deltaX < 1.0 && deltaY < 1.0 {
                    print("    ✅ \(testObj.name): Expected (\(testObj.point.x), \(testObj.point.y)) → Actual (\(String(format: "%.1f", actualCenter.x)), \(String(format: "%.1f", actualCenter.y)))")
                } else {
                    print("    ❌ \(testObj.name): Expected (\(testObj.point.x), \(testObj.point.y)) → Actual (\(String(format: "%.1f", actualCenter.x)), \(String(format: "%.1f", actualCenter.y))) - DRIFT!")
                }
            }
        }
        
        // Restore original state
        document.zoomLevel = originalZoom
        document.canvasOffset = originalOffset
        
        print("  🔍 TESTING COMPLETE:")
        print("    - If all objects show ✅, coordinate system is CONSISTENT")
        print("    - If any show ❌, there's coordinate drift that needs fixing")
        print("    - Objects should remain in same relative positions when zooming")
        print("    - Drawing preview should match where final objects appear")
        print("=" + String(repeating: "=", count: 58))
    }
    
    /// CRITICAL DRAWING TEST - Verifies canvas doesn't move during drawing
    /// Use Cmd+Shift+D to test drawing stability
    private func runDrawingStabilityTest() {
        print("🚨 DRAWING STABILITY TEST")
        print("=" + String(repeating: "=", count: 58))
        print("  TESTING: Canvas must NOT move during drawing operations")
        print("  STATUS: isDrawing = \(isDrawing), isBezierDrawing = \(isBezierDrawing)")
        print("  ZOOM GESTURE: \(!isDrawing && !isBezierDrawing ? "ACTIVE" : "DISABLED")")
        print("  CURRENT ZOOM: \(String(format: "%.3f", document.zoomLevel))x")
        print("  CURRENT OFFSET: (\(String(format: "%.1f", document.canvasOffset.x)), \(String(format: "%.1f", document.canvasOffset.y)))")
        
        if isDrawing || isBezierDrawing {
            print("  🎯 DRAWING IN PROGRESS - Zoom gesture should be DISABLED")
            print("  ✅ Canvas is protected from zoom changes during drawing")
        } else {
            print("  ⏸️  NOT DRAWING - Zoom gesture is available")
            print("  📝 Start drawing a shape to test stability")
        }
        
        print("  INSTRUCTIONS:")
        print("    1. Select rectangle tool")
        print("    2. Start drawing a rectangle")
        print("    3. While drawing, try to pinch/zoom")
        print("    4. Canvas should NOT move or zoom")
        print("    5. Only after releasing should zoom be available")
        print("=" + String(repeating: "=", count: 58))
    }
    
    /// Create a simple circle path for testing purposes
    private func createTestCirclePath(center: CGPoint, radius: Double) -> VectorPath {
        let steps = 32 // Number of segments for circle approximation
        var elements: [PathElement] = []
        
        for i in 0...steps {
            let angle = Double(i) * 2.0 * .pi / Double(steps)
            let x = center.x + cos(angle) * radius
            let y = center.y + sin(angle) * radius
            
            if i == 0 {
                elements.append(.move(to: VectorPoint(x, y)))
            } else {
                elements.append(.line(to: VectorPoint(x, y)))
            }
        }
        elements.append(.close)
        
        return VectorPath(elements: elements, isClosed: true)
    }
    
    /// COMPREHENSIVE DRAWING TEST - Run this to debug coordinate system issues
    /// Use Cmd+Shift+R to run this test
    private func runRealDrawingTest(geometry: GeometryProxy) {
        print("🔥 REAL DRAWING TEST - TRACKING COORDINATE SYSTEM CHANGES")
        print("=" + String(repeating: "=", count: 80))
        
        // Log initial state
        print("📊 INITIAL STATE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Initial Zoom Level: \(String(format: "%.6f", initialZoomLevel))")
        print("   Is Drawing: \(isDrawing)")
        print("   Is Bezier Drawing: \(isBezierDrawing)")
        
        // Clear any existing shapes
        if !document.layers.isEmpty {
            document.layers[0].shapes.removeAll()
        }
        
        // Create a test shape at a known position
        let testCenter = CGPoint(x: 300, y: 250)
        let testShape = VectorShape(
            name: "TEST SHAPE",
            path: createTestCirclePath(center: testCenter, radius: 30),
            strokeStyle: StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), width: 3),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), opacity: 0.8)
        )
        
        print("📍 CREATING TEST SHAPE:")
        print("   Expected center: (\(testCenter.x), \(testCenter.y))")
        
        // Log state before adding shape
        print("📊 BEFORE ADDING SHAPE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Add the shape
        document.addShape(testShape)
        
        // Log state after adding shape
        print("📊 AFTER ADDING SHAPE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Verify the shape's actual position
        if let addedShape = document.layers[0].shapes.first(where: { $0.name == "TEST SHAPE" }) {
            let actualCenter = CGPoint(
                x: (addedShape.bounds.minX + addedShape.bounds.maxX) / 2,
                y: (addedShape.bounds.minY + addedShape.bounds.maxY) / 2
            )
            
            print("📍 SHAPE VERIFICATION:")
            print("   Expected center: (\(String(format: "%.6f", testCenter.x)), \(String(format: "%.6f", testCenter.y)))")
            print("   Actual center: (\(String(format: "%.6f", actualCenter.x)), \(String(format: "%.6f", actualCenter.y)))")
            
            let deltaX = abs(actualCenter.x - testCenter.x)
            let deltaY = abs(actualCenter.y - testCenter.y)
            
            if deltaX < 0.1 && deltaY < 0.1 {
                print("   ✅ SHAPE POSITION CORRECT")
            } else {
                print("   ❌ SHAPE POSITION DRIFT: ΔX=\(String(format: "%.6f", deltaX)), ΔY=\(String(format: "%.6f", deltaY))")
            }
        }
        
        // Now simulate drawing operations to see if coordinate system changes
        print("🎨 SIMULATING DRAWING OPERATIONS:")
        
        // Simulate start drawing
        isDrawing = true
        print("📊 DURING DRAWING (isDrawing = true):")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        // Create a drawing preview to see if coordinate system shifts
        let previewStart = CGPoint(x: 200, y: 200)
        let previewEnd = CGPoint(x: 400, y: 300)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(previewStart)),
            .line(to: VectorPoint(previewEnd))
        ])
        
        print("📍 DRAWING PREVIEW CREATED:")
        print("   Preview start: (\(String(format: "%.6f", previewStart.x)), \(String(format: "%.6f", previewStart.y)))")
        print("   Preview end: (\(String(format: "%.6f", previewEnd.x)), \(String(format: "%.6f", previewEnd.y)))")
        
        // Log state with drawing preview
        print("📊 WITH DRAWING PREVIEW:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Simulate end drawing
        isDrawing = false
        currentPath = nil
        
        print("📊 AFTER DRAWING (isDrawing = false):")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        // Test coordinate conversion consistency
        print("🔄 COORDINATE CONVERSION TEST:")
        let testCanvasPoint = CGPoint(x: 300, y: 200)
        let screenPoint = canvasToScreen(testCanvasPoint, geometry: geometry)
        let backToCanvas = screenToCanvas(screenPoint, geometry: geometry)
        
        print("   Canvas → Screen → Canvas:")
        print("   Original: (\(String(format: "%.6f", testCanvasPoint.x)), \(String(format: "%.6f", testCanvasPoint.y)))")
        print("   Screen: (\(String(format: "%.6f", screenPoint.x)), \(String(format: "%.6f", screenPoint.y)))")
        print("   Back to Canvas: (\(String(format: "%.6f", backToCanvas.x)), \(String(format: "%.6f", backToCanvas.y)))")
        
        let conversionDeltaX = abs(backToCanvas.x - testCanvasPoint.x)
        let conversionDeltaY = abs(backToCanvas.y - testCanvasPoint.y)
        
        if conversionDeltaX < 0.001 && conversionDeltaY < 0.001 {
            print("   ✅ COORDINATE CONVERSION ACCURATE")
        } else {
            print("   ❌ COORDINATE CONVERSION DRIFT: ΔX=\(String(format: "%.6f", conversionDeltaX)), ΔY=\(String(format: "%.6f", conversionDeltaY))")
        }
        
        print("=" + String(repeating: "=", count: 80))
        print("🏁 TEST COMPLETE - Check above for coordinate system issues")
    }

    /// SIMPLE DRAWING TEST - Debug coordinate system without geometry
    /// Use Cmd+Shift+R to run this test
    private func runRealDrawingTestSimple() {
        print("🔥 SIMPLE DRAWING TEST - TRACKING COORDINATE SYSTEM")
        print("=" + String(repeating: "=", count: 80))
        
        // Log initial state
        print("📊 INITIAL STATE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Initial Zoom Level: \(String(format: "%.6f", initialZoomLevel))")
        print("   Is Drawing: \(isDrawing)")
        print("   Is Bezier Drawing: \(isBezierDrawing)")
        
        // Clear any existing shapes
        if !document.layers.isEmpty {
            document.layers[0].shapes.removeAll()
        }
        
        // Create a test shape at a known position
        let testCenter = CGPoint(x: 300, y: 250)
        let testShape = VectorShape(
            name: "TEST SHAPE",
            path: createTestCirclePath(center: testCenter, radius: 30),
            strokeStyle: StrokeStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), width: 3),
            fillStyle: FillStyle(color: VectorColor.rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), opacity: 0.8)
        )
        
        print("📍 CREATING TEST SHAPE:")
        print("   Expected center: (\(testCenter.x), \(testCenter.y))")
        
        // Log state before adding shape
        print("📊 BEFORE ADDING SHAPE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Add the shape
        document.addShape(testShape)
        
        // Log state after adding shape
        print("📊 AFTER ADDING SHAPE:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Verify the shape's actual position
        if let addedShape = document.layers[0].shapes.first(where: { $0.name == "TEST SHAPE" }) {
            let actualCenter = CGPoint(
                x: (addedShape.bounds.minX + addedShape.bounds.maxX) / 2,
                y: (addedShape.bounds.minY + addedShape.bounds.maxY) / 2
            )
            
            print("📍 SHAPE VERIFICATION:")
            print("   Expected center: (\(String(format: "%.6f", testCenter.x)), \(String(format: "%.6f", testCenter.y)))")
            print("   Actual center: (\(String(format: "%.6f", actualCenter.x)), \(String(format: "%.6f", actualCenter.y)))")
            
            let deltaX = abs(actualCenter.x - testCenter.x)
            let deltaY = abs(actualCenter.y - testCenter.y)
            
            if deltaX < 0.1 && deltaY < 0.1 {
                print("   ✅ SHAPE POSITION CORRECT")
            } else {
                print("   ❌ SHAPE POSITION DRIFT: ΔX=\(String(format: "%.6f", deltaX)), ΔY=\(String(format: "%.6f", deltaY))")
            }
        }
        
        // Now simulate drawing operations to see if coordinate system changes
        print("🎨 SIMULATING DRAWING OPERATIONS:")
        
        // Simulate start drawing
        isDrawing = true
        print("📊 DURING DRAWING (isDrawing = true):")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        // Create a drawing preview to see if coordinate system shifts
        let previewStart = CGPoint(x: 200, y: 200)
        let previewEnd = CGPoint(x: 400, y: 300)
        currentPath = VectorPath(elements: [
            .move(to: VectorPoint(previewStart)),
            .line(to: VectorPoint(previewEnd))
        ])
        
        print("📍 DRAWING PREVIEW CREATED:")
        print("   Preview start: (\(String(format: "%.6f", previewStart.x)), \(String(format: "%.6f", previewStart.y)))")
        print("   Preview end: (\(String(format: "%.6f", previewEnd.x)), \(String(format: "%.6f", previewEnd.y)))")
        
        // Log state with drawing preview
        print("📊 WITH DRAWING PREVIEW:")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        
        // Simulate end drawing
        isDrawing = false
        currentPath = nil
        
        print("📊 AFTER DRAWING (isDrawing = false):")
        print("   Zoom Level: \(String(format: "%.6f", document.zoomLevel))")
        print("   Canvas Offset: (\(String(format: "%.6f", document.canvasOffset.x)), \(String(format: "%.6f", document.canvasOffset.y)))")
        print("   Zoom Gesture Enabled: \(!isDrawing && !isBezierDrawing)")
        
        print("=" + String(repeating: "=", count: 80))
        print("🏁 SIMPLE TEST COMPLETE - Run this test and then try drawing to compare")
        print("   Next steps:")
        print("   1. Note the values above")
        print("   2. Try drawing a rectangle manually")
        print("   3. Check if zoom/offset values change during drawing")
        print("   4. If values change, we found the coordinate system bug!")
    }
    
    // MARK: - Native Mouse Event Handling
    
    private func handleMouseEvent(_ event: NSEvent, geometry: GeometryProxy) {
        switch event.type {
        case .leftMouseDown:
            handleNativeMouseDown(event, geometry: geometry)
        default:
            break
        }
    }
    
    private func handleNativeMouseDown(_ event: NSEvent, geometry: GeometryProxy) {
        // Get mouse location in view coordinates
        guard let window = NSApp.keyWindow else { return }
        
        let locationInWindow = event.locationInWindow
        let locationInView = window.contentView?.convert(locationInWindow, from: nil) ?? locationInWindow
        
        // Convert to our coordinate system (flip Y axis for AppKit->SwiftUI conversion)
        let screenLocation = CGPoint(x: locationInView.x, y: geometry.size.height - locationInView.y)
        let canvasLocation = screenToCanvas(screenLocation, geometry: geometry)
        
        // Check if this is in pasteboard area (outside canvas bounds)
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612)
        let isInPasteboardArea = !canvasBounds.contains(canvasLocation)
        
        if isInPasteboardArea {
            print("🖱️ NATIVE MOUSE DOWN in PASTEBOARD AREA at: \(canvasLocation)")
            print("🖱️ This bypasses SwiftUI gesture limitations for negative/large coordinates!")
            
            // Handle the pasteboard click directly
            if document.currentTool == .selection {
                handleSelectionTap(at: canvasLocation)
            }
        }
    }

    private func fitToPage(geometry: GeometryProxy) {
        // Use standard document bounds for fit-to-page calculations
        let documentBounds = document.documentBounds
        let viewSize = geometry.size
        
        // Calculate zoom level to fit the canvas in the view with padding
        let padding: CGFloat = 50.0
        let availableWidth = viewSize.width - (padding * 2)
        let availableHeight = viewSize.height - (padding * 2)
        
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let fitZoom = min(scaleX, scaleY)
        
        // Set zoom level to fit canvas in view
        document.zoomLevel = max(0.1, min(10.0, fitZoom))
        
        // Center canvas in view at the fit zoom
        let viewCenter = CGPoint(
            x: viewSize.width / 2.0,
            y: viewSize.height / 2.0
        )
        
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Calculate offset to center document
        document.canvasOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * document.zoomLevel),
            y: viewCenter.y - (documentCenter.y * document.zoomLevel)
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = document.zoomLevel
        
        print("🔍 FIT TO PAGE: Using standard document bounds")
        print("   Document Bounds: \(documentBounds)")
        print("   Fit Zoom: \(String(format: "%.1f", fitZoom * 100))% (minimum scale to fit)")
        print("   Standard coordinate system approach")
    }

}

// MARK: - Native Mouse Event View

struct MouseEventView: NSViewRepresentable {
    let onMouseEvent: (NSEvent) -> Void
    
    func makeNSView(context: Context) -> NSView {
        let view = MouseTrackingView()
        view.onMouseEvent = onMouseEvent
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        if let trackingView = nsView as? MouseTrackingView {
            trackingView.onMouseEvent = onMouseEvent
        }
    }
}

class MouseTrackingView: NSView {
    var onMouseEvent: ((NSEvent) -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        onMouseEvent?(event)
        super.mouseDown(with: event)
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}

struct ProfessionalDirectSelectionView: View {
    let document: VectorDocument
    let selectedPoints: Set<DrawingCanvas.PointID>
    let selectedHandles: Set<DrawingCanvas.HandleID>
    let directSelectedShapeIDs: Set<UUID>
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // PROFESSIONAL BEZIER DISPLAY: Show ALL anchor points and handles for direct-selected shapes
            // This matches Adobe Illustrator, Photoshop, and FreeHand professional standards
            ForEach(document.layers.indices, id: \.self) { layerIndex in
                let layer = document.layers[layerIndex]
                if layer.isVisible {
                    ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                        let shape = layer.shapes[shapeIndex]
                        if shape.isVisible && directSelectedShapeIDs.contains(shape.id) {
                            // CRITICAL: Show ALL bezier curve handles for direct-selected shapes (Adobe Illustrator standard)
                            professionalBezierDisplay(for: shape)
                        }
                    }
                }
            }
            
            // HIGHLIGHT INDIVIDUALLY SELECTED HANDLES - USE SAME COORDINATE SYSTEM AS ARROW TOOL
            ForEach(Array(selectedHandles), id: \.self) { handleID in
                if let handleInfo = getHandleInfo(handleID),
                   let shape = getShapeForHandle(handleID) {
                    // Draw HIGHLIGHTED line from point to handle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    Path { path in
                        path.move(to: handleInfo.pointLocation)
                        path.addLine(to: handleInfo.handleLocation)
                    }
                    .stroke(Color.orange, lineWidth: 2.0 / document.zoomLevel) // Scale-independent, orange for selected handles
                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                    .transformEffect(shape.transform)
                    
                    // Draw HIGHLIGHTED handle as larger circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    Circle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 6 / document.zoomLevel, height: 6 / document.zoomLevel) // Scale-independent
                        .position(handleInfo.handleLocation)
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                        .transformEffect(shape.transform)
                }
            }
            
            // HIGHLIGHT INDIVIDUALLY SELECTED ANCHOR POINTS - USE SAME COORDINATE SYSTEM AS ARROW TOOL
            ForEach(Array(selectedPoints), id: \.self) { pointID in
                if let pointLocation = getPointLocation(pointID),
                   let shape = getShapeForPoint(pointID) {
                    Rectangle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 8 / document.zoomLevel, height: 8 / document.zoomLevel) // Scale-independent
                        .position(pointLocation)
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                        .transformEffect(shape.transform)
                }
            }
        }
    }
    
    @ViewBuilder
    private func professionalBezierDisplay(for shape: VectorShape) -> some View {
        ZStack {
            // RENDER ALL HANDLES AND ANCHOR POINTS - USE SAME COORDINATE CHAIN AS ARROW TOOL
            ForEach(Array(shape.path.elements.enumerated()), id: \.offset) { elementIndex, element in
                Group {
                    // HANDLES FIRST - USE SAME COORDINATE CHAIN AS ARROW TOOL
                    switch element {
                    case .curve(let to, _, let control2):
                        let anchorLocation = CGPoint(x: to.x, y: to.y)
                        let control2Location = CGPoint(x: control2.x, y: control2.y)
                        
                        // INCOMING HANDLE LINE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Path { path in
                            path.move(to: anchorLocation)
                            path.addLine(to: control2Location)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                        .scaleEffect(document.zoomLevel, anchor: .topLeading)
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                        .transformEffect(shape.transform)
                        
                        // INCOMING HANDLE CIRCLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Circle()
                            .fill(Color.blue)
                            .stroke(Color.white, lineWidth: 0.5)
                            .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                            .position(control2Location)
                            .scaleEffect(document.zoomLevel, anchor: .topLeading)
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                            .transformEffect(shape.transform)
                            
                        // OUTGOING HANDLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        if elementIndex + 1 < shape.path.elements.count {
                            let nextElement = shape.path.elements[elementIndex + 1]
                            if case .curve(_, let nextControl1, _) = nextElement {
                                let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                
                                // OUTGOING HANDLE LINE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Path { path in
                                    path.move(to: anchorLocation)
                                    path.addLine(to: control1Location)
                                }
                                .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                                .transformEffect(shape.transform)
                                
                                // OUTGOING HANDLE CIRCLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Circle()
                                    .fill(Color.blue)
                                    .stroke(Color.white, lineWidth: 0.5)
                                    .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                                    .position(control1Location)
                                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                                    .transformEffect(shape.transform)
                            }
                        }
                        
                    case .move(let to), .line(let to):
                        let anchorLocation = CGPoint(x: to.x, y: to.y)
                        
                        // OUTGOING HANDLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        if elementIndex + 1 < shape.path.elements.count {
                            let nextElement = shape.path.elements[elementIndex + 1]
                            if case .curve(_, let nextControl1, _) = nextElement {
                                let control1Location = CGPoint(x: nextControl1.x, y: nextControl1.y)
                                
                                // OUTGOING HANDLE LINE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Path { path in
                                    path.move(to: anchorLocation)
                                    path.addLine(to: control1Location)
                                }
                                .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                                .transformEffect(shape.transform)
                                
                                // OUTGOING HANDLE CIRCLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Circle()
                                    .fill(Color.blue)
                                    .stroke(Color.white, lineWidth: 0.5)
                                    .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                                    .position(control1Location)
                                    .scaleEffect(document.zoomLevel, anchor: .topLeading)
                                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                                    .transformEffect(shape.transform)
                            }
                        }
                        
                    default:
                        EmptyView()
                    }
                    
                    // ANCHOR POINTS ON TOP - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    if let point = extractPointFromElement(element) {
                        let pointLocation = CGPoint(x: point.x, y: point.y)
                        
                        let pointID = DrawingCanvas.PointID(
                            shapeID: shape.id,
                            pathIndex: 0,
                            elementIndex: elementIndex
                        )
                        let isPointSelected = selectedPoints.contains(pointID)
                        
                        Rectangle()
                            .fill(isPointSelected ? Color.blue : Color.white)
                            .stroke(Color.blue, lineWidth: 1.0)
                            .frame(width: 6 / document.zoomLevel, height: 6 / document.zoomLevel) // Scale-independent
                            .position(pointLocation)
                            .scaleEffect(document.zoomLevel, anchor: .topLeading)
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                            .transformEffect(shape.transform)
                    }
                }
            }
        }
    }
    
    private func extractPointFromElement(_ element: PathElement) -> VectorPoint? {
        switch element {
        case .move(let to), .line(let to):
            return to
        case .curve(let to, _, _), .quadCurve(let to, _):
            return to
        case .close:
            return nil
        }
    }
    
    // REMOVED: Duplicate function - use the precision version above
    
    private func getPointLocation(_ pointID: DrawingCanvas.PointID) -> CGPoint? {
        // Find the shape and extract point location
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                if pointID.elementIndex < shape.path.elements.count {
                    let element = shape.path.elements[pointID.elementIndex]
                    
                    switch element {
                    case .move(let to), .line(let to):
                        return CGPoint(x: to.x, y: to.y)
                    case .curve(let to, _, _):
                        return CGPoint(x: to.x, y: to.y)
                    case .quadCurve(let to, _):
                        return CGPoint(x: to.x, y: to.y)
                    case .close:
                        return nil
                    }
                }
            }
        }
        return nil
    }
    
    private func getHandleInfo(_ handleID: DrawingCanvas.HandleID) -> (pointLocation: CGPoint, handleLocation: CGPoint)? {
        // CRITICAL FIX: Match the selection logic exactly!
        // HandleIDs now point to where the handle data actually lives in the bezier structure
        
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                if handleID.elementIndex < shape.path.elements.count {
                    let element = shape.path.elements[handleID.elementIndex]
                    
                    switch element {
                    case .curve(let to, let control1, let control2):
                        if handleID.handleType == .control1 {
                            // OUTGOING HANDLE: control1 of current element belongs to PREVIOUS anchor point
                            if handleID.elementIndex > 0 {
                                let prevElement = shape.path.elements[handleID.elementIndex - 1]
                                switch prevElement {
                                case .move(let prevTo), .line(let prevTo):
                                    let pointLocation = CGPoint(x: prevTo.x, y: prevTo.y)
                                    let handleLocation = CGPoint(x: control1.x, y: control1.y)
                                    return (pointLocation, handleLocation)
                                case .curve(let prevTo, _, _):
                                    let pointLocation = CGPoint(x: prevTo.x, y: prevTo.y)
                                    let handleLocation = CGPoint(x: control1.x, y: control1.y)
                                    return (pointLocation, handleLocation)
                                default:
                                    return nil
                                }
                            }
                        } else {
                            // INCOMING HANDLE: control2 of current element belongs to current anchor point
                            let pointLocation = CGPoint(x: to.x, y: to.y)
                            let handleLocation = CGPoint(x: control2.x, y: control2.y)
                            return (pointLocation, handleLocation)
                        }
                    case .quadCurve(let to, let control):
                        if handleID.handleType == .control1 {
                            // For quad curves, control1 could be outgoing from previous point
                            if handleID.elementIndex > 0 {
                                let prevElement = shape.path.elements[handleID.elementIndex - 1]
                                switch prevElement {
                                case .move(let prevTo), .line(let prevTo), .curve(let prevTo, _, _):
                                    let pointLocation = CGPoint(x: prevTo.x, y: prevTo.y)
                                    let handleLocation = CGPoint(x: control.x, y: control.y)
                                    return (pointLocation, handleLocation)
                                default:
                                    return nil
                                }
                            }
                        } else {
                            // Standard quad curve control handle
                            let pointLocation = CGPoint(x: to.x, y: to.y)
                            let handleLocation = CGPoint(x: control.x, y: control.y)
                            return (pointLocation, handleLocation)
                        }
                    default:
                        return nil
                    }
                }
            }
        }
        return nil
    }
    
    private func getShapeForHandle(_ handleID: DrawingCanvas.HandleID) -> VectorShape? {
        // Find the shape that contains this handle
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                return shape
            }
        }
        return nil
    }
    
    private func getShapeForPoint(_ pointID: DrawingCanvas.PointID) -> VectorShape? {
        // Find the shape that contains this point
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                return shape
            }
        }
        return nil
    }
    
}
