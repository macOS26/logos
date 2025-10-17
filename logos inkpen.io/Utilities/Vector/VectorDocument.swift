import SwiftUI
import Combine

class VectorDocument: ObservableObject, Codable {
    @Published var settings: DocumentSettings
    @Published var layers: [VectorLayer] = [] {
        didSet {
            cachedStackingOrder = nil
        }
    }
    @Published var layerIndex: Int = 0
    @Published var selectedLayerIndex: Int?
    @Published var selectedShapeIDs: Set<UUID> = []
    @Published var selectedTextIDs: Set<UUID> = []
    @Published var selectedObjectIDs: Set<UUID> = []
    @Published var directSelectedShapeIDs: Set<UUID> = []
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
    @Published var processedLayersDuringDrag: Set<Int> = []
    @Published var processedObjectsDuringDrag: Set<UUID> = []

    @Published var isHandleScalingActive = false
    @Published var unifiedObjects: [VectorObject] = [] {
        didSet {
            if oldValue.count != unifiedObjects.count {
                rebuildLookupCache()
            } else {
                for (index, object) in unifiedObjects.enumerated() {
                    if index < oldValue.count && oldValue[index].id == object.id {
                        unifiedObjectLookupCache[object.id] = object
                    }
                }
            }
            cachedStackingOrder = nil
            rebuildLayerCache()
        }
    }
    
    internal var unifiedObjectLookupCache: [UUID: VectorObject] = [:]

    var cachedStackingOrder: [VectorObject]? = nil

    internal var objectsByLayerCache: [Int: [VectorObject]] = [:]

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
    @Published var currentDragOffset: CGPoint = .zero
    @Published var cachedSelectionBounds: CGRect? = nil
    @Published var dragPreviewCoordinates: CGPoint = .zero
    @Published var scalePreviewDimensions: CGSize = .zero
    @Published var warpEnvelopeCorners: [UUID: [CGPoint]] = [:]
    @Published var warpBounds: [UUID: CGRect] = [:]
    
    enum FreehandFillMode: String, CaseIterable {
        case fill = "Fill"
        case noFill = "No Fill"
    }
    
    @Published var currentBrushThickness: Double = 20.0 {
        didSet { UserDefaults.standard.set(currentBrushThickness, forKey: "brushThickness") }
    }
    @Published var currentBrushSmoothingTolerance: Double = 5.0 {
        didSet { UserDefaults.standard.set(currentBrushSmoothingTolerance, forKey: "brushSmoothingTolerance") }
    }
    @Published var currentBrushMinTaperThickness: Double = 0.5 {
        didSet { UserDefaults.standard.set(currentBrushMinTaperThickness, forKey: "brushMinTaperThickness") }
    }
    @Published var currentBrushTaperStart: Double = 0.15 {
        didSet { UserDefaults.standard.set(currentBrushTaperStart, forKey: "brushTaperStart") }
    }
    @Published var currentBrushTaperEnd: Double = 0.15 {
        didSet { UserDefaults.standard.set(currentBrushTaperEnd, forKey: "brushTaperEnd") }
    }
    @Published var hasPressureInput: Bool = false
    @Published var brushApplyNoStroke: Bool = true {
        didSet { UserDefaults.standard.set(brushApplyNoStroke, forKey: "brushApplyNoStroke") }
    }
    @Published var brushRemoveOverlap: Bool = true {
        didSet { UserDefaults.standard.set(brushRemoveOverlap, forKey: "brushRemoveOverlap") }
    }
    
    @Published var advancedSmoothingEnabled: Bool {
        didSet { UserDefaults.standard.set(advancedSmoothingEnabled, forKey: "advancedSmoothingEnabled") }
    }
    @Published var chaikinSmoothingIterations: Int {
        didSet { UserDefaults.standard.set(chaikinSmoothingIterations, forKey: "chaikinSmoothingIterations") }
    }
    
