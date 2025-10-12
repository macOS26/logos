import SwiftUI

private func makeHaloCursor(symbolName: String, pointSize: CGFloat, originalHotspot: CGPoint) -> NSCursor {
    guard let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return .crosshair }
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
    NSGraphicsContext.current?.saveGraphicsState()
    let halo = NSShadow()
    halo.shadowBlurRadius = 2
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    whiteSymbol.draw(in: destRect)
    NSGraphicsContext.current?.restoreGraphicsState()

    blackSymbol.draw(in: destRect)

    composed.unlockFocus()

    let hotspot = CGPoint(x: padding + originalHotspot.x, y: padding + originalHotspot.y)
    return NSCursor(image: composed, hotSpot: hotspot)
}

let EyedropperCursor: NSCursor = {
    let originalHotspot = CGPoint(x: 4, y: 16)
    return makeHaloCursor(symbolName: "eyedropper", pointSize: 18, originalHotspot: originalHotspot)
}()

let MagnifyingGlassCursor: NSCursor = {
    guard let base = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil) else { return .crosshair }
    let config = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
    let symbol = base.withSymbolConfiguration(config) ?? base
    let center = CGPoint(x: symbol.size.width * 0.35, y: symbol.size.height * 0.35)
    return makeHaloCursor(symbolName: "magnifyingglass", pointSize: 18, originalHotspot: center)
}()

let HandOpenCursor: NSCursor = {
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeHaloCursor(symbolName: "hand.raised", pointSize: 18, originalHotspot: originalHotspot)
}()

let HandClosedCursor: NSCursor = {
    let originalHotspot = CGPoint(x: 9, y: 9)
    return makeHaloCursor(symbolName: "hand.raised", pointSize: 18, originalHotspot: originalHotspot)
}()

