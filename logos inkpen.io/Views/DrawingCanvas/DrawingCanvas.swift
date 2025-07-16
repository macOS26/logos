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
    
    internal func deleteSelectedPoints() {
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
    internal func closeBezierPath() {
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
                    // FINAL FILL: Make fully opaque when path is closed
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: document.defaultFillColor,
                        opacity: document.defaultFillOpacity // Full opacity (usually 1.0)
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
        
        // TRACING WORKFLOW IMPROVEMENT: Don't auto-switch tools to allow continuous pen tool usage
        // This allows users to trace multiple objects without tool interruption
        let _ = activeShape.id // Unused variable
        
        // Clear bezier state BUT KEEP pen tool active for continuous tracing
        cancelBezierDrawing()
        
        // Hide any close path hints
        showClosePathHint = false
        
        // NOTE: Removed automatic tool switch to direct selection
        // Users can manually switch tools when they're ready to edit points
        // This enables uninterrupted tracing workflows
        
        print("✅ CLOSED PATH: Pen tool remains active for continuous tracing")
    }
    
    internal func handleConvertAnchorPointTap(at location: CGPoint) {
        let tolerance: Double = 8.0 // Hit test tolerance
        
        // TEXT EDITING REMOVED
        
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
    internal func tryToSelectShapeForConvertTool(at location: CGPoint) {
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
    internal func enableDirectSelectionForConvertedPoint(shapeID: UUID, elementIndex: Int) {
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
    
    internal func convertLineToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
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
    
    internal func convertSmoothToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
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
    
    internal func convertCornerToSmooth(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
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
    
    
    
    internal func convertQuadToCorner(layerIndex: Int, shapeIndex: Int, elementIndex: Int) {
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
    
    // MARK: - COORDINATE SYSTEM DEBUGGING AND TESTING
    // Use Cmd+Shift+T to analyze coordinate system consistency
    
    /// COMPREHENSIVE DRAWING TEST - Run this to debug coordinate system issues
    /// Use Cmd+Shift+R to run this test
    internal func runRealDrawingTest(geometry: GeometryProxy) {
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
    
    // MARK: - PROFESSIONAL COINCIDENT POINT HANDLING
    // Coincident point functions moved to CoincidentPointHandling.swift
    
    // MARK: - Font Tool Handler (Core Graphics Based)
    // Text handling functions moved to TextHandling.swift
    
}














extension DrawingCanvas {
    internal func startSelectionDrag() {
        guard let layerIndex = document.selectedLayerIndex,
              (!document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty) else { return }
        
        // PROTECT LOCKED LAYERS: Don't allow moving objects on locked layers
        if document.layers[layerIndex].isLocked {
            print("🚫 Cannot move objects on locked layer '\(document.layers[layerIndex].name)'")
            return
        }
        
        // PROFESSIONAL OBJECT DRAGGING: Save initial positions (not transforms)
        // This matches the precision approach used by the hand tool
        initialObjectPositions.removeAll()
        
        // Store initial positions for shapes
        for shapeID in document.selectedShapeIDs {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let shape = document.layers[layerIndex].shapes[shapeIndex]
                // Store the actual center position of the shape
                let centerX = shape.bounds.midX
                let centerY = shape.bounds.midY
                initialObjectPositions[shapeID] = CGPoint(x: centerX, y: centerY)
            }
        }
        
        // Store initial positions for text objects
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }) {
                let textObj = document.textObjects[textIndex]
                // Store the text baseline position
                initialObjectPositions[textID] = textObj.position
            }
        }
        
        print("🎯 SELECTION DRAG: Established reference positions for \(document.selectedShapeIDs.count) shapes and \(document.selectedTextIDs.count) text objects")
    }
    
    internal func handleSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        guard let layerIndex = document.selectedLayerIndex,
              (!document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty) else { return }
        
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
        
        // Move selected text objects by directly updating their position
        for textID in document.selectedTextIDs {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == textID }),
               let initialPosition = initialObjectPositions[textID] {
                
                // Calculate new position based on initial position + cursor delta
                let newPosition = CGPoint(
                    x: initialPosition.x + canvasDelta.x,
                    y: initialPosition.y + canvasDelta.y
                )
                
                // Update text position directly
                document.textObjects[textIndex].position = newPosition
                
                // Update text bounds if needed
                document.textObjects[textIndex].updateBounds()
            }
        }
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    internal func finishSelectionDrag() {
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
}

extension DrawingCanvas {
    internal func handleShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
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
    
    internal func finishShapeDrawing(value: DragGesture.Value, geometry: GeometryProxy) {
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
}

extension DrawingCanvas {
    internal func cancelBezierDrawing() {
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
    }
    
    internal func handleBezierPenTap(at location: CGPoint) {
        // 🔒 COMPLETE ISOLATION: Pen tool is TOTALLY isolated from existing objects
        // ✅ NO hit-testing against existing shapes, locked objects, or other layers
        // ✅ NO interference from pasteboard vs canvas area differences
        // ✅ NO automatic finishing except explicit user actions (green close hints)
        // ✅ ONLY interacts with the current path being drawn
        
        // Check if we're trying to close the CURRENT path by clicking near its first point
        // CRITICAL: Only allow closing if the green close hint is showing (explicit user intent)
        if isBezierDrawing && bezierPoints.count >= 3 && showClosePathHint {
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            if distance(location, firstPointLocation) <= 25.0 { // Close tolerance (Adobe Illustrator standard)
                closeBezierPath()
                return
            }
        }
        
        if !isBezierDrawing {
            // CREATE FIRST POINT IMMEDIATELY: Handle both canvas and pasteboard areas consistently
            // This allows click-and-drag for smooth points or simple clicks for corner points
            
            // Create the bezier path and add the first point as a corner point
            bezierPath = VectorPath(elements: [.move(to: VectorPoint(location))])
            bezierPoints = [VectorPoint(location)]
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
                color: document.defaultFillColor,
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
            
            print("🎯 CREATED FIRST POINT: Started new path at \(location)")
            print("🎨 PEN TOOL INITIAL COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
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
    
    internal func handleBezierPenDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        // Calculate actual drag distance to distinguish click vs drag
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let minimumDragThreshold: Double = 8.0 // Must drag at least 8 pixels to create handles
        
        // First point creation is now handled in handleBezierPenTap()
        // This drag handler only deals with subsequent points and handle manipulation
        if !isBezierDrawing {
            print("⚠️ Warning: Drag detected but no bezier path active - first point should be created in tap handler")
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
    internal func updateActiveBezierShapeInDocument() {
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
                
                // REAL-TIME FILL WITH OPACITY: Show entire fill while drawing! (BETTER THAN ADOBE!)
                document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                    color: document.defaultFillColor,
                    opacity: 0.4 // Semi-transparent fill during drawing
                )
                
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                break
            }
        }
        
        // Force UI update for real-time visual feedback
        document.objectWillChange.send()
    }
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
    // MARK: - Professional Multi-Selection Key Monitoring (Adobe Illustrator Standards)
    internal func setupKeyEventMonitoring() {
        // Monitor for key down/up and modifier flag changes
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.updateModifierKeyStates(with: event)
            }
            return event
        }
    }
    
    internal func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    // PROFESSIONAL TOOL KEYBOARD SHORTCUTS (Adobe Illustrator Standards)
    internal func setupToolKeyboardShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // TEXT EDITING REMOVED - All shortcuts now active
            
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
    
    internal func updateModifierKeyStates(with event: NSEvent) {
        let modifierFlags = event.modifierFlags
        isShiftPressed = modifierFlags.contains(.shift)
        isCommandPressed = modifierFlags.contains(.command)
        isOptionPressed = modifierFlags.contains(.option)
        
        // FONT TOOL TEXT EDITING
        if event.type == .keyDown && isEditingText, let editingID = editingTextID {
            if let textIndex = document.textObjects.firstIndex(where: { $0.id == editingID }) {
                var updatedText = document.textObjects[textIndex]
                
                switch event.keyCode {
                case 51: // Delete key
                    if !updatedText.content.isEmpty {
                        updatedText.content.removeLast()
                        updatedText.updateBounds() // SURGICAL FIX: Update bounds for dynamic sizing
                        document.textObjects[textIndex] = updatedText
                        document.objectWillChange.send()
                    }
                case 36, 76: // Return/Enter key
                    // Finish editing
                    finishTextEditing()
                case 53: // Escape key
                    // Cancel editing
                    cancelTextEditing()
                default:
                    // Regular character input
                    if let characters = event.characters, !characters.isEmpty {
                        // Filter out control characters
                        let filteredChars = characters.filter { $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isSymbol || $0.isWhitespace }
                        if !filteredChars.isEmpty {
                            updatedText.content.append(String(filteredChars))
                            updatedText.updateBounds() // SURGICAL FIX: Update bounds for dynamic sizing
                            document.textObjects[textIndex] = updatedText
                            document.objectWillChange.send()
                        }
                    }
                }
            }
            return
        }
        
        // Handle Tab key for deselection (only if not editing text)
        if event.type == .keyDown && !isEditingText {
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
