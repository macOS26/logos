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
    @State internal var currentPath: VectorPath?
    @State internal var isDrawing = false
    @State internal var dragOffset = CGSize.zero
    @State internal var lastPanLocation = CGPoint.zero
    @State internal var drawingStartPoint: CGPoint?
    @State internal var currentDrawingPoints: [CGPoint] = []
    
    @State internal var lastTapTime: Date = Date()
    
    // PROFESSIONAL HAND TOOL STATE (Industry Standards)
    // Based on Adobe Illustrator, MacroMedia FreeHand, Inkscape, and CorelDRAW
    // Reference: US Patent 6097387A - "Dynamic control of panning operation in computer graphics"
    @State internal var initialCanvasOffset = CGPoint.zero    // Reference canvas position when drag started
    @State internal var handToolDragStart = CGPoint.zero      // Reference cursor position when drag started
    
    // PROFESSIONAL OBJECT DRAGGING STATE (Same precision as hand tool)
    @State internal var selectionDragStart = CGPoint.zero     // Reference cursor position when object drag started
    @State internal var initialObjectPositions: [UUID: CGPoint] = [:]  // Initial object positions when drag started
    
    // PROFESSIONAL SHAPE DRAWING STATE (Same precision as hand tool)
    @State internal var shapeDragStart = CGPoint.zero         // Reference cursor position when shape drawing started
    @State internal var shapeStartPoint = CGPoint.zero       // Reference canvas position when shape drawing started
    
    // PROFESSIONAL MULTI-SELECTION (Adobe Illustrator Standards)
    @State internal var isShiftPressed = false
    @State internal var isCommandPressed = false
    @State internal var isOptionPressed = false
    @State internal var keyEventMonitor: Any?
    
    // Bezier tool specific state
    @State internal var bezierPath: VectorPath?
    @State internal var bezierPoints: [VectorPoint] = []
    @State internal var isBezierDrawing = false
    @State internal var isDraggingBezierHandle = false
    @State internal var activeBezierPointIndex: Int? = nil // Currently active (solid) point
    @State internal var isDraggingBezierPoint = false
    @State internal var bezierHandles: [Int: BezierHandleInfo] = [:] // Point handles for each bezier point
    @State internal var currentMouseLocation: CGPoint? = nil // For rubber band preview
    @State internal var showClosePathHint = false
    @State internal var closePathHintLocation: CGPoint = .zero
    
    // PROFESSIONAL REAL-TIME PATH CREATION (Adobe Illustrator Style)
    @State internal var activeBezierShape: VectorShape? = nil // Real shape being built
    
    // Track previous tool to detect changes
    @State internal var previousTool: DrawingTool = .selection
    
    // Zoom gesture state
    @State internal var initialZoomLevel: CGFloat = 1.0
    
    // PROFESSIONAL GESTURE COORDINATION STATE
    @State internal var isZoomGestureActive = false
    @State internal var isPanGestureActive = false
    
    // Direct selection state
    @State internal var selectedPoints: Set<PointID> = []
    @State internal var selectedHandles: Set<HandleID> = []
    @State internal var directSelectedShapeIDs: Set<UUID> = [] // Track which shapes have been direct-selected
    @State internal var isDraggingPoint = false
    @State internal var isDraggingHandle = false
    @State internal var dragStartLocation: CGPoint = .zero
    @State internal var originalPointPositions: [PointID: VectorPoint] = [:]
    @State internal var originalHandlePositions: [HandleID: VectorPoint] = [:]
    
    // PROFESSIONAL COINCIDENT POINT MANAGEMENT
    // This handles the case where multiple points exist at the same X,Y coordinates
    // Essential for maintaining continuity in closed paths (circles, etc.)
    @State internal var coincidentPointTolerance: Double = 1.0 // Points within 1 pixel are considered coincident
    
    // FONT TOOL STATE (Core Graphics based - no Core Text)
    @State internal var isEditingText = false
    @State internal var editingTextID: UUID? = nil
    @State internal var textCursorPosition: Int = 0
    
    // Point and handle identification moved to PointAndHandleID.swift
    var body: some View {
        GeometryReader { geometry in
            canvasMainContent(geometry: geometry)
        }
    }
}