    @Published var freehandSmoothingTolerance: Double {
        didSet { UserDefaults.standard.set(freehandSmoothingTolerance, forKey: "freehandSmoothingTolerance") }
    }
    @Published var realTimeSmoothingEnabled: Bool {
        didSet { UserDefaults.standard.set(realTimeSmoothingEnabled, forKey: "realTimeSmoothingEnabled") }
    }
    @Published var realTimeSmoothingStrength: Double {
        didSet { UserDefaults.standard.set(realTimeSmoothingStrength, forKey: "realTimeSmoothingStrength") }
    }
    @Published var preserveSharpCorners: Bool {
        didSet { UserDefaults.standard.set(preserveSharpCorners, forKey: "preserveSharpCorners") }
    }
    @Published var freehandFillMode: FreehandFillMode = .noFill {
        didSet { UserDefaults.standard.set(freehandFillMode.rawValue, forKey: "freehandFillMode") }
    }
    @Published var freehandExpandStroke: Bool = false {
        didSet { UserDefaults.standard.set(freehandExpandStroke, forKey: "freehandExpandStroke") }
    }
    @Published var freehandClosePath: Bool = false {
        didSet { UserDefaults.standard.set(freehandClosePath, forKey: "freehandClosePath") }
    }
    
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
    
    @Published var currentMarkerSmoothingTolerance: Double {
        didSet { UserDefaults.standard.set(currentMarkerSmoothingTolerance, forKey: "markerSmoothingTolerance") }
    }
    @Published var currentMarkerTipSize: Double {
        didSet { UserDefaults.standard.set(currentMarkerTipSize, forKey: "markerTipSize") }
    }
    @Published var currentMarkerOpacity: Double {
        didSet { UserDefaults.standard.set(currentMarkerOpacity, forKey: "markerOpacity") }
    }
    @Published var currentMarkerFeathering: Double {
        didSet { UserDefaults.standard.set(currentMarkerFeathering, forKey: "markerFeathering") }
    }
    @Published var currentMarkerTaperStart: Double {
        didSet { UserDefaults.standard.set(currentMarkerTaperStart, forKey: "markerTaperStart") }
    }
    @Published var currentMarkerTaperEnd: Double {
        didSet { UserDefaults.standard.set(currentMarkerTaperEnd, forKey: "markerTaperEnd") }
    }
    @Published var currentMarkerMinTaperThickness: Double {
        didSet { UserDefaults.standard.set(currentMarkerMinTaperThickness, forKey: "markerMinTaperThickness") }
    }
    @Published var markerUseFillAsStroke: Bool {
        didSet { UserDefaults.standard.set(markerUseFillAsStroke, forKey: "markerUseFillAsStroke") }
    }
    @Published var markerApplyNoStroke: Bool {
        didSet { UserDefaults.standard.set(markerApplyNoStroke, forKey: "markerApplyNoStroke") }
    }
    @Published var markerRemoveOverlap: Bool {
        didSet { UserDefaults.standard.set(markerRemoveOverlap, forKey: "markerRemoveOverlap") }
    }
    
    @Published var originalHandlePositions: [String: VectorPoint] = [:]
    
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
        
        self.currentBrushThickness = UserDefaults.standard.object(forKey: "brushThickness") as? Double ?? 20.0
        self.currentBrushSmoothingTolerance = UserDefaults.standard.object(forKey: "brushSmoothingTolerance") as? Double ?? 5.0
        self.currentBrushTaperStart = UserDefaults.standard.object(forKey: "brushTaperStart") as? Double ?? 0.15
        self.currentBrushTaperEnd = UserDefaults.standard.object(forKey: "brushTaperEnd") as? Double ?? 0.15

        self.advancedSmoothingEnabled = UserDefaults.standard.object(forKey: "advancedSmoothingEnabled") as? Bool ?? false
        self.chaikinSmoothingIterations = UserDefaults.standard.object(forKey: "chaikinSmoothingIterations") as? Int ?? 1
        
