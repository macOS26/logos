//
//  DrawingCanvas.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

// MARK: - Hashable CGPoint Wrapper for macOS < 15.0 Compatibility
struct HashableCGPoint: Hashable, Equatable {
    let point: CGPoint
    
    init(_ point: CGPoint) {
        self.point = point
    }
    
    static func == (lhs: HashableCGPoint, rhs: HashableCGPoint) -> Bool {
        return lhs.point.x == rhs.point.x && lhs.point.y == rhs.point.y
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(point.x)
        hasher.combine(point.y)
    }
}

// MARK: - Shared Data Structures (Consolidated from extensions)

// Brush Point Data Structure (used in BrushTool extension)
struct BrushPoint {
    let location: CGPoint
    let pressure: Double // 0.0 to 1.0
    let timestamp: Date
    
    init(location: CGPoint, pressure: Double = 1.0, timestamp: Date = Date()) {
        self.location = location
        self.pressure = max(0.0, min(1.0, pressure)) // Clamp between 0 and 1
        self.timestamp = timestamp
    }
}

// Marker Point Data Structure (used in MarkerTool extension)
struct MarkerPoint {
    let location: CGPoint
    let pressure: Double // 0.0 to 1.0
    let timestamp: Date
    
    init(location: CGPoint, pressure: Double = 1.0, timestamp: Date = Date()) {
        self.location = location
        self.pressure = max(0.0, min(1.0, pressure)) // Clamp between 0 and 1
        self.timestamp = timestamp
    }
}

struct DrawingCanvas: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) internal var appState
    @State internal var currentPath: VectorPath?
    @State internal var tempBoundingBoxPath: VectorPath? // DEBUG: Temporary bounding box for triangle drift verification
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
    @State internal var initialObjectTransforms: [UUID: CGAffineTransform] = [:]  // Initial object transforms when drag started
    @State internal var currentDragDelta: CGPoint = .zero  // Current drag offset for 60fps preview rendering
    @State internal var dragPreviewUpdateTrigger: Bool = false  // Trigger for preview rendering only
    
    // PROFESSIONAL SHAPE DRAWING STATE (Same precision as hand tool)
    @State internal var shapeDragStart = CGPoint.zero         // Reference cursor position when shape drawing started
    @State internal var shapeStartPoint = CGPoint.zero       // Reference canvas position when shape drawing started
    
    // PROFESSIONAL MULTI-SELECTION (Adobe Illustrator Standards)
    @State internal var isShiftPressed = false
    @State internal var isCommandPressed = false
    @State internal var isOptionPressed = false
    @State internal var isControlPressed = false
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
    
    // FREEHAND DRAWING STATE (Professional curve fitting)
    @State internal var freehandPath: VectorPath?
    @State internal var freehandRawPoints: [CGPoint] = [] // Raw mouse tracking points
    @State internal var freehandSimplifiedPoints: [VectorPoint] = [] // Douglas-Peucker simplified points
    @State internal var freehandRealtimeSmoothingPoints: [CGPoint] = [] // For real-time smoothing
    @State internal var isFreehandDrawing = false
    @State internal var activeFreehandShape: VectorShape? = nil // Real-time freehand shape preview

    // BRUSH DRAWING STATE (Variable width brush strokes)
    @State internal var brushPath: VectorPath?
    @State internal var brushRawPoints: [BrushPoint] = [] // Raw mouse tracking points with pressure
    @State internal var brushSimplifiedPoints: [CGPoint] = [] // Douglas-Peucker simplified points  
    @State internal var isBrushDrawing = false
    @State internal var activeBrushShape: VectorShape? = nil // Real-time brush shape preview

    // MARKER DRAWING STATE (Felt-tip marker with circular strokes)
    @State internal var markerPath: VectorPath?
    @State internal var markerRawPoints: [MarkerPoint] = [] // Raw mouse tracking points with pressure
    @State internal var markerSimplifiedPoints: [CGPoint] = [] // Douglas-Peucker simplified points  
    @State internal var isMarkerDrawing = false
    @State internal var activeMarkerShape: VectorShape? = nil // Real-time marker shape preview

    // Note: freehandSmoothingTolerance now comes from document.settings.freehandSmoothingTolerance
    
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
    @State internal var isCornerRadiusEditMode = false // Control-Click to enter corner radius editing mode
    @State internal var isDraggingPoint = false
    @State internal var isDraggingHandle = false
    @State internal var dragStartLocation: CGPoint = .zero
    @State internal var originalPointPositions: [PointID: VectorPoint] = [:]
    @State internal var originalHandlePositions: [HandleID: VectorPoint] = [:]
    
    // Corner radius drag state (professional cursor tracking)
    @State internal var cornerDragStart: CGPoint = .zero
    @State internal var initialCornerRadius: Double = 0.0
    @State internal var isDraggingCorner = false
    @State internal var draggedCornerIndex: Int = -1
    @State internal var currentMousePosition: CGPoint = .zero
    
    // PROFESSIONAL COINCIDENT POINT MANAGEMENT
    // This handles the case where multiple points exist at the same X,Y coordinates
    // Essential for maintaining continuity in closed paths (circles, etc.)
    @State internal var coincidentPointClusters: [HashableCGPoint: [PointID]] = [:]
    @State internal var coincidentPointRadius: CGFloat = 2.0 // Points within this radius are considered coincident
    @State internal var coincidentPointTolerance: Double = 1.0 // Points within 1 pixel are considered coincident
    
    // ENHANCED TEXT EDITING STATE (Professional Core Graphics Text Editing)
    @State internal var isEditingText = false
    @State internal var editingTextID: UUID? = nil
    @State internal var currentCursorPosition: Int = 0
    @State internal var currentSelectionRange: NSRange = NSRange(location: 0, length: 0)
    @State internal var lastTapLocation: CGPoint = .zero
    
    // Point and handle identification moved to PointAndHandleID.swift
    
    // MARK: - Shared Utility Variables (Consolidated from extensions)
    // These variables are used across multiple DrawingCanvas extensions to avoid duplication
    
    // Shared hit testing variables
    @State internal var isHit = false
    @State internal var foundPointOrHandle = false
    
    // Shared path manipulation variables
    @State internal var sharedElements: [PathElement] = []
    @State internal var sharedNewElements: [PathElement] = []
    @State internal var sharedValidElements: [PathElement] = []
    
    // Shared Douglas-Peucker algorithm variables (used in Brush, Marker, Freehand tools)
    @State internal var sharedMaxDistance: Double = 0
    @State internal var sharedMaxIndex: Int = 0
    
    // Shared pressure/closest point variables (used in Brush and Marker tools)
    @State internal var sharedClosestDistance: Double = Double.infinity
    @State internal var sharedClosestPressure: Double = 1.0
    
    // Shared thickness calculation variables (used in Brush and Marker tools)
    @State internal var sharedThicknessPoints: [(location: CGPoint, thickness: Double)] = []
    
    // Shared handle analysis variables (used in multiple extensions)
    @State internal var sharedOutgoingHandleCollapsed: Bool = true
    
    // Shared shape update variables
    @State internal var sharedUpdatedShape: VectorShape?
    @State internal var sharedOriginalShape: VectorShape?
    
    // Shared curve position variables
    @State internal var sharedCurvePositions: [CGPoint] = []
    
    // Shared radius variables (used in corner radius editing)
    @State internal var sharedAllRadii: [Double] = []
    @State internal var sharedUpdatedRadii: [Double] = []
    
    var body: some View {
        GeometryReader { geometry in
            canvasMainContent(geometry: geometry)
        }
    }
}
