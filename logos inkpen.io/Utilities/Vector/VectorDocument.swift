import SwiftUI
import Combine

class VectorDocument: ObservableObject, Codable {
    // View-only state (doesn't trigger document saves)
    @Published var viewState: DocumentViewState = DocumentViewState()

    @Published var settings: DocumentSettings
    @Published var layers: [VectorLayer] = []
    var layerIndex: Int = 0
    var selectedLayerIndex: Int?
    var selectedShapeIDs: Set<UUID> = []
    var selectedTextIDs: Set<UUID> = []
    @Published var selectedObjectIDs: Set<UUID> = []
    var directSelectedShapeIDs: Set<UUID> = []
    @Published var documentColorDefaults: ColorDefaults = ColorDefaults() {
        didSet {
            settings.fillColor = documentColorDefaults.fillColor
            settings.strokeColor = documentColorDefaults.strokeColor
        }
    }
    
    @Published var customRgbSwatches: [VectorColor] = [] {
        didSet { settings.customRgbSwatches = customRgbSwatches }
    }
    @Published var customCmykSwatches: [VectorColor] = [] {
        didSet { settings.customCmykSwatches = customCmykSwatches }
    }
    @Published var customHsbSwatches: [VectorColor] = [] {
        didSet { settings.customHsbSwatches = customHsbSwatches }
    }
    
    @Published var isDraggingVisibility: Bool = false
    @Published var isDraggingLock: Bool = false
    var processedLayersDuringDrag: Set<Int> = []
    var processedObjectsDuringDrag: Set<UUID> = []

    // Track active layer during object drag for performance optimization
    var activeLayerIndexDuringDrag: Int? = nil

    var isHandleScalingActive = false
    var unifiedObjects: [VectorObject] = [] {
        didSet {
            if oldValue.count != unifiedObjects.count {
                rebuildIndexCache()
            } else {
                for (index, object) in unifiedObjects.enumerated() {
                    if index < oldValue.count && oldValue[index].id == object.id {
                        unifiedObjectIndexCache[object.id] = index
                    }
                }
            }
            changeNotifier.notifyGeneralChange()
        }
    }

    // Index cache: maps UUID -> array index (O(1) lookup, minimal memory)
    internal var unifiedObjectIndexCache: [UUID: Int] = [:]

    // Lightweight change notifier - avoids copying unifiedObjects array
    let changeNotifier = DocumentChangeNotifier()

    var textPreviewTypography: [UUID: TypographyProperties] = [:]

    @Published var currentTool: DrawingTool = .brush {
        didSet {
            UserDefaults.standard.set(currentTool.rawValue, forKey: "lastUsedTool")
            
            if currentTool == .freehand && defaultStrokeColor == .clear {
                defaultStrokeColor = defaultFillColor
            }
        }
    }
    @Published var scalingAnchor: ScalingAnchor = .center
    @Published var rotationAnchor: RotationAnchor = .center
    @Published var shearAnchor: ShearAnchor = .center
    @Published var transformOrigin: TransformOrigin = .center
    @Published var objectPositionUpdateTrigger: Bool = false
    var currentDragOffset: CGPoint = .zero
    var cachedSelectionBounds: CGRect? = nil
    var dragPreviewCoordinates: CGPoint = .zero
    @Published var scalePreviewDimensions: CGSize = .zero
    @Published var warpEnvelopeCorners: [UUID: [CGPoint]] = [:]
    @Published var warpBounds: [UUID: CGRect] = [:]
    
    enum FreehandFillMode: String, CaseIterable {
        case fill = "Fill"
        case noFill = "No Fill"
    }

    @Published var hasPressureInput: Bool = false
    
    @Published var viewMode: ViewMode = .color
    @Published var zoomLevel: Double = 1.0
    @Published var canvasOffset: CGPoint = .zero
    @Published var zoomRequest: ZoomRequest? = nil
    @Published var showRulers: Bool = false
    @Published var showGrid: Bool = false
    @Published var snapToGrid: Bool = false
    @Published var snapToPoint: Bool = false
    @Published var gridSpacing: Double = 12.0
    @Published var backgroundColor: VectorColor = .white
    
    internal var isUndoRedoOperation: Bool = false
    
    lazy var commandManager: CommandManager = {
        let manager = CommandManager(maxStackSize: maxUndoStackSize)
        manager.document = self
        return manager
    }()
    
    @Published var fontManager: FontManager = FontManager()

