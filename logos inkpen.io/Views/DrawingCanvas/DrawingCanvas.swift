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




