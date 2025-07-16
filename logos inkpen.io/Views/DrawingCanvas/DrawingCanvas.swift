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
    
    internal func finishBezierPath() {
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
                    // FINAL FILL: Make fully opaque when path is finished
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: document.defaultFillColor,
                        opacity: document.defaultFillOpacity // Full opacity (usually 1.0)
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
        
        // TRACING WORKFLOW IMPROVEMENT: Don't auto-switch tools to allow continuous pen tool usage
        // This allows users to trace multiple objects without tool interruption
        let _ = activeBezierShape.id // Unused variable
        
        // Reset bezier state BUT KEEP pen tool active for continuous tracing
        cancelBezierDrawing()
        
        // NOTE: Removed automatic tool switch to direct selection
        // Users can manually switch tools when they're ready to edit points
        // This enables uninterrupted tracing workflows
        
        print("✅ FINISHED PATH: Pen tool remains active for continuous tracing")
    }
    
    internal func finishBezierPenDrag() {
        // Reset bezier drag state
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        
        // Update the real shape in the document
        updateActiveBezierShapeInDocument()
    }
    

    


    
    // MARK: - PROFESSIONAL COINCIDENT POINT HANDLING
    // Coincident point functions moved to CoincidentPointHandling.swift
    
    // MARK: - Font Tool Handler (Core Graphics Based)
    // Text handling functions moved to TextHandling.swift
    
}

extension DrawingCanvas {
    // TEXT EDITING FUNCTIONS REMOVED - Starting over with simple approach
    
    internal func handleSelectionTap(at location: CGPoint) {
        // Clean up excessive logging per user request
        
        // CRITICAL: Regular Selection tool must clear direct selection
        // Professional tools have mutually exclusive selection modes
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        
        // Only handle selection for selection tool
        guard document.currentTool == .selection else { return }
        
        // CRITICAL FIX: Check for text objects FIRST (they should be selectable with selection tool!)
        if let textID = findTextAt(location: location) {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObject = document.textObjects[textIndex]
                
                // Check if text is locked
                if textObject.isLocked {
                    document.selectedShapeIDs.removeAll()
                    document.selectedTextIDs.removeAll()
                    document.objectWillChange.send()
                    return
                }
                
                // Select the text object
                if isShiftPressed {
                    // SHIFT+CLICK: Add to selection
                    document.selectedTextIDs.insert(textID)
                } else if isCommandPressed {
                    // CMD+CLICK: Toggle selection
                    if document.selectedTextIDs.contains(textID) {
                        document.selectedTextIDs.remove(textID)
                    } else {
                        document.selectedTextIDs.insert(textID)
                    }
                } else {
                    // REGULAR CLICK: Replace selection
                    document.selectedTextIDs = [textID]
                    document.selectedShapeIDs.removeAll() // Clear shape selection
                }
                
                // Force UI update
                document.objectWillChange.send()
                return
            }
        }
        
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
                } else {
                    // Regular shapes: Use different logic for stroke vs filled
                    let isStrokeOnly = shape.fillStyle?.color == .clear || shape.fillStyle == nil
                    
                    if isStrokeOnly && shape.strokeStyle != nil {
                        // Method 1: Stroke-only shapes - use stroke-based hit testing only
                        let strokeWidth = shape.strokeStyle?.width ?? 1.0
                        let strokeTolerance = max(15.0, strokeWidth + 10.0)
                        
                        isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                    } else {
                        // Method 2: Filled shapes - use bounds + path hit testing
                        let transformedBounds = shape.bounds.applying(shape.transform)
                        let expandedBounds = transformedBounds.insetBy(dx: -12, dy: -12)
                        
                        if expandedBounds.contains(location) {
                            isHit = true
                        } else {
                            // Fallback: precise path hit test
                            isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: 8.0)
                        }
                    }
                }
                
                if isHit {
                    hitShape = shape
                    hitLayerIndex = layerIndex
                    break
                }
            }
            if hitShape != nil { break }
        }
        
        if let shape = hitShape, let layerIndex = hitLayerIndex {
            // IMPROVED LOCKED BEHAVIOR: Instead of preventing interaction, deselect current selection
            if document.layers[layerIndex].isLocked || shape.isLocked {
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
            } else if isCommandPressed {
                // CMD+CLICK: Toggle selection (add if not selected, remove if selected)
                if document.selectedShapeIDs.contains(shape.id) {
                    document.selectedShapeIDs.remove(shape.id)
                } else {
                    document.selectedShapeIDs.insert(shape.id)
                }
            } else {
                // REGULAR CLICK: Replace selection (clear existing, select new)
                document.selectedShapeIDs = [shape.id]
                document.selectedTextIDs.removeAll() // Clear text selection
            }
        } else {
            // NO OBJECT HIT: Clicking on background or empty space
            let documentBounds = document.documentBounds
            let isOutsideDocument = !documentBounds.contains(location)
            
            if isOutsideDocument {
                // Clicking in gray background area outside document always deselects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
            } else if !isShiftPressed && !isCommandPressed {
                // Clicking inside document bounds on empty space deselects
                document.selectedShapeIDs.removeAll()
                document.selectedTextIDs.removeAll()
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
}



extension DrawingCanvas {
    internal func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        // PASTEBOARD TAP SIMULATION: Convert zero-distance drags to taps for tools that need it
        // This fixes the issue where .onTapGesture doesn't work for pasteboard coordinates
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let tapThreshold: Double = 3.0 // Very small movement counts as a tap
        
        if dragDistance <= tapThreshold {
            // This was essentially a tap (zero or minimal drag distance)
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612)
            let isInPasteboardArea = !canvasBounds.contains(canvasLocation)
            
            if isInPasteboardArea {
                // PASTEBOARD TAP: Convert zero-distance drag to tap
                print("🎯 PASTEBOARD TAP SIMULATION: Zero-distance drag (\(String(format: "%.1f", dragDistance))px) converted to tap")
                print("🎯 PASTEBOARD CLICK at canvas: \(canvasLocation)")
                
                // Call the appropriate tap handler based on current tool
                switch document.currentTool {
                case .selection:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleSelectionTap(at: canvasLocation)
                case .directSelection:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleDirectSelectionTap(at: canvasLocation)
                case .convertAnchorPoint:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleConvertAnchorPointTap(at: canvasLocation)
                case .bezierPen:
                    // ✅ ISOLATION FIX: Pen tool works the same everywhere - canvas or pasteboard
                    // Never automatically finish paths - only add points for continuous tracing
                    handleBezierPenTap(at: canvasLocation)
                    // Note: Pen tool is isolated from existing objects and layers
                    // TEXT TOOL COMPLETELY REMOVED
                default:
                    break
                }
                
                // Early return - don't process as regular drag end
                return
            }
        }
        
        // Regular drag end processing for actual drags (not taps)
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
            // TEXT TOOL COMPLETELY REMOVED
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
}