extension DrawingCanvas {
    @ViewBuilder
    internal func fillClosePreview(geometry: GeometryProxy) -> some View {
        // Show fill preview when close to closing path - this shows what the final filled shape will look like
        if showClosePathHint && bezierPoints.count >= 3,
           let currentBezierPath = bezierPath {
            
            let lastPointIndex = bezierPoints.count - 1
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            
            // Get handle information for proper closing curve
            let lastPointHandles = bezierHandles[lastPointIndex]
            let firstPointHandles = bezierHandles[0]
            
            // Create complete preview path (existing path + closing segment)
            Path { path in
                // Start with the existing path elements (converted to SwiftUI Path)
                addPathElements(currentBezierPath.elements, to: &path)
                
                // Add the closing segment with proper curve handling
                let lastPoint = bezierPoints[lastPointIndex]
                let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
                
                if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
                    // Both points have handles - create smooth closing curve
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                    path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstControl1Location)
                } else if let lastControl2 = lastPointHandles?.control2 {
                    // Only last point has handle - asymmetric curve
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    path.addCurve(to: firstPointLocation, control1: lastControl2Location, control2: firstPointLocation)
                } else if let firstControl1 = firstPointHandles?.control1 {
                    // Only first point has handle - asymmetric curve
                    let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                    path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
                } else {
                    // Straight line close
                    path.addLine(to: firstPointLocation)
                }
                
                // Close the path for fill preview
                path.closeSubpath()
            }
            .fill(document.defaultFillColor.color.opacity(0.3)) // Semi-transparent fill preview
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }
}

extension DrawingCanvas {
    @ViewBuilder
    internal func rubberBandFillPreview(geometry: GeometryProxy) -> some View {
        // Show fill preview during normal drawing - BETTER THAN ADOBE!
        if let mouseLocation = currentMouseLocation,
           let currentBezierPath = bezierPath,
           bezierPoints.count >= 2 {
            
            let canvasMouseLocation = screenToCanvas(mouseLocation, geometry: geometry)
            let lastPointIndex = bezierPoints.count - 1
            let lastPoint = bezierPoints[lastPointIndex]
            let _ = CGPoint(x: lastPoint.x, y: lastPoint.y) // Unused variable
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            
            // Create preview path (existing path + rubber band to cursor + back to first point)
            Path { path in
                // Start with the existing path elements (converted to SwiftUI Path)
                addPathElements(currentBezierPath.elements, to: &path)
                
                // Add rubber band segment to cursor
                if let lastPointHandles = bezierHandles[lastPointIndex],
                   let lastControl2 = lastPointHandles.control2 {
                    // Curve rubber band
                    let lastControl2Location = CGPoint(x: lastControl2.x, y: lastControl2.y)
                    path.addCurve(
                        to: canvasMouseLocation,
                        control1: lastControl2Location,
                        control2: canvasMouseLocation
                    )
                } else {
                    // Straight rubber band
                    path.addLine(to: canvasMouseLocation)
                }
                
                // Add line back to first point to complete the preview shape
                path.addLine(to: firstPointLocation)
                
                // Close the path for fill preview
                path.closeSubpath()
            }
            .fill(document.defaultFillColor.color.opacity(0.15)) // Very subtle fill preview (lighter than close preview)
            .scaleEffect(document.zoomLevel, anchor: .topLeading)
            .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        }
    }
}

extension DrawingCanvas {
    // MARK: - Professional Preview Functions (Adobe Illustrator Standards)
    
    // REMOVED: bezierPathPreview() - Now using real VectorShapes with actual document colors
    // Professional vector apps (Illustrator, FreeHand, CorelDraw) show the actual path being built, not a preview
    
