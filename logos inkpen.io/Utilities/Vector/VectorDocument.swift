//
//  VectorDocument 2.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

// MARK: - Vector Document
class VectorDocument: ObservableObject, Codable {
    @Published var settings: DocumentSettings
    @Published var layers: [VectorLayer] = []
    @Published var layerIndex: Int = 0
    @Published var pasteboard: VectorLayer = VectorLayer(name: "Pasteboard")
    
    @Published var selectedLayerIndex: Int?
    @Published var selectedShapeIDs: Set<UUID> = []
    @Published var selectedTextIDs: Set<UUID> = [] // PROFESSIONAL TEXT SUPPORT
    
    // NEW: Unified object system for proper layer ordering
    @Published var selectedObjectIDs: Set<UUID> = [] // Unified selection for both shapes and text
    
    // Direct selection state (managed by DrawingCanvas, used by panels)
    @Published var directSelectedShapeIDs: Set<UUID> = []
    
    // Document-specific color defaults (saved with document)
    @Published var documentColorDefaults: ColorDefaults = ColorDefaults() {
        didSet {
            // Update document settings when colors change
            settings.fillColor = documentColorDefaults.fillColor
            settings.strokeColor = documentColorDefaults.strokeColor
        }
    }

    // Document-specific custom swatches (only user-added swatches)
    @Published var customRgbSwatches: [VectorColor] = [] {
        didSet { settings.customRgbSwatches = customRgbSwatches }
    }
    @Published var customCmykSwatches: [VectorColor] = [] {
        didSet { settings.customCmykSwatches = customCmykSwatches }
    }
    @Published var customHsbSwatches: [VectorColor] = [] {
        didSet { settings.customHsbSwatches = customHsbSwatches }
    }

    // Computed properties for combined swatches (default + custom)
    var rgbSwatches: [VectorColor] {
        // Start with default swatches from ColorManager
        var swatches = ColorManager.shared.colorDefaults.rgbSwatches
        // Add document-specific custom swatches
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
    
    // CRITICAL FIX: Shared state to prevent double transformations  
    @Published var isHandleScalingActive = false // Set by SelectionHandles, checked by canvas gesture
    
    // Text is now stored as VectorShape with isTextObject=true in the unified system
    
    // NEW: Unified objects array for proper layer ordering
    @Published var unifiedObjects: [VectorObject] = [] // All objects (shapes + text) with proper ordering
    
    // PERFORMANCE: O(1) object lookup cache to replace O(n) searches
    private var unifiedObjectLookupCache: [UUID: VectorObject] = [:]
    private var lookupCacheValid: Bool = false

    // PREVIEW: Temporary typography storage for smooth live preview during drag
    // This avoids updating unified objects which causes choppy updates
    var textPreviewTypography: [UUID: TypographyProperties] = [:]
    
    // MIGRATION: Safe computed properties for gradual transition to unified-only access
    // These provide unified access while preserving backward compatibility
    var allShapes: [VectorShape] {
        return unifiedObjects.compactMap { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType, !shape.isTextObject {
                return shape
            }
            return nil
        }
    }
    
    // Get all text objects from unified system
    var allTextObjects: [VectorText] {
        return unifiedObjects.compactMap { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject {
                // Convert VectorShape back to VectorText
                if var vectorText = VectorText.from(shape) {
                    vectorText.layerIndex = unifiedObject.layerIndex
                    return vectorText
                }
            }
            return nil
        }
    }
    
    var allObjectsByLayer: [Int: [VectorObject]] {
        return Dictionary(grouping: unifiedObjects) { $0.layerIndex }
    }
    
    // MIGRATION: Helper methods for common unified operations
    func findObject(by id: UUID) -> VectorObject? {
        return unifiedObjects.first { $0.id == id }
    }
    
    func findShape(by id: UUID) -> VectorShape? {
        return allShapes.first { $0.id == id }
    }
    
    func findText(by id: UUID) -> VectorText? {
        for unifiedObject in unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType, 
               shape.isTextObject,
               shape.id == id,
               var vectorText = VectorText.from(shape) {
                vectorText.layerIndex = unifiedObject.layerIndex
                return vectorText
            }
        }
        return nil
    }
    
    func getObjectsInLayer(_ layerIndex: Int) -> [VectorObject] {
        return unifiedObjects.filter { $0.layerIndex == layerIndex }
    }
    
