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
    var rgbSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.rgbSwatches
        swatches.append(contentsOf: customRgbSwatches)
        return swatches
    }
    var cmykSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.cmykSwatches
        swatches.append(contentsOf: customCmykSwatches)
        return swatches
    }
    var hsbSwatches: [VectorColor] {
        var swatches = ColorManager.shared.colorDefaults.hsbSwatches
        swatches.append(contentsOf: customHsbSwatches)
        return swatches
    }

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

    private var unifiedObjectLookupCache: [UUID: VectorObject] = [:]

    var cachedStackingOrder: [VectorObject]? = nil

    private var objectsByLayerCache: [Int: [VectorObject]] = [:]

    func rebuildLookupCache() {
        unifiedObjectLookupCache = Dictionary(uniqueKeysWithValues: unifiedObjects.map { ($0.id, $0) })
        rebuildLayerCache()
    }

    private func rebuildLayerCache() {
        objectsByLayerCache = Dictionary(grouping: unifiedObjects, by: { $0.layerIndex })
    }

    var textPreviewTypography: [UUID: TypographyProperties] = [:]
    var shapePreviewStyles: [UUID: (fillOpacity: Double?, strokeOpacity: Double?, strokeWidth: Double?)] = [:]
    var allShapes: [VectorShape] {
        return unifiedObjects.compactMap { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType, !shape.isTextObject {
                return shape
            }
            return nil
        }
    }
    var allObjectsByLayer: [Int: [VectorObject]] {
        return Dictionary(grouping: unifiedObjects) { $0.layerIndex }
    }

    func findObject(by id: UUID) -> VectorObject? {
        return unifiedObjectLookupCache[id]
    }

    func findObjectIndex(by id: UUID) -> Int? {
        return unifiedObjects.firstIndex(where: { $0.id == id })
    }

    func findShape(by id: UUID) -> VectorShape? {
        guard let object = unifiedObjectLookupCache[id],
              case .shape(let shape) = object.objectType,
              !shape.isTextObject else { return nil }
        return shape
    }

    func findText(by id: UUID) -> VectorText? {
        if let object = unifiedObjectLookupCache[id],
           case .shape(let shape) = object.objectType,
           shape.isTextObject,
           var vectorText = VectorText.from(shape) {
            vectorText.layerIndex = object.layerIndex
            return vectorText
        }

        for object in unifiedObjects {
            if case .shape(let shape) = object.objectType, shape.isGroupContainer {
                if let textShape = shape.groupedShapes.first(where: { $0.id == id && $0.isTextObject }),
                   var vectorText = VectorText.from(textShape) {
                    vectorText.layerIndex = object.layerIndex
                    return vectorText
                }
            }
        }

        return nil
    }

    func getObjectsInLayer(_ layerIndex: Int) -> [VectorObject] {
        return objectsByLayerCache[layerIndex] ?? []
    }

    func forEachTextInOrder(_ action: (VectorText) throws -> Void) rethrows {
        for unifiedObject in unifiedObjects.sorted(by: { $0.orderID < $1.orderID }) {
            if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject,
               let text = VectorText.from(shape) {
                try action(text)
            }
        }
    }

    func getShapesInLayer(_ layerIndex: Int) -> [VectorShape] {
        return allShapes.filter { shape in
            return unifiedObjects.first { obj in
                if case .shape(let objShape) = obj.objectType {
                    return objShape.id == shape.id && obj.layerIndex == layerIndex
                }
                return false
            } != nil
        }
    }

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

    func updateTransformPanelValues() {
        guard !selectedObjectIDs.isEmpty else { return }

        var combinedBounds: CGRect?
        for objectID in selectedObjectIDs {
            if let unifiedObject = findObject(by: objectID) {
                switch unifiedObject.objectType {
                case .shape(let shape):
                    let shapeBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
                    if let existing = combinedBounds {
                        combinedBounds = existing.union(shapeBounds)
                    } else {
                        combinedBounds = shapeBounds
                    }
                }
            }
        }

        objectPositionUpdateTrigger.toggle()
    }

    @Published var currentBrushThickness: Double = 20.0 {
        didSet { UserDefaults.standard.set(currentBrushThickness, forKey: "brushThickness") }
    }
    @Published var currentBrushSmoothingTolerance: Double = 5.0 {
        didSet { UserDefaults.standard.set(currentBrushSmoothingTolerance, forKey: "brushSmoothingTolerance") }
    }
    @Published var currentBrushLiquid: Double = 0.0 {
        didSet { UserDefaults.standard.set(currentBrushLiquid, forKey: "brushLiquid") }
    }
    @Published var currentBrushMinTaperThickness: Double = 0.5 {
        didSet { UserDefaults.standard.set(currentBrushMinTaperThickness, forKey: "brushMinTaperThickness") }
    }
    @Published var currentBrushSimplification: Double = 50.0 {
        didSet { UserDefaults.standard.set(currentBrushSimplification, forKey: "brushSimplification") }
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

    enum FreehandFillMode: String, CaseIterable {
        case fill = "Fill"
        case noFill = "No Fill"
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
    var defaultFillColor: VectorColor {
        get { documentColorDefaults.fillColor }
        set {
            objectWillChange.send()
            documentColorDefaults.fillColor = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }
    var defaultStrokeColor: VectorColor {
        get { documentColorDefaults.strokeColor }
        set {
            objectWillChange.send()
            documentColorDefaults.strokeColor = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }
    var defaultFillOpacity: Double {
        get { documentColorDefaults.fillOpacity }
        set {
            documentColorDefaults.fillOpacity = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }
    var defaultStrokeOpacity: Double {
        get { documentColorDefaults.strokeOpacity }
        set {
            documentColorDefaults.strokeOpacity = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }
    var defaultStrokeWidth: Double {
        get { documentColorDefaults.strokeWidth }
        set {
            documentColorDefaults.strokeWidth = newValue
            documentColorDefaults.saveToUserDefaults()
        }
    }

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

    private var _encodableSettings: DocumentSettings
    private var _encodableLayers: [VectorLayer]
    private var _encodableCurrentTool: DrawingTool
    private var _encodableViewMode: ViewMode
    private var _encodableZoomLevel: Double
    private var _encodableCanvasOffset: CGPoint
    private var _encodableUnifiedObjects: [VectorObject]

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
        self.currentBrushSimplification = UserDefaults.standard.object(forKey: "brushSimplification") as? Double ?? 50.0

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

    private func syncEncodableStorage() {
        _encodableSettings = settings
        _encodableLayers = layers
        _encodableCurrentTool = currentTool
        _encodableViewMode = viewMode
        _encodableZoomLevel = zoomLevel
        _encodableCanvasOffset = canvasOffset
        _encodableUnifiedObjects = unifiedObjects
    }

    var currentSwatches: [VectorColor] {
        switch settings.colorMode {
        case .rgb:
            return rgbSwatches
        case .cmyk:
            return cmykSwatches
        case .pms:
            return hsbSwatches
        }
    }

    func addCustomSwatch(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            if !customRgbSwatches.contains(where: { $0 == color }) {
                customRgbSwatches.append(color)
            }
        case .cmyk:
            if !customCmykSwatches.contains(where: { $0 == color }) {
                customCmykSwatches.append(color)
            }
        case .pms:
            if !customHsbSwatches.contains(where: { $0 == color }) {
                customHsbSwatches.append(color)
            }
        }
    }

    func removeCustomSwatch(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            customRgbSwatches.removeAll(where: { $0 == color })
        case .cmyk:
            customCmykSwatches.removeAll(where: { $0 == color })
        case .pms:
            customHsbSwatches.removeAll(where: { $0 == color })
        }
    }

    deinit {}

    enum CodingKeys: CodingKey {
        case settings, layers, selectedLayerIndex, selectedShapeIDs, selectedTextIDs, selectedObjectIDs, currentTool, viewMode, zoomLevel, canvasOffset, unifiedObjects, warpEnvelopeCorners, warpBounds
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
        currentBrushLiquid = UserDefaults.standard.object(forKey: "brushLiquid") as? Double ?? 0.0
        currentBrushMinTaperThickness = UserDefaults.standard.object(forKey: "brushMinTaperThickness") as? Double ?? 0.5
        currentBrushSimplification = UserDefaults.standard.object(forKey: "brushSimplification") as? Double ?? 50.0

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
            guard let self = self else { return }

            var foundObjectToToggle = false

            for layerIndex in self.layers.indices {
                let objects = self.unifiedObjects.filter { $0.layerIndex == layerIndex }
                if let firstObject = objects.first {
                    if case .shape(var shape) = firstObject.objectType {
                        let wasVisible = shape.isVisible
                        shape.isVisible = !wasVisible
                        if let index = self.unifiedObjects.firstIndex(where: { $0.id == firstObject.id }) {
                            self.unifiedObjects[index] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: firstObject.orderID
                            )
                        }
                        shape.isVisible = wasVisible
                        if let index = self.unifiedObjects.firstIndex(where: { $0.id == firstObject.id }) {
                            self.unifiedObjects[index] = VectorObject(
                                shape: shape,
                                layerIndex: layerIndex,
                                orderID: firstObject.orderID
                            )
                        }
                        foundObjectToToggle = true
break
                    }
                }
            }

            if !foundObjectToToggle {
                self.objectWillChange.send()
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        syncEncodableStorage()

        var container = encoder.container(keyedBy: CodingKeys.self)

        _encodableSettings.fillColor = documentColorDefaults.fillColor
        _encodableSettings.strokeColor = documentColorDefaults.strokeColor
        _encodableSettings.customRgbSwatches = customRgbSwatches.isEmpty ? nil : customRgbSwatches
        _encodableSettings.customCmykSwatches = customCmykSwatches.isEmpty ? nil : customCmykSwatches
        _encodableSettings.customHsbSwatches = customHsbSwatches.isEmpty ? nil : customHsbSwatches

        try container.encode(_encodableSettings, forKey: .settings)
        try container.encode(_encodableLayers, forKey: .layers)
        try container.encode(_encodableCurrentTool, forKey: .currentTool)
        try container.encode(_encodableViewMode, forKey: .viewMode)
        try container.encode(_encodableZoomLevel, forKey: .zoomLevel)
        try container.encode(_encodableCanvasOffset, forKey: .canvasOffset)
        try container.encode(_encodableUnifiedObjects, forKey: .unifiedObjects)

        try container.encode(selectedLayerIndex, forKey: .selectedLayerIndex)
        try container.encode(selectedShapeIDs, forKey: .selectedShapeIDs)
        try container.encode(selectedTextIDs, forKey: .selectedTextIDs)
        try container.encode(selectedObjectIDs, forKey: .selectedObjectIDs)
        try container.encode(warpEnvelopeCorners, forKey: .warpEnvelopeCorners)
        try container.encode(warpBounds, forKey: .warpBounds)
    }

}
