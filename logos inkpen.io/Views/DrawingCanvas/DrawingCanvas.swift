//
//  DrawingCanvas.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 10/22/25.
//

import SwiftUI

struct DrawingCanvas: View {
    var viewState: DocumentViewState = DocumentViewState()
    var document: VectorDocument = VectorDocument()
    @Binding var zoomLevel: Double
    @Binding var canvasOffset: CGPoint
    @Binding var layerPreviewOpacities: [UUID: Double]
    @Binding var liveDragOffset: CGPoint
    @Binding var liveScaleDimensions: CGSize
    @Binding var liveScaleTransform: CGAffineTransform
    @Binding var livePointPositions: [PointID: CGPoint]
    @Binding var liveHandlePositions: [HandleID: CGPoint]
    @Binding var fillDeltaOpacity: Double?
    @Binding var strokeDeltaOpacity: Double?
    @Binding var strokeDeltaWidth: Double?
    @Binding var activeGradientDelta: VectorGradient?
    @Binding var fontSizeDelta: Double?
    @Binding var lineSpacingDelta: Double?
    @Binding var lineHeightDelta: Double?
    @Binding var letterSpacingDelta: Double?
    @Binding var imagePreviewQuality: Double
    @Binding var imageTileSize: Int
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

    // PROTOTYPE: Test anchor point types
    @State internal var testAnchorTypes: [PointID: AnchorPointType] = [:]

    // Spatial index for O(1) hit testing
    @State internal var spatialIndex = SpatialIndex()
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

    @State internal var dragStartGradient: VectorGradient? = nil
    @State internal var doubleClickTimeout: TimeInterval = 0.3
    @State internal var isTextEditingMode = false
    //internal let metalPerformanceMonitor = PerformanceMonitor()

    @State internal var zoomToolDragStartPoint: CGPoint = .zero
    @State internal var zoomToolInitialZoomLevel: CGFloat = 1.0
    @State internal var selectedPoints: Set<PointID> = []
    @State internal var selectedHandles: Set<HandleID> = []
    @State internal var visibleHandles: Set<HandleID> = []
    @State internal var selectedObjectIDs: Set<UUID> = []
    @State internal var isCornerRadiusEditMode = false
    @State internal var isDraggingPoint = false
    @State internal var isDraggingHandle = false
    @State internal var isDraggingCurveSegment = false
    @State internal var draggedCurveSegment: (shapeID: UUID, elementIndex: Int)? = nil
    @State internal var curveSegmentDragT: Double = 0.5  // Parametric position on curve
    @State internal var dragStartLocation: CGPoint = .zero
    @State internal var lockedObjectIDs: Set<UUID> = [] // O(1) cache of locked objects
    @State private var cachedObjectCount: Int = 0 // Track object count to detect changes

    internal func syncDirectSelectionWithDocument() {
        viewState.selectedObjectIDs = selectedObjectIDs
        viewState.selectedPoints = selectedPoints
        viewState.selectedHandles = selectedHandles

        if !selectedObjectIDs.isEmpty {
            viewState.selectedObjectIDs = Set(selectedObjectIDs)
            viewState.selectedObjectIDs = selectedObjectIDs
        } else if viewState.currentTool == .directSelection ||
                  viewState.currentTool == .convertAnchorPoint ||
                    viewState.currentTool == .penPlusMinus {
            viewState.selectedObjectIDs.removeAll()
        }
    }

    internal func rebuildLockedObjectsCache() {
        lockedObjectIDs.removeAll(keepingCapacity: true)
        for layer in document.snapshot.layers where layer.isLocked {
            for objectID in layer.objectIDs {
                lockedObjectIDs.insert(objectID)
            }
        }
        // Also add individually locked objects
        for (id, object) in document.snapshot.objects {
            if object.shape.isLocked {
                lockedObjectIDs.insert(id)
            }
        }
    }
    @State internal var originalPointPositions: [PointID: VectorPoint] = [:]
    @State internal var originalHandlePositions: [HandleID: VectorPoint] = [:]
    @State internal var originalDragShapes: [UUID: VectorShape] = [:]

    @State internal var cornerDragStart: CGPoint = .zero
    @State internal var initialCornerRadius: Double = 0.0
    @State internal var isDraggingCorner = false
    @State internal var draggedCornerIndex: Int? = nil
    @State internal var currentMousePosition: CGPoint = .zero
    @State internal var coincidentPointClusters: [HashableCGPoint: [PointID]] = [:]
    @State internal var coincidentPointRadius: CGFloat = 2.0
    @State internal var coincidentPointTolerance: Double = 0.1
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
    @State internal var hasPerformedInitialFitToPage = false
    @State internal var cachedSelectionBoundsForDrag: CGRect? = nil

    var body: some View {
        GeometryReader { geometry in
            enhancedCanvasMainContent(geometry: geometry)
                .onAppear {
                    if !hasPerformedInitialFitToPage {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            fitToPage(geometry: geometry)
                            hasPerformedInitialFitToPage = true
                        }
                    }
                }
                .onAppear {
                    // Initial setup only
                    selectedObjectIDs = document.viewState.selectedObjectIDs
                    cachedObjectCount = document.snapshot.objects.count
                    spatialIndex.rebuild(from: document.snapshot)
                    rebuildLockedObjectsCache()
                }
                .onChange(of: document.viewState.objectUpdateTrigger) { _, _ in
                    // Rebuild spatial index when objects are updated (moved, transformed, visibility changed)
                    spatialIndex.rebuild(from: document.snapshot)
                    rebuildLockedObjectsCache()
                }
                .onChange(of: document.viewState.layerUpdateTriggers) { oldTriggers, newTriggers in
                    // Skip spatial index rebuild during live point drags for performance
                    guard !document.viewState.isLivePointDrag else { return }

                    // Rebuild spatial index only for layers that changed (preferred granular approach)
                    var changedLayerIDs = Set<UUID>()

                    // Find layers with changed trigger values
                    for (layerID, newValue) in newTriggers {
                        if oldTriggers[layerID] != newValue {
                            changedLayerIDs.insert(layerID)
                        }
                    }

                    if !changedLayerIDs.isEmpty {
                        // print("🔷 Spatial index: rebuilding \(changedLayerIDs.count) layer(s)")
                        spatialIndex.rebuildLayers(changedLayerIDs, from: document.snapshot)
                        rebuildLockedObjectsCache()
                    }
                }
                .onChange(of: document.snapshot.objects.count) { _, newCount in
                    // Rebuild spatial index when objects are added/removed
                    if newCount != cachedObjectCount {
                        cachedObjectCount = newCount
                        spatialIndex.rebuild(from: document.snapshot)
                        rebuildLockedObjectsCache()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshVisibleHandles"))) { _ in
                    // Refresh visible handles after anchor type conversion
                    if viewState.currentTool == .directSelection {
                        showHandlesForSelectedPoints()
                    }
                }
        }
    }
}