    // Helper method for ordered text iteration (avoids code duplication)
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
            // Find the unified object for this shape to get its layer
            return unifiedObjects.first { obj in
                if case .shape(let objShape) = obj.objectType {
                    return objShape.id == shape.id && obj.layerIndex == layerIndex
                }
                return false
            } != nil
        }
    }
    
    
    
    @Published var currentTool: DrawingTool = .brush
    @Published var scalingAnchor: ScalingAnchor = .center // NEW: Scaling anchor point selection
    @Published var rotationAnchor: RotationAnchor = .center // NEW: Rotation anchor point selection
    @Published var shearAnchor: ShearAnchor = .center // NEW: Shear anchor point selection
    @Published var transformOrigin: TransformOrigin = .center // 9-point transform origin for ALL transforms
    @Published var objectPositionUpdateTrigger: Bool = false // Triggers transform panel updates after object movement
    @Published var currentDragOffset: CGPoint = .zero // Current drag delta for transform panel to show live updates
    @Published var dragPreviewCoordinates: CGPoint = .zero // Live preview coordinates for two-way binding
    @Published var scalePreviewDimensions: CGSize = .zero // Live preview W/H for scaling operations
    @Published var warpEnvelopeCorners: [UUID: [CGPoint]] = [:] // Store warp envelope corners per shape
    @Published var warpBounds: [UUID: CGRect] = [:] // Store warp tool bounds for every shape - ALWAYS AVAILABLE

    // COMMON UPDATE FUNCTION: Actually calculate and update X Y W H values
    func updateTransformPanelValues() {
        // First sync unified objects
        updateUnifiedObjectsOptimized()

        // Calculate bounds for all selected objects
        guard !selectedObjectIDs.isEmpty else { return }

        var combinedBounds: CGRect?
        for objectID in selectedObjectIDs {
            if let unifiedObject = unifiedObjects.first(where: { $0.id == objectID }) {
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

        // Force the transform panel to update
        objectPositionUpdateTrigger.toggle()
        objectWillChange.send()
    }

    // BRUSH TOOL SETTINGS (Current tool settings, stored in UserDefaults)
    @Published var currentBrushThickness: Double = 20.0 {
        didSet { UserDefaults.standard.set(currentBrushThickness, forKey: "brushThickness") }
    }
    @Published var currentBrushPressureSensitivity: Double = 0.5 {
        didSet { UserDefaults.standard.set(currentBrushPressureSensitivity, forKey: "brushPressureSensitivity") }
    }
    @Published var currentBrushTaper: Double = 0.4 {
        didSet { UserDefaults.standard.set(currentBrushTaper, forKey: "brushTaper") }
    }
    @Published var currentBrushSmoothingTolerance: Double = 2.0 {
        didSet { UserDefaults.standard.set(currentBrushSmoothingTolerance, forKey: "brushSmoothingTolerance") }
    }
    @Published var currentBrushLiquid: Double = 0.0 {  // Internal: 0=moderate, 50=none, 100=max (UI shows reversed)
        didSet { UserDefaults.standard.set(currentBrushLiquid, forKey: "brushLiquid") }
    }
    @Published var hasPressureInput: Bool = false // Whether pressure-sensitive input is detected
    @Published var brushApplyNoStroke: Bool = true // When enabled, applies no stroke regardless of current stroke settings
    

    
    @Published var brushRemoveOverlap: Bool = true // When enabled, applies union operation to merge overlapping parts

    // ADVANCED SMOOTHING SETTINGS (stored in UserDefaults for all drawing tools)
    @Published var advancedSmoothingEnabled: Bool {
        didSet { UserDefaults.standard.set(advancedSmoothingEnabled, forKey: "advancedSmoothingEnabled") }
    }
    @Published var chaikinSmoothingIterations: Int {
        didSet { UserDefaults.standard.set(chaikinSmoothingIterations, forKey: "chaikinSmoothingIterations") }
    }
    @Published var adaptiveTensionEnabled: Bool {
        didSet { UserDefaults.standard.set(adaptiveTensionEnabled, forKey: "adaptiveTensionEnabled") }
    }

    // FREEHAND TOOL SETTINGS (stored in UserDefaults)
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

    // Freehand fill mode: .fill (use current fill color), .noFill (transparent)
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
    @Published var zoomRequest: ZoomRequest? = nil // For coordinated zoom operations
    @Published var showRulers: Bool = false
    @Published var showGrid: Bool = false
    @Published var snapToGrid: Bool = false
    @Published var snapToPoint: Bool = false
    @Published var gridSpacing: Double = 12.0
    @Published var backgroundColor: VectorColor = .white
    
    @Published var undoStack: [VectorDocument] = []
    @Published var redoStack: [VectorDocument] = []
    
    // Flag to track when we're in an undo/redo operation to prevent reordering
    internal var isUndoRedoOperation: Bool = false
    
    // PROFESSIONAL TYPOGRAPHY MANAGEMENT
    @Published var fontManager: FontManager = FontManager()
    
    // Computed properties for easy access to document color defaults
    var defaultFillColor: VectorColor {
        get { documentColorDefaults.fillColor }
        set {
            objectWillChange.send() // Trigger UI update
            documentColorDefaults.fillColor = newValue
        }
    }
    var defaultStrokeColor: VectorColor {
        get { documentColorDefaults.strokeColor }
        set {
            objectWillChange.send() // Trigger UI update
            documentColorDefaults.strokeColor = newValue
        }
    }
    var defaultFillOpacity: Double {
        get { documentColorDefaults.fillOpacity }
        set {
            documentColorDefaults.fillOpacity = newValue
        }
    }
    var defaultStrokeOpacity: Double {
        get { documentColorDefaults.strokeOpacity }
        set {
            documentColorDefaults.strokeOpacity = newValue
        }
    }
    var defaultStrokeWidth: Double {
        get { documentColorDefaults.strokeWidth }
        set {
            documentColorDefaults.strokeWidth = newValue
        }
    }

    // DEFAULT STROKE STYLE PROPERTIES FOR NEW SHAPES (stored in UserDefaults)
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
    
    // ACTIVE COLOR STATE
    @Published var activeColorTarget: ColorTarget = .fill // Which color is currently active for editing
    
    // COLOR CHANGE NOTIFICATION FOR ACTIVE DRAWING TOOLS
    @Published var colorChangeNotification: UUID = UUID() // Changes when colors are updated to notify active tools
    @Published var lastColorChangeType: ColorChangeType = .fillOpacity // What type of change occurred
    
    internal let maxUndoStackSize = 50
    
    // MARKER SETTINGS (Felt-tip marker specific)
    @Published var currentMarkerPressureSensitivity: Double = 0.6 // Marker pressure sensitivity (0.0-1.0)
    @Published var currentMarkerSmoothingTolerance: Double = 2.0 // Marker smoothing tolerance (0.0-10.0)
    @Published var currentMarkerTipSize: Double = 8.0 // Marker tip size in points (1.0-50.0)
    @Published var currentMarkerOpacity: Double = 0.9 // Marker ink opacity (0.0-1.0)
    @Published var currentMarkerFeathering: Double = 0.3 // Marker edge feathering (0.0-1.0)
    @Published var currentMarkerTaperStart: Double = 0.1 // Marker start taper (0.0-0.5)
    @Published var currentMarkerTaperEnd: Double = 0.1 // Marker end taper (0.0-0.5)
    @Published var markerUseFillAsStroke: Bool = true // Default ON: use fill color for both fill and stroke for marker
    @Published var markerApplyNoStroke: Bool = false // When enabled, applies no stroke regardless of current stroke settings
    @Published var markerRemoveOverlap: Bool = true // Default ON: union overlapping parts of same marker shape
    
    // CONVERT ANCHOR POINT TOOL: Store original handle positions for restoration
    @Published var originalHandlePositions: [String: VectorPoint] = [:] // Key: "layerIndex_shapeIndex_elementIndex_handleType", Value: original position
    
    // BRUSH SETTINGS (Variable width brush strokes)
    
    // Thread-safe backing storage for encoding
    private var _encodableSettings: DocumentSettings
    private var _encodableLayers: [VectorLayer]
    private var _encodableCurrentTool: DrawingTool
    private var _encodableViewMode: ViewMode
    private var _encodableZoomLevel: Double
    private var _encodableCanvasOffset: CGPoint
    private var _encodableUnifiedObjects: [VectorObject]
    
    init(settings: DocumentSettings = DocumentSettings()) {
        // Initialize encodable backing storage first
        self._encodableSettings = settings
        self._encodableLayers = []
        self._encodableCurrentTool = .brush
        self._encodableViewMode = .color
        self._encodableZoomLevel = 1.0
        self._encodableCanvasOffset = .zero
        self._encodableUnifiedObjects = []
        
        self.settings = settings

        // Initialize document color defaults first
        self.documentColorDefaults = ColorDefaults()

        // Initialize custom swatches arrays first
        self.customRgbSwatches = []
        self.customCmykSwatches = []
        self.customHsbSwatches = []

        // Initialize brush settings from UserDefaults
        self.currentBrushThickness = UserDefaults.standard.object(forKey: "brushThickness") as? Double ?? 20.0
        self.currentBrushPressureSensitivity = UserDefaults.standard.object(forKey: "brushPressureSensitivity") as? Double ?? 0.5
        self.currentBrushTaper = UserDefaults.standard.object(forKey: "brushTaper") as? Double ?? 0.4
        self.currentBrushSmoothingTolerance = UserDefaults.standard.object(forKey: "brushSmoothingTolerance") as? Double ?? 2.0

        // Initialize advanced smoothing settings from UserDefaults
        self.advancedSmoothingEnabled = UserDefaults.standard.object(forKey: "advancedSmoothingEnabled") as? Bool ?? false
        self.chaikinSmoothingIterations = UserDefaults.standard.object(forKey: "chaikinSmoothingIterations") as? Int ?? 1
        self.adaptiveTensionEnabled = UserDefaults.standard.object(forKey: "adaptiveTensionEnabled") as? Bool ?? true

        // Initialize freehand tool settings from UserDefaults
        self.freehandSmoothingTolerance = UserDefaults.standard.object(forKey: "freehandSmoothingTolerance") as? Double ?? 2.0
        self.realTimeSmoothingEnabled = UserDefaults.standard.object(forKey: "realTimeSmoothingEnabled") as? Bool ?? true
        self.realTimeSmoothingStrength = UserDefaults.standard.object(forKey: "realTimeSmoothingStrength") as? Double ?? 0.3
        self.preserveSharpCorners = UserDefaults.standard.object(forKey: "preserveSharpCorners") as? Bool ?? true
        self.freehandFillMode = FreehandFillMode(rawValue: UserDefaults.standard.string(forKey: "freehandFillMode") ?? "No Fill") ?? .noFill
        self.freehandExpandStroke = UserDefaults.standard.object(forKey: "freehandExpandStroke") as? Bool ?? false
        self.freehandClosePath = UserDefaults.standard.object(forKey: "freehandClosePath") as? Bool ?? false

        // Load stroke style defaults
        loadStrokeStyleDefaults()

        // Stroke properties defaults are loaded via loadUserDefaults()

        // Color palettes are loaded from ColorManager
        
        self.selectedLayerIndex = nil // Will be set after layer creation
        self.selectedShapeIDs = []
        self.selectedTextIDs = [] // PROFESSIONAL TEXT SUPPORT
        // Text is now stored in unified system
        self.currentTool = .brush
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
        self.undoStack = []
        self.redoStack = []
                
        // Create canvas layer + default working layer
        createCanvasAndWorkingLayers()
        
        // CRITICAL: Populate unified objects array with existing shapes
        populateUnifiedObjectsFromLayersPreservingOrder()
        
        // Set the selected layer index to working layer (not canvas or pasteboard)
        self.selectedLayerIndex = 2 // Working layer is now at index 2
        self.layerIndex = 2 // Also set layerIndex

        // Sync selected layer in settings with Layer 1 (working layer)
        if layers.count > 2 {
            let workingLayer = layers[2]
            self.settings.selectedLayerId = workingLayer.id
            self.settings.selectedLayerName = workingLayer.name
        }
        // Logging removed
        
        // Set up settings change observation
        setupSettingsObservation()

        // Load document-specific colors from settings after initialization
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

        // Load custom swatches from document settings
        if let rgbSwatches = settings.customRgbSwatches {
            self.customRgbSwatches = rgbSwatches
        }
        if let cmykSwatches = settings.customCmykSwatches {
            self.customCmykSwatches = cmykSwatches
        }
        if let hsbSwatches = settings.customHsbSwatches {
            self.customHsbSwatches = hsbSwatches
        }
        
        // Sync encodable storage
        syncEncodableStorage()
    }
    
    // Sync encodable storage with current values
    private func syncEncodableStorage() {
        _encodableSettings = settings
        _encodableLayers = layers
        _encodableCurrentTool = currentTool
        _encodableViewMode = viewMode
        _encodableZoomLevel = zoomLevel
        _encodableCanvasOffset = canvasOffset
        _encodableUnifiedObjects = unifiedObjects
    }
    
    // Current color swatches based on mode - computed property
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

    // Add a custom swatch to the current document
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

    // Remove a custom swatch from the current document
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
    
    // MARK: - Canvas Management (User's Brilliant Solution!)
    

    
    deinit {}
        
    
    private func applyScalingToShape(
        shapeId: UUID,
        scaleX: CGFloat,
        scaleY: CGFloat,
        initialTransform: CGAffineTransform,
        initialBounds: CGRect
    ) {
        // Find the shape across all layers using unified objects
        for layerIndex in layers.indices {
            let shapes = getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeId }) {
                // Calculate center point of original bounds for scaling origin
                let centerX = initialBounds.midX
                let centerY = initialBounds.midY
                
                // Create scaling transform around center point
                let scaleTransform = CGAffineTransform.identity
                    .translatedBy(x: centerX, y: centerY)
                    .scaledBy(x: scaleX, y: scaleY)
                    .translatedBy(x: -centerX, y: -centerY)
                
                // Apply scaling to the initial transform (not the current one to avoid accumulation)
                let newTransform = initialTransform.concatenating(scaleTransform)
                
                // Update the shape's transform
                guard var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { continue }
                shape.transform = newTransform
                setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
                
                // CRITICAL FIX: Apply transform to actual coordinates after scaling
                // This ensures object origin stays with object
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
                
                // Force UI update
                objectWillChange.send()
                break
            }
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object
    internal func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        guard var shape = getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
        let transform = shape.transform
        
        // Don't apply identity transforms
        if transform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying transform to shape coordinates: \(shape.name)", level: .info)
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        shape.path = transformedPath
        shape.transform = .identity
        shape.updateBounds()
        setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
        
        Log.info("✅ Shape coordinates updated - object origin now follows object position", category: .fileOperations)
    }


    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case settings, layers, selectedLayerIndex, selectedShapeIDs, selectedTextIDs, currentTool, viewMode, zoomLevel, canvasOffset, unifiedObjects
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode all values first into temporary variables
        let decodedSettings = try container.decode(DocumentSettings.self, forKey: .settings)
        let decodedLayers = try container.decode([VectorLayer].self, forKey: .layers)
        let decodedCurrentTool = try container.decode(DrawingTool.self, forKey: .currentTool)
        let decodedViewMode = try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .color
        let decodedZoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        let decodedCanvasOffset = try container.decode(CGPoint.self, forKey: .canvasOffset)
        let decodedUnifiedObjects = try container.decodeIfPresent([VectorObject].self, forKey: .unifiedObjects) ?? []

        // Initialize encodable backing storage first with decoded values
        _encodableSettings = decodedSettings
        _encodableLayers = decodedLayers
        _encodableCurrentTool = decodedCurrentTool
        _encodableViewMode = decodedViewMode
        _encodableZoomLevel = decodedZoomLevel
        _encodableCanvasOffset = decodedCanvasOffset
        _encodableUnifiedObjects = decodedUnifiedObjects

        // Now initialize all stored properties
        settings = decodedSettings
        layers = decodedLayers
        layerIndex = 0
        pasteboard = VectorLayer(name: "Pasteboard")

        // Initialize document color defaults and swatches arrays first
        documentColorDefaults = ColorDefaults()
        customRgbSwatches = []
        customCmykSwatches = []
        customHsbSwatches = []

        // CRITICAL FIX: Decode selection state for undo/redo to work properly
        // These MUST be decoded, not reset to empty!
        selectedLayerIndex = try? container.decodeIfPresent(Int.self, forKey: .selectedLayerIndex)
        selectedShapeIDs = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .selectedShapeIDs)) ?? []
        selectedTextIDs = (try? container.decodeIfPresent(Set<UUID>.self, forKey: .selectedTextIDs)) ?? []
        selectedObjectIDs = []
        directSelectedShapeIDs = []
        isHandleScalingActive = false

        currentTool = decodedCurrentTool
        scalingAnchor = .center
        rotationAnchor = .center
        shearAnchor = .center
        transformOrigin = .center
        objectPositionUpdateTrigger = false
        currentDragOffset = .zero
        dragPreviewCoordinates = .zero
        scalePreviewDimensions = .zero
        warpEnvelopeCorners = [:]
        warpBounds = [:]

        viewMode = decodedViewMode
        zoomLevel = decodedZoomLevel
        canvasOffset = decodedCanvasOffset
        zoomRequest = nil

        // Initialize all simple properties first
        undoStack = []
        redoStack = []
        isUndoRedoOperation = false
        fontManager = FontManager() // PROFESSIONAL FONT MANAGEMENT

        // CRITICAL FIX: Load unified objects array to preserve order during undo/redo
        unifiedObjects = decodedUnifiedObjects

        // Document color defaults were already loaded above from settings

        // Stroke properties defaults
        defaultStrokePlacement = .center
        defaultStrokeLineJoin = .miter
        defaultStrokeLineCap = .butt
        defaultStrokeMiterLimit = 10.0

        // Initialize other published properties that aren't persisted
        hasPressureInput = false
        brushApplyNoStroke = true
        brushRemoveOverlap = true

        activeColorTarget = .fill
        colorChangeNotification = UUID()
        lastColorChangeType = .fillOpacity

        // Initialize marker settings (not persisted)
        currentMarkerPressureSensitivity = 0.6
        currentMarkerSmoothingTolerance = 2.0
        currentMarkerTipSize = 8.0
        currentMarkerOpacity = 0.9
        currentMarkerFeathering = 0.3
        currentMarkerTaperStart = 0.1
        currentMarkerTaperEnd = 0.1
        markerUseFillAsStroke = true
        markerApplyNoStroke = false
        markerRemoveOverlap = true

        // Initialize other properties
        originalHandlePositions = [:]

        // Initialize brush settings from UserDefaults (properties with didSet) - MUST be done before accessing settings
        currentBrushThickness = UserDefaults.standard.object(forKey: "brushThickness") as? Double ?? 20.0
        currentBrushPressureSensitivity = UserDefaults.standard.object(forKey: "brushPressureSensitivity") as? Double ?? 0.5
        currentBrushTaper = UserDefaults.standard.object(forKey: "brushTaper") as? Double ?? 0.4
        currentBrushSmoothingTolerance = UserDefaults.standard.object(forKey: "brushSmoothingTolerance") as? Double ?? 2.0
        currentBrushLiquid = UserDefaults.standard.object(forKey: "brushLiquid") as? Double ?? 0.0

        // Initialize advanced smoothing settings from UserDefaults (properties with didSet)
        advancedSmoothingEnabled = UserDefaults.standard.object(forKey: "advancedSmoothingEnabled") as? Bool ?? false
        chaikinSmoothingIterations = UserDefaults.standard.object(forKey: "chaikinSmoothingIterations") as? Int ?? 1
        adaptiveTensionEnabled = UserDefaults.standard.object(forKey: "adaptiveTensionEnabled") as? Bool ?? true

        // Initialize freehand tool settings from UserDefaults (properties with didSet)
        freehandSmoothingTolerance = UserDefaults.standard.object(forKey: "freehandSmoothingTolerance") as? Double ?? 2.0
        realTimeSmoothingEnabled = UserDefaults.standard.object(forKey: "realTimeSmoothingEnabled") as? Bool ?? true
        realTimeSmoothingStrength = UserDefaults.standard.object(forKey: "realTimeSmoothingStrength") as? Double ?? 0.3
        preserveSharpCorners = UserDefaults.standard.object(forKey: "preserveSharpCorners") as? Bool ?? true
        freehandFillMode = FreehandFillMode(rawValue: UserDefaults.standard.string(forKey: "freehandFillMode") ?? "No Fill") ?? .noFill
        freehandExpandStroke = UserDefaults.standard.object(forKey: "freehandExpandStroke") as? Bool ?? false
        freehandClosePath = UserDefaults.standard.object(forKey: "freehandClosePath") as? Bool ?? false

        // NOW we can safely access settings for display settings
        // FIX: Sync display settings from DocumentSettings to ensure UserDefaults are respected
        showRulers = settings.showRulers
        showGrid = settings.showGrid
        snapToGrid = settings.snapToGrid
        snapToPoint = settings.snapToPoint
        gridSpacing = settings.gridSpacing
        backgroundColor = settings.backgroundColor
        
        // CRITICAL FIX: Only populate unified objects if they don't exist (for new documents)
        if unifiedObjects.isEmpty {
            populateUnifiedObjectsFromLayersPreservingOrder()
        }

        // Validate that a layer is always selected after loading
        validateSelectedLayer()

        // Load document-specific colors from settings after all properties are initialized
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

        // Load custom swatches from document settings
        if let rgbSwatches = settings.customRgbSwatches {
            customRgbSwatches = rgbSwatches
        }
        if let cmykSwatches = settings.customCmykSwatches {
            customCmykSwatches = cmykSwatches
        }
        if let hsbSwatches = settings.customHsbSwatches {
            customHsbSwatches = hsbSwatches
        }
        
        // Load stroke style defaults
        loadStrokeStyleDefaults()
    }
    

    
    func encode(to encoder: Encoder) throws {
        // Sync encodable storage before encoding
        syncEncodableStorage()
        
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Update settings with current document colors and swatches before saving
        _encodableSettings.fillColor = documentColorDefaults.fillColor
        _encodableSettings.strokeColor = documentColorDefaults.strokeColor
        _encodableSettings.customRgbSwatches = customRgbSwatches.isEmpty ? nil : customRgbSwatches
        _encodableSettings.customCmykSwatches = customCmykSwatches.isEmpty ? nil : customCmykSwatches
        _encodableSettings.customHsbSwatches = customHsbSwatches.isEmpty ? nil : customHsbSwatches

        // Use thread-safe backing storage instead of @Published properties
        try container.encode(_encodableSettings, forKey: .settings)
        try container.encode(_encodableLayers, forKey: .layers)
        try container.encode(_encodableCurrentTool, forKey: .currentTool)
        try container.encode(_encodableViewMode, forKey: .viewMode)
        try container.encode(_encodableZoomLevel, forKey: .zoomLevel)
        try container.encode(_encodableCanvasOffset, forKey: .canvasOffset)
        try container.encode(_encodableUnifiedObjects, forKey: .unifiedObjects)
    }
    

    

    



    

    

    

    
    // MARK: - Color Collection
    /// Collects all colors actually used in the document
    private func collectUsedColors() -> Set<VectorColor> {
        var colors = Set<VectorColor>()

        // Collect colors from all shapes
        for object in unifiedObjects {
            if case .shape(let shape) = object.objectType {
                // Collect fill colors
                if let fillStyle = shape.fillStyle {
                    colors.insert(fillStyle.color)
                }

                // Collect stroke colors
                if let strokeStyle = shape.strokeStyle {
                    colors.insert(strokeStyle.color)
                }
            }
        }

        // Only include backgroundColor if it's not white (the default)
        if backgroundColor != .white {
            colors.insert(backgroundColor)
        }

        return colors
    }

    // MARK: - PROFESSIONAL STROKE OUTLINING
    /// Converts selected strokes to outlined filled paths ("Outline Stroke" feature)

    

    

    
    // MARK: - PROFESSIONAL PATHFINDER OPERATIONS
    
    /// Performs pathfinder operations following

    



    

    







    // MARK: - Palette Helper Functions

    /// Checks if a color is permanent (non-deletable)
    static func isPermanentColor(_ color: VectorColor) -> Bool {
        switch color {
        case .black, .white, .clear:
            return true
        default:
            return false
        }
    }

    // MARK: - Stroke Style UserDefaults Management
    private func saveStrokeStyleDefaults() {
        var prefs: [String: Any] = [:]
        prefs["strokePlace"] = defaultStrokePlacement.rawValue
        prefs["strokeJoin"] = Int(defaultStrokeLineJoin.rawValue)
        prefs["strokeCap"] = Int(defaultStrokeLineCap.rawValue)
        prefs["strokeMiter"] = defaultStrokeMiterLimit
        UserDefaults.standard.set(prefs, forKey: "strokeStylePrefs")
    }

    private func loadStrokeStyleDefaults() {
        guard let prefs = UserDefaults.standard.dictionary(forKey: "strokeStylePrefs") else { return }

        if let placement = prefs["strokePlace"] as? String {
            defaultStrokePlacement = StrokePlacement(rawValue: placement) ?? .center
        }
        if let joinInt = prefs["strokeJoin"] as? Int {
            defaultStrokeLineJoin = CGLineJoin(rawValue: Int32(joinInt)) ?? .miter
        }
        if let capInt = prefs["strokeCap"] as? Int {
            defaultStrokeLineCap = CGLineCap(rawValue: Int32(capInt)) ?? .butt
        }
        if let miter = prefs["strokeMiter"] as? Double {
            defaultStrokeMiterLimit = miter
        }
    }

}