        self.freehandSmoothingTolerance = UserDefaults.standard.object(forKey: "freehandSmoothingTolerance") as? Double ?? 2.0
        self.realTimeSmoothingEnabled = UserDefaults.standard.object(forKey: "realTimeSmoothingEnabled") as? Bool ?? true
        self.realTimeSmoothingStrength = UserDefaults.standard.object(forKey: "realTimeSmoothingStrength") as? Double ?? 0.3
        self.preserveSharpCorners = UserDefaults.standard.object(forKey: "preserveSharpCorners") as? Bool ?? true
        self.freehandFillMode = FreehandFillMode(rawValue: UserDefaults.standard.string(forKey: "freehandFillMode") ?? "No Fill") ?? .noFill
        self.freehandExpandStroke = UserDefaults.standard.object(forKey: "freehandExpandStroke") as? Bool ?? false
        self.freehandClosePath = UserDefaults.standard.object(forKey: "freehandClosePath") as? Bool ?? false
        
        self.currentMarkerSmoothingTolerance = UserDefaults.standard.object(forKey: "markerSmoothingTolerance") as? Double ?? 20.0
        self.currentMarkerTipSize = UserDefaults.standard.object(forKey: "markerTipSize") as? Double ?? 31.0
        self.currentMarkerOpacity = UserDefaults.standard.object(forKey: "markerOpacity") as? Double ?? 1.0
        self.currentMarkerFeathering = UserDefaults.standard.object(forKey: "markerFeathering") as? Double ?? 0.3
        self.currentMarkerTaperStart = UserDefaults.standard.object(forKey: "markerTaperStart") as? Double ?? 0.1
        self.currentMarkerTaperEnd = UserDefaults.standard.object(forKey: "markerTaperEnd") as? Double ?? 0.1
        self.currentMarkerMinTaperThickness = UserDefaults.standard.object(forKey: "markerMinTaperThickness") as? Double ?? 2.0
        self.markerUseFillAsStroke = UserDefaults.standard.object(forKey: "markerUseFillAsStroke") as? Bool ?? true
        self.markerApplyNoStroke = UserDefaults.standard.object(forKey: "markerApplyNoStroke") as? Bool ?? false
        self.markerRemoveOverlap = UserDefaults.standard.object(forKey: "markerRemoveOverlap") as? Bool ?? true
        
        loadStrokeStyleDefaults()
        
        self.selectedLayerIndex = nil
        self.selectedShapeIDs = []
        self.selectedTextIDs = []
        
        if let lastToolRaw = UserDefaults.standard.string(forKey: "lastUsedTool"),
           let lastTool = DrawingTool(rawValue: lastToolRaw) {
            self.currentTool = lastTool
        } else {
            self.currentTool = .selection
        }
        self.scalingAnchor = .center
        self.viewMode = .color
        self.zoomLevel = 1.0
        self.canvasOffset = .zero
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
        
        setupSettingsObservation()
        
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
        directSelectedShapeIDs = []
        isHandleScalingActive = false
        
        currentTool = decodedCurrentTool
        scalingAnchor = .center
        rotationAnchor = .center
        shearAnchor = .center
        transformOrigin = .center
        objectPositionUpdateTrigger = false
        currentDragOffset = .zero
        cachedSelectionBounds = nil
        dragPreviewCoordinates = .zero
        scalePreviewDimensions = .zero
        warpEnvelopeCorners = (try? container.decodeIfPresent([UUID: [CGPoint]].self, forKey: .warpEnvelopeCorners)) ?? [:]
        warpBounds = (try? container.decodeIfPresent([UUID: CGRect].self, forKey: .warpBounds)) ?? [:]
        
        viewMode = decodedViewMode
        zoomLevel = decodedZoomLevel
        canvasOffset = decodedCanvasOffset
        zoomRequest = nil
        
        isUndoRedoOperation = false
        fontManager = FontManager()
        
        unifiedObjects = decodedUnifiedObjects
        