    @Published var defaultStrokePlacement: StrokePlacement = .center {
        didSet { saveStrokeStyleDefaults() }
    }
    @Published var defaultStrokeLineJoin: CGLineJoin = .miter {
        didSet { saveStrokeStyleDefaults() }
    }
    @Published var defaultStrokeLineCap: CGLineCap = .butt {
        didSet { saveStrokeStyleDefaults() }
    }
    @Published var defaultStrokeMiterLimit: Double = 10.0 {
        didSet { saveStrokeStyleDefaults() }
    }
    
    @Published var activeColorTarget: ColorTarget = .fill
    @Published var colorChangeNotification: UUID = UUID()
    @Published var lastColorChangeType: ColorChangeType = .fillOpacity
    
    internal let maxUndoStackSize = 50

    var originalHandlePositions: [String: VectorPoint] = [:]
    
    internal var _encodableSettings: DocumentSettings
    internal var _encodableLayers: [VectorLayer]
    internal var _encodableCurrentTool: DrawingTool
    internal var _encodableViewMode: ViewMode
    internal var _encodableZoomLevel: Double
    internal var _encodableCanvasOffset: CGPoint
    internal var _encodableUnifiedObjects: [VectorObject]
    
    init(settings: DocumentSettings = DocumentSettings()) {
        self._encodableSettings = settings
        self._encodableLayers = []
        self._encodableCurrentTool = .selection
        self._encodableViewMode = .color
        self._encodableZoomLevel = 1.0
        self._encodableCanvasOffset = .zero
        self._encodableUnifiedObjects = []
        
        self.settings = settings
        
        self.documentColorDefaults = ColorDefaults()
        
        self.customRgbSwatches = []
        self.customCmykSwatches = []
        self.customHsbSwatches = []

        loadStrokeStyleDefaults()
        
        self.selectedLayerIndex = nil
        self.selectedShapeIDs = []
        self.selectedTextIDs = []
        
        if let lastToolRaw = UserDefaults.standard.string(forKey: "lastUsedTool"),
           let lastTool = DrawingTool(rawValue: lastToolRaw) {
            self.currentTool = lastTool
            self.viewState.currentTool = lastTool
        } else {
            self.currentTool = .selection
            self.viewState.currentTool = .selection
        }
        self.scalingAnchor = .center
        self.viewState.scalingAnchor = .center
        self.viewMode = .color
        self.viewState.viewMode = .color
        self.zoomLevel = 1.0
        self.viewState.zoomLevel = 1.0
        self.canvasOffset = .zero
        self.viewState.canvasOffset = .zero
        self.showRulers = settings.showRulers
        self.showGrid = settings.showGrid
        self.snapToGrid = settings.snapToGrid
        self.snapToPoint = settings.snapToPoint
        self.gridSpacing = settings.gridSpacing
        self.backgroundColor = settings.backgroundColor
        
        createCanvasAndWorkingLayers()
        
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        self.selectedLayerIndex = 2
        self.layerIndex = 2
        
        if layers.count > 2 {
            let workingLayer = layers[2]
            self.settings.selectedLayerId = workingLayer.id
            self.settings.selectedLayerName = workingLayer.name
        }

        if let fillColor = settings.fillColor {
            self.documentColorDefaults.fillColor = fillColor
        } else {
            self.documentColorDefaults.fillColor = ColorManager.shared.colorDefaults.fillColor
        }
        
        if let strokeColor = settings.strokeColor {
            self.documentColorDefaults.strokeColor = strokeColor
        } else {
            self.documentColorDefaults.strokeColor = ColorManager.shared.colorDefaults.strokeColor
        }
        
        if let rgbSwatches = settings.customRgbSwatches {
            self.customRgbSwatches = rgbSwatches
        }
        if let cmykSwatches = settings.customCmykSwatches {
            self.customCmykSwatches = cmykSwatches
        }
        if let hsbSwatches = settings.customHsbSwatches {
            self.customHsbSwatches = hsbSwatches
        }
        
        syncEncodableStorage()
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedSettings = try container.decode(DocumentSettings.self, forKey: .settings)
        let decodedLayers = try container.decode([VectorLayer].self, forKey: .layers)
        let decodedCurrentTool = try container.decode(DrawingTool.self, forKey: .currentTool)
        let decodedViewMode = try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .color
        let decodedZoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        let decodedCanvasOffset = try container.decode(CGPoint.self, forKey: .canvasOffset)
        let decodedUnifiedObjects = try container.decodeIfPresent([VectorObject].self, forKey: .unifiedObjects) ?? []
        
        _encodableSettings = decodedSettings
        _encodableLayers = decodedLayers
        _encodableCurrentTool = decodedCurrentTool
        _encodableViewMode = decodedViewMode
        _encodableZoomLevel = decodedZoomLevel
        _encodableCanvasOffset = decodedCanvasOffset
        _encodableUnifiedObjects = decodedUnifiedObjects
        
        settings = decodedSettings
        layers = decodedLayers
        layerIndex = 0
        
        documentColorDefaults = ColorDefaults()
        customRgbSwatches = []
        customCmykSwatches = []
        customHsbSwatches = []
        
        selectedLayerIndex = try? container.decodeIfPresent(Int.self, forKey: .selectedLayerIndex)
        selectedShapeIDs = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .selectedShapeIDs)) ?? []
        selectedTextIDs = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .selectedTextIDs)) ?? []
        selectedObjectIDs = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .selectedObjectIDs)) ?? []
        viewState.selectedObjectIDs = selectedObjectIDs
        directSelectedShapeIDs = []
        isHandleScalingActive = false
        isDraggingVisibility = false
        viewState.isDraggingVisibility = false
        isDraggingLock = false
        viewState.isDraggingLock = false
        
        currentTool = decodedCurrentTool
        viewState.currentTool = decodedCurrentTool
        scalingAnchor = .center
        viewState.scalingAnchor = .center
        rotationAnchor = .center
        viewState.rotationAnchor = .center
        shearAnchor = .center
        viewState.shearAnchor = .center
        transformOrigin = .center
        viewState.transformOrigin = .center
        objectPositionUpdateTrigger = false
        viewState.objectPositionUpdateTrigger = false
        currentDragOffset = .zero
        cachedSelectionBounds = nil
        dragPreviewCoordinates = .zero
        scalePreviewDimensions = .zero
        viewState.scalePreviewDimensions = .zero
        warpEnvelopeCorners = (try? container.decodeIfPresent([UUID: [CGPoint]].self, forKey: .warpEnvelopeCorners)) ?? [:]
        viewState.warpEnvelopeCorners = warpEnvelopeCorners
        warpBounds = (try? container.decodeIfPresent([UUID: CGRect].self, forKey: .warpBounds)) ?? [:]
        viewState.warpBounds = warpBounds

        viewMode = decodedViewMode
        viewState.viewMode = decodedViewMode
        zoomLevel = decodedZoomLevel
        viewState.zoomLevel = decodedZoomLevel
        canvasOffset = decodedCanvasOffset
        viewState.canvasOffset = decodedCanvasOffset
        zoomRequest = nil
        viewState.zoomRequest = nil
        
        isUndoRedoOperation = false
        fontManager = FontManager()
        
        unifiedObjects = decodedUnifiedObjects
        
        defaultStrokePlacement = .center
        defaultStrokeLineJoin = .miter
        defaultStrokeLineCap = .butt
        defaultStrokeMiterLimit = 10.0
        
        hasPressureInput = false
        viewState.hasPressureInput = false

        activeColorTarget = .fill
        viewState.activeColorTarget = .fill
        colorChangeNotification = UUID()
        viewState.colorChangeNotification = UUID()
        lastColorChangeType = .fillOpacity
        viewState.lastColorChangeType = .fillOpacity

        originalHandlePositions = [:]
        
        showRulers = settings.showRulers
        showGrid = settings.showGrid
        snapToGrid = settings.snapToGrid
        snapToPoint = settings.snapToPoint
        gridSpacing = settings.gridSpacing
        backgroundColor = settings.backgroundColor
        
        if unifiedObjects.isEmpty {
            populateUnifiedObjectsFromLayersPreservingOrder()
        }
        
        validateSelectedLayer()
        
        if let fillColor = settings.fillColor {
            documentColorDefaults.fillColor = fillColor
        } else {
            documentColorDefaults.fillColor = ColorManager.shared.colorDefaults.fillColor
        }
        
        if let strokeColor = settings.strokeColor {
            documentColorDefaults.strokeColor = strokeColor
        } else {
            documentColorDefaults.strokeColor = ColorManager.shared.colorDefaults.strokeColor
        }
        
        if let rgbSwatches = settings.customRgbSwatches {
            customRgbSwatches = rgbSwatches
        }
        if let cmykSwatches = settings.customCmykSwatches {
            customCmykSwatches = cmykSwatches
        }
        if let hsbSwatches = settings.customHsbSwatches {
            customHsbSwatches = hsbSwatches
        }
        
        loadStrokeStyleDefaults()

        migrateLegacyTextObjects()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshSystemLayers()
        }
    }

    private func refreshSystemLayers() {
        rebuildIndexCache()
        changeNotifier.notifyGeneralChange()
    }

    func toggleActiveLayerVisibility() {
        guard let activeIndex = selectedLayerIndex,
              activeIndex >= 0,
              activeIndex < layers.count else { return }

        layers[activeIndex].isVisible.toggle()
        layers[activeIndex].isVisible.toggle()
    }
}
