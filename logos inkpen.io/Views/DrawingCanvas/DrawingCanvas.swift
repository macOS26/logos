//
//  DrawingCanvas.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreImage

#if os(macOS)
// Build a cursor by drawing a solid black symbol with a uniform white shadow (halo)
private func makeSolidShadowCursor(symbolName: String, pointSize: CGFloat, originalHotspot: CGPoint, shadowBlur: CGFloat = 2.0) -> NSCursor {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return .crosshair }
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    let blackSymbol = base.withSymbolConfiguration(config) ?? base

    let padding: CGFloat = 4
    let symbolSize = blackSymbol.size
    let destRect = NSRect(x: padding, y: padding, width: symbolSize.width, height: symbolSize.height)
    let newSize = NSSize(width: symbolSize.width + padding * 2, height: symbolSize.height + padding * 2)

    let composed = NSImage(size: newSize)
    composed.lockFocus()
    // Shadow pass to create even halo
    NSGraphicsContext.current?.saveGraphicsState()
    let halo = NSShadow()
    halo.shadowBlurRadius = shadowBlur
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    blackSymbol.draw(in: destRect)
    NSGraphicsContext.current?.restoreGraphicsState()
    // Crisp solid symbol on top
    blackSymbol.draw(in: destRect)
    composed.unlockFocus()

    let hotspot = CGPoint(x: padding + originalHotspot.x, y: padding + originalHotspot.y)
    return NSCursor(image: composed, hotSpot: hotspot)
}

// Build the HAND cursor: solid white interior, crisp black outline, white shadow halo (4pt)
private func makeSolidHandCursor(pointSize: CGFloat, originalHotspot: CGPoint, shadowBlur: CGFloat = 4.0) -> NSCursor {
    guard let outlineBase = NSImage(systemSymbolName: "hand.raised", accessibilityDescription: nil),
          let fillBase = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)
    else { return .crosshair }

    let outlineConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    let outlineImage = outlineBase.withSymbolConfiguration(outlineConfig) ?? outlineBase

    let fillConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    let whitePalette = NSImage.SymbolConfiguration(paletteColors: [NSColor.white])
    let fillImage = (fillBase.withSymbolConfiguration(fillConfig.applying(whitePalette)) ?? fillBase)

    let padding: CGFloat = 4
    let symbolSize = outlineImage.size
    let destRect = NSRect(x: padding, y: padding, width: symbolSize.width, height: symbolSize.height)
    let newSize = NSSize(width: symbolSize.width + padding * 2, height: symbolSize.height + padding * 2)

    let composed = NSImage(size: newSize)
    composed.lockFocus()

    // 1) Shadow pass for even white halo around the hand outline
    NSGraphicsContext.current?.saveGraphicsState()
    let halo = NSShadow()
    halo.shadowBlurRadius = shadowBlur
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    outlineImage.draw(in: destRect)
    NSGraphicsContext.current?.restoreGraphicsState()

    // 2) Solid white fill using the filled hand symbol, slightly inset to avoid peeking past outline
    // Render white fill to offscreen, then erode (shrink) by 1px for a clean inset
    let fillMaskImage = NSImage(size: symbolSize)
    fillMaskImage.lockFocus()
    NSColor.clear.set()
    NSBezierPath(rect: NSRect(origin: .zero, size: symbolSize)).fill()
    fillImage.draw(in: NSRect(origin: .zero, size: symbolSize))
    fillMaskImage.unlockFocus()

    if let fillCG = fillMaskImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let ciFill = CIImage(cgImage: fillCG)
        if let minFilter = CIFilter(name: "CIMorphologyMinimum") {
            minFilter.setValue(ciFill, forKey: kCIInputImageKey)
            minFilter.setValue(1.0, forKey: kCIInputRadiusKey)
            let ciContext = CIContext(options: nil)
            if let output = minFilter.outputImage,
               let shrunkCG = ciContext.createCGImage(output, from: output.extent) {
                NSImage(cgImage: shrunkCG, size: symbolSize).draw(in: destRect)
            } else {
                // Fallback: draw unmodified fill
                fillImage.draw(in: destRect)
            }
        } else {
            fillImage.draw(in: destRect)
        }
    } else {
        fillImage.draw(in: destRect)
    }

    // 3) Crisp black outline on top
    outlineImage.draw(in: destRect)

    composed.unlockFocus()

    let hotspot = CGPoint(x: padding + originalHotspot.x, y: padding + originalHotspot.y)
    return NSCursor(image: composed, hotSpot: hotspot)
}

