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
        
        // PROFESSIONAL REAL-TIME BEZIER PATH (Adobe Illustrator style - shows actual path with real colors)
        // Note: Real bezier shapes are now shown as actual VectorShapes in the document
        
        // PROFESSIONAL RUBBER BAND PREVIEW (Adobe Illustrator Standards)
        rubberBandPreview(geometry: geometry)
        
        bezierAnchorPoints()
        bezierControlHandles()
        bezierClosePathHint()
        
        // Selection handles for selected shapes (EXCEPT during pen tool drawing or selection dragging)
        // PROFESSIONAL UX: Hide selection dots during movement (Adobe Illustrator standard)
        if !(document.currentTool == .bezierPen && isBezierDrawing) && 
           !(document.currentTool == .selection && isDrawing) {
            SelectionHandlesView(
                document: document,
                geometry: geometry,
                isShiftPressed: self.isShiftPressed
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
        
        // Gradient center point visualization and editing
        gradientCenterPointOverlay(geometry: geometry)
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
        canvasBaseContent(geometry: geometry)
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
    
    // MARK: - Gradient Center Point Overlay
    
    @ViewBuilder
    internal func gradientCenterPointOverlay(geometry: GeometryProxy) -> some View {
        // Only show for selected shapes with gradients
        if let selectedGradient = getSelectedShapeGradient(document: document),
           let layerIndex = document.selectedLayerIndex,
           let firstSelectedID = document.selectedShapeIDs.first,
           let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }) {
            
            // Calculate the gradient center point in canvas coordinates
            let centerPoint = getGradientCenterPoint(gradient: selectedGradient, shape: shape)
            
            // Convert to screen coordinates
            let screenPoint = canvasToScreen(centerPoint, geometry: geometry)
            
            // Draw the gradient center point with type indicator
            ZStack {
                // Main circle
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .stroke(Color.white, lineWidth: 2.0)
                    .frame(width: 16, height: 16)
                
                // Type indicator (small inner circle for radial, line for linear)
                switch selectedGradient {
                case .radial:
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                case .linear:
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 8, height: 2)
                        .rotationEffect(.degrees(45))
                }
            }
            .position(screenPoint)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                .onTapGesture {
                    // Optional: Add tap behavior if needed
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handleGradientCenterDrag(value: value, geometry: geometry, shape: shape, gradient: selectedGradient)
                        }
                        .onEnded { _ in
                            // Save to undo stack when drag ends
                            document.saveToUndoStack()
                        }
                )
        }
    }
    
    // Helper function to get gradient center point in canvas coordinates
    // Uses the SAME origin point logic as the stroke/fill panel
    private func getGradientCenterPoint(gradient: VectorGradient, shape: VectorShape) -> CGPoint {
        let shapeBounds = shape.bounds
        
        // Get origin point using the same functions as the stroke/fill panel
        let originX = getGradientOriginX(gradient)
        let originY = getGradientOriginY(gradient)
        
        // Get gradient scale to account for scaled gradient positioning
        let scale = getGradientScale(gradient)
        
        // Calculate scaled bounds - when gradient is scaled, origin point can extend beyond object bounds
        let scaledWidth = shapeBounds.width * scale
        let scaledHeight = shapeBounds.height * scale
        
        // Calculate offset from object center to scaled gradient center
        let offsetX = (scaledWidth - shapeBounds.width) / 2.0
        let offsetY = (scaledHeight - shapeBounds.height) / 2.0
        
        // Convert to canvas coordinates accounting for scale
        let canvasX = shapeBounds.minX - offsetX + scaledWidth * originX
        let canvasY = shapeBounds.minY - offsetY + scaledHeight * originY
        return CGPoint(x: canvasX, y: canvasY)
    }
    
    // Get gradient scale (same as stroke/fill panel)
    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX // Use scaleX as the primary scale
        case .radial(let radial):
            return radial.scaleX // Use scaleX as the primary scale
        }
    }
    
    // Same origin point functions as stroke/fill panel
    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            return radial.originPoint.x
        }
    }
    
    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            return radial.originPoint.y
        }
    }
    
    // Handle gradient center point dragging
    private func handleGradientCenterDrag(value: DragGesture.Value, geometry: GeometryProxy, shape: VectorShape, gradient: VectorGradient) {
        // Convert screen coordinates to canvas coordinates
        let canvasPoint = screenToCanvas(value.location, geometry: geometry)
        
        // Get gradient scale to account for scaled gradient positioning
        let scale = getGradientScale(gradient)
        let shapeBounds = shape.bounds
        
        // Calculate scaled bounds
        let scaledWidth = shapeBounds.width * scale
        let scaledHeight = shapeBounds.height * scale
        
        // Calculate offset from object center to scaled gradient center
        let offsetX = (scaledWidth - shapeBounds.width) / 2.0
        let offsetY = (scaledHeight - shapeBounds.height) / 2.0
        
        // Convert to relative coordinates within the scaled gradient bounds
        // Allow coordinates to extend beyond 0-1 range when gradient is scaled
        let relativeX = (canvasPoint.x - (shapeBounds.minX - offsetX)) / scaledWidth
        let relativeY = (canvasPoint.y - (shapeBounds.minY - offsetY)) / scaledHeight
        
        // Don't clamp the coordinates - allow them to extend beyond object bounds
        // This allows the origin point to move freely within the scaled gradient area
        updateGradientOriginX(relativeX, shape: shape, applyToShapes: true)
        updateGradientOriginY(relativeY, shape: shape, applyToShapes: true)
    }
    
    // Same update functions as stroke/fill panel
    private func updateGradientOriginX(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            updateShapeGradient(shape: shape, newGradient: .linear(linear))
        case .radial(var radial):
            radial.originPoint.x = newX
            // Set focal point to match origin point (same as StrokeFillPanel)
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            updateShapeGradient(shape: shape, newGradient: .radial(radial))
        }
    }
    
    private func updateGradientOriginY(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            updateShapeGradient(shape: shape, newGradient: .linear(linear))
        case .radial(var radial):
            radial.originPoint.y = newY
            // Set focal point to match origin point (same as StrokeFillPanel)
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            updateShapeGradient(shape: shape, newGradient: .radial(radial))
        }
    }
    
    // Helper function to update shape gradient
    private func updateShapeGradient(shape: VectorShape, newGradient: VectorGradient) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        // Find and update the shape in the document
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            var updatedShape = shape
            updatedShape.fillStyle = FillStyle(color: .gradient(newGradient))
            document.layers[layerIndex].shapes[shapeIndex] = updatedShape
            
            // Trigger document update to refresh UI
            document.objectWillChange.send()
        }
    }
    
    // Helper function to get selected shape gradient (copied from StrokeFillPanel)
    private func getSelectedShapeGradient(document: VectorDocument) -> VectorGradient? {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
              let fillStyle = shape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
    }
} 