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

    // Combine subscriptions for nested ObservableObjects
    private var cancellables = Set<AnyCancellable>()

    var textPreviewTypography: [UUID: TypographyProperties] = [:]

    var currentDragOffset: CGPoint = .zero
    var cachedSelectionBounds: CGRect? = nil
    var dragPreviewCoordinates: CGPoint = .zero

    enum FreehandFillMode: String, CaseIterable {
        case fill = "Fill"
        case noFill = "No Fill"
    }
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
            self.viewState.currentTool = lastTool
        } else {
            self.viewState.currentTool = .selection
        }
        self.viewState.scalingAnchor = .center
        self.viewState.viewMode = .color
        self.viewState.zoomLevel = 1.0
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

        setupViewStateForwarding()
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
        viewState.selectedObjectIDs = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .selectedObjectIDs)) ?? []
        directSelectedShapeIDs = []
        isHandleScalingActive = false

        viewState.currentTool = decodedCurrentTool
        viewState.scalingAnchor = .center
        viewState.rotationAnchor = .center
        viewState.shearAnchor = .center
        viewState.transformOrigin = .center
        viewState.objectPositionUpdateTrigger = false
        currentDragOffset = .zero
        cachedSelectionBounds = nil
        dragPreviewCoordinates = .zero
        viewState.scalePreviewDimensions = .zero
        viewState.warpEnvelopeCorners = (try? container.decodeIfPresent([UUID: [CGPoint]].self, forKey: .warpEnvelopeCorners)) ?? [:]
        viewState.warpBounds = (try? container.decodeIfPresent([UUID: CGRect].self, forKey: .warpBounds)) ?? [:]

        viewState.viewMode = decodedViewMode
        viewState.zoomLevel = decodedZoomLevel
        viewState.canvasOffset = decodedCanvasOffset
        viewState.zoomRequest = nil
        
        isUndoRedoOperation = false
        fontManager = FontManager()
        
        unifiedObjects = decodedUnifiedObjects
        
        defaultStrokePlacement = .center
        defaultStrokeLineJoin = .miter
        defaultStrokeLineCap = .butt
        defaultStrokeMiterLimit = 10.0

        viewState.hasPressureInput = false
        viewState.activeColorTarget = .fill
        viewState.colorChangeNotification = UUID()
        viewState.lastColorChangeType = .fillOpacity
        viewState.isDraggingVisibility = false
        viewState.isDraggingLock = false

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

        setupViewStateForwarding()
        migrateLegacyTextObjects()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.refreshSystemLayers()
        }
    }

    private func setupViewStateForwarding() {
        viewState.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        changeNotifier.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
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
