//
//  DrawingCanvas.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

#if os(macOS)
// Build a haloed SF Symbol cursor with white glow for visibility on any background
private func makeHaloCursor(symbolName: String, pointSize: CGFloat, originalHotspot: CGPoint) -> NSCursor {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return .crosshair }
    // Prepare white and black variants of the symbol for layered rendering
    let baseConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)

    let whiteConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.white])
    let blackConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.black])
    let whiteSymbol = (base.withSymbolConfiguration(baseConfig.applying(whiteConfig)) ?? base)
    let blackSymbol = (base.withSymbolConfiguration(baseConfig.applying(blackConfig)) ?? base)

    let padding: CGFloat = 10
    let symbolSize = blackSymbol.size
    let destRect = NSRect(x: padding, y: padding, width: symbolSize.width, height: symbolSize.height)
    let newSize = NSSize(width: symbolSize.width + padding * 2, height: symbolSize.height + padding * 2)

    let composed = NSImage(size: newSize)
    composed.lockFocus()
    // First draw a solid white version of the cursor glyph (acts as interior white)
    NSGraphicsContext.current?.saveGraphicsState()
    // Optional subtle halo
    let halo = NSShadow()
    halo.shadowBlurRadius = 2
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    whiteSymbol.draw(in: destRect)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Then draw crisp black glyph on top
    blackSymbol.draw(in: destRect)

    composed.unlockFocus()

    let hotspot = CGPoint(x: padding + originalHotspot.x, y: padding + originalHotspot.y)
    return NSCursor(image: composed, hotSpot: hotspot)
}

// Shared eyedropper cursor for the whole canvas module (with halo)
let EyedropperCursor: NSCursor = {
    // Hotspot tuned to tip location in original symbol space
    let originalHotspot = CGPoint(x: 4, y: 16) // approx tip for 18pt symbol
    return makeHaloCursor(symbolName: "eyedropper", pointSize: 18, originalHotspot: originalHotspot)
}()

// Shared magnifying glass cursor for zoom tool (with halo)
let MagnifyingGlassCursor: NSCursor = {
    // Hotspot near lens center in original symbol space
    guard let base = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil) else { return .crosshair }
    let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    let symbol = base.withSymbolConfiguration(config) ?? base
    let center = CGPoint(x: symbol.size.width * 0.35, y: symbol.size.height * 0.35)
    return makeHaloCursor(symbolName: "magnifyingglass", pointSize: 18, originalHotspot: center)
}()

// Shared hand cursors for pan tool (with halo)
let HandOpenCursor: NSCursor = {
    // Approximate hotspot at palm center for 18pt symbol
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeHaloCursor(symbolName: "hand.raised", pointSize: 18, originalHotspot: originalHotspot)
}()

let HandClosedCursor: NSCursor = {
    // Use outline variant (non-solid) for closed/grab state
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeHaloCursor(symbolName: "hand.raised", pointSize: 18, originalHotspot: originalHotspot)
}()

// Crosshair cursor with slight hotspot adjustment to correct 1–2px left bias
private func makeCrosshairCursor(size: CGFloat = 20, hotspotAdjustX: CGFloat = 0, hotspotAdjustY: CGFloat = -1) -> NSCursor {
    let imgSize = NSSize(width: size, height: size)
    // Align 1pt strokes to pixel grid using 0.5 offsets
    let centerX = floor(imgSize.width / 2) + 0.5
    let centerY = floor(imgSize.height / 2) + 0.5
    let image = NSImage(size: imgSize)
    image.lockFocus()
    // White shadow halo for visibility
    NSGraphicsContext.current?.saveGraphicsState()
    let halo = NSShadow()
    halo.shadowBlurRadius = 2
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    NSColor.black.setStroke()
    let pathShadow = NSBezierPath()
    pathShadow.lineWidth = 1
    // Horizontal line
    pathShadow.move(to: CGPoint(x: 0, y: centerY))
    pathShadow.line(to: CGPoint(x: imgSize.width, y: centerY))
    // Vertical line
    pathShadow.move(to: CGPoint(x: centerX, y: 0))
    pathShadow.line(to: CGPoint(x: centerX, y: imgSize.height))
    pathShadow.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
    // Crisp black lines on top
    NSColor.black.setStroke()
    let path = NSBezierPath()
    path.lineWidth = 1
    path.move(to: CGPoint(x: 0, y: centerY))
    path.line(to: CGPoint(x: imgSize.width, y: centerY))
    path.move(to: CGPoint(x: centerX, y: 0))
    path.line(to: CGPoint(x: centerX, y: imgSize.height))
    path.stroke()
    image.unlockFocus()
    let hotspot = CGPoint(x: centerX + hotspotAdjustX, y: centerY + hotspotAdjustY)
    return NSCursor(image: image, hotSpot: hotspot)
}

