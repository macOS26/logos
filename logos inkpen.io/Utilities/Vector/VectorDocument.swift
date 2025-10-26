import SwiftUI
import Combine

final class VectorDocument: ObservableObject, Codable {
    // MARK: - New Structure
    var snapshot: DocumentSnapshot = DocumentSnapshot()

    // MARK: - Legacy Structure (to be migrated)
    // View-only state (doesn't trigger document saves)
    var viewState: DocumentViewState = DocumentViewState()
    @Published var settings: DocumentSettings
    var layers: [VectorLayer] = []
    var layerIndex: Int = 0
    var selectedLayerIndex: Int?
    
    @Published var documentColorDefaults: ColorDefaults = ColorDefaults() {
        didSet {
            
            settings.fillColor = documentColorDefaults.fillColor
            settings.strokeColor = documentColorDefaults.strokeColor
        }
    }
    
    @Published var colorSwatches: ColorSwatches = .empty {
        didSet {
            settings.customRgbSwatches = colorSwatches.rgb
            settings.customCmykSwatches = colorSwatches.cmyk
            settings.customHsbSwatches = colorSwatches.hsb
        }
    }

    var processedLayersDuringDrag: Set<Int> = []
    var processedObjectsDuringDrag: Set<UUID> = []

    // Track active layer during object drag for performance optimization
    var activeLayerIndexDuringDrag: Int? = nil

    var isHandleScalingActive = false
    var unifiedObjects: [VectorObject] = [] {
        didSet {
            // Only trigger full refresh when objects are added/removed
            if oldValue.count != unifiedObjects.count {
                changeNotifier.notifyGeneralChange()
            }
        }
    }

    // Lightweight change notifier
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
    @Published var gridSettings: GridSettings = .default

    internal var isUndoRedoOperation: Bool = false
    
    lazy var commandManager: CommandManager = {
        let manager = CommandManager(maxStackSize: maxUndoStackSize)
        manager.document = self
        return manager
    }()

    // Per-document image storage (isolated from other documents)
    internal var imageStorage: [UUID: NSImage] = [:]
    internal var baseDirectoryURL: URL? = nil

    @Published var fontManager: FontManager = FontManager()
    @Published var strokeDefaults: StrokeDefaults = .default {
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
        self.colorSwatches = .empty
        self.gridSettings = .default
        self.strokeDefaults = .default

        loadStrokeStyleDefaults()

        self.selectedLayerIndex = nil

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
        self.gridSettings = GridSettings(
            showRulers: settings.showRulers,
            showGrid: settings.showGrid,
            snapToGrid: settings.snapToGrid,
            snapToPoint: settings.snapToPoint,
            gridSpacing: settings.gridSpacing
        )

        createCanvasAndWorkingLayers()

        populateUnifiedObjectsFromLayersPreservingOrder()

        migrateToNewStructure()

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

        self.colorSwatches = ColorSwatches(
            rgb: settings.customRgbSwatches ?? [],
            cmyk: settings.customCmykSwatches ?? [],
            hsb: settings.customHsbSwatches ?? []
        )

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
        colorSwatches = .empty
        gridSettings = .default
        strokeDefaults = .default

        selectedLayerIndex = try? container.decodeIfPresent(Int.self, forKey: .selectedLayerIndex)
        viewState.selectedObjectIDs = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .selectedObjectIDs)) ?? []
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

        viewState.hasPressureInput = false
        viewState.activeColorTarget = .fill
        viewState.colorChangeNotification = UUID()
        viewState.lastColorChangeType = .fillOpacity
        viewState.isDraggingVisibility = false
        viewState.isDraggingLock = false

        originalHandlePositions = [:]

        gridSettings = GridSettings(
            showRulers: settings.showRulers,
            showGrid: settings.showGrid,
            snapToGrid: settings.snapToGrid,
            snapToPoint: settings.snapToPoint,
            gridSpacing: settings.gridSpacing
        )

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

        colorSwatches = ColorSwatches(
            rgb: settings.customRgbSwatches ?? [],
            cmyk: settings.customCmykSwatches ?? [],
            hsb: settings.customHsbSwatches ?? []
        )

        loadStrokeStyleDefaults()

        setupViewStateForwarding()
        migrateLegacyTextObjects()
        migrateBackgroundShapesToCanvas()
        migrateToNewStructure()

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

        fontManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
    }

    private func refreshSystemLayers() {
        changeNotifier.notifyGeneralChange()
    }

    // MARK: - Layer Update Triggers

    /// Triggers updates for specific layers by their indices
    func triggerLayerUpdates(for layerIndices: Set<Int>) {
        for layerIndex in layerIndices {
            guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { continue }
            let layerID = snapshot.layers[layerIndex].id
            viewState.layerUpdateTriggers[layerID, default: 0] &+= 1
        }
    }

    /// Triggers update for a single layer by index
    func triggerLayerUpdate(for layerIndex: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }
        let layerID = snapshot.layers[layerIndex].id
        viewState.layerUpdateTriggers[layerID, default: 0] &+= 1
    }

    /// Updates layer objectIDs and automatically triggers layer update
    func updateLayerObjectIDs(layerIndex: Int, newObjectIDs: [UUID]) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        var layer = snapshot.layers[layerIndex]
        layer.objectIDs = newObjectIDs
        snapshot.layers[layerIndex] = layer

        triggerLayerUpdate(for: layerIndex)
    }

    /// Appends object ID to layer and automatically triggers layer update
    func appendToLayer(layerIndex: Int, objectID: UUID) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        if !snapshot.layers[layerIndex].objectIDs.contains(objectID) {
            var layer = snapshot.layers[layerIndex]
            layer.objectIDs.append(objectID)
            snapshot.layers[layerIndex] = layer
            triggerLayerUpdate(for: layerIndex)
        }
    }

    /// Removes object ID from layer and automatically triggers layer update
    func removeFromLayer(layerIndex: Int, objectID: UUID) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        var layer = snapshot.layers[layerIndex]
        layer.objectIDs.removeAll { $0 == objectID }
        snapshot.layers[layerIndex] = layer

        triggerLayerUpdate(for: layerIndex)
    }

    /// Inserts object ID at specific index in layer and automatically triggers layer update
    func insertIntoLayer(layerIndex: Int, objectID: UUID, at index: Int) {
        guard layerIndex >= 0 && layerIndex < snapshot.layers.count else { return }

        var layer = snapshot.layers[layerIndex]
        layer.objectIDs.insert(objectID, at: index)
        snapshot.layers[layerIndex] = layer

        triggerLayerUpdate(for: layerIndex)
    }
}