private func makeCrosshairCursor(size: CGFloat = 20, hotspotAdjustX: CGFloat = 0, hotspotAdjustY: CGFloat = -1) -> NSCursor {
    let imgSize = NSSize(width: size, height: size)
    let centerX = floor(imgSize.width / 2) + 0.5
    let centerY = floor(imgSize.height / 2) + 0.5
    let image = NSImage(size: imgSize)
    image.lockFocus()
    NSGraphicsContext.current?.saveGraphicsState()
    let halo = NSShadow()
    halo.shadowBlurRadius = 2
    halo.shadowColor = NSColor.white
    halo.shadowOffset = .zero
    halo.set()
    NSColor.black.setStroke()
    let pathShadow = NSBezierPath()
    pathShadow.lineWidth = 1
    pathShadow.move(to: CGPoint(x: 0, y: centerY))
    pathShadow.line(to: CGPoint(x: imgSize.width, y: centerY))
    pathShadow.move(to: CGPoint(x: centerX, y: 0))
    pathShadow.line(to: CGPoint(x: centerX, y: imgSize.height))
    pathShadow.stroke()
    NSGraphicsContext.current?.restoreGraphicsState()
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


struct BrushPoint {
    let location: CGPoint
    let pressure: Double

    init(location: CGPoint, pressure: Double = 1.0) {
        self.location = location
        self.pressure = max(0.0, min(1.0, pressure))
    }
}

struct DrawingCanvas: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) internal var appState
    @State internal var currentPath: VectorPath?
    @State internal var tempBoundingBoxPath: VectorPath?
    @State internal var isDrawing = false
    @State internal var dragOffset = CGSize.zero
    @State internal var lastPanLocation = CGPoint.zero
    @State internal var drawingStartPoint: CGPoint?
    @State internal var currentDrawingPoints: [CGPoint] = []

    @State internal var lastTapTime: Date = Date()

    @State internal var initialCanvasOffset = CGPoint.zero
    @State internal var handToolDragStart = CGPoint.zero

    @State internal var selectionDragStart = CGPoint.zero
    @State internal var initialObjectPositions: [UUID: CGPoint] = [:]
    @State internal var initialObjectTransforms: [UUID: CGAffineTransform] = [:]
    @State internal var currentDragDelta: CGPoint = .zero
    @State internal var dragPreviewUpdateTrigger: Bool = false
    @State internal var dragUpdateCounter: Int = 0

    @State internal var shapeDragStart = CGPoint.zero
    @State internal var shapeStartPoint = CGPoint.zero

    @State internal var isShiftPressed = false
    @State internal var isCommandPressed = false
    @State internal var isOptionPressed = false
    @State internal var isControlPressed = false

    @State internal var isDraggingDirectSelectedShapes = false
    @State internal var keyEventMonitor: Any?

    @State internal var bezierPath: VectorPath?
    @State internal var bezierPoints: [VectorPoint] = []
    @State internal var isBezierDrawing = false
    @State internal var isDraggingBezierHandle = false
    @State internal var activeBezierPointIndex: Int? = nil
    @State internal var isDraggingBezierPoint = false
    @State internal var bezierHandles: [Int: BezierHandleInfo] = [:]
    @State internal var currentMouseLocation: CGPoint? = nil
    @State internal var showClosePathHint = false
    @State internal var closePathHintLocation: CGPoint = .zero

    @State internal var showContinuePathHint = false
    @State internal var continuePathHintLocation: CGPoint = .zero
    @State internal var isCanvasHovering: Bool = false

    @State internal var currentSnapPoint: CGPoint? = nil
    @State internal var currentShapeId: UUID? = nil

    @State internal var activeBezierShape: VectorShape? = nil

    @State internal var freehandPath: VectorPath?
    @State internal var freehandRawPoints: [CGPoint] = []
    @State internal var freehandSimplifiedPoints: [VectorPoint] = []
    @State internal var freehandRealtimeSmoothingPoints: [CGPoint] = []
    @State internal var isFreehandDrawing = false
    @State internal var activeFreehandShape: VectorShape? = nil
    @State internal var freehandPreviewPath: VectorPath? = nil

    @State internal var brushPath: VectorPath?
    @State internal var brushRawPoints: [BrushPoint] = []
    @State internal var brushSimplifiedPoints: [CGPoint] = []
    @State internal var isBrushDrawing = false
    @State internal var activeBrushShape: VectorShape? = nil
    @State internal var brushPreviewPath: VectorPath? = nil

    @State internal var markerPath: VectorPath?
    @State internal var markerRawPoints: [MarkerPoint] = []
    @State internal var markerSimplifiedPoints: [CGPoint] = []
    @State internal var isMarkerDrawing = false
    @State internal var activeMarkerShape: VectorShape? = nil
    @State internal var markerPreviewPath: VectorPath? = nil


    @State internal var previousTool: DrawingTool = .selection

    @State internal var isTemporaryHandToolActive = false
    @State internal var temporaryToolPreviousTool: DrawingTool? = nil

    @State internal var isTemporaryDirectSelectionViaCommand = false
    @State internal var isTemporarySelectionViaCommand = false
    @State internal var temporaryCommandPreviousTool: DrawingTool? = nil

    @State internal var initialZoomLevel: CGFloat = 1.0

    @State internal var isZoomGestureActive = false
    @State internal var isPanGestureActive = false

    @State internal var lastClickTime: Date = Date.distantPast
    @State internal var lastClickLocation: CGPoint = .zero
    @State internal var doubleClickTimeout: TimeInterval = 0.3

    @State internal var isTextEditingMode = false

    @State internal var zoomToolDragStartPoint: CGPoint = .zero
    @State internal var zoomToolInitialZoomLevel: CGFloat = 1.0

    @State internal var selectedPoints: Set<PointID> = []
    @State internal var selectedHandles: Set<HandleID> = []
    @State internal var visibleHandles: Set<HandleID> = []
    @State internal var directSelectedShapeIDs: Set<UUID> = []
    @State internal var isCornerRadiusEditMode = false
    @State internal var isDraggingPoint = false
    @State internal var isDraggingHandle = false
    @State internal var dragStartLocation: CGPoint = .zero

    internal func syncDirectSelectionWithDocument() {
        document.directSelectedShapeIDs = directSelectedShapeIDs

        if !directSelectedShapeIDs.isEmpty {
            document.selectedObjectIDs = Set(directSelectedShapeIDs)
            document.selectedShapeIDs = directSelectedShapeIDs
            document.syncSelectionArrays()
        } else if document.currentTool == .directSelection ||
                  document.currentTool == .convertAnchorPoint ||
                  document.currentTool == .penPlusMinus {
            document.selectedObjectIDs.removeAll()
            document.selectedShapeIDs.removeAll()
            document.syncSelectionArrays()
        }
    }
    @State internal var originalPointPositions: [PointID: VectorPoint] = [:]
    @State internal var originalHandlePositions: [HandleID: VectorPoint] = [:]

    @State internal var cornerDragStart: CGPoint = .zero
    @State internal var initialCornerRadius: Double = 0.0
    @State internal var isDraggingCorner = false
    @State internal var draggedCornerIndex: Int? = nil
    @State internal var currentMousePosition: CGPoint = .zero

    @State internal var coincidentPointClusters: [HashableCGPoint: [PointID]] = [:]
    @State internal var coincidentPointRadius: CGFloat = 2.0
    @State internal var coincidentPointTolerance: Double = 1.0

	@State internal var isHUDDragging = false
	@State internal var hudDragStartOffsetX: CGFloat = 0
	@State internal var hudDragStartOffsetY: CGFloat = 0

    @State internal var isEditingText = false
    @State internal var editingTextID: UUID? = nil
    @State internal var currentCursorPosition: Int = 0
    @State internal var currentSelectionRange: NSRange = NSRange(location: 0, length: 0)
    @State internal var lastTapLocation: CGPoint = .zero


    @State internal var isHit = false
    @State internal var foundPointOrHandle = false

    @State internal var sharedElements: [PathElement] = []
    @State internal var sharedNewElements: [PathElement] = []
    @State internal var sharedValidElements: [PathElement] = []

    @State internal var sharedMaxDistance: Double = 0
    @State internal var sharedMaxIndex: Int = 0

    @State internal var sharedClosestDistance: Double = Double.infinity
    @State internal var sharedClosestPressure: Double = 1.0

    @State internal var sharedThicknessPoints: [(location: CGPoint, thickness: Double)] = []

    @State internal var sharedOutgoingHandleCollapsed: Bool = true

    @State internal var sharedUpdatedShape: VectorShape?
    @State internal var sharedOriginalShape: VectorShape?

    @State internal var sharedCurvePositions: [CGPoint] = []

    @State internal var sharedAllRadii: [Double] = []
    @State internal var sharedUpdatedRadii: [Double] = []

    var body: some View {
        GeometryReader { geometry in
            enhancedCanvasMainContent(geometry: geometry)
        }
    }
}