        defaultStrokePlacement = .center
        defaultStrokeLineJoin = .miter
        defaultStrokeLineCap = .butt
        defaultStrokeMiterLimit = 10.0
        
        hasPressureInput = false
        brushApplyNoStroke = UserDefaults.standard.object(forKey: "brushApplyNoStroke") as? Bool ?? true
        brushRemoveOverlap = UserDefaults.standard.object(forKey: "brushRemoveOverlap") as? Bool ?? true
        
        activeColorTarget = .fill
        colorChangeNotification = UUID()
        lastColorChangeType = .fillOpacity
        
        originalHandlePositions = [:]
        
        currentBrushThickness = UserDefaults.standard.object(forKey: "brushThickness") as? Double ?? 20.0
        currentBrushSmoothingTolerance = UserDefaults.standard.object(forKey: "brushSmoothingTolerance") as? Double ?? 5.0
        currentBrushMinTaperThickness = UserDefaults.standard.object(forKey: "brushMinTaperThickness") as? Double ?? 0.5
        currentBrushTaperStart = UserDefaults.standard.object(forKey: "brushTaperStart") as? Double ?? 0.15
        currentBrushTaperEnd = UserDefaults.standard.object(forKey: "brushTaperEnd") as? Double ?? 0.15

        advancedSmoothingEnabled = UserDefaults.standard.object(forKey: "advancedSmoothingEnabled") as? Bool ?? false
        chaikinSmoothingIterations = UserDefaults.standard.object(forKey: "chaikinSmoothingIterations") as? Int ?? 1
        
        freehandSmoothingTolerance = UserDefaults.standard.object(forKey: "freehandSmoothingTolerance") as? Double ?? 2.0
        realTimeSmoothingEnabled = UserDefaults.standard.object(forKey: "realTimeSmoothingEnabled") as? Bool ?? true
        realTimeSmoothingStrength = UserDefaults.standard.object(forKey: "realTimeSmoothingStrength") as? Double ?? 0.3
        preserveSharpCorners = UserDefaults.standard.object(forKey: "preserveSharpCorners") as? Bool ?? true
        freehandFillMode = FreehandFillMode(rawValue: UserDefaults.standard.string(forKey: "freehandFillMode") ?? "No Fill") ?? .noFill
        freehandExpandStroke = UserDefaults.standard.object(forKey: "freehandExpandStroke") as? Bool ?? false
        freehandClosePath = UserDefaults.standard.object(forKey: "freehandClosePath") as? Bool ?? false
        
        currentMarkerSmoothingTolerance = UserDefaults.standard.object(forKey: "markerSmoothingTolerance") as? Double ?? 20.0
        currentMarkerTipSize = UserDefaults.standard.object(forKey: "markerTipSize") as? Double ?? 31.0
        currentMarkerOpacity = UserDefaults.standard.object(forKey: "markerOpacity") as? Double ?? 1.0
        currentMarkerFeathering = UserDefaults.standard.object(forKey: "markerFeathering") as? Double ?? 0.3
        currentMarkerTaperStart = UserDefaults.standard.object(forKey: "markerTaperStart") as? Double ?? 0.1
        currentMarkerTaperEnd = UserDefaults.standard.object(forKey: "markerTaperEnd") as? Double ?? 0.1
        currentMarkerMinTaperThickness = UserDefaults.standard.object(forKey: "markerMinTaperThickness") as? Double ?? 2.0
        markerUseFillAsStroke = UserDefaults.standard.object(forKey: "markerUseFillAsStroke") as? Bool ?? true
        markerApplyNoStroke = UserDefaults.standard.object(forKey: "markerApplyNoStroke") as? Bool ?? false
        markerRemoveOverlap = UserDefaults.standard.object(forKey: "markerRemoveOverlap") as? Bool ?? true
        
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
        let temp = unifiedObjects
        unifiedObjects = []
        objectWillChange.send()
        unifiedObjects = temp
        objectWillChange.send()
    }
}
