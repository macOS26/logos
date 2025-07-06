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
    @State private var isDraggingPoint = false
    @State private var isDraggingHandle = false
    
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
        if document.currentTool == .directSelection && !selectedPoints.isEmpty {
            Button("Close Path") {
                closeSelectedPaths()
            }
            .keyboardShortcut("c", modifiers: [.command])
            
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
                
                // Bezier path preview
                if let bezierPath = bezierPath {
                    Path { path in
                        addPathElements(bezierPath.elements, to: &path)
                    }
                    .stroke(Color.orange, lineWidth: 2.0)
                    .scaleEffect(document.zoomLevel)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                }
                
                // Rubber band preview line (professional pen tool behavior)
                if isBezierDrawing && document.currentTool == .bezierPen,
                   let mouseLocation = currentMouseLocation,
                   bezierPoints.count > 0 {
                    let canvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
                    let lastPoint = bezierPoints[bezierPoints.count - 1]
                    let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
                    
                    Path { path in
                        path.move(to: lastPointLocation)
                        path.addLine(to: canvasMouseLocation)
                    }
                    .stroke(Color.gray.opacity(0.7), style: SwiftUI.StrokeStyle(lineWidth: 1.0, lineCap: .round))
                    .scaleEffect(document.zoomLevel)
                    .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
                }
                
                // Professional bezier anchor points
                if isBezierDrawing {
                    ForEach(bezierPoints.indices, id: \.self) { index in
                        let point = bezierPoints[index]
                        let screenPoint = canvasToScreen(point.cgPoint, geometry: geometry)
                        let isActive = activeBezierPointIndex == index
                        
                        // Render anchor point as square (solid if active, hollow if inactive)
                        Rectangle()
                            .fill(isActive ? Color.black : Color.clear)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.black, lineWidth: 1.0)
                            )
                            .frame(width: 6, height: 6)
                            .position(screenPoint)
                        
                        // Render bezier handles if they exist for this point
                        if let handleInfo = bezierHandles[index], handleInfo.hasHandles {
                            // Draw control handle lines
                            if let control1 = handleInfo.control1 {
                                let control1Screen = canvasToScreen(control1.cgPoint, geometry: geometry)
                                Path { path in
                                    path.move(to: screenPoint)
                                    path.addLine(to: control1Screen)
                                }
                                .stroke(Color.blue, lineWidth: 1.0)
                                
                                // Control handle circle
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 4)
                                    .position(control1Screen)
                            }
                            
                            if let control2 = handleInfo.control2 {
                                let control2Screen = canvasToScreen(control2.cgPoint, geometry: geometry)
                                Path { path in
                                    path.move(to: screenPoint)
                                    path.addLine(to: control2Screen)
                                }
                                .stroke(Color.blue, lineWidth: 1.0)
                                
                                // Control handle circle
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 4, height: 4)
                                    .position(control2Screen)
                            }
                        }
                    }
                }
                
                // Selection handles for selected shapes
                SelectionHandlesView(
                    document: document,
                    geometry: geometry
                )
                
                // Direct selection points and handles
                if document.currentTool == .directSelection {
                    DirectSelectionVisualsView(
                        document: document,
                        selectedPoints: selectedPoints,
                        selectedHandles: selectedHandles,
                        geometry: geometry
                    )
                }
            }
            .clipped()
            .onAppear {
                setupCanvas(geometry: geometry)
                previousTool = document.currentTool
            }
            .onChange(of: document.currentTool) { newTool in
                // Auto-finalize bezier path when switching away from bezier tool
                if previousTool == .bezierPen && newTool != .bezierPen && isBezierDrawing {
                    finishBezierPath()
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
                } else {
                    currentMouseLocation = nil
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
        case .bezierPen:
            finishBezierPenDrag()
            // Don't reset bezier state here - it continues until double-tap
        default:
            break
        }
    }
    
    private func handleSelectionTap(at location: CGPoint) {
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
            // Select the shape and make its layer active
            document.selectedLayerIndex = layerIndex
            document.selectedShapeIDs = [shape.id]
            print("Selected shape: \(shape.name) in layer \(layerIndex)")
        } else {
            // Clear selection if clicking on empty space
            document.selectedShapeIDs.removeAll()
            print("Cleared selection")
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
    
    private func handleBezierPenTap(at location: CGPoint) {
        let now = Date()
        let timeSinceLastTap = now.timeIntervalSince(bezierLastTapTime)
        bezierLastTapTime = now
        
        // Check if we're trying to close the path by clicking near the first point
        if isBezierDrawing && bezierPoints.count >= 3 {
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            if distance(location, firstPointLocation) <= 12.0 { // Close tolerance
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
            
            // Create handles based on drag direction
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
            
            // Check if any shape actually moved
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
        
        print("Finished bezier path with \(bezierPoints.count) points")
        print("Path elements: \(path.elements.count)")
        print("Shape bounds: \(shape.bounds)")
        print("Stroke color: \(strokeStyle.color)")
        
        document.addShape(shape)
        
        // Reset bezier state
        cancelBezierDrawing()
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
    
    private func handleDirectSelectionTap(at location: CGPoint) {
        // Clear previous selections if not holding Shift
        // TODO: Add Shift key detection for multi-selection
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        
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
                            selectedHandles.insert(HandleID(
                                shapeID: shape.id,
                                pathIndex: 0, // Assuming single path for now
                                elementIndex: elementIndex,
                                handleType: .control1
                            ))
                            foundPoint = true
                            break
                        }
                        
                        if distance(location, handle2Location) <= tolerance {
                            selectedHandles.insert(HandleID(
                                shapeID: shape.id,
                                pathIndex: 0,
                                elementIndex: elementIndex,
                                handleType: .control2
                            ))
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
                        selectedPoints.insert(PointID(
                            shapeID: shape.id,
                            pathIndex: 0,
                            elementIndex: elementIndex
                        ))
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
        guard let path = bezierPath, bezierPoints.count >= 3 else {
            print("Cannot close bezier path - insufficient points or no path")
            cancelBezierDrawing()
            return
        }
        
        // Add close element to complete the path
        bezierPath?.addElement(.close)
        
        // Create the shape with stroke and fill
        let strokeStyle = StrokeStyle(color: .rgb(RGBColor(red: 1.0, green: 0.5, blue: 0.0)), width: 2.0)
        let fillStyle = FillStyle(color: .clear) // Can be changed later
        
        let shape = VectorShape(
            name: "Closed Bezier Path \(bezierPoints.count) points",
            path: path,
            strokeStyle: strokeStyle,
            fillStyle: fillStyle
        )
        
        print("Closed bezier path with \(bezierPoints.count) points")
        
        // Add to document
        document.addShape(shape)
        
        // Clear bezier state
        bezierPath = nil
        bezierPoints.removeAll()
        isBezierDrawing = false
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        activeBezierPointIndex = nil
        bezierHandles.removeAll()
    }
    
    private func handleConvertAnchorPointTap(at location: CGPoint) {
        let tolerance: Double = 8.0 // Hit test tolerance
        
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
                            return
                        }
                    case .curve(let to, _, _):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // Convert smooth point to corner point by removing curve handles
                            convertSmoothToCorner(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                            return
                        }
                    case .quadCurve(let to, _):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        if distance(location, pointLocation) <= tolerance {
                            // Convert quad curve to corner point
                            convertQuadToCorner(layerIndex: layerIndex, shapeIndex: shapeIndex, elementIndex: elementIndex)
                            return
                        }
                    case .close:
                        continue
                    }
                }
            }
        }
        
        print("Convert Anchor Point: No point found at location \(location)")
    }
    
    private func convertLineToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        switch element {
        case .line(let to):
            // Convert line to cubic curve with small handles
            let point = VectorPoint(to.x, to.y)
            let handleOffset: Double = 20.0
            let control1 = VectorPoint(to.x - handleOffset, to.y)
            let control2 = VectorPoint(to.x + handleOffset, to.y)
            
            let newElement = PathElement.curve(to: point, control1: control1, control2: control2)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("Converted line point to smooth curve")
        default:
            break
        }
    }
    
    private func convertSmoothToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        switch element {
        case .curve(let to, _, _):
            // Convert curve to line (corner point)
            let newElement = PathElement.line(to: to)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("Converted smooth curve to corner point")
        default:
            break
        }
    }
    
    private func convertQuadToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        switch element {
        case .quadCurve(let to, _):
            // Convert quad curve to line (corner point)
            let newElement = PathElement.line(to: to)
            document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex] = newElement
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            print("Converted quad curve to corner point")
        default:
            break
        }
    }
}