let CrosshairCursor: NSCursor = makeCrosshairCursor()
#endif

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
            // Based on professional vector graphics software
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
    
            // PROFESSIONAL MULTI-SELECTION (Professional Standards)
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
    
    // MARK: - Continue Path Hint State
    @State internal var showContinuePathHint = false
    @State internal var continuePathHintLocation: CGPoint = .zero
    @State internal var isCanvasHovering: Bool = false // Track whether the mouse is over the drawing canvas
    
            // PROFESSIONAL REAL-TIME PATH CREATION (Professional Style)
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
    @State internal var brushPreviewPath: VectorPath? = nil // Preview path drawn by Metal overlay (not in document)

    // MARKER DRAWING STATE (Felt-tip marker with circular strokes)
    @State internal var markerPath: VectorPath?
    @State internal var markerRawPoints: [MarkerPoint] = [] // Raw mouse tracking points with pressure
    @State internal var markerSimplifiedPoints: [CGPoint] = [] // Douglas-Peucker simplified points  
    @State internal var isMarkerDrawing = false
    @State internal var activeMarkerShape: VectorShape? = nil // Real-time marker shape preview

    // Note: freehandSmoothingTolerance now comes from document.settings.freehandSmoothingTolerance
    
    // Track previous tool to detect changes
    @State internal var previousTool: DrawingTool = .selection
    
    // TEMPORARY HAND TOOL STATE (Spacebar activation)
    @State internal var isTemporaryHandToolActive = false
    @State internal var temporaryToolPreviousTool: DrawingTool? = nil
    
    // TEMPORARY COMMAND MODIFIER STATE (Arrow tool outline + temp direct selection)
    @State internal var isTemporaryDirectSelectionViaCommand = false
    @State internal var temporaryCommandPreviousTool: DrawingTool? = nil
    
    // Zoom gesture state
    @State internal var initialZoomLevel: CGFloat = 1.0
    
    // PROFESSIONAL GESTURE COORDINATION STATE
    @State internal var isZoomGestureActive = false
    @State internal var isPanGestureActive = false
    
    // ZOOM TOOL DRAG STATE (Scrubby zoom-style)
    @State internal var zoomToolDragStartPoint: CGPoint = .zero
    @State internal var zoomToolInitialZoomLevel: CGFloat = 1.0
    
    // Direct selection state
    @State internal var selectedPoints: Set<PointID> = []
    @State internal var selectedHandles: Set<HandleID> = []
    @State internal var directSelectedShapeIDs: Set<UUID> = [] // Track which shapes have been direct-selected
    @State internal var isCornerRadiusEditMode = false // Control-Click to enter corner radius editing mode
    @State internal var isDraggingPoint = false
    @State internal var isDraggingHandle = false
    @State internal var dragStartLocation: CGPoint = .zero
    
    // Sync direct selection state with document
    internal func syncDirectSelectionWithDocument() {
        document.directSelectedShapeIDs = directSelectedShapeIDs
    }
    @State internal var originalPointPositions: [PointID: VectorPoint] = [:]
    @State internal var originalHandlePositions: [HandleID: VectorPoint] = [:]
    
    // Corner radius drag state (professional cursor tracking)
    @State internal var cornerDragStart: CGPoint = .zero
    @State internal var initialCornerRadius: Double = 0.0
    @State internal var isDraggingCorner = false
    @State internal var draggedCornerIndex: Int? = nil
    @State internal var currentMousePosition: CGPoint = .zero
    
    // PROFESSIONAL COINCIDENT POINT MANAGEMENT
    // This handles the case where multiple points exist at the same X,Y coordinates
    // Essential for maintaining continuity in closed paths (circles, etc.)
    @State internal var coincidentPointClusters: [HashableCGPoint: [PointID]] = [:]
    @State internal var coincidentPointRadius: CGFloat = 2.0 // Points within this radius are considered coincident
    @State internal var coincidentPointTolerance: Double = 1.0 // Points within 1 pixel are considered coincident

	// In-App Performance HUD drag state
	@State internal var isHUDDragging = false
	@State internal var hudDragStartOffsetX: CGFloat = 0
	@State internal var hudDragStartOffsetY: CGFloat = 0
    
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
            //canvasMainContent(geometry: geometry)
            enhancedCanvasMainContent(geometry: geometry)
        }
    }
}
