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
    private var contextMenuOptions: some View {
        // PROFESSIONAL BEZIER CONTEXT MENU OPTIONS
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
            // PROFESSIONAL POINT CONVERSION (Adobe Illustrator / FreeHand Standards)
            Text("🎯 Professional Point Conversion")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Convert to Smooth Curve") {
                convertSelectedPointsToSmooth()
            }
            .keyboardShortcut("s", modifiers: [.command, .option]) // Adobe Illustrator standard
            
            Button("Convert to Corner Point") {
                convertSelectedPointsToCorner()
            }
            .keyboardShortcut("c", modifiers: [.command, .option]) // Adobe Illustrator standard
            
            Divider()
            
            // PROFESSIONAL HANDLE OPERATIONS (Adobe Illustrator Standards)
            Text("🔧 Professional Handle Control")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Break Handle Symmetry") {
                breakHandleSymmetryForSelectedPoints()
            }
            .keyboardShortcut("b", modifiers: [.command, .option]) // Professional standard
            
            Button("Make Handles Symmetric") {
                makeHandlesSymmetricForSelectedPoints()
            }
            .keyboardShortcut("h", modifiers: [.command, .option]) // Professional standard
            
            Button("Retract Handles") {
                retractHandlesForSelectedPoints()
            }
            .keyboardShortcut("r", modifiers: [.command, .option]) // Professional standard
            
            Divider()
            
            Button("Close Selected Paths") {
                closeSelectedPaths()
            }
            .keyboardShortcut("j", modifiers: [.command]) // Adobe Illustrator standard (Cmd+J)
            
            Button("Delete Selected Points") {
                deleteSelectedPoints()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
        }
        
        // PROFESSIONAL ANCHOR POINT CONVERSION FOR ALL DIRECT SELECTION TOOLS
        if (document.currentTool == .directSelection || document.currentTool == .convertAnchorPoint) && !directSelectedShapeIDs.isEmpty {
            // Show anchor point conversion options when shapes are direct-selected
            Text("🎯 Adobe Illustrator Anchor Point Tool")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button("Convert All Corner Points to Smooth") {
                convertAllCornerPointsToSmooth()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift, .option])
            
            Button("Convert All Smooth Points to Corner") {
                convertAllSmoothPointsToCorner()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift, .option])
            
            Divider()
            
            Button("Make All Handles Symmetric") {
                makeAllHandlesSymmetric()
            }
            .keyboardShortcut("h", modifiers: [.command, .shift, .option])
            
            Button("Optimize Path (Simplify)") {
                optimizeSelectedPaths()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift, .option])
        }
        
        // General path operations for any selected shape
        if !document.selectedShapeIDs.isEmpty {
            Button("Duplicate") {
                document.duplicateSelectedShapes()
            }
            .keyboardShortcut("d", modifiers: [.command])
            
            Button("Delete") {
                document.removeSelectedShapes()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
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
                
                // PROFESSIONAL TEXT RENDERING (Adobe Illustrator / FreeHand Standards)
                ForEach(document.textObjects.indices, id: \.self) { textIndex in
                    let textObject = document.textObjects[textIndex]
                    if textObject.isVisible {
                        TextObjectView(
                            textObject: textObject,
                            isSelected: document.selectedTextIDs.contains(textObject.id),
                            isEditing: textObject.isEditing,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset,
                            onTextChange: { newContent in
                                document.updateTextContent(textObject.id, content: newContent)
                            },
                            onEditingChanged: { isEditing in
                                document.setTextEditing(textObject.id, isEditing: isEditing)
                            }
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
                
                // Bezier path preview with closing preview
                bezierPathPreview()
                
                // Rubber band preview line (professional pen tool behavior)
                rubberBandPreview(geometry: geometry)
                
                // Professional bezier anchor points
                bezierAnchorPoints(geometry: geometry)
                
                // PROFESSIONAL CLOSE PATH VISUAL HINT (like Adobe Illustrator)
                if showClosePathHint {
                    ZStack {
                        // Green circle indicating close path area
                        Circle()
                            .stroke(Color.green, lineWidth: 2.0)
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 16, height: 16)
                            .position(closePathHintLocation)
                        
                        // Small "close" icon
                        Image(systemName: "multiply.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                            .position(closePathHintLocation)
                    }
                    .animation(.easeInOut(duration: 0.2), value: showClosePathHint)
                }
                
                // Selection handles for selected shapes
                SelectionHandlesView(
                    document: document,
                    geometry: geometry
                )
                
                // Direct selection points and handles
                if document.currentTool == .directSelection {
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
                
                // Clear direct selection state when switching away from direct selection tool
                if previousTool == .directSelection && newTool != .directSelection {
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    directSelectedShapeIDs.removeAll()
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
                            closePathHintLocation = canvasToScreen(firstPointLocation, geometry: geometry)
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
                contextMenuOptions
            }
        }
    }
    
    // MARK: - Helper Views for Complex UI Elements
    
    private var closingPreviewElements: [PathElement] {
        guard let bezierPath = bezierPath, showClosePathHint && bezierPoints.count >= 3 else {
            return []
        }
        var elements = bezierPath.elements
        elements.append(.close)
        return elements
    }
    
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
    
    @ViewBuilder
    private func bezierAnchorPoints(geometry: GeometryProxy) -> some View {
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                let point = bezierPoints[index]
                let screenPoint = canvasToScreen(point.cgPoint, geometry: geometry)
                let isActive = activeBezierPointIndex == index
                let isFirstPoint = index == 0
                let isCloseHovering = showClosePathHint && isFirstPoint
                
                // PROFESSIONAL ANCHOR POINTS (Adobe Illustrator Standards)
                let anchorSize = 6.0 / document.zoomLevel  // Scale-independent anchor point size
                let lineWidth = 1.0 / document.zoomLevel   // Scale-independent stroke width
                
                // PROFESSIONAL FIRST POINT HIGHLIGHTING (like Adobe Illustrator)
                if isCloseHovering {
                    // Enlarged, highlighted first point when hovering to close
                    Rectangle()
                        .fill(Color.green)
                        .overlay(
                            Rectangle()
                                .stroke(Color.white, lineWidth: lineWidth)
                        )
                        .frame(width: anchorSize * 1.3, height: anchorSize * 1.3)
                        .position(screenPoint)
                        .scaleEffect(1.2)
                        .animation(.easeInOut(duration: 0.2), value: isCloseHovering)
                } else {
                    // PROFESSIONAL ANCHOR POINT RENDERING (Adobe Illustrator style)
                    // Active point: solid black square with white stroke
                    // Inactive point: hollow white square with black stroke
                    Rectangle()
                        .fill(isActive ? Color.black : Color.white)
                        .overlay(
                            Rectangle()
                                .stroke(isActive ? Color.white : Color.black, lineWidth: lineWidth)
                        )
                        .frame(width: anchorSize, height: anchorSize)
                        .position(screenPoint)
                }
                
                // PROFESSIONAL BEZIER HANDLES (Adobe Illustrator Standards)
                if let handleInfo = bezierHandles[index], handleInfo.hasHandles {
                    // PROFESSIONAL SCALE-INDEPENDENT SIZING
                    let handleSize = 6.0 / document.zoomLevel  // Scale with zoom like professionals
                    let lineWidth = 1.0 / document.zoomLevel   // Scale-independent line width
                    
                    // Draw control handle lines (incoming handle - control1)
                    if let control1 = handleInfo.control1 {
                        let control1Screen = canvasToScreen(control1.cgPoint, geometry: geometry)
                        Path { path in
                            path.move(to: screenPoint)
                            path.addLine(to: control1Screen)
                        }
                        .stroke(Color.blue, lineWidth: lineWidth)
                        
                        // PROFESSIONAL CONTROL HANDLE CIRCLE (hollow with blue outline - Adobe Illustrator standard)
                        Circle()
                            .fill(Color.white)
                            .stroke(Color.blue, lineWidth: lineWidth)
                            .frame(width: handleSize, height: handleSize)
                            .position(control1Screen)
                    }
                    
                    // Draw control handle lines (outgoing handle - control2)
                    if let control2 = handleInfo.control2 {
                        let control2Screen = canvasToScreen(control2.cgPoint, geometry: geometry)
                        Path { path in
                            path.move(to: screenPoint)
                            path.addLine(to: control2Screen)
                        }
                        .stroke(Color.blue, lineWidth: lineWidth)
                        
                        // PROFESSIONAL CONTROL HANDLE CIRCLE (hollow with blue outline - Adobe Illustrator standard)
                        Circle()
                            .fill(Color.white)
                            .stroke(Color.blue, lineWidth: lineWidth)
                            .frame(width: handleSize, height: handleSize)
                            .position(control2Screen)
                    }
                }
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
    
    // MARK: - Professional Multi-Selection Key Monitoring (Adobe Illustrator Standards)
    
    private func setupKeyEventMonitoring() {
        // Monitor for key down/up and modifier flag changes
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                updateModifierKeyStates(with: event)
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
            guard !isAnyTextEditing() else { return event }
            
            let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let modifiers = event.modifierFlags
            
            // PROFESSIONAL COMMAND SHORTCUTS (Adobe Illustrator Standards)
            if modifiers.contains(.command) {
                switch characters {
                case "a": // Select All (Cmd+A)
                    document.selectAll()
                    return nil
                case "]": // Bring Forward (Cmd+])
                    bringSelectedForward()
                    return nil
                case "[": // Send Backward (Cmd+[)
                    sendSelectedBackward()
                    return nil
                case "d": // Duplicate (Cmd+D)
                    document.duplicateSelectedShapes()
                    return nil
                    
                // PROFESSIONAL TOOL SHORTCUTS WITH COMMAND MODIFIER (Fixed to prevent text interference)
                case "v": // Selection Tool (Cmd+V conflicts with paste, use Cmd+Shift+V)
                    if modifiers.contains(.shift) {
                        switchToTool(.selection)
                        return nil
                    }
                case "1": // Direct Selection Tool (Cmd+1)
                    switchToTool(.directSelection)
                    return nil
                case "h": // Hand Tool (Cmd+H)
                    switchToTool(.hand)
                    return nil
                case "t": // Text Tool (Cmd+T)
                    switchToTool(.text)
                    return nil
                case "p": // Bezier Pen Tool (Cmd+P)
                    switchToTool(.bezierPen)
                    return nil
                case "l": // Line Tool (Cmd+L)
                    switchToTool(.line)
                    return nil
                case "r": // Rectangle Tool (Cmd+R)
                    switchToTool(.rectangle)
                    return nil
                case "e": // Circle Tool (Cmd+E for Ellipse)
                    switchToTool(.circle)
                    return nil
                case "s": // Star Tool (Cmd+S conflicts with save, use Cmd+Shift+S)
                    if modifiers.contains(.shift) {
                        switchToTool(.star)
                        return nil
                    }
                case "z": // Zoom Tool (Cmd+Z conflicts with undo, use Cmd+Shift+Z for zoom)
                    if modifiers.contains(.shift) {
                        switchToTool(.zoom)
                        return nil
                    }
                default:
                    break
                }
                
                // PROFESSIONAL COMMAND+SHIFT SHORTCUTS
                if modifiers.contains(.shift) {
                    switch characters {
                    case "]": // Bring to Front (Cmd+Shift+])
                        bringSelectedToFront()
                        return nil
                    case "[": // Send to Back (Cmd+Shift+[)
                        sendSelectedToBack()
                        return nil
                    default:
                        break
                    }
                }
                
                return event
            }
            
            // SPECIAL SYSTEM KEYS (with proper handling)
            switch characters {
            case "\u{1b}": // Escape key - Exit text editing or emergency tool reset
                if isAnyTextEditing() {
                    print("🔤 Escape pressed: Exit text editing")
                    exitAllTextEditing()
                    return nil
                } else {
                    print("🚨 Escape pressed: Emergency tool reset")
                    emergencyToolReset()
                    return nil
                }
            case "\u{7f}": // Delete key - Only if not in text editing mode
                if !isAnyTextEditing() {
                    deleteSelectedObjects()
                    return nil
                }
            default:
                break
            }
            
            return event
        }
    }
    
    private func switchToTool(_ newTool: DrawingTool) {
        // EXIT ALL TEXT EDITING when switching tools (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        // SAFE CURSOR MANAGEMENT - Limited cursor pops to prevent infinite loops
        var popCount = 0
        while NSCursor.current != NSCursor.arrow && popCount < 10 {
            NSCursor.pop()
            popCount += 1
        }
        
        // If still not arrow cursor, force reset
        if NSCursor.current != NSCursor.arrow {
            NSCursor.arrow.set()
        }
        
        document.currentTool = newTool
        newTool.cursor.push()
        
        print("⌨️ Keyboard shortcut: Switched to \(newTool.rawValue)")
    }
    
    private func isAnyTextEditing() -> Bool {
        // PROFESSIONAL TEXT EDITING DETECTION - Check if any text objects are currently being edited
        return document.textObjects.contains { $0.isEditing }
    }
    
    // MARK: - Professional Text Editing Management (Adobe Illustrator Standards)
    
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
    
    /// Exit text editing for a specific text object
    private func exitTextEditing(for textID: UUID) {
        if let index = document.textObjects.firstIndex(where: { $0.id == textID }) {
            if document.textObjects[index].isEditing {
                document.textObjects[index].isEditing = false
                print("🔤 EXIT: Finished editing text '\(document.textObjects[index].content)'")
                document.objectWillChange.send()
            }
        }
    }
    
    private func emergencyToolReset() {
        // EXIT ALL TEXT EDITING first (professional behavior)
        exitAllTextEditing()
        
        // EMERGENCY CURSOR AND TOOL RESET
        // Clear all cursors back to arrow with safety limit
        var popCount = 0
        while NSCursor.current != NSCursor.arrow && popCount < 10 {
            NSCursor.pop()
            popCount += 1
        }
        
        // Force arrow cursor if needed
        NSCursor.arrow.set()
        
        // Reset all drawing states
        isDrawing = false
        isDraggingPoint = false
        isDraggingHandle = false
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        
        // Cancel any active bezier drawing
        if isBezierDrawing {
            cancelBezierDrawing()
        }
        
        // Switch back to selection tool
        document.currentTool = .selection
        DrawingTool.selection.cursor.push()
        
        print("✅ Emergency reset complete - Selection tool active")
    }
    
    // MARK: - Professional Object Management (Adobe Illustrator Standards)
    
    /// Delete selected objects (shapes and text)
    private func deleteSelectedObjects() {
        if !document.selectedShapeIDs.isEmpty {
            document.removeSelectedShapes()
            print("🗑️ Deleted \(document.selectedShapeIDs.count) selected shapes")
        }
        
        if !document.selectedTextIDs.isEmpty {
            document.removeSelectedText()
            print("🗑️ Deleted \(document.selectedTextIDs.count) selected text objects")
        }
    }
    
    /// Bring selected objects forward one step in z-order
    private func bringSelectedForward() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Move each selected shape forward by one position
        var shapes = document.layers[layerIndex].shapes
        
        // Process from back to front to avoid index conflicts
        for i in (0..<shapes.count).reversed() {
            if document.selectedShapeIDs.contains(shapes[i].id) && i < shapes.count - 1 {
                shapes.swapAt(i, i + 1)
            }
        }
        
        document.layers[layerIndex].shapes = shapes
        print("⬆️ Brought forward \(document.selectedShapeIDs.count) objects")
    }
    
    /// Send selected objects backward one step in z-order
    private func sendSelectedBackward() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Move each selected shape backward by one position
        var shapes = document.layers[layerIndex].shapes
        
        // Process from front to back to avoid index conflicts
        for i in 0..<shapes.count {
            if document.selectedShapeIDs.contains(shapes[i].id) && i > 0 {
                shapes.swapAt(i, i - 1)
            }
        }
        
        document.layers[layerIndex].shapes = shapes
        print("⬇️ Sent backward \(document.selectedShapeIDs.count) objects")
    }
    
    /// Bring selected objects to front (top of z-order)
    private func bringSelectedToFront() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Get selected shapes and remove them from current positions
        var shapes = document.layers[layerIndex].shapes
        let selectedShapes = shapes.filter { document.selectedShapeIDs.contains($0.id) }
        shapes.removeAll { document.selectedShapeIDs.contains($0.id) }
        
        // Add selected shapes to the end (front)
        shapes.append(contentsOf: selectedShapes)
        
        document.layers[layerIndex].shapes = shapes
        print("⬆️⬆️ Brought to front \(document.selectedShapeIDs.count) objects")
    }
    
    /// Send selected objects to back (bottom of z-order)
    private func sendSelectedToBack() {
        guard let layerIndex = document.selectedLayerIndex,
              !document.selectedShapeIDs.isEmpty else { return }
        
        document.saveToUndoStack()
        
        // Get selected shapes and remove them from current positions
        var shapes = document.layers[layerIndex].shapes
        let selectedShapes = shapes.filter { document.selectedShapeIDs.contains($0.id) }
        shapes.removeAll { document.selectedShapeIDs.contains($0.id) }
        
        // Insert selected shapes at the beginning (back)
        shapes.insert(contentsOf: selectedShapes, at: 0)
        
        document.layers[layerIndex].shapes = shapes
        print("⬇️⬇️ Sent to back \(document.selectedShapeIDs.count) objects")
    }
    
    private func updateModifierKeyStates(with event: NSEvent) {
        let modifierFlags = event.modifierFlags
        isShiftPressed = modifierFlags.contains(.shift)
        isCommandPressed = modifierFlags.contains(.command)
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
            // PROFESSIONAL FIX: Force UI refresh to ensure shapes are detected
            document.objectWillChange.send()
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
        case .eyedropper:
            // Cancel bezier drawing if switching to eyedropper tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleEyedropperTap(at: canvasLocation)
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
                // Check if we're starting a drag on a selected object (shape or text)
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                
                // If nothing is selected, or if we're dragging on an unselected object, try to select it first
                if document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty || 
                   (!isDraggingSelectedObject(at: startLocation) && !isDraggingSelectedText(at: startLocation)) {
                    selectObjectAt(startLocation)
                }
                
                // Only start drag if we have something selected (shapes or text)
                if !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty {
                    startSelectionDrag()
                    isDrawing = true
                }
            }
            
            if isDrawing {
                handleSelectionDrag(value: value, geometry: geometry)
            }
        case .directSelection:
            // Handle direct selection point/handle dragging
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
        case .hand:
            // Reset cursor back to open hand after panning
            if isDrawing {
                NSCursor.pop() // Remove closed hand
                isDrawing = false
                print("🖐️ Hand tool: Finished panning")
            }
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
    
    private func handleSelectionTap(at location: CGPoint) {
        print("🎯 Selection tool tap at: \(location)")
        
        // EXIT TEXT EDITING when clicking with selection tool (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        // CRITICAL: Regular Selection tool must clear direct selection
        // Professional tools have mutually exclusive selection modes
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        
        // PROFESSIONAL UNIFIED SELECTION (Adobe Illustrator Standards)
        // Selection tool should be able to select BOTH shapes AND text objects
        
        var hitShape: VectorShape?
        var hitLayerIndex: Int?
        var hitText: VectorText?
        
        // First check for text objects (they have priority in Adobe Illustrator)
        for textObj in document.textObjects.reversed() {
            if textObj.isVisible && !textObj.isLocked {
                let transformedBounds = textObj.bounds.applying(textObj.transform)
                let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8) // Tolerance for easier selection
                if expandedBounds.contains(location) {
                    hitText = textObj
                    break
                }
            }
        }
        
        // If no text hit, check for shapes
        if hitText == nil {
            // Search through layers from top to bottom
            for layerIndex in document.layers.indices.reversed() {
                let layer = document.layers[layerIndex]
                
                if !layer.isVisible || layer.isLocked { continue }
                
                // Search through shapes from top to bottom (last drawn first)
                for shape in layer.shapes.reversed() {
                    if !shape.isVisible || shape.isLocked { continue }
                    
                    var isHit = false
                    
                    print("  - Testing shape: \(shape.name)")
                    
                    if shape.strokeStyle != nil && (shape.fillStyle?.color == .clear || shape.fillStyle == nil) {
                        // Stroke-only shape - use stroke tolerance
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(strokeWidth * 0.5, 8.0) // At least 8 points for easier selection
                        print("  - Testing stroke-only path with tolerance: \(strokeTolerance)")
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                        print("  - Stroke hit test result: \(isHit)")
                    } else {
                        // PROFESSIONAL FIX: Use consistent transformed bounds for filled shapes
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                            print("  - Hit via transformed bounds check")
                        } else {
                            // Fallback: More precise path hit test
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
        }
        
        // PROFESSIONAL MULTI-SELECTION HANDLING (Adobe Illustrator Standards)
        if let textObj = hitText {
            // Hit a text object
            document.selectedLayerIndex = 0 // Text objects are conceptually on the current layer
            
            if isShiftPressed {
                // SHIFT+CLICK: Add to selection (extend selection)
                document.selectedTextIDs.insert(textObj.id)
                document.selectedShapeIDs.removeAll() // Clear shape selection (mutually exclusive in this implementation)
                print("🎯 SHIFT+CLICK: Added text '\(textObj.content)' to selection (total: \(document.selectedTextIDs.count))")
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection (add if not selected, remove if selected)
                if document.selectedTextIDs.contains(textObj.id) {
                    document.selectedTextIDs.remove(textObj.id)
                    print("🎯 CMD+CLICK: Removed text '\(textObj.content)' from selection (total: \(document.selectedTextIDs.count))")
                } else {
                    document.selectedTextIDs.insert(textObj.id)
                    document.selectedShapeIDs.removeAll() // Clear shape selection
                    print("🎯 CMD+CLICK: Added text '\(textObj.content)' to selection (total: \(document.selectedTextIDs.count))")
                }
            } else {
                // REGULAR CLICK: Replace selection (clear existing, select new)
                document.selectedTextIDs = [textObj.id]
                document.selectedShapeIDs.removeAll() // Clear shape selection
                print("🎯 REGULAR CLICK: Selected text '\(textObj.content)' only (cleared previous selection)")
            }
        } else if let shape = hitShape, let layerIndex = hitLayerIndex {
            // Hit a shape object
            document.selectedLayerIndex = layerIndex
            
            if isShiftPressed {
                // SHIFT+CLICK: Add to selection (extend selection)
                document.selectedShapeIDs.insert(shape.id)
                document.selectedTextIDs.removeAll() // Clear text selection
                print("🎯 SHIFT+CLICK: Added \(shape.name) to selection (total: \(document.selectedShapeIDs.count))")
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection (add if not selected, remove if selected)
                if document.selectedShapeIDs.contains(shape.id) {
                    document.selectedShapeIDs.remove(shape.id)
                    print("🎯 CMD+CLICK: Removed \(shape.name) from selection (total: \(document.selectedShapeIDs.count))")
                } else {
                    document.selectedShapeIDs.insert(shape.id)
                    document.selectedTextIDs.removeAll() // Clear text selection
                    print("🎯 CMD+CLICK: Added \(shape.name) to selection (total: \(document.selectedShapeIDs.count))")
                }
            } else {
                // REGULAR CLICK: Replace selection (clear existing, select new)
                document.selectedShapeIDs = [shape.id]
                document.selectedTextIDs.removeAll() // Clear text selection
                print("🎯 REGULAR CLICK: Selected \(shape.name) only (cleared previous selection)")
            }
        } else {
            // Only clear selection if clicking on empty space without modifiers
            if !isShiftPressed && !isCommandPressed {
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
    }
    
    // MARK: - Professional Text Tool (Adobe Illustrator / FreeHand Standards)
    private func handleTextTap(at location: CGPoint) {
        print("🔤 Text tool tap at: \(location)")
        
        // Clear any shape selections (professional behavior - mutually exclusive)
        document.selectedShapeIDs.removeAll()
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        
        // Check if we're clicking on existing text for editing or selection
        var hitText: VectorText?
        
        // Search through text objects from top to bottom
        for textObj in document.textObjects.reversed() {
            if textObj.isVisible && !textObj.isLocked {
                let transformedBounds = textObj.bounds.applying(textObj.transform)
                let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8) // Tolerance for easier selection
                if expandedBounds.contains(location) {
                    hitText = textObj
                    break
                }
            }
        }
        
        if let textObj = hitText {
            // PROFESSIONAL MULTI-SELECTION FOR TEXT OBJECTS
            if isShiftPressed {
                // SHIFT+CLICK: Add to text selection (don't start editing)
                document.selectedTextIDs.insert(textObj.id)
                print("🔤 SHIFT+CLICK: Added text '\(textObj.content)' to selection (total: \(document.selectedTextIDs.count))")
            } else if isCommandPressed {
                // CMD+CLICK: Toggle text selection (don't start editing)
                if document.selectedTextIDs.contains(textObj.id) {
                    document.selectedTextIDs.remove(textObj.id)
                    print("🔤 CMD+CLICK: Removed text '\(textObj.content)' from selection (total: \(document.selectedTextIDs.count))")
                } else {
                    document.selectedTextIDs.insert(textObj.id)
                    print("🔤 CMD+CLICK: Added text '\(textObj.content)' to selection (total: \(document.selectedTextIDs.count))")
                }
            } else {
                // REGULAR CLICK: Exit editing for other text, select this text and start editing
                exitAllTextEditing()
                document.selectedTextIDs = [textObj.id]
                print("🔤 REGULAR CLICK: Selected text '\(textObj.content)' for editing")
                startTextEditing(textObj)
            }
        } else {
            // Only create new text if clicking on empty space without modifiers
            if !isShiftPressed && !isCommandPressed {
                // Exit editing for all other text first
                exitAllTextEditing()
                print("🔤 Creating new text at: \(location)")
                createNewTextAt(location)
            } else {
                print("🔤 Clicked empty space with modifiers: Keeping existing text selection")
            }
        }
    }
    
    private func createNewTextAt(_ location: CGPoint) {
        // Professional default typography properties (Adobe Illustrator standard)
        let defaultTypography = TypographyProperties(
            fontFamily: "Helvetica",
            fontWeight: .regular,
            fontStyle: .normal,
            fontSize: 24.0, // Professional default for new text
            lineHeight: 28.8, // 120% of font size
            letterSpacing: 0.0,
            alignment: .left,
            fillColor: .black,
            fillOpacity: 1.0
        )
        
        let newText = VectorText(
            content: "Text",
            typography: defaultTypography,
            position: location,
            isEditing: true // Start in editing mode
        )
        
        document.addText(newText)
        print("🔤 Created new text object: \(newText.id)")
        
        // Trigger text editing UI
        startTextEditing(newText)
    }
    
    private func startTextEditing(_ text: VectorText) {
        // Set the text object to editing mode (Adobe Illustrator behavior)
        if let index = document.textObjects.firstIndex(where: { $0.id == text.id }) {
            document.textObjects[index].isEditing = true
            print("🔤 STARTED editing text: '\(text.content)'")
            document.objectWillChange.send()
        }
    }
    
    // MARK: - Professional Eyedropper Tool (Adobe Illustrator Standards)
    
    private func handleEyedropperTap(at location: CGPoint) {
        print("💧 Eyedropper tool tap at: \(location)")
        
        // Sample color from objects at the clicked location
        var sampledColor: VectorColor?
        var sampledFillColor: VectorColor?
        var sampledStrokeColor: VectorColor?
        
        // First check text objects (they have priority in Adobe Illustrator)
        for textObj in document.textObjects.reversed() {
            if textObj.isVisible && !textObj.isLocked {
                let transformedBounds = textObj.bounds.applying(textObj.transform)
                let expandedBounds = transformedBounds.insetBy(dx: -4, dy: -4) // Smaller tolerance for precise sampling
                if expandedBounds.contains(location) {
                    sampledColor = textObj.typography.fillColor
                    sampledFillColor = textObj.typography.fillColor
                    print("💧 Sampled text fill color: \(String(describing: sampledColor))")
                    break
                }
            }
        }
        
        // If no text hit, check for shapes
        if sampledColor == nil {
            // Search through layers from top to bottom
            for layerIndex in document.layers.indices.reversed() {
                let layer = document.layers[layerIndex]
                
                if !layer.isVisible || layer.isLocked { continue }
                
                // Search through shapes from top to bottom (last drawn first)
                for shape in layer.shapes.reversed() {
                    if !shape.isVisible || shape.isLocked { continue }
                    
                    var isHit = false
                    
                    // Test if we hit the shape
                    if shape.strokeStyle != nil && (shape.fillStyle?.color == .clear || shape.fillStyle == nil) {
                        // Stroke-only shape - use stroke tolerance
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(strokeWidth * 0.5, 4.0) // Smaller tolerance for precise sampling
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                        
                        if isHit {
                            sampledColor = shape.strokeStyle?.color
                            sampledStrokeColor = shape.strokeStyle?.color
                            print("💧 Sampled stroke color: \(String(describing: sampledColor))")
                        }
                    } else {
                        // Shape with fill - check bounds first, then precise path
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -4, dy: -4)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                        } else {
                            // Fallback: More precise path hit test
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 4.0)
                        }
                        
                        if isHit {
                            // Priority: Fill color first, then stroke if no fill
                            if let fillColor = shape.fillStyle?.color, fillColor != .clear {
                                sampledColor = fillColor
                                sampledFillColor = fillColor
                                print("💧 Sampled fill color: \(String(describing: sampledColor))")
                            } else if let strokeColor = shape.strokeStyle?.color {
                                sampledColor = strokeColor
                                sampledStrokeColor = strokeColor
                                print("💧 Sampled stroke color: \(String(describing: sampledColor))")
                            }
                        }
                    }
                    
                    if isHit && sampledColor != nil { break }
                }
                if sampledColor != nil { break }
            }
        }
        
        // Apply sampled color to selected objects or color swatches
        if let color = sampledColor {
            applySampledColor(color, fillColor: sampledFillColor, strokeColor: sampledStrokeColor)
        } else {
            print("💧 No color found at location")
            // Visual feedback for no color found
            showEyedropperFeedback(at: location, success: false)
        }
    }
    
    private func applySampledColor(_ color: VectorColor, fillColor: VectorColor?, strokeColor: VectorColor?) {
        print("💧 Applying sampled color: \(String(describing: color))")
        
        // Professional Adobe Illustrator behavior:
        // 1. If objects are selected, apply to them
        // 2. If no objects selected, set as default colors and add to swatches
        
        let hasSelectedShapes = !document.selectedShapeIDs.isEmpty
        let hasSelectedText = !document.selectedTextIDs.isEmpty
        
        if hasSelectedShapes || hasSelectedText {
            // Apply to selected objects
            if hasSelectedShapes {
                applyColorToSelectedShapes(fillColor: fillColor, strokeColor: strokeColor)
            }
            
            if hasSelectedText {
                applyColorToSelectedText(color: fillColor ?? color)
            }
            
            print("💧 Applied sampled color to \(document.selectedShapeIDs.count) shapes and \(document.selectedTextIDs.count) text objects")
        } else {
            // No objects selected - set as default colors and add to swatches
            if let fillColor = fillColor {
                addColorToSwatches(fillColor)
            }
            if let strokeColor = strokeColor, strokeColor != fillColor {
                addColorToSwatches(strokeColor)
            }
            if fillColor == nil && strokeColor == nil {
                addColorToSwatches(color)
            }
            
            print("💧 Added sampled color to swatches")
        }
        
        // Visual feedback for successful sampling
        showEyedropperFeedback(at: CGPoint.zero, success: true)
    }
    
    private func applyColorToSelectedShapes(fillColor: VectorColor?, strokeColor: VectorColor?) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Apply fill color if sampled from a fill
                if let fillColor = fillColor {
                    if shape.fillStyle != nil {
                        shape.fillStyle?.color = fillColor
                    } else {
                        shape.fillStyle = logos.FillStyle(color: fillColor)
                    }
                }
                
                // Apply stroke color if sampled from a stroke
                if let strokeColor = strokeColor {
                    if shape.strokeStyle != nil {
                        shape.strokeStyle?.color = strokeColor
                    } else {
                        shape.strokeStyle = StrokeStyle(color: strokeColor, width: 2.0)
                    }
                }
                
                document.layers[layerIndex].shapes[shapeIndex] = shape
            }
        }
    }
    
    private func applyColorToSelectedText(color: VectorColor) {
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                document.textObjects[textIndex].typography.fillColor = color
            }
        }
    }
    
    private func addColorToSwatches(_ color: VectorColor) {
        // Only add if not already in swatches
        if !document.colorSwatches.contains(color) {
            document.colorSwatches.append(color)
            // Limit swatches to prevent UI overflow
            if document.colorSwatches.count > 32 {
                document.colorSwatches.removeFirst()
            }
        }
    }
    
    private func showEyedropperFeedback(at location: CGPoint, success: Bool) {
        // TODO: Add visual feedback animation (brief flash or icon)
        // For now, just print feedback
        if success {
            print("💧 ✅ Color sampled successfully!")
        } else {
            print("💧 ❌ No color found at location")
        }
    }
    
    // MARK: - PROFESSIONAL BEZIER PEN TOOL (Adobe Illustrator Standards)
    
    private func handleBezierPenTap(at location: CGPoint) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(bezierLastTapTime)
        bezierLastTapTime = now
        
        print("🎯 PROFESSIONAL BEZIER PEN: Click at \(location)")
        
        // PROFESSIONAL ADOBE ILLUSTRATOR-STYLE PATH CLOSING
        // Check if we're trying to close the path by clicking near the first point
        if isBezierDrawing && bezierPoints.count >= 3 {
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            let closeTolerance: Double = 25.0 // Increased for better UX (Adobe Illustrator standard)
            
            if distance(location, firstPointLocation) <= closeTolerance {
                print("🎯 CLOSING PATH: Clicked near first point")
                closeBezierPath()
                return
            }
        }
        
        // Check for double-tap to finish path (within 0.5 seconds)
        if timeSinceLastTap < 0.5 && isBezierDrawing && bezierPoints.count > 1 {
            print("🎯 FINISHING PATH: Double-tap detected")
            finishBezierPath()
            return
        }
        
        if !isBezierDrawing {
            // PROFESSIONAL: Start new bezier path (Adobe Illustrator behavior)
            print("🆕 STARTING NEW BEZIER PATH")
            bezierPath = VectorPath(elements: [.move(to: VectorPoint(location))])
            bezierPoints = [VectorPoint(location)]
            isBezierDrawing = true
            activeBezierPointIndex = 0 // First point is active (solid)
            bezierHandles.removeAll()
            print("✅ Started bezier path at \(location)")
        } else {
            // PROFESSIONAL: Add point to existing path (Adobe Illustrator behavior)
            print("➕ ADDING POINT TO EXISTING PATH")
            
            // Make previous point inactive (hollow)
            let previousActiveIndex = activeBezierPointIndex
            
            // Add new point and make it active (solid)
            let newPoint = VectorPoint(location)
            bezierPoints.append(newPoint)
            activeBezierPointIndex = bezierPoints.count - 1
            
            // Create line to the new point (will be converted to curve if handles are added)
            bezierPath?.addElement(.line(to: newPoint))
            
            print("✅ Added bezier point \(bezierPoints.count): \(location)")
            print("Previous point \(previousActiveIndex ?? -1) is now hollow, current point \(activeBezierPointIndex ?? -1) is solid")
        }
    }
    
    // PROFESSIONAL BEZIER PEN DRAG (Adobe Illustrator/FreeHand Standards)
    private func handleBezierPenDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard isBezierDrawing else { return }
        
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        if !isDraggingBezierHandle {
            isDraggingBezierHandle = true
            print("🎯 PROFESSIONAL ADOBE ILLUSTRATOR: Creating bezier handles with industry standards")
        }
        
        // PROFESSIONAL ADOBE ILLUSTRATOR BEHAVIOR: Click+drag from point creates symmetric handles
        // The direction and distance of drag determines the curve direction and strength
        
        let dragVector = CGPoint(
            x: currentLocation.x - startLocation.x,
            y: currentLocation.y - startLocation.y
        )
        
        // Calculate handle length (professional behavior: use actual drag distance)
        let handleLength = sqrt(dragVector.x * dragVector.x + dragVector.y * dragVector.y)
        
        // PROFESSIONAL CONSTRAINT: Prevent extremely long handles (Adobe Illustrator behavior)
        let maxHandleLength: Double = 150.0 // Professional maximum
        let constrainedLength = min(handleLength, maxHandleLength)
        
        // Normalize drag vector for consistent handle directions
        let normalizedX = handleLength > 0 ? dragVector.x / handleLength : 0
        let normalizedY = handleLength > 0 ? dragVector.y / handleLength : 0
        
        // ADOBE ILLUSTRATOR STANDARD: Create symmetric handles
        // Outgoing handle: points in direction of drag (where you're dragging to)
        // Incoming handle: points in opposite direction (180 degrees - where you came from)
        let control1 = VectorPoint(
            startLocation.x - normalizedX * constrainedLength,  // Incoming handle (back direction)
            startLocation.y - normalizedY * constrainedLength
        )
        let control2 = VectorPoint(
            startLocation.x + normalizedX * constrainedLength,  // Outgoing handle (drag direction)
            startLocation.y + normalizedY * constrainedLength
        )
        
        // Store handles for the current point being created
        let currentIndex = bezierPoints.count - 1
        bezierHandles[currentIndex] = BezierHandleInfo(
            control1: control1,
            control2: control2,
            hasHandles: true
        )
        
        // CRITICAL: Update path immediately with professional curve mathematics
        updatePathWithHandlesProfessional()
        
        print("📐 PROFESSIONAL HANDLES: length=\(String(format: "%.1f", constrainedLength)) (max: \(maxHandleLength)), angle=\(String(format: "%.1f", atan2(normalizedY, normalizedX) * 180 / .pi))°")
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
        
        // PROFESSIONAL DEFAULTS (Adobe Illustrator Standards)
        let strokeStyle = StrokeStyle(color: .black, width: 1.0, opacity: 1.0)
        let fillStyle = FillStyle(color: .white, opacity: 1.0) // SOLID WHITE FILL for visibility
        
        let shape = VectorShape(
            name: document.currentTool.rawValue,
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        document.addShape(shape)
        
        // AUTO-SELECT new shape (Adobe Illustrator behavior)
        if let layerIndex = document.selectedLayerIndex,
           let newShape = document.layers[layerIndex].shapes.last {
            document.selectedShapeIDs = [newShape.id]
            print("✅ Created and selected new \(document.currentTool.rawValue): \(newShape.id)")
        }
    }
    
    private func startSelectionDrag() {
        // PROFESSIONAL TEXT AND SHAPE DRAGGING (Adobe Illustrator Standards)
        
        // Save initial transforms for all selected shapes
        dragStartTransforms.removeAll()
        if let layerIndex = document.selectedLayerIndex {
            for shapeID in document.selectedShapeIDs {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    dragStartTransforms[shapeID] = document.layers[layerIndex].shapes[shapeIndex].transform
                }
            }
        }
        
        // Save initial transforms for all selected text objects
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                dragStartTransforms[textID] = document.textObjects[textIndex].transform
            }
        }
    }
    
    private func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL TEXT AND SHAPE DRAGGING (Adobe Illustrator Standards)
        
        let delta = CGPoint(
            x: value.translation.width / document.zoomLevel,
            y: value.translation.height / document.zoomLevel
        )
        
        // Move selected shapes by directly modifying their transforms
        if let layerIndex = document.selectedLayerIndex {
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
        }
        
        // Move selected text objects by directly modifying their transforms
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }),
               let initialTransform = dragStartTransforms[textID] {
                
                // Apply translation to the transform
                let translation = CGAffineTransform(translationX: delta.x, y: delta.y)
                let newTransform = initialTransform.concatenating(translation)
                
                // Update the text object's transform
                document.textObjects[textIndex].transform = newTransform
                
                // Don't update bounds during movement - same principle as shapes
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishSelectionDrag() {
        if !dragStartTransforms.isEmpty {
            // Only save to undo if we actually moved something
            var didMove = false
            
            // Check if any shape actually moved
            if let layerIndex = document.selectedLayerIndex {
                for shapeID in document.selectedShapeIDs {
                    if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }),
                       let originalTransform = dragStartTransforms[shapeID] {
                        let currentTransform = document.layers[layerIndex].shapes[shapeIndex].transform
                        if currentTransform != originalTransform {
                            didMove = true
                            break
                        }
                    }
                }
            }
            
            // Check if any text object actually moved
            if !didMove {
                for textID in document.selectedTextIDs {
                    if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }),
                       let originalTransform = dragStartTransforms[textID] {
                        let currentTransform = document.textObjects[textIndex].transform
                        if currentTransform != originalTransform {
                            didMove = true
                            break
                        }
                    }
                }
            }
            
            if didMove {
                document.saveToUndoStack()
            }
            
            dragStartTransforms.removeAll()
        }
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
                        // PROFESSIONAL FIX: For filled shapes, use consistent transformed bounds
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                        
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
    
    private func isDraggingSelectedText(at location: CGPoint) -> Bool {
        // Check if the tap location is on any selected text object
        for textID in document.selectedTextIDs {
            if let textObj = document.textObjects.first(where: { $0.id == textID }) {
                let transformedBounds = textObj.bounds.applying(textObj.transform)
                let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                if expandedBounds.contains(location) {
                    return true
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
        guard let _ = bezierPath, bezierPoints.count >= 2 else { 
            print("Cannot finish bezier path - insufficient points or no path")
            cancelBezierDrawing()
            return 
        }
        
        // CRITICAL FIX: Update path with handles to preserve curve data
        updatePathWithHandles()
        
        guard let finalPath = bezierPath else {
            print("Failed to update path with handles")
            cancelBezierDrawing()
            return
        }
        
        // Create bezier curve with orange stroke (more visible than black)
        let strokeStyle = StrokeStyle(color: .rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), width: 2.0)
        let fillStyle = FillStyle(color: .clear) // No fill for open bezier curves
        
        let shape = VectorShape(
            name: "Bezier Path \(bezierPoints.count) points",
            path: finalPath,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        print("✅ FINISHED BEZIER PATH with \(bezierPoints.count) points")
        print("Path elements: \(finalPath.elements.count)")
        print("Curve data preserved: \(finalPath.elements.compactMap { if case .curve = $0 { return 1 } else { return nil } }.count) curves")
        print("Shape bounds: \(shape.bounds)")
        print("Shape ID: \(shape.id)")
        
        document.addShape(shape)
        
        // Reset bezier state
        cancelBezierDrawing()
    }
    
    private func finishBezierPenDrag() {
        // Finalize bezier curve drag
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
    }
    
    // MARK: - Direct Selection Drag Handling
    
    private func handleDirectSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        // Check if we're starting a drag
        if !isDraggingPoint && !isDraggingHandle {
            dragStartLocation = startLocation
            
            // Check if clicking on a selected point or handle
            let tolerance: Double = 8.0
            var foundSelectedPoint = false
            var foundSelectedHandle = false
            
            // Check selected points
            for pointID in selectedPoints {
                if let pointLocation = getPointLocation(pointID) {
                    // Apply shape transform
                    let shape = getShape(pointID.shapeID)
                    let transformedLocation = pointLocation.cgPoint.applying(shape?.transform ?? .identity)
                    
                    if distance(startLocation, transformedLocation) <= tolerance {
                        foundSelectedPoint = true
                        break
                    }
                }
            }
            
            // Check selected handles
            if !foundSelectedPoint {
                for handleID in selectedHandles {
                    if let handleLocation = getHandleLocation(handleID) {
                        // Apply shape transform
                        let shape = getShape(handleID.shapeID)
                        let transformedLocation = handleLocation.cgPoint.applying(shape?.transform ?? .identity)
                        
                        if distance(startLocation, transformedLocation) <= tolerance {
                            foundSelectedHandle = true
                            break
                        }
                    }
                }
            }
            
            // Start dragging if we found a selected point or handle
            if foundSelectedPoint || foundSelectedHandle {
                isDraggingPoint = foundSelectedPoint
                isDraggingHandle = foundSelectedHandle
                
                // Store original positions for undo
                originalPointPositions.removeAll()
                originalHandlePositions.removeAll()
                
                if isDraggingPoint {
                    for pointID in selectedPoints {
                        if let position = getPointLocation(pointID) {
                            originalPointPositions[pointID] = position
                        }
                    }
                }
                
                if isDraggingHandle {
                    for handleID in selectedHandles {
                        if let position = getHandleLocation(handleID) {
                            originalHandlePositions[handleID] = position
                        }
                    }
                }
                
                document.saveToUndoStack()
            }
        }
        
        // Perform dragging if we're in drag mode
        if isDraggingPoint || isDraggingHandle {
            let deltaX = currentLocation.x - dragStartLocation.x
            let deltaY = currentLocation.y - dragStartLocation.y
            
            if isDraggingPoint {
                // Move all selected points
                for pointID in selectedPoints {
                    if let originalPosition = originalPointPositions[pointID] {
                        let newPosition = VectorPoint(
                            originalPosition.x + deltaX,
                            originalPosition.y + deltaY
                        )
                        updatePointLocation(pointID, newPosition: newPosition)
                    }
                }
            }
            
            if isDraggingHandle {
                // Move all selected handles
                for handleID in selectedHandles {
                    if let originalPosition = originalHandlePositions[handleID] {
                        let newPosition = VectorPoint(
                            originalPosition.x + deltaX,
                            originalPosition.y + deltaY
                        )
                        updateHandleLocation(handleID, newPosition: newPosition)
                    }
                }
            }
            
            // Force UI update
            document.objectWillChange.send()
        }
    }
    
    private func finishDirectSelectionDrag() {
        isDraggingPoint = false
        isDraggingHandle = false
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
    }
    
    // MARK: - Direct Selection Helper Methods
    
    private func getShape(_ shapeID: UUID) -> VectorShape? {
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == shapeID }) {
                return shape
            }
        }
        return nil
    }
    
    private func getPointLocation(_ pointID: PointID) -> VectorPoint? {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                guard pointID.elementIndex < shape.path.elements.count else { return nil }
                
                let element = shape.path.elements[pointID.elementIndex]
                switch element {
                case .move(let to), .line(let to):
                    return to
                case .curve(let to, _, _):
                    return to
                case .quadCurve(let to, _):
                    return to
                case .close:
                    return nil
                }
            }
        }
        return nil
    }
    
    private func getHandleLocation(_ handleID: HandleID) -> VectorPoint? {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == handleID.shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
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
    
    private func updatePointLocation(_ pointID: PointID, newPosition: VectorPoint) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex]
                let newElement: PathElement
                
                switch element {
                case .move(_):
                    newElement = .move(to: newPosition)
                case .line(_):
                    newElement = .line(to: newPosition)
                case .curve(_, let control1, let control2):
                    newElement = .curve(to: newPosition, control1: control1, control2: control2)
                case .quadCurve(_, let control):
                    newElement = .quadCurve(to: newPosition, control: control)
                case .close:
                    return // Can't move close elements
                }
                
                document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                return
            }
        }
    }
    
    private func updateHandleLocation(_ handleID: HandleID, newPosition: VectorPoint) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == handleID.shapeID }) {
                guard handleID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[handleID.elementIndex]
                let newElement: PathElement
                
                switch element {
                case .curve(let to, let control1, let control2):
                    if handleID.handleType == .control1 {
                        newElement = .curve(to: to, control1: newPosition, control2: control2)
                    } else {
                        newElement = .curve(to: to, control1: control1, control2: newPosition)
                    }
                case .quadCurve(let to, _):
                    if handleID.handleType == .control1 {
                        newElement = .quadCurve(to: to, control: newPosition)
                    } else {
                        return // Quad curves only have one control point
                    }
                default:
                    return // Can't update handles on non-curve elements
                }
                
                document.layers[layerIndex].shapes[shapeIndex].path.elements[handleID.elementIndex] = newElement
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                return
            }
        }
    }
    
    // MARK: - Point Conversion for Direct Selection
    
    private func convertSelectedPointsToSmooth() {
        document.saveToUndoStack()
        
        for pointID in selectedPoints {
            convertPointToSmooth(pointID)
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func convertSelectedPointsToCorner() {
        document.saveToUndoStack()
        
        for pointID in selectedPoints {
            convertPointToCorner(pointID)
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func convertPointToSmooth(_ pointID: PointID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex]
                let path = document.layers[layerIndex].shapes[shapeIndex].path
                
                switch element {
                case .line(let to):
                    // PROFESSIONAL: Convert line to smooth curve with intelligent handle placement
                    let handles = calculateProfessionalHandles(for: to, at: pointID.elementIndex, in: path)
                    let newElement = PathElement.curve(to: to, control1: handles.inHandle, control2: handles.outHandle)
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("✅ Professional: Converted line point to smooth curve with intelligent handles")
                    
                case .curve(let to, let control1, let control2):
                    // PROFESSIONAL: Make handles symmetric (Adobe Illustrator standard)
                    let centerPoint = to
                    let averageDistance = (distance(centerPoint.cgPoint, control1.cgPoint) + distance(centerPoint.cgPoint, control2.cgPoint)) / 2
                    
                    // Calculate average direction for symmetric handles
                    let angle1 = atan2(control1.y - centerPoint.y, control1.x - centerPoint.x)
                    let angle2 = atan2(control2.y - centerPoint.y, control2.x - centerPoint.x)
                    let averageAngle = (angle1 + angle2) / 2
                    
                    // Create symmetric handles (Adobe Illustrator style)
                    let handleLength = min(averageDistance, 60.0) // Professional constraint
                    let inHandle = VectorPoint(
                        centerPoint.x + Darwin.cos(averageAngle + .pi) * handleLength,
                        centerPoint.y + Darwin.sin(averageAngle + .pi) * handleLength
                    )
                    let outHandle = VectorPoint(
                        centerPoint.x + Darwin.cos(averageAngle) * handleLength,
                        centerPoint.y + Darwin.sin(averageAngle) * handleLength
                    )
                    
                    let newElement = PathElement.curve(
                        to: to,
                        control1: inHandle,
                        control2: outHandle
                    )
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("✅ Professional: Made curve handles symmetric (Adobe Illustrator style)")
                    
                case .move(_):
                    // Convert move to move (no change needed)
                    break
                    
                default:
                    // Already processed or unsupported type
                    break
                }
                
                return
            }
        }
    }
    
    // MARK: - Professional Handle Calculation (Adobe Illustrator / FreeHand Standards)
    
    private func calculateProfessionalHandles(for point: VectorPoint, at elementIndex: Int, in path: VectorPath) -> (inHandle: VectorPoint, outHandle: VectorPoint) {
        let elements = path.elements
        
        // Get previous and next points for intelligent handle calculation
        let previousPoint = getPreviousPoint(elementIndex: elementIndex, in: elements)
        let nextPoint = getNextPoint(elementIndex: elementIndex, in: elements)
        
        let currentPoint = point.cgPoint
        
        // PROFESSIONAL ALGORITHM: Handle length = 1/3 of curve distance (Adobe standard)
        let defaultHandleLength: Double = 40.0
        
        var inHandle = point
        var outHandle = point
        
        if let prevPoint = previousPoint {
            let distance = distance(currentPoint, prevPoint)
            let handleLength = min(distance / 3.0, defaultHandleLength) // Professional 1/3 rule
            
            if handleLength > 0 {
                let angle = atan2(currentPoint.y - prevPoint.y, currentPoint.x - prevPoint.x)
                inHandle = VectorPoint(
                    point.x - Darwin.cos(angle) * handleLength,
                    point.y - Darwin.sin(angle) * handleLength
                )
            }
        }
        
        if let nextPt = nextPoint {
            let distance = distance(currentPoint, nextPt)
            let handleLength = min(distance / 3.0, defaultHandleLength) // Professional 1/3 rule
            
            if handleLength > 0 {
                let angle = atan2(nextPt.y - currentPoint.y, nextPt.x - currentPoint.x)
                outHandle = VectorPoint(
                    point.x + Darwin.cos(angle) * handleLength,
                    point.y + Darwin.sin(angle) * handleLength
                )
            }
        }
        
        // MACROMEDIA FREEHAND STYLE: If only one neighbor, create symmetric handles
        if previousPoint == nil || nextPoint == nil {
            if let neighbor = previousPoint ?? nextPoint {
                let angle = atan2(currentPoint.y - neighbor.y, currentPoint.x - neighbor.x)
                let handleLength = min(distance(currentPoint, neighbor) / 3.0, defaultHandleLength)
                
                // Symmetric handles
                inHandle = VectorPoint(
                    point.x - Darwin.cos(angle) * handleLength,
                    point.y - Darwin.sin(angle) * handleLength
                )
                outHandle = VectorPoint(
                    point.x + Darwin.cos(angle) * handleLength,
                    point.y + Darwin.sin(angle) * handleLength
                )
            }
        }
        
        return (inHandle: inHandle, outHandle: outHandle)
    }
    
    private func getPreviousPoint(elementIndex: Int, in elements: [PathElement]) -> CGPoint? {
        guard elementIndex > 0 else { return nil }
        
        for i in (0..<elementIndex).reversed() {
            switch elements[i] {
            case .move(let to), .line(let to):
                return to.cgPoint
            case .curve(let to, _, _), .quadCurve(let to, _):
                return to.cgPoint
            case .close:
                continue
            }
        }
        return nil
    }
    
    private func getNextPoint(elementIndex: Int, in elements: [PathElement]) -> CGPoint? {
        guard elementIndex < elements.count - 1 else { return nil }
        
        for i in (elementIndex + 1)..<elements.count {
            switch elements[i] {
            case .move(let to), .line(let to):
                return to.cgPoint
            case .curve(let to, _, _), .quadCurve(let to, _):
                return to.cgPoint
            case .close:
                continue
            }
        }
        return nil
    }
    
    private func convertPointToCorner(_ pointID: PointID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex]
                
                switch element {
                case .curve(let to, _, _):
                    // PROFESSIONAL: Convert curve to line (Adobe Illustrator standard - click removes handles)
                    let newElement = PathElement.line(to: to)
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("✅ Professional: Converted smooth curve to corner point (Adobe Illustrator style)")
                    
                case .quadCurve(let to, _):
                    // PROFESSIONAL: Convert quad curve to line (corner point)
                    let newElement = PathElement.line(to: to)
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("✅ Professional: Converted quad curve to corner point")
                    
                default:
                    // Already a corner point or unsupported type
                    print("Point is already a corner point or cannot be converted")
                    break
                }
                
                return
            }
        }
    }
    
    // PROFESSIONAL BEZIER PATH UPDATE (Adobe Illustrator/FreeHand Standards)
    private func updatePathWithHandlesProfessional() {
        guard let path = bezierPath, bezierPoints.count >= 1 else { return }
        
        var newElements: [PathElement] = []
        
        // Start with move to first point
        newElements.append(.move(to: bezierPoints[0]))
        
        // PROFESSIONAL STANDARD: Create path elements that match Adobe Illustrator behavior
        for i in 1..<bezierPoints.count {
            let currentPoint = bezierPoints[i]
            let previousPoint = bezierPoints[i - 1]
            
            // Check for handles (professional standards)
            let previousHandles = bezierHandles[i - 1] 
            let currentHandles = bezierHandles[i]
            
            // ADOBE ILLUSTRATOR BEHAVIOR: Use handles when they exist, otherwise straight lines
            if let prevHandles = previousHandles, prevHandles.hasHandles,
               let prevControl2 = prevHandles.control2 {
                
                // Previous point has outgoing handle - create curve
                let control1 = prevControl2
                
                // Check if current point has incoming handle
                let control2 = currentHandles?.control1 ?? VectorPoint(currentPoint.x, currentPoint.y)
                
                newElements.append(.curve(to: currentPoint, control1: control1, control2: control2))
                print("🎯 Created curve with handles: prev=\(prevControl2) curr=\(control2)")
                
            } else if let currHandles = currentHandles, currHandles.hasHandles,
                      let currControl1 = currHandles.control1 {
                
                // Current point has incoming handle - create curve
                let control1 = VectorPoint(previousPoint.x, previousPoint.y)
                let control2 = currControl1
                
                newElements.append(.curve(to: currentPoint, control1: control1, control2: control2))
                print("🎯 Created curve with current handle: \(currControl1)")
                
            } else {
                // No handles - straight line (corner points)
                newElements.append(.line(to: currentPoint))
                print("📏 Created straight line segment")
            }
        }
        
        // Update the path with professional curve data
        bezierPath = VectorPath(elements: newElements, isClosed: path.isClosed)
        print("✅ Professional path updated: \(newElements.count) elements")
    }
    
    // Legacy function for compatibility
    private func updatePathWithHandles() {
        updatePathWithHandlesProfessional()
    }
    
    private func handlePanGesture(value: DragGesture.Value) {
        // Change cursor to closed hand during dragging
        if !isDrawing {
            isDrawing = true
            NSCursor.closedHand.push()
            print("🖐️ Hand tool: Started panning")
        }
        
        document.canvasOffset = CGPoint(
            x: document.canvasOffset.x + value.translation.width,
            y: document.canvasOffset.y + value.translation.height
        )
    }
    
    private func handleZoom(value: CGFloat, geometry: GeometryProxy) {
        // PROFESSIONAL ZOOM IMPLEMENTATION (Adobe Illustrator Standards)
        // This fixes the critical issue where zoom was going in opposite direction
        
        let oldZoomLevel = document.zoomLevel
        let newZoomLevel = max(0.1, min(10.0, oldZoomLevel * value))
        
        // Don't update if zoom level hasn't actually changed
        if abs(newZoomLevel - oldZoomLevel) < 0.001 {
            return
        }
        
        // PROFESSIONAL ZOOM CENTER CALCULATION
        // Get the center of the view as the zoom focal point (Adobe Illustrator behavior)
        let viewCenter = CGPoint(
            x: geometry.size.width / 2,
            y: geometry.size.height / 2
        )
        
        // Convert zoom center to canvas coordinates using OLD zoom level
        let canvasZoomCenter = CGPoint(
            x: (viewCenter.x - document.canvasOffset.x) / oldZoomLevel,
            y: (viewCenter.y - document.canvasOffset.y) / oldZoomLevel
        )
        
        // Apply new zoom level
        document.zoomLevel = newZoomLevel
        
        // CRITICAL FIX: Adjust canvas offset so zoom center stays at same screen position
        // This prevents selection tools from going in opposite direction
        let newCanvasOffset = CGPoint(
            x: viewCenter.x - (canvasZoomCenter.x * newZoomLevel),
            y: viewCenter.y - (canvasZoomCenter.y * newZoomLevel)
        )
        
        document.canvasOffset = newCanvasOffset
        
        print("🔍 PROFESSIONAL ZOOM: \(oldZoomLevel) -> \(newZoomLevel)")
        print("  Zoom center (canvas): (\(canvasZoomCenter.x), \(canvasZoomCenter.y))")
        print("  Old offset: (\(document.canvasOffset.x), \(document.canvasOffset.y))")
        print("  New offset: (\(newCanvasOffset.x), \(newCanvasOffset.y))")
    }
    
    // MARK: - PROFESSIONAL ZOOM TO MOUSE CURSOR (Adobe Illustrator Style)
    
    private func handleZoomAtPoint(_ zoomFactor: CGFloat, at mouseLocation: CGPoint, geometry: GeometryProxy) {
        // PROFESSIONAL ZOOM TO MOUSE CURSOR (Adobe Illustrator Standards)
        // This allows zooming directly to where the mouse cursor is positioned
        
        let oldZoomLevel = document.zoomLevel
        let newZoomLevel = max(0.1, min(10.0, oldZoomLevel * zoomFactor))
        
        // Don't update if zoom level hasn't actually changed
        if abs(newZoomLevel - oldZoomLevel) < 0.001 {
            return
        }
        
        // Convert mouse location to canvas coordinates using OLD zoom level
        let canvasZoomCenter = CGPoint(
            x: (mouseLocation.x - document.canvasOffset.x) / oldZoomLevel,
            y: (mouseLocation.y - document.canvasOffset.y) / oldZoomLevel
        )
        
        // Apply new zoom level
        document.zoomLevel = newZoomLevel
        
        // PROFESSIONAL: Adjust canvas offset so the point under mouse cursor stays there
        let newCanvasOffset = CGPoint(
            x: mouseLocation.x - (canvasZoomCenter.x * newZoomLevel),
            y: mouseLocation.y - (canvasZoomCenter.y * newZoomLevel)
        )
        
        document.canvasOffset = newCanvasOffset
        
        print("🎯 PROFESSIONAL ZOOM TO MOUSE: \(oldZoomLevel) -> \(newZoomLevel)")
        print("  Mouse location: (\(mouseLocation.x), \(mouseLocation.y))")
        print("  Canvas zoom center: (\(canvasZoomCenter.x), \(canvasZoomCenter.y))")
        print("  New offset: (\(newCanvasOffset.x), \(newCanvasOffset.y))")
    }
    
    private func screenToCanvas(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: (point.x - document.canvasOffset.x) / document.zoomLevel,
            y: (point.y - document.canvasOffset.y) / document.zoomLevel
        )
    }
    
    private func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: point.x * document.zoomLevel + document.canvasOffset.x,
            y: point.y * document.zoomLevel + document.canvasOffset.y
        )
    }
    
    private func createCirclePath(center: CGPoint, radius: Double) -> VectorPath {
        let controlPointOffset = radius * 0.552
        
        return VectorPath(elements: [
            .move(to: VectorPoint(center.x + radius, center.y)),
            .curve(to: VectorPoint(center.x, center.y + radius),
                   control1: VectorPoint(center.x + radius, center.y + controlPointOffset),
                   control2: VectorPoint(center.x + controlPointOffset, center.y + radius)),
            .curve(to: VectorPoint(center.x - radius, center.y),
                   control1: VectorPoint(center.x - controlPointOffset, center.y + radius),
                   control2: VectorPoint(center.x - radius, center.y + controlPointOffset)),
            .curve(to: VectorPoint(center.x, center.y - radius),
                   control1: VectorPoint(center.x - radius, center.y - controlPointOffset),
                   control2: VectorPoint(center.x - controlPointOffset, center.y - radius)),
            .curve(to: VectorPoint(center.x + radius, center.y),
                   control1: VectorPoint(center.x + controlPointOffset, center.y - radius),
                   control2: VectorPoint(center.x + radius, center.y - controlPointOffset)),
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
        
        // Clear bezier state
        cancelBezierDrawing()
        
        // Hide any close path hints
        showClosePathHint = false
    }
    
    // MARK: - PROFESSIONAL ADOBE ILLUSTRATOR ANCHOR POINT TOOL
    
    /// Professional anchor point conversion that works exactly like Adobe Illustrator
    private func handleConvertAnchorPointTap(at location: CGPoint) {
        let tolerance: Double = 8.0 // Hit test tolerance
        
        print("🎯 PROFESSIONAL ANCHOR POINT TOOL: Click at \(location)")
        
        // EXIT TEXT EDITING when using anchor point tool (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        // Search through all visible layers and shapes for points to convert
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for (shapeIndex, shape) in layer.shapes.enumerated().reversed() {
                if !shape.isVisible { continue }
                
                // Check each path element for points
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    let pointLocation: CGPoint
                    let pointType: AnchorPointType
                    
                    switch element {
                    case .move(let to), .line(let to):
                        pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                        pointType = .corner
                        
                    case .curve(let to, _, _):
                        pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                        pointType = .smooth
                        
                    case .quadCurve(let to, _):
                        pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                        pointType = .quadratic
                        
                    case .close:
                        continue
                    }
                    
                    // Hit test for the anchor point
                    if distance(location, pointLocation) <= tolerance {
                        print("✅ FOUND ANCHOR POINT: \(pointType) at element \(elementIndex)")
                        
                        // PROFESSIONAL ANCHOR POINT CONVERSION (Adobe Illustrator Standards)
                        document.saveToUndoStack()
                        
                        switch pointType {
                        case .corner:
                            // Convert corner to smooth with professional handle calculation
                            convertCornerPointToSmooth(
                                layerIndex: layerIndex,
                                shapeIndex: shapeIndex,
                                elementIndex: elementIndex,
                                clickLocation: location
                            )
                            
                        case .smooth:
                            // Convert smooth to corner (remove handles)
                            convertSmoothPointToCorner(
                                layerIndex: layerIndex,
                                shapeIndex: shapeIndex,
                                elementIndex: elementIndex
                            )
                            
                        case .quadratic:
                            // Convert quadratic to corner
                            convertQuadraticPointToCorner(
                                layerIndex: layerIndex,
                                shapeIndex: shapeIndex,
                                elementIndex: elementIndex
                            )
                        }
                        
                        // Force UI update
                        document.objectWillChange.send()
                        print("🎯 ANCHOR POINT CONVERSION COMPLETE")
                        return
                    }
                }
            }
        }
        
        print("❌ No anchor point found at location \(location)")
    }
    
    // MARK: - PROFESSIONAL ANCHOR POINT CONVERSION METHODS
    
    /// Adobe Illustrator anchor point types
    enum AnchorPointType {
        case corner      // No handles (line segments)
        case smooth      // Symmetric handles (cubic curves)
        case quadratic   // Single handle (quadratic curves)
    }
    
    /// Convert corner point to smooth point with professional handle calculation
    private func convertCornerPointToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int, clickLocation: CGPoint) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        let path = document.layers[layerIndex].shapes[shapeIndex].path
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        
        switch element {
        case .line(let to):
            print("🔄 Converting corner point to smooth curve...")
            
            // PROFESSIONAL HANDLE CALCULATION (Adobe Illustrator method)
            let handles = calculateProfessionalHandlesForPoint(
                point: to,
                elementIndex: elementIndex,
                path: path,
                shape: shape
            )
            
            let newElement = PathElement.curve(
                to: to,
                control1: handles.incomingHandle,
                control2: handles.outgoingHandle
            )
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ PROFESSIONAL: Converted corner to smooth curve with intelligent handles")
            print("  Incoming handle: (\(handles.incomingHandle.x), \(handles.incomingHandle.y))")
            print("  Outgoing handle: (\(handles.outgoingHandle.x), \(handles.outgoingHandle.y))")
            
        case .move(_):
            // Move points don't get converted directly, but we can prepare for the next segment
            print("ℹ️ Move point - no conversion needed")
            
        default:
            print("⚠️ Point is already smooth or unsupported type")
        }
    }
    
    /// Convert smooth point to corner point (remove handles)
    private func convertSmoothPointToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        switch element {
        case .curve(let to, _, _):
            print("🔄 Converting smooth point to corner point...")
            
            // Convert curve to line (corner point)
            let newElement = PathElement.line(to: to)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ PROFESSIONAL: Converted smooth curve to corner point")
            
        default:
            print("⚠️ Point is not a smooth curve")
        }
    }
    
    /// Convert quadratic point to corner point
    private func convertQuadraticPointToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        switch element {
        case .quadCurve(let to, _):
            print("🔄 Converting quadratic point to corner point...")
            
            // Convert quad curve to line (corner point)
            let newElement = PathElement.line(to: to)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ PROFESSIONAL: Converted quadratic curve to corner point")
            
        default:
            print("⚠️ Point is not a quadratic curve")
        }
    }
    
    /// Professional handle calculation for anchor point conversion (Adobe Illustrator algorithm)
    private func calculateProfessionalHandlesForPoint(
        point: VectorPoint,
        elementIndex: Int,
        path: VectorPath,
        shape: VectorShape
    ) -> (incomingHandle: VectorPoint, outgoingHandle: VectorPoint) {
        
        let elements = path.elements
        let currentPoint = point.cgPoint
        
        // Get previous and next points for intelligent handle calculation
        let previousPoint = getPreviousPointInPath(elementIndex: elementIndex, elements: elements)
        let nextPoint = getNextPointInPath(elementIndex: elementIndex, elements: elements)
        
        // PROFESSIONAL HANDLE LENGTH CALCULATION (Adobe Illustrator standard)
        // Handle length = 1/3 of the distance to adjacent points
        let baseHandleLength: Double = 30.0 // Default minimum handle length
        var incomingLength = baseHandleLength
        var outgoingLength = baseHandleLength
        
        // Calculate intelligent handle directions and lengths
        var incomingAngle: Double = 0.0
        var outgoingAngle: Double = 0.0
        
        if let prevPoint = previousPoint, let nextPoint = nextPoint {
            // PROFESSIONAL: Calculate average direction for smooth transition
            let prevToCurrentAngle = atan2(currentPoint.y - prevPoint.y, currentPoint.x - prevPoint.x)
            let currentToNextAngle = atan2(nextPoint.y - currentPoint.y, nextPoint.x - currentPoint.x)
            
            // Average angle for smooth curve
            let averageAngle = (prevToCurrentAngle + currentToNextAngle) / 2.0
            
            incomingAngle = averageAngle + .pi // Incoming handle (opposite direction)
            outgoingAngle = averageAngle        // Outgoing handle
            
            // Professional length calculation (1/3 rule)
            let prevDistance = distance(currentPoint, prevPoint)
            let nextDistance = distance(currentPoint, nextPoint)
            
            incomingLength = min(prevDistance / 3.0, 50.0) // Cap at reasonable length
            outgoingLength = min(nextDistance / 3.0, 50.0)
            
        } else if let prevPoint = previousPoint {
            // Only previous point available
            let angle = atan2(currentPoint.y - prevPoint.y, currentPoint.x - prevPoint.x)
            incomingAngle = angle + .pi
            outgoingAngle = angle
            
            let prevDistance = distance(currentPoint, prevPoint)
            incomingLength = min(prevDistance / 3.0, 50.0)
            outgoingLength = incomingLength
            
        } else if let nextPoint = nextPoint {
            // Only next point available
            let angle = atan2(nextPoint.y - currentPoint.y, nextPoint.x - currentPoint.x)
            incomingAngle = angle + .pi
            outgoingAngle = angle
            
            let nextDistance = distance(currentPoint, nextPoint)
            outgoingLength = min(nextDistance / 3.0, 50.0)
            incomingLength = outgoingLength
        }
        
        // Calculate handle positions using Foundation's cos and sin
        let incomingHandle = VectorPoint(
            point.x + Foundation.cos(incomingAngle) * incomingLength,
            point.y + Foundation.sin(incomingAngle) * incomingLength
        )
        
        let outgoingHandle = VectorPoint(
            point.x + Foundation.cos(outgoingAngle) * outgoingLength,
            point.y + Foundation.sin(outgoingAngle) * outgoingLength
        )
        
        print("📐 PROFESSIONAL HANDLE CALCULATION:")
        print("  Previous point: \(previousPoint?.debugDescription ?? "none")")
        print("  Current point: \(currentPoint)")
        print("  Next point: \(nextPoint?.debugDescription ?? "none")")
        print("  Incoming angle: \(incomingAngle * 180 / .pi)°, length: \(incomingLength)")
        print("  Outgoing angle: \(outgoingAngle * 180 / .pi)°, length: \(outgoingLength)")
        
        return (incomingHandle: incomingHandle, outgoingHandle: outgoingHandle)
    }
    
    /// Get the previous point in the path for handle calculation
    private func getPreviousPointInPath(elementIndex: Int, elements: [PathElement]) -> CGPoint? {
        guard elementIndex > 0 else { return nil }
        
        // Look backwards for the previous point
        for i in (0..<elementIndex).reversed() {
            switch elements[i] {
            case .move(let to), .line(let to):
                return CGPoint(x: to.x, y: to.y)
            case .curve(let to, _, _):
                return CGPoint(x: to.x, y: to.y)
            case .quadCurve(let to, _):
                return CGPoint(x: to.x, y: to.y)
            case .close:
                continue
            }
        }
        
        return nil
    }
    
    /// Get the next point in the path for handle calculation
    private func getNextPointInPath(elementIndex: Int, elements: [PathElement]) -> CGPoint? {
        guard elementIndex < elements.count - 1 else { return nil }
        
        // Look forwards for the next point
        for i in (elementIndex + 1)..<elements.count {
            switch elements[i] {
            case .move(let to), .line(let to):
                return CGPoint(x: to.x, y: to.y)
            case .curve(let to, _, _):
                return CGPoint(x: to.x, y: to.y)
            case .quadCurve(let to, _):
                return CGPoint(x: to.x, y: to.y)
            case .close:
                continue
            }
        }
        
        return nil
    }
    
    // MARK: - PROFESSIONAL ADOBE ILLUSTRATOR DIRECT SELECTION (Two-Stage Implementation)
    
    /// Professional direct selection that works exactly like Adobe Illustrator with anchor point conversion
    private func handleDirectSelectionTap(at location: CGPoint) {
        print("🎯 PROFESSIONAL DIRECT SELECTION tap at: \(location)")
        
        // EXIT TEXT EDITING when using direct selection tool (Adobe Illustrator behavior)
        exitAllTextEditing()
        
        let tolerance: Double = 15.0
        var foundSelection = false
        
        // First check for text objects (Adobe Illustrator behavior: Direct Selection can select text objects)
        var hitText: VectorText?
        for textObj in document.textObjects.reversed() {
            if textObj.isVisible && !textObj.isLocked {
                let transformedBounds = textObj.bounds.applying(textObj.transform)
                let expandedBounds = transformedBounds.insetBy(dx: -8, dy: -8)
                if expandedBounds.contains(location) {
                    hitText = textObj
                    break
                }
            }
        }
        
        if let textObj = hitText {
            // PROFESSIONAL TEXT SELECTION WITH DIRECT SELECTION TOOL
            document.selectedTextIDs = [textObj.id]
            document.selectedShapeIDs.removeAll() // Clear shape selection
            selectedPoints.removeAll()
            selectedHandles.removeAll()
            directSelectedShapeIDs.removeAll()
            
            print("🎯 DIRECT SELECTION: Selected text '\(textObj.content)' for property editing")
            document.objectWillChange.send()
            return
        }
        
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
        // Search through direct-selected shapes for individual anchor points and handles
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes.reversed() {
                if !shape.isVisible || !directSelectedShapeIDs.contains(shape.id) { continue }
                
                print("🔍 Checking anchor points in direct-selected shape: \(shape.name)")
                
                // Check each path element for points and handles
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    let point: VectorPoint
                    
                    switch element {
                    case .move(let to), .line(let to):
                        point = to
                        
                    case .curve(let to, let control1, let control2):
                        point = to
                        
                        // PROFESSIONAL HANDLE SELECTION (Adobe Illustrator priority: handles first)
                        let handle1Location = CGPoint(x: control1.x, y: control1.y).applying(shape.transform)
                        let handle2Location = CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                        
                        if distance(location, handle1Location) <= tolerance {
                            // Select incoming handle
                            selectedHandles.removeAll()
                            selectedPoints.removeAll()
                            selectedHandles.insert(HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex,
                                handleType: .control1
                            ))
                            print("  ✅ SELECTED INCOMING HANDLE (control1) - Adobe Illustrator behavior")
                            return true
                        }
                        
                        if distance(location, handle2Location) <= tolerance {
                            // Select outgoing handle
                            selectedHandles.removeAll()
                            selectedPoints.removeAll()
                            selectedHandles.insert(HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex,
                                handleType: .control2
                            ))
                            print("  ✅ SELECTED OUTGOING HANDLE (control2) - Adobe Illustrator behavior")
                            return true
                        }
                        
                    case .quadCurve(let to, let control):
                        point = to
                        
                        // Check handle
                        let handleLocation = CGPoint(x: control.x, y: control.y).applying(shape.transform)
                        if distance(location, handleLocation) <= tolerance {
                            selectedHandles.removeAll()
                            selectedPoints.removeAll()
                            selectedHandles.insert(HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex,
                                handleType: .control1
                            ))
                            print("  ✅ SELECTED QUAD HANDLE - Adobe Illustrator behavior")
                            return true
                        }
                        
                    case .close:
                        continue
                    }
                    
                    // PROFESSIONAL ANCHOR POINT SELECTION (after checking handles)
                    let pointLocation = CGPoint(x: point.x, y: point.y).applying(shape.transform)
                    if distance(location, pointLocation) <= tolerance {
                        selectedHandles.removeAll()
                        selectedPoints.removeAll()
                        selectedPoints.insert(PointID(
                            shapeID: shape.id,
                            pathIndex: 0,
                            elementIndex: elementIndex
                        ))
                        print("  ✅ SELECTED ANCHOR POINT \(elementIndex) - Adobe Illustrator behavior")
                        
                        // PROFESSIONAL FEATURE: Double-click on anchor point converts it (Adobe Illustrator standard)
                        let now = Date()
                        if now.timeIntervalSince(lastTapTime) < 0.3 {
                            print("🎯 DOUBLE-CLICK DETECTED: Converting anchor point type...")
                            convertSelectedAnchorPointType(
                                layerIndex: layerIndex,
                                shapeIndex: layer.shapes.firstIndex(where: { $0.id == shape.id }) ?? 0,
                                elementIndex: elementIndex
                            )
                        }
                        lastTapTime = now
                        
                        return true
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
    
    // MARK: - PROFESSIONAL ANCHOR POINT CONVERSION FOR DIRECT SELECTION
    
    /// Convert anchor point type when double-clicked in direct selection mode (Adobe Illustrator behavior)
    private func convertSelectedAnchorPointType(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        document.saveToUndoStack()
        
        switch element {
        case .line(let to):
            // Convert corner to smooth
            print("🔄 DOUBLE-CLICK: Converting corner point to smooth curve...")
            let path = document.layers[layerIndex].shapes[shapeIndex].path
            let shape = document.layers[layerIndex].shapes[shapeIndex]
            
            let handles = calculateProfessionalHandlesForPoint(
                point: to,
                elementIndex: elementIndex,
                path: path,
                shape: shape
            )
            
            let newElement = PathElement.curve(
                to: to,
                control1: handles.incomingHandle,
                control2: handles.outgoingHandle
            )
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ CONVERTED: Corner → Smooth curve (Adobe Illustrator behavior)")
            
        case .curve(let to, _, _):
            // Convert smooth to corner
            print("🔄 DOUBLE-CLICK: Converting smooth point to corner point...")
            
            let newElement = PathElement.line(to: to)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ CONVERTED: Smooth curve → Corner point (Adobe Illustrator behavior)")
            
        case .quadCurve(let to, _):
            // Convert quadratic to corner
            print("🔄 DOUBLE-CLICK: Converting quadratic point to corner point...")
            
            let newElement = PathElement.line(to: to)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("✅ CONVERTED: Quadratic curve → Corner point (Adobe Illustrator behavior)")
            
        default:
            print("ℹ️ Point type not convertible")
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    // MARK: - PROFESSIONAL HANDLE CONTROL OPERATIONS (Adobe Illustrator Standards)
    
    /// Break handle symmetry for selected points (allows independent handle control)
    private func breakHandleSymmetryForSelectedPoints() {
        document.saveToUndoStack()
        
        print("🔧 BREAKING HANDLE SYMMETRY for \(selectedPoints.count) selected points...")
        
        for pointID in selectedPoints {
            breakHandleSymmetryForPoint(pointID)
        }
        
        document.objectWillChange.send()
        print("✅ HANDLE SYMMETRY BROKEN - Independent handle control enabled (Adobe Illustrator behavior)")
    }
    
    /// Make handles symmetric for selected points (smooth curves)
    private func makeHandlesSymmetricForSelectedPoints() {
        document.saveToUndoStack()
        
        print("🔧 MAKING HANDLES SYMMETRIC for \(selectedPoints.count) selected points...")
        
        for pointID in selectedPoints {
            makeHandlesSymmetricForPoint(pointID)
        }
        
        document.objectWillChange.send()
        print("✅ HANDLES MADE SYMMETRIC - Smooth curves restored (Adobe Illustrator behavior)")
    }
    
    /// Retract handles for selected points (convert to corner points)
    private func retractHandlesForSelectedPoints() {
        document.saveToUndoStack()
        
        print("🔧 RETRACTING HANDLES for \(selectedPoints.count) selected points...")
        
        for pointID in selectedPoints {
            retractHandlesForPoint(pointID)
        }
        
        document.objectWillChange.send()
        print("✅ HANDLES RETRACTED - Points converted to corners (Adobe Illustrator behavior)")
    }
    
    /// Convert all corner points to smooth in direct-selected shapes
    private func convertAllCornerPointsToSmooth() {
        document.saveToUndoStack()
        
        print("🔧 CONVERTING ALL CORNER POINTS TO SMOOTH in \(directSelectedShapeIDs.count) shapes...")
        
        for shapeID in directSelectedShapeIDs {
            convertAllCornerPointsInShape(shapeID)
        }
        
        document.objectWillChange.send()
        print("✅ ALL CORNER POINTS CONVERTED TO SMOOTH (Adobe Illustrator behavior)")
    }
    
    /// Convert all smooth points to corner in direct-selected shapes
    private func convertAllSmoothPointsToCorner() {
        document.saveToUndoStack()
        
        print("🔧 CONVERTING ALL SMOOTH POINTS TO CORNER in \(directSelectedShapeIDs.count) shapes...")
        
        for shapeID in directSelectedShapeIDs {
            convertAllSmoothPointsInShape(shapeID)
        }
        
        document.objectWillChange.send()
        print("✅ ALL SMOOTH POINTS CONVERTED TO CORNER (Adobe Illustrator behavior)")
    }
    
    /// Make all handles symmetric in direct-selected shapes
    private func makeAllHandlesSymmetric() {
        document.saveToUndoStack()
        
        print("🔧 MAKING ALL HANDLES SYMMETRIC in \(directSelectedShapeIDs.count) shapes...")
        
        for shapeID in directSelectedShapeIDs {
            makeAllHandlesSymmetricInShape(shapeID)
        }
        
        document.objectWillChange.send()
        print("✅ ALL HANDLES MADE SYMMETRIC (Adobe Illustrator behavior)")
    }
    
    /// Optimize selected paths (simplify curves)
    private func optimizeSelectedPaths() {
        document.saveToUndoStack()
        
        print("🔧 OPTIMIZING PATHS in \(directSelectedShapeIDs.count) shapes...")
        
        for shapeID in directSelectedShapeIDs {
            optimizePathInShape(shapeID)
        }
        
        document.objectWillChange.send()
        print("✅ PATHS OPTIMIZED (Adobe Illustrator behavior)")
    }
    
    // MARK: - INDIVIDUAL POINT HANDLE OPERATIONS
    
    /// Break handle symmetry for a specific point (Adobe Illustrator behavior)
    private func breakHandleSymmetryForPoint(_ pointID: PointID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex]
                
                switch element {
                case .curve(_, _, _):
                    // Already a curve with independent handles - no change needed
                    print("  Point already has independent handles")
                    
                case .line(let to):
                    // Convert to curve with asymmetric handles
                    let path = document.layers[layerIndex].shapes[shapeIndex].path
                    let shape = document.layers[layerIndex].shapes[shapeIndex]
                    
                    let handles = calculateProfessionalHandlesForPoint(
                        point: to,
                        elementIndex: pointID.elementIndex,
                        path: path,
                        shape: shape
                    )
                    
                    // Make handles slightly asymmetric for independent control
                    let asymmetricIncoming = VectorPoint(
                        handles.incomingHandle.x * 0.8,
                        handles.incomingHandle.y * 0.8
                    )
                    let asymmetricOutgoing = VectorPoint(
                        handles.outgoingHandle.x * 1.2,
                        handles.outgoingHandle.y * 1.2
                    )
                    
                    let newElement = PathElement.curve(
                        to: to,
                        control1: asymmetricIncoming,
                        control2: asymmetricOutgoing
                    )
                    
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("  ✅ BROKE SYMMETRY: Corner → Asymmetric curve")
                    
                default:
                    break
                }
                return
            }
        }
    }
    
    /// Make handles symmetric for a specific point
    private func makeHandlesSymmetricForPoint(_ pointID: PointID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex]
                
                switch element {
                case .curve(let to, let control1, let control2):
                    // Calculate symmetric handles based on average direction and length
                    let currentPoint = CGPoint(x: to.x, y: to.y)
                    let handle1Point = CGPoint(x: control1.x, y: control1.y)
                    let handle2Point = CGPoint(x: control2.x, y: control2.y)
                    
                    // Calculate average direction
                    let dir1 = CGPoint(x: handle1Point.x - currentPoint.x, y: handle1Point.y - currentPoint.y)
                    let dir2 = CGPoint(x: handle2Point.x - currentPoint.x, y: handle2Point.y - currentPoint.y)
                    
                    let avgLength = (distance(currentPoint, handle1Point) + distance(currentPoint, handle2Point)) / 2.0
                    let avgAngle = (atan2(dir1.y, dir1.x) + atan2(dir2.y, dir2.x)) / 2.0
                    
                    // Create symmetric handles
                    let symmetricIncoming = VectorPoint(
                        to.x - Foundation.cos(avgAngle) * avgLength,
                        to.y - Foundation.sin(avgAngle) * avgLength
                    )
                    let symmetricOutgoing = VectorPoint(
                        to.x + Foundation.cos(avgAngle) * avgLength,
                        to.y + Foundation.sin(avgAngle) * avgLength
                    )
                    
                    let newElement = PathElement.curve(
                        to: to,
                        control1: symmetricIncoming,
                        control2: symmetricOutgoing
                    )
                    
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("  ✅ MADE SYMMETRIC: Handles balanced")
                    
                case .line(let to):
                    // Convert to symmetric curve
                    let path = document.layers[layerIndex].shapes[shapeIndex].path
                    let shape = document.layers[layerIndex].shapes[shapeIndex]
                    
                    let handles = calculateProfessionalHandlesForPoint(
                        point: to,
                        elementIndex: pointID.elementIndex,
                        path: path,
                        shape: shape
                    )
                    
                    let newElement = PathElement.curve(
                        to: to,
                        control1: handles.incomingHandle,
                        control2: handles.outgoingHandle
                    )
                    
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("  ✅ MADE SYMMETRIC: Corner → Symmetric curve")
                    
                default:
                    break
                }
                return
            }
        }
    }
    
    /// Retract handles for a specific point (convert to corner)
    private func retractHandlesForPoint(_ pointID: PointID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex]
                
                switch element {
                case .curve(let to, _, _), .quadCurve(let to, _):
                    // Convert to line (retract handles)
                    let newElement = PathElement.line(to: to)
                    document.layers[layerIndex].shapes[shapeIndex].path.elements[pointID.elementIndex] = newElement
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    
                    print("  ✅ RETRACTED HANDLES: Curve → Corner")
                    
                default:
                    print("  Point already has no handles")
                }
                return
            }
        }
    }
    
    // MARK: - SHAPE-WIDE OPERATIONS
    
    /// Convert all corner points in a shape to smooth curves
    private func convertAllCornerPointsInShape(_ shapeID: UUID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                let path = shape.path
                
                for elementIndex in 0..<path.elements.count {
                    let element = path.elements[elementIndex]
                    
                    switch element {
                    case .line(let to):
                        let handles = calculateProfessionalHandlesForPoint(
                            point: to,
                            elementIndex: elementIndex,
                            path: path,
                            shape: shape
                        )
                        
                        let newElement = PathElement.curve(
                            to: to,
                            control1: handles.incomingHandle,
                            control2: handles.outgoingHandle
                        )
                        
                        document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
                        
                    default:
                        continue
                    }
                }
                
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                print("  ✅ SHAPE PROCESSED: All corners → smooth")
                return
            }
        }
    }
    
    /// Convert all smooth points in a shape to corners
    private func convertAllSmoothPointsInShape(_ shapeID: UUID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let path = document.layers[layerIndex].shapes[shapeIndex].path
                
                for elementIndex in 0..<path.elements.count {
                    let element = path.elements[elementIndex]
                    
                    switch element {
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        let newElement = PathElement.line(to: to)
                        document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
                        
                    default:
                        continue
                    }
                }
                
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                print("  ✅ SHAPE PROCESSED: All smooth → corners")
                return
            }
        }
    }
    
    /// Make all handles symmetric in a shape
    private func makeAllHandlesSymmetricInShape(_ shapeID: UUID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                let path = shape.path
                
                for elementIndex in 0..<path.elements.count {
                    let element = path.elements[elementIndex]
                    
                    switch element {
                    case .curve(let to, let control1, let control2):
                        // Make handles symmetric
                        let currentPoint = CGPoint(x: to.x, y: to.y)
                        let handle1Point = CGPoint(x: control1.x, y: control1.y)
                        let handle2Point = CGPoint(x: control2.x, y: control2.y)
                        
                        let avgLength = (distance(currentPoint, handle1Point) + distance(currentPoint, handle2Point)) / 2.0
                        let dir1 = CGPoint(x: handle1Point.x - currentPoint.x, y: handle1Point.y - currentPoint.y)
                        let dir2 = CGPoint(x: handle2Point.x - currentPoint.x, y: handle2Point.y - currentPoint.y)
                        let avgAngle = (atan2(dir1.y, dir1.x) + atan2(dir2.y, dir2.x)) / 2.0
                        
                        let symmetricIncoming = VectorPoint(
                            to.x - Foundation.cos(avgAngle) * avgLength,
                            to.y - Foundation.sin(avgAngle) * avgLength
                        )
                        let symmetricOutgoing = VectorPoint(
                            to.x + Foundation.cos(avgAngle) * avgLength,
                            to.y + Foundation.sin(avgAngle) * avgLength
                        )
                        
                        let newElement = PathElement.curve(
                            to: to,
                            control1: symmetricIncoming,
                            control2: symmetricOutgoing
                        )
                        
                        document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
                        
                    default:
                        continue
                    }
                }
                
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                print("  ✅ SHAPE PROCESSED: All handles made symmetric")
                return
            }
        }
    }
    
    /// Optimize path in a shape (simplify curves)
    private func optimizePathInShape(_ shapeID: UUID) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let originalPath = document.layers[layerIndex].shapes[shapeIndex].path
                
                // TODO: Implement professional path optimization algorithm
                // For now, we'll do basic optimization by removing redundant points
                
                var optimizedElements: [PathElement] = []
                var lastPoint: CGPoint?
                
                for element in originalPath.elements {
                    switch element {
                    case .move(let to):
                        lastPoint = CGPoint(x: to.x, y: to.y)
                        optimizedElements.append(element)
                        
                    case .line(let to):
                        let currentPoint = CGPoint(x: to.x, y: to.y)
                        if let last = lastPoint, distance(last, currentPoint) > 1.0 {
                            optimizedElements.append(element)
                            lastPoint = currentPoint
                        }
                        
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        let currentPoint = CGPoint(x: to.x, y: to.y)
                        if let last = lastPoint, distance(last, currentPoint) > 1.0 {
                            optimizedElements.append(element)
                            lastPoint = currentPoint
                        }
                        
                    case .close:
                        optimizedElements.append(element)
                    }
                }
                
                let optimizedPath = VectorPath(elements: optimizedElements, isClosed: originalPath.isClosed)
                document.layers[layerIndex].shapes[shapeIndex].path = optimizedPath
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                
                print("  ✅ SHAPE OPTIMIZED: \(originalPath.elements.count) → \(optimizedElements.count) elements")
                return
            }
        }
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
        }
    }
    
    @ViewBuilder
    private func professionalBezierDisplay(for shape: VectorShape) -> some View {
        ForEach(shape.path.elements.indices, id: \.self) { elementIndex in
            let element = shape.path.elements[elementIndex]
            
            switch element {
            case .move(let to), .line(let to):
                // Corner point (no handles) - PROFESSIONAL ADOBE ILLUSTRATOR STYLE
                let pointID = DrawingCanvas.PointID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex
                )
                let isSelected = selectedPoints.contains(pointID)
                let pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                let screenPoint = canvasToScreen(pointLocation, geometry: geometry)
                
                // PROFESSIONAL: Square handles for corner points (Illustrator/FreeHand standard)
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.white) // Solid when selected, hollow when not
                    .stroke(Color.blue, lineWidth: 1.5) // Always blue outline
                    .frame(width: 6, height: 6)
                    .position(screenPoint)
                
            case .curve(let to, let control1, let control2):
                // PROFESSIONAL CURVE POINT with handles (Adobe Illustrator standard)
                let pointID = DrawingCanvas.PointID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex
                )
                let isSelected = selectedPoints.contains(pointID)
                let pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                let screenPoint = canvasToScreen(pointLocation, geometry: geometry)
                
                // Main anchor point - square for curve points (professional standard)
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.white)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
                    .position(screenPoint)
                
                // INCOMING HANDLE (control1) - ALWAYS VISIBLE for curves (Adobe Illustrator standard)
                let handle1Location = CGPoint(x: control1.x, y: control1.y).applying(shape.transform)
                let screenHandle1 = canvasToScreen(handle1Location, geometry: geometry)
                
                // Handle direction line (professional blue)
                Path { path in
                    path.move(to: screenPoint)
                    path.addLine(to: screenHandle1)
                }
                .stroke(Color.blue, lineWidth: 1.0)
                
                // Handle circle (hollow with blue outline - professional standard)
                Circle()
                    .fill(Color.white)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 5, height: 5)
                    .position(screenHandle1)
                
                // OUTGOING HANDLE (control2) - ALWAYS VISIBLE for curves
                let handle2Location = CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                let screenHandle2 = canvasToScreen(handle2Location, geometry: geometry)
                
                // Handle direction line (professional blue)
                Path { path in
                    path.move(to: screenPoint)
                    path.addLine(to: screenHandle2)
                }
                .stroke(Color.blue, lineWidth: 1.0)
                
                // Handle circle (hollow with blue outline - professional standard)
                Circle()
                    .fill(Color.white)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 5, height: 5)
                    .position(screenHandle2)
                
            case .quadCurve(let to, let control):
                // Quadratic curve point (professional support)
                let pointID = DrawingCanvas.PointID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex
                )
                let isSelected = selectedPoints.contains(pointID)
                let pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                let screenPoint = canvasToScreen(pointLocation, geometry: geometry)
                
                // Main anchor point
                Rectangle()
                    .fill(isSelected ? Color.blue : Color.white)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 6, height: 6)
                    .position(screenPoint)
                
                // Single control handle
                let handleLocation = CGPoint(x: control.x, y: control.y).applying(shape.transform)
                let screenHandle = canvasToScreen(handleLocation, geometry: geometry)
                
                Path { path in
                    path.move(to: screenPoint)
                    path.addLine(to: screenHandle)
                }
                .stroke(Color.blue, lineWidth: 1.0)
                
                Circle()
                    .fill(Color.white)
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: 5, height: 5)
                    .position(screenHandle)
                
            case .close:
                EmptyView()
            }
        }
    }
    
    private func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: point.x * document.zoomLevel + document.canvasOffset.x,
            y: point.y * document.zoomLevel + document.canvasOffset.y
        )
    }
    
    private func getCurveInfo(_ pointID: DrawingCanvas.PointID) -> (pointLocation: CGPoint, control1: CGPoint?, control2: CGPoint?)? {
        // Find the shape and extract curve information
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                if pointID.elementIndex < shape.path.elements.count {
                    let element = shape.path.elements[pointID.elementIndex]
                    
                    switch element {
                    case .curve(let to, let control1, let control2):
                        return (
                            pointLocation: CGPoint(x: to.x, y: to.y).applying(shape.transform),
                            control1: CGPoint(x: control1.x, y: control1.y).applying(shape.transform),
                            control2: CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                        )
                    case .quadCurve(let to, let control):
                        return (
                            pointLocation: CGPoint(x: to.x, y: to.y).applying(shape.transform),
                            control1: CGPoint(x: control.x, y: control.y).applying(shape.transform),
                            control2: nil
                        )
                    default:
                        return nil
                    }
                }
            }
        }
        return nil
    }
    
    private func getPointLocation(_ pointID: DrawingCanvas.PointID) -> CGPoint? {
        // Find the shape and extract point location
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                if pointID.elementIndex < shape.path.elements.count {
                    let element = shape.path.elements[pointID.elementIndex]
                    
                    switch element {
                    case .move(let to), .line(let to):
                        return CGPoint(x: to.x, y: to.y).applying(shape.transform)
                    case .curve(let to, _, _):
                        return CGPoint(x: to.x, y: to.y).applying(shape.transform)
                    case .quadCurve(let to, _):
                        return CGPoint(x: to.x, y: to.y).applying(shape.transform)
                    case .close:
                        return nil
                    }
                }
            }
        }
        return nil
    }
    
    private func getHandleInfo(_ handleID: DrawingCanvas.HandleID) -> (pointLocation: CGPoint, handleLocation: CGPoint)? {
        // Find the shape and extract handle information
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                if handleID.elementIndex < shape.path.elements.count {
                    let element = shape.path.elements[handleID.elementIndex]
                    
                    switch element {
                    case .curve(let to, let control1, let control2):
                        let pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                        let handleLocation = handleID.handleType == .control1 
                            ? CGPoint(x: control1.x, y: control1.y).applying(shape.transform)
                            : CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                        return (pointLocation, handleLocation)
                    case .quadCurve(let to, let control):
                        let pointLocation = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                        let handleLocation = CGPoint(x: control.x, y: control.y).applying(shape.transform)
                        return (pointLocation, handleLocation)
                    default:
                        return nil
                    }
                }
            }
        }
        return nil
    }
}