    @ViewBuilder
    internal func rubberBandPreview(geometry: GeometryProxy) -> some View {
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
            
            // RUBBER BAND FILL PREVIEW - Show what next point would look like (only when NOT closing)
            if bezierPoints.count >= 2 && !showClosePathHint {
                rubberBandFillPreview(geometry: geometry)
            }
            
            // PROFESSIONAL FILL PREVIEW - Show what the closed shape will look like
            if showClosePathHint && bezierPoints.count >= 3 {
                fillClosePreview(geometry: geometry)
            }
            
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
                    } else if let firstControl1 = firstPointHandles?.control1 {
                        // Only first point has handle - asymmetric curve preview
                        let firstControl1Location = CGPoint(x: firstControl1.x, y: firstControl1.y)
                        path.addCurve(to: firstPointLocation, control1: lastPointLocation, control2: firstControl1Location)
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
}

extension DrawingCanvas {
    @ViewBuilder
    internal func bezierClosePathHint() -> some View {
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
}

extension DrawingCanvas {
    @ViewBuilder
    internal func bezierControlHandles() -> some View {
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
}

extension DrawingCanvas {
    @ViewBuilder
    internal func bezierAnchorPoints() -> some View {
        // PROFESSIONAL BEZIER ANCHOR POINTS - USE SAME COORDINATE SYSTEM AS ARROW TOOL
        if isBezierDrawing {
            ForEach(bezierPoints.indices, id: \.self) { index in
                let point = bezierPoints[index]
                let pointLocation = CGPoint(x: point.x, y: point.y)
                let isActive = activeBezierPointIndex == index
                
                // PROFESSIONAL SCALE-INDEPENDENT SIZING (Adobe Illustrator Standards)
                let anchorSize = 6.0 / document.zoomLevel  // Scale-independent anchor point size
                let lineWidth = 1.0 / document.zoomLevel   // Scale-independent stroke width
                
                // PROFESSIONAL ANCHOR POINT RENDERING - USE SAME COORDINATE SYSTEM AS ARROW TOOL
                // Active point: solid black square with white stroke
                // Inactive point: hollow white square with black stroke
                // Note: Removed green square highlighting - close hint circle and preview line are sufficient
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
}









extension DrawingCanvas {
    internal func handleToolChange(oldTool: DrawingTool, newTool: DrawingTool) {
        // ✅ EXPLICIT USER ACTION: Auto-finish bezier path when user switches away from pen tool
        // This is standard Adobe Illustrator behavior and represents explicit user intent to stop drawing
        if previousTool == .bezierPen && newTool != .bezierPen && isBezierDrawing {
            print("🔧 USER SWITCHED TOOLS: Auto-finishing current bezier path (explicit user action)")
            finishBezierPath()
        }
        
        // SURGICAL FIX: Cancel text editing when switching away from font tool
        if previousTool == .font && newTool != .font && isEditingText {
            print("🔧 USER SWITCHED TOOLS: Canceling text editing (switched away from font tool)")
            finishTextEditing()
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
}

extension DrawingCanvas {
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
                        viewMode: document.viewMode
                    )
                }
            }
            
            // RENDER TEXT OBJECTS using Core Graphics (NO CORE TEXT)
            ForEach(document.textObjects.indices, id: \.self) { textIndex in
                let textObj = document.textObjects[textIndex]
                if textObj.isVisible {
                    TextObjectView(
                        textObject: textObj,
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        isSelected: document.selectedTextIDs.contains(textObj.id),
                        isEditing: isEditingText && editingTextID == textObj.id
                    )
                }
            }
            
            canvasOverlays(geometry: geometry)
        }
    }
}

extension DrawingCanvas {
    @ViewBuilder
    internal func canvasMainContent(geometry: GeometryProxy) -> some View {
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
                // UNIFIED COORDINATE SYSTEM: Handle ALL clicks (canvas + pasteboard) with SwiftUI
                // This gives perfect accuracy everywhere using the same coordinate system
                print("🎯 UNIFIED TAP GESTURE at screen: \(location)")
                handleTap(at: location, geometry: geometry)
            }
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
}