extension DrawingCanvas {
    internal func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL FIX: DrawingCanvas drags are automatically constrained to view bounds
        // SwiftUI ensures drag gestures only fire within the DrawingCanvas area
        let canvasStart = screenToCanvas(value.startLocation, geometry: geometry)
        let _ = screenToCanvas(value.location, geometry: geometry)
        
        // DETAILED LOGGING: Determine if this started in canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let startedInCanvasArea = canvasBounds.contains(canvasStart)
        let _ = startedInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        // Calculate drag distance to understand if this should have been a tap
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        
        // PASTEBOARD OPTIMIZATION: Use 0-pixel threshold for pasteboard to maximize single-click sensitivity
        let _ = startedInCanvasArea ? 40.0 : 0.0
        
        //print("🎯 DRAG GESTURE CHANGED at start: \(canvasStart) current: \(canvasCurrent) in \(areaType)")
        //print("🎯 DRAG GESTURE: This is CLICK AND DRAG, not a single click")
        //print("🎯 Drag distance: \(String(format: "%.2f", dragDistance)) pixels (threshold: \(effectiveThreshold))")
        
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
            // TEXT TOOL COMPLETELY REMOVED
        case .selection:
            if !isDrawing {
                // Check if we're starting a drag on a selected object
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                
                // If nothing is selected, or if we're dragging on an unselected object, try to select it first
                if (document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty) || !isDraggingSelectedObject(at: startLocation) {
                    selectObjectAt(startLocation)
                }
                
                // Only start drag if we have something selected (shapes or text)
                if !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty {
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
}

extension DrawingCanvas {
    internal func handleTap(at location: CGPoint, geometry: GeometryProxy) {
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
        case .font:
            handleFontToolTap(at: canvasLocation)
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
    /// Updates the active bezier shape with a specific path (used for live previews)
    internal func updateActiveBezierShapeWithPath(_ path: VectorPath) {
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
}

extension DrawingCanvas {
    /// Updates the live path with a closing preview
    internal func updateLivePathWithClosingPreview(mouseLocation: CGPoint) {
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
}

extension DrawingCanvas {
    /// Updates the live path with a rubber band preview to the mouse location
    internal func updateLivePathWithRubberBand(mouseLocation: CGPoint) {
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
}

extension DrawingCanvas {
    internal func handleHover(phase: HoverPhase, geometry: GeometryProxy) {
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