struct DirectSelectionVisualsView: View {
    let document: VectorDocument
    let selectedPoints: Set<DrawingCanvas.PointID>
    let selectedHandles: Set<DrawingCanvas.HandleID>
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Render control handle lines and handles
            ForEach(Array(selectedHandles), id: \.self) { handleID in
                if let handleInfo = getHandleInfo(handleID) {
                    // Draw line from point to handle
                    Path { path in
                        let screenPoint = canvasToScreen(handleInfo.pointLocation, geometry: geometry)
                        let screenHandle = canvasToScreen(handleInfo.handleLocation, geometry: geometry)
                        path.move(to: screenPoint)
                        path.addLine(to: screenHandle)
                    }
                    .stroke(Color.blue, lineWidth: 1.0)
                    
                    // Draw handle as circle
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .position(canvasToScreen(handleInfo.handleLocation, geometry: geometry))
                }
            }
            
            // Render selected points as squares
            ForEach(Array(selectedPoints), id: \.self) { pointID in
                if let pointLocation = getPointLocation(pointID) {
                    Rectangle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .position(canvasToScreen(pointLocation, geometry: geometry))
                }
            }
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
        // Find the shape and extract handle information
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                if handleID.elementIndex < shape.path.elements.count {
                    let element = shape.path.elements[handleID.elementIndex]
                    
                    switch element {
                    case .curve(let to, let control1, let control2):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        let handleLocation = handleID.handleType == .control1 
                            ? CGPoint(x: control1.x, y: control1.y)
                            : CGPoint(x: control2.x, y: control2.y)
                        return (pointLocation, handleLocation)
                    case .quadCurve(let to, let control):
                        let pointLocation = CGPoint(x: to.x, y: to.y)
                        let handleLocation = CGPoint(x: control.x, y: control.y)
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