// Build a cursor: black foreground glyph, solid white fill behind it, and a 1pt white halo
private func makeHaloCursor(symbolName: String, pointSize: CGFloat, originalHotspot: CGPoint, fillSymbolName: String? = nil) -> NSCursor {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return .crosshair }
    let fillBase: NSImage? = {
        if let name = fillSymbolName { return NSImage(systemSymbolName: name, accessibilityDescription: nil) }
        return nil
    }()
    // Prepare white and black variants of the symbol for layered rendering
    let baseConfig = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
    let whiteConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.white])
    let blackConfig = NSImage.SymbolConfiguration(paletteColors: [NSColor.black])
    let whiteSymbol = ((fillBase ?? base).withSymbolConfiguration(baseConfig.applying(whiteConfig)) ?? (fillBase ?? base))
    let blackSymbol = (base.withSymbolConfiguration(baseConfig.applying(blackConfig)) ?? base)

    let padding: CGFloat = 4
    let symbolSize = blackSymbol.size
    let destRect = NSRect(x: padding, y: padding, width: symbolSize.width, height: symbolSize.height)
    let newSize = NSSize(width: symbolSize.width + padding * 2, height: symbolSize.height + padding * 2)

    let composed = NSImage(size: newSize)
    composed.lockFocus()
    // Create uniform 1px halo using morphological dilation on the white glyph
    // 1) Render white symbol to an offscreen image (transparent background)
    let whiteMaskImage = NSImage(size: symbolSize)
    whiteMaskImage.lockFocus()
    NSColor.clear.set()
    NSBezierPath(rect: NSRect(origin: .zero, size: symbolSize)).fill()
    whiteSymbol.draw(in: NSRect(origin: .zero, size: symbolSize))
    whiteMaskImage.unlockFocus()

    // 2) Convert to CIImage and dilate
    var dilatedCG: CGImage? = nil
    if let whiteCG = whiteMaskImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let ciImg = CIImage(cgImage: whiteCG)
        if let filter = CIFilter(name: "CIMorphologyMaximum") {
            filter.setValue(ciImg, forKey: kCIInputImageKey)
            filter.setValue(1.0, forKey: kCIInputRadiusKey)
            let context = CIContext(options: nil)
            if let output = filter.outputImage,
               let cgOut = context.createCGImage(output, from: output.extent) {
                dilatedCG = cgOut
            }
        }
    }

    // 3) Draw dilated white (uniform halo) then solid white fill for the center
    if let dilatedCG {
        NSImage(cgImage: dilatedCG, size: symbolSize).draw(in: destRect)
    }
    whiteSymbol.draw(in: destRect)

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
    return makeHaloCursor(symbolName: "eyedropper", pointSize: 18, originalHotspot: originalHotspot, fillSymbolName: "eyedropper")
}()

// Shared magnifying glass cursor for zoom tool (with halo)
let MagnifyingGlassCursor: NSCursor = {
    // Hotspot near lens center in original symbol space
    guard let base = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil) else { return .crosshair }
    let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    let symbol = base.withSymbolConfiguration(config) ?? base
    let center = CGPoint(x: symbol.size.width * 0.35, y: symbol.size.height * 0.35)
    return makeHaloCursor(symbolName: "magnifyingglass", pointSize: 18, originalHotspot: center, fillSymbolName: "magnifyingglass")
}()

// Shared hand cursors for pan tool (with halo)
let HandOpenCursor: NSCursor = {
    // Solid white interior, black outline, 4pt white halo
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeSolidHandCursor(pointSize: 18, originalHotspot: originalHotspot, shadowBlur: 4.0)
}()

let HandClosedCursor: NSCursor = {
    // Same visual as open (solid white, black outline, 4pt halo) per request
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeSolidHandCursor(pointSize: 18, originalHotspot: originalHotspot, shadowBlur: 4.0)
}()
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
    @State internal var isCanvasHovering: Bool = false // Track whether the mouse is over the drawing canvas
    
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
    
    // TEMPORARY HAND TOOL STATE (Spacebar activation)
    @State internal var isTemporaryHandToolActive = false
    @State internal var temporaryToolPreviousTool: DrawingTool? = nil
    
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
