//
//  DrawingCanvas.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct DrawingCanvas: View {
    @ObservedObject var document: VectorDocument
    @State private var currentPath: VectorPath?
    @State private var isDrawing = false
    @State private var dragOffset = CGSize.zero
    @State private var lastPanLocation = CGPoint.zero
    @State private var drawingStartPoint: CGPoint?
    @State private var currentDrawingPoints: [CGPoint] = []
    @State private var dragStartTransforms: [UUID: CGAffineTransform] = [:]
    @State private var lastTapTime: Date = Date()
    
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
    
    // Professional bezier handle information
    struct BezierHandleInfo {
        var control1: VectorPoint?
        var control2: VectorPoint?
        var hasHandles: Bool = false
    }
    
    // Track previous tool to detect changes
    @State private var previousTool: DrawingTool = .selection
    
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
            ZStack {
                // Background
                Rectangle()
                    .fill(document.settings.backgroundColor.color)
                    .frame(width: document.settings.sizeInPoints.width * document.zoomLevel,
                           height: document.settings.sizeInPoints.height * document.zoomLevel)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                
                // Grid (if enabled)
                if document.snapToGrid {
                    GridView(document: document, geometry: geometry)
                }
                
                // Render all layers and shapes
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
                
                // Current drawing path (while drawing)
                if let currentPath = currentPath {
                    Path { path in
                        addPathElements(currentPath.elements, to: &path)
                    }
                    .stroke(Color.blue, lineWidth: 1.0)
                    .scaleEffect(document.zoomLevel)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                }
                
                // PROFESSIONAL BEZIER PATH PREVIEW (Adobe Illustrator style with scale-independent rendering)
                bezierPathPreview()
                
                // PROFESSIONAL RUBBER BAND PREVIEW (Adobe Illustrator Standards)
                rubberBandPreview(geometry: geometry)
                
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
                                .scaleEffect(document.zoomLevel * 1.2)   // Same as arrow tool with animation scale
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
                                .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        }
                        
                        // Render bezier handles if they exist for this point - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        if let handleInfo = bezierHandles[index], handleInfo.hasHandles {
                            // Draw control handle lines - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                            if let control1 = handleInfo.control1 {
                                let control1Location = CGPoint(x: control1.x, y: control1.y)
                                Path { path in
                                    path.move(to: pointLocation)
                                    path.addLine(to: control1Location)
                                }
                                .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                                .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                                
                                // Control handle circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                                    .position(control1Location)
                                    .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                            }
                            
                            if let control2 = handleInfo.control2 {
                                let control2Location = CGPoint(x: control2.x, y: control2.y)
                                Path { path in
                                    path.move(to: pointLocation)
                                    path.addLine(to: control2Location)
                                }
                                .stroke(Color.blue, lineWidth: 1.0 / document.zoomLevel) // Scale-independent
                                .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                                
                                // Control handle circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                                    .position(control2Location)
                                    .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                            }
                        }
                    }
                }
                
                // PROFESSIONAL CLOSE PATH VISUAL HINT - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                if showClosePathHint {
                    ZStack {
                        // Green circle indicating close path area - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Circle()
                            .stroke(Color.green, lineWidth: 2.0 / document.zoomLevel) // Scale-independent
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 16 / document.zoomLevel, height: 16 / document.zoomLevel) // Scale-independent
                            .position(closePathHintLocation)
                            .scaleEffect(document.zoomLevel)   // Same as arrow tool
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        
                        // Small "close" icon - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Image(systemName: "multiply.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12 / document.zoomLevel)) // Scale-independent
                            .position(closePathHintLocation)
                            .scaleEffect(document.zoomLevel)   // Same as arrow tool
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                    }
                    .animation(.easeInOut(duration: 0.2), value: showClosePathHint)
                }
                
                // Selection handles for selected shapes
                SelectionHandlesView(
                    document: document,
                    geometry: geometry
                )
                
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
            .onTapGesture { location in
                handleTap(at: location, geometry: geometry)
            }
            .onHover { isHovering in
                // Enable mouse tracking for rubber band preview
            }
            .onContinuousHover { phase in
                if case .active(let location) = phase {
                    currentMouseLocation = location
                    
                    // PROFESSIONAL CLOSE PATH VISUAL FEEDBACK
                    if isBezierDrawing && document.currentTool == .bezierPen && bezierPoints.count >= 3 {
                        let canvasLocation = screenToCanvas(location, geometry: geometry)
                        let firstPoint = bezierPoints[0]
                        let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                        let closeTolerance: Double = 25.0
                        
                        if distance(canvasLocation, firstPointLocation) <= closeTolerance {
                            showClosePathHint = true
                            closePathHintLocation = firstPointLocation // USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        } else {
                            showClosePathHint = false
                        }
                    } else {
                        showClosePathHint = false
                    }
                } else {
                    currentMouseLocation = nil
                    showClosePathHint = false
                }
            }

            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        handleDragChanged(value: value, geometry: geometry)
                    }
                    .onEnded { value in
                        handleDragEnded(value: value, geometry: geometry)
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        handleZoom(value: value, geometry: geometry)
                    }
            )
            .contextMenu {
                directSelectionContextMenu
            }
        }
    }
    
    // MARK: - Professional Preview Functions (Adobe Illustrator Standards)
    
    @ViewBuilder
    private func bezierPathPreview() -> some View {
        // PROFESSIONAL BEZIER PATH PREVIEW (Adobe Illustrator style with scale-independent rendering)
        if let bezierPath = bezierPath {
            // PROFESSIONAL SCALE-INDEPENDENT PATH RENDERING
            let strokeWidth = 2.0 / document.zoomLevel  // Scale-independent stroke width
            
            // Show current path with professional scaling
            Path { path in
                addPathElements(bezierPath.elements, to: &path)
            }
            .stroke(Color.orange, lineWidth: strokeWidth)
            .scaleEffect(document.zoomLevel)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            
            // ADOBE ILLUSTRATOR-STYLE CLOSING PREVIEW
            // Show what the closed path will look like when hovering near first point
            if showClosePathHint && bezierPoints.count >= 3 {
                let dashLength = 5.0 / document.zoomLevel  // Scale-independent dash
                let gapLength = 3.0 / document.zoomLevel   // Scale-independent gap
                
                let closingPreviewElements: [PathElement] = {
                    var elements = bezierPath.elements
                    elements.append(.close)
                    return elements
                }()
                
                Path { path in
                    addPathElements(closingPreviewElements, to: &path)
                }
                .stroke(Color.green.opacity(0.8), style: SwiftUI.StrokeStyle(
                    lineWidth: strokeWidth, 
                    lineCap: .round, 
                    dash: [dashLength, gapLength]
                ))
                .scaleEffect(document.zoomLevel)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            }
        }
    }
    
    @ViewBuilder
    private func rubberBandPreview(geometry: GeometryProxy) -> some View {
        if isBezierDrawing && document.currentTool == .bezierPen,
           let mouseLocation = currentMouseLocation,
           bezierPoints.count > 0 {
            let canvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPoint = bezierPoints[bezierPoints.count - 1]
            let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
            
            // PROFESSIONAL SCALE-INDEPENDENT RUBBER BAND (Adobe Illustrator Standards)
            let strokeWidth = 2.0 / document.zoomLevel    // Scale-independent close preview
            let rubberBandWidth = 1.0 / document.zoomLevel  // Scale-independent rubber band
            
            // PROFESSIONAL CLOSING STROKE PREVIEW
            if showClosePathHint && bezierPoints.count >= 3 {
                // Show the closing stroke back to first point (GREEN)
                let firstPoint = bezierPoints[0]
                let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                
                Path { path in
                    path.move(to: lastPointLocation)
                    path.addLine(to: firstPointLocation)
                }
                .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .scaleEffect(document.zoomLevel)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            } else {
                // PROFESSIONAL RUBBER BAND LINE (Adobe Illustrator style)
                Path { path in
                    path.move(to: lastPointLocation)
                    path.addLine(to: canvasMouseLocation)
                }
                .stroke(Color.gray.opacity(0.7), style: SwiftUI.StrokeStyle(lineWidth: rubberBandWidth, lineCap: .round))
                .scaleEffect(document.zoomLevel)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            }
        }
    }
    
    private func setupCanvas(geometry: GeometryProxy) {
        // Center the canvas initially
        let canvasSize = document.settings.sizeInPoints
        let viewSize = geometry.size
        
        document.canvasOffset = CGPoint(
            x: (viewSize.width - canvasSize.width * document.zoomLevel) / 2,
            y: (viewSize.height - canvasSize.height * document.zoomLevel) / 2
        )
    }
    
    private func handleTap(at location: CGPoint, geometry: GeometryProxy) {
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
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
        default:
            // Cancel bezier drawing if switching to other tools
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            break
        }
    }
    
    private func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        switch document.currentTool {
        case .hand:
            handlePanGesture(value: value)
        case .line, .rectangle, .circle, .star:
            handleShapeDrawing(value: value, geometry: geometry)
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
                    startSelectionDrag()
                    isDrawing = true
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
            if isBezierDrawing {
                handleBezierPenDrag(value: value, geometry: geometry)
            }
        default:
            break
        }
    }
    
    private func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        switch document.currentTool {
        case .line, .rectangle, .circle, .star:
            finishShapeDrawing(value: value, geometry: geometry)
            // Reset drawing state for shape tools
            isDrawing = false
            currentPath = nil
            drawingStartPoint = nil
            currentDrawingPoints.removeAll()
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
                    return nil
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
        print("🎯 Selection tool tap at: \(location)")
        
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
                
                print("Testing shape: \(shape.name)")
                print("  - Has stroke: \(shape.strokeStyle != nil)")
                print("  - Has fill: \(shape.fillStyle != nil)")
                print("  - Fill color: \(String(describing: shape.fillStyle?.color))")
                print("  - Bounds: \(shape.bounds)")
                
                // Try multiple hit testing approaches for better reliability
                var isHit = false
                
                // Method 1: For stroke-only paths (like bezier curves), use stroke-based hit testing
                let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                
                if isStrokeOnly && shape.strokeStyle != nil {
                    // Use stroke width + padding for tolerance
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeTolerance = max(15.0, strokeWidth + 10.0) // Increased tolerance
                    
                    print("  - Testing stroke-only path with tolerance: \(strokeTolerance)")
                    isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    print("  - Stroke hit test result: \(isHit)")
                } else {
                    // Method 2: Check transformed bounds with tolerance for filled shapes
                    let transformedBounds = shape.bounds.applying(shape.transform)
                    let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                    
                    if expandedBounds.contains(location) {
                        isHit = true
                        print("  - Hit via bounds check")
                    } else {
                        // Method 3: Fallback path hit test
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                        print("  - Path hit test result: \(isHit)")
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
            // Only clear selection if clicking on empty space without modifiers
            if !isShiftPressed && !isCommandPressed {
                document.selectedShapeIDs.removeAll()
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
            // Start new bezier path
            bezierPath = VectorPath(elements: [.move(to: VectorPoint(location))])
            bezierPoints = [VectorPoint(location)]
            isBezierDrawing = true
            activeBezierPointIndex = 0 // First point is active (solid)
            bezierHandles.removeAll()
            print("Started bezier path at \(location)")
        } else {
            // Make previous point inactive (hollow)
            let previousActiveIndex = activeBezierPointIndex
            
            // Add new point and make it active (solid)
            let newPoint = VectorPoint(location)
            bezierPoints.append(newPoint)
            activeBezierPointIndex = bezierPoints.count - 1
            
            // Create line to the new point (will be converted to curve if handles are added)
            bezierPath?.addElement(.line(to: newPoint))
            
            print("Added bezier point \(bezierPoints.count): \(location)")
            print("Previous point \(previousActiveIndex ?? -1) is now hollow, current point \(activeBezierPointIndex ?? -1) is solid")
        }
    }
    
    private func handleBezierPenDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard isBezierDrawing else { return }
        
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        // Check if we're dragging from an existing anchor point (Option+drag behavior)
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
            if !isDraggingBezierHandle {
                isDraggingBezierHandle = true
                isDraggingBezierPoint = true
                print("Started dragging handle from point \(pointIndex)")
            }
            
            // Create/update bezier handles for this point (Option+drag behavior)
            let point = bezierPoints[pointIndex]
            let pointLocation = CGPoint(x: point.x, y: point.y)
            
            // Calculate handle positions based on drag direction
            let dragVector = CGPoint(
                x: currentLocation.x - pointLocation.x,
                y: currentLocation.y - pointLocation.y
            )
            
            // Create symmetric handles (professional behavior)
            let control1 = VectorPoint(
                pointLocation.x + dragVector.x,
                pointLocation.y + dragVector.y
            )
            let control2 = VectorPoint(
                pointLocation.x - dragVector.x,
                pointLocation.y - dragVector.y
            )
            
            // Store handle information
            bezierHandles[pointIndex] = BezierHandleInfo(
                control1: control1,
                control2: control2,
                hasHandles: true
            )
            
            // Update the path elements to use curves where handles exist
            updatePathWithHandles()
            
        } else if activeBezierPointIndex == bezierPoints.count - 1 && bezierPoints.count >= 2 {
            // Dragging the active (most recent) point creates handles automatically
            if !isDraggingBezierHandle {
                isDraggingBezierHandle = true
                print("Creating handles for active point while placing")
            }
            
            // Create handles for the active point based on drag direction
            let activeIndex = bezierPoints.count - 1
            let activePoint = bezierPoints[activeIndex]
            let activeLocation = CGPoint(x: activePoint.x, y: activePoint.y)
            
            let dragVector = CGPoint(
                x: currentLocation.x - activeLocation.x,
                y: currentLocation.y - activeLocation.y
            )
            
            // Create handles based on drag direction (logos2 working version)
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
        }
    }
    
    private func handleShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        if !isDrawing {
            isDrawing = true
            drawingStartPoint = startLocation
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
        default:
            break
        }
    }
    
    private func finishShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let path = currentPath else { return }
        
        // Create shapes with visible defaults
        let strokeStyle = StrokeStyle(color: .black, width: 1.0)
        let fillStyle = FillStyle(color: .white, opacity: 0.8)
        
        let shape = VectorShape(
            name: document.currentTool.rawValue,
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        document.addShape(shape)
    }
    
    private func startSelectionDrag() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        // Save initial transforms for all selected shapes
        dragStartTransforms.removeAll()
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                dragStartTransforms[shapeID] = document.layers[layerIndex].shapes[shapeIndex].transform
            }
        }
    }
    
    private func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        let delta = CGPoint(
            x: value.translation.width / document.zoomLevel,
            y: value.translation.height / document.zoomLevel
        )
        
        // Move selected shapes by directly modifying their transforms
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }),
               let initialTransform = dragStartTransforms[shapeID] {
                
                // Apply translation to the transform
                let translation = CGAffineTransform(translationX: delta.x, y: delta.y)
                let newTransform = initialTransform.concatenating(translation)
                
                // Update the shape's transform
                document.layers[layerIndex].shapes[shapeIndex].transform = newTransform
                
                // Don't update bounds during movement - transformEffect() handles visual positioning
                // and bounds should remain as original path bounds to avoid double transformation
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishSelectionDrag() {
        if !dragStartTransforms.isEmpty {
            // Only save to undo if we actually moved something
            var didMove = false
            
            guard let layerIndex = document.selectedLayerIndex else {
                dragStartTransforms.removeAll()
                return
            }
            
            // CRITICAL FIX: Apply transform to actual path coordinates and reset transform
            // This ensures object origin moves with the object for proper direct selection and scaling
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }),
                   let originalTransform = dragStartTransforms[shapeID] {
                    let currentTransform = document.layers[layerIndex].shapes[shapeIndex].transform
                    
                    if currentTransform != originalTransform {
                        didMove = true
                        
                        // Apply the transform to the actual path coordinates
                        applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
                    }
                }
            }
            
            if didMove {
                document.saveToUndoStack()
            }
            
            dragStartTransforms.removeAll()
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Adobe Illustrator behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let transform = shape.transform
        
        // Don't apply identity transforms
        if transform.isIdentity {
            return
        }
        
        print("🔧 Applying transform to shape coordinates: \(shape.name)")
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        print("✅ Shape coordinates updated - object origin now follows object position")
    }
    
    // MARK: - Direct Selection Drag Handling
    
    private func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard !selectedPoints.isEmpty || !selectedHandles.isEmpty else { return }
        
        if !isDraggingPoint && !isDraggingHandle {
            // Start dragging - capture initial positions
            isDraggingPoint = !selectedPoints.isEmpty
            isDraggingHandle = !selectedHandles.isEmpty
            document.saveToUndoStack() // Save state before modifying paths
            
            // Store initial positions for accurate dragging
            captureOriginalPositions()
        }
        
        let delta = CGPoint(
            x: value.translation.width / document.zoomLevel,
            y: value.translation.height / document.zoomLevel
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
                    // Use the same improved hit testing logic as selection
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Use stroke width + padding for tolerance
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        
                        if PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance) {
                            return true
                        }
                    } else {
                        // For filled shapes, use bounds check
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
        return false
    }
    
    private func selectObjectAt(_ location: CGPoint) {
        // Reuse the selection tap logic
        handleSelectionTap(at: location)
    }
    
    private func finishBezierPath() {
        guard let path = bezierPath, bezierPoints.count >= 2 else { 
            print("Cannot finish bezier path - insufficient points or no path")
            cancelBezierDrawing()
            return 
        }
        
        // Create bezier curve with orange stroke (more visible than black)
        let strokeStyle = StrokeStyle(color: .rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), width: 2.0)
        let fillStyle = FillStyle(color: .clear) // No fill for bezier curves
        
        let shape = VectorShape(
            name: "Bezier Path \(bezierPoints.count) points",
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        print("✅ Finished bezier path with \(bezierPoints.count) points")
        print("Path elements: \(path.elements.count)")
        print("Shape bounds: \(shape.bounds)")
        print("Stroke color: \(strokeStyle.color)")
        
        // Add shape to document
        document.addShape(shape)
        
        // PROFESSIONAL ADOBE ILLUSTRATOR BEHAVIOR: Auto-switch to direct selection and select new path
        let newShapeID = shape.id
        
        // Reset bezier state BEFORE switching tools
        cancelBezierDrawing()
        
        // Switch to direct selection tool
        document.currentTool = .directSelection
        
        // Direct-select the newly created shape
        directSelectedShapeIDs.removeAll()
        directSelectedShapeIDs.insert(newShapeID)
        selectedPoints.removeAll() // Clear any existing point selections
        selectedHandles.removeAll() // Clear any existing handle selections
        
        print("🎯 AUTO-SWITCHED to Direct Selection and direct-selected new path")
    }
    
    private func finishBezierPenDrag() {
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
    
    private func handlePanGesture(value: DragGesture.Value) {
        document.canvasOffset = CGPoint(
            x: document.canvasOffset.x + value.translation.width,
            y: document.canvasOffset.y + value.translation.height
        )
    }
    
    private func handleZoom(value: CGFloat, geometry: GeometryProxy) {
        let newZoomLevel = max(0.1, min(10.0, document.zoomLevel * value))
        document.zoomLevel = newZoomLevel
    }
    
    private func screenToCanvas(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // CRITICAL FIX: Use high precision conversion to match visual coordinate system exactly
        // This must be the mathematical inverse of the visual coordinate chain:
        // Visual: ((originalCoords * transform) * zoomLevel) + canvasOffset = screen
        // Reverse: (screen - canvasOffset) / zoomLevel = originalCoords * transform
        let precision = Double(document.zoomLevel)
        let precisionOffsetX = Double(document.canvasOffset.x)
        let precisionOffsetY = Double(document.canvasOffset.y)
        let precisionPointX = Double(point.x)
        let precisionPointY = Double(point.y)
        
        return CGPoint(
            x: (precisionPointX - precisionOffsetX) / precision,
            y: (precisionPointY - precisionOffsetY) / precision
        )
    }
    
    private func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // CRITICAL FIX: Use high precision conversion to match visual coordinate system exactly
        // This must exactly match the visual coordinate chain:
        // Visual: ((originalCoords * transform) * zoomLevel) + canvasOffset = screen
        let precision = Double(document.zoomLevel)
        let precisionOffsetX = Double(document.canvasOffset.x)
        let precisionOffsetY = Double(document.canvasOffset.y)
        let precisionPointX = Double(point.x)
        let precisionPointY = Double(point.y)
        
        return CGPoint(
            x: (precisionPointX * precision) + precisionOffsetX,
            y: (precisionPointY * precision) + precisionOffsetY
        )
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
            for layer in document.layers {
                if let shape = layer.shapes.first(where: { $0.id == shapeID }) {
                    
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
                            
                        case .curve(let to, let control1, let control2):
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
                
                var isHit = false
                
                // PROFESSIONAL HIT TESTING (same logic as regular selection)
                let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                
                if isStrokeOnly && shape.strokeStyle != nil {
                    // Stroke-only shapes: Use stroke-based hit testing
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeTolerance = max(15.0, strokeWidth + 10.0)
                    isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    print("  - Stroke hit test: \(isHit) (tolerance: \(strokeTolerance))")
                } else {
                    // Filled shapes: Use bounds + path hit testing
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
                
                if isHit {
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
                         // Delete specific points (more complex - for now just delete the shape)
                         // TODO: Implement proper point deletion while maintaining path integrity
                         document.layers[layerIndex].shapes.remove(at: shapeIndex)
                         print("Deleted shape (point deletion not yet implemented)")
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
     
     private func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    private func closeBezierPath() {
        guard let _ = bezierPath, bezierPoints.count >= 3 else {
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
        
        // PROFESSIONAL ADOBE ILLUSTRATOR-STYLE CLOSED SHAPE
        // Closed paths get both stroke AND fill by default
        let strokeStyle = StrokeStyle(color: .black, width: 1.0) // Black stroke like Illustrator
        let fillStyle = FillStyle(color: .rgb(RGBColor(red: 0.9, green: 0.9, blue: 0.9)), opacity: 0.8) // Light gray fill
        
        let shape = VectorShape(
            name: "Closed Bezier Path",
            path: closedPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        print("✅ SUCCESSFULLY CLOSED BEZIER PATH with \(bezierPoints.count) points")
        print("Path elements: \(closedPath.elements.count) (including close)")
        print("Curve data preserved: \(closedPath.elements.compactMap { if case .curve = $0 { return 1 } else { return nil } }.count) curves")
        
        // Add to document
        document.addShape(shape)
        
        // PROFESSIONAL ADOBE ILLUSTRATOR BEHAVIOR: Auto-switch to direct selection and select new closed path
        let newShapeID = shape.id
        
        // Clear bezier state BEFORE switching tools
        cancelBezierDrawing()
        
        // Hide any close path hints
        showClosePathHint = false
        
        // Switch to direct selection tool
        document.currentTool = .directSelection
        
        // Direct-select the newly created closed shape
        directSelectedShapeIDs.removeAll()
        directSelectedShapeIDs.insert(newShapeID)
        selectedPoints.removeAll() // Clear any existing point selections
        selectedHandles.removeAll() // Clear any existing handle selections
        
        print("🎯 AUTO-SWITCHED to Direct Selection and direct-selected new closed path")
    }
    
    private func handleConvertAnchorPointTap(at location: CGPoint) {
        let tolerance: Double = 8.0 // Hit test tolerance
        
        // EXIT TEXT EDITING when using convert point tool (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        // Search through all visible layers and shapes for points to convert
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
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
                    case .curve(let to, let control1, let control2):
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
        
        print("Convert Anchor Point: No point found at location \(location)")
    }
    
    // PROFESSIONAL UX: Auto-select shapes when clicking with Convert Point tool
    private func tryToSelectShapeForConvertTool(at location: CGPoint) {
        // Search for any shape at the click location
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible { continue }
                
                var isHit = false
                
                // Use the same hit testing logic as selection tool
                let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                
                if isStrokeOnly && shape.strokeStyle != nil {
                    // Stroke-only shapes: Use stroke-based hit testing
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeTolerance = max(15.0, strokeWidth + 10.0)
                    isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                } else {
                    // Filled shapes: Use bounds + path hit testing
                    let transformedBounds = shape.bounds.applying(shape.transform)
                    let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                    
                    if expandedBounds.contains(location) {
                        isHit = true
                    } else {
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                    }
                }
                
                if isHit {
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
            
            // Create symmetric handles using the direction vector (EXACTLY like pen tool)
            let outgoingHandle = VectorPoint(
                point.x + directionVector.x * handleLength,
                point.y + directionVector.y * handleLength
            )
            let incomingHandle = VectorPoint(
                point.x - directionVector.x * handleLength,
                point.y - directionVector.y * handleLength
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
                    .transformEffect(shape.transform)  // Same as arrow tool
                    .scaleEffect(document.zoomLevel)   // Same as arrow tool
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                    
                    // Draw HIGHLIGHTED handle as larger circle - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                    Circle()
                        .fill(Color.orange)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: 6 / document.zoomLevel, height: 6 / document.zoomLevel) // Scale-independent
                        .position(handleInfo.handleLocation)
                        .transformEffect(shape.transform)  // Same as arrow tool
                        .scaleEffect(document.zoomLevel)   // Same as arrow tool
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
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
                        .transformEffect(shape.transform)  // Same as arrow tool
                        .scaleEffect(document.zoomLevel)   // Same as arrow tool
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
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
                        .transformEffect(shape.transform)  // Same as arrow tool
                        .scaleEffect(document.zoomLevel)   // Same as arrow tool
                        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                        
                        // INCOMING HANDLE CIRCLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                        Circle()
                            .fill(Color.blue)
                            .stroke(Color.white, lineWidth: 0.5)
                            .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                            .position(control2Location)
                            .transformEffect(shape.transform)  // Same as arrow tool
                            .scaleEffect(document.zoomLevel)   // Same as arrow tool
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                            
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
                                .transformEffect(shape.transform)  // Same as arrow tool
                                .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                                
                                // OUTGOING HANDLE CIRCLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Circle()
                                    .fill(Color.blue)
                                    .stroke(Color.white, lineWidth: 0.5)
                                    .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                                    .position(control1Location)
                                    .transformEffect(shape.transform)  // Same as arrow tool
                                    .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
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
                                .transformEffect(shape.transform)  // Same as arrow tool
                                .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
                                
                                // OUTGOING HANDLE CIRCLE - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                                Circle()
                                    .fill(Color.blue)
                                    .stroke(Color.white, lineWidth: 0.5)
                                    .frame(width: 4 / document.zoomLevel, height: 4 / document.zoomLevel) // Scale-independent
                                    .position(control1Location)
                                    .transformEffect(shape.transform)  // Same as arrow tool
                                    .scaleEffect(document.zoomLevel)   // Same as arrow tool
                                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
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
                            .transformEffect(shape.transform)  // Same as arrow tool
                            .scaleEffect(document.zoomLevel)   // Same as arrow tool
                            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y) // Same as arrow tool
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
    
    private func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: point.x * document.zoomLevel + document.canvasOffset.x,
            y: point.y * document.zoomLevel + document.canvasOffset.y
        )
    }
    
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
