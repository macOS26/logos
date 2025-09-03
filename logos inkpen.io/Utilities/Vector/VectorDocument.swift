//
//  VectorDocument 2.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import CoreGraphics
import CoreText
import AppKit



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
    
    // SIMPLIFIED SWATCH SYSTEM - Three separate modifiable arrays
    @Published var rgbSwatches: [VectorColor] = []
    @Published var cmykSwatches: [VectorColor] = []
    @Published var hsbSwatches: [VectorColor] = []
    
    // CRITICAL FIX: Shared state to prevent double transformations  
    @Published var isHandleScalingActive = false // Set by SelectionHandles, checked by canvas gesture
    @Published var textObjects: [VectorText] = [] // PROFESSIONAL TEXT OBJECTS
    
    // NEW: Unified objects array for proper layer ordering
    @Published var unifiedObjects: [VectorObject] = [] // All objects (shapes + text) with proper ordering
    
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
    
    var allTextObjects: [VectorText] {
        return unifiedObjects.compactMap { unifiedObject in
            if case .shape(let shape) = unifiedObject.objectType, shape.isTextObject {
                // Convert VectorShape back to VectorText
                return VectorText.from(shape)
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
        return allTextObjects.first { $0.id == id }
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
    
    // BRUSH TOOL SETTINGS (Current tool settings, not document settings)
    @Published var currentBrushThickness: Double = 20.0 // Current brush thickness
    @Published var currentBrushPressureSensitivity: Double = 0.5 // Current pressure sensitivity (0.0-1.0)
    @Published var currentBrushTaper: Double = 0.3 // Current brush taper (0.0-1.0)
    @Published var currentBrushSmoothingTolerance: Double = 2.0 // Current brush smoothing tolerance (like freehand)
    @Published var hasPressureInput: Bool = false // Whether pressure-sensitive input is detected
    @Published var brushApplyNoStroke: Bool = true // When enabled, applies no stroke regardless of current stroke settings
    

    
    @Published var brushRemoveOverlap: Bool = true // When enabled, applies union operation to merge overlapping parts
    @Published var viewMode: ViewMode = .color
    @Published var zoomLevel: Double = 1.0
    @Published var canvasOffset: CGPoint = .zero
    @Published var zoomRequest: ZoomRequest? = nil // For coordinated zoom operations
    @Published var showRulers: Bool = false
    @Published var showGrid: Bool = false
    @Published var snapToGrid: Bool = false
    @Published var gridSpacing: Double = 12.0
    @Published var backgroundColor: VectorColor = .white
    
    @Published var undoStack: [VectorDocument] = []
    @Published var redoStack: [VectorDocument] = []
    
    // Flag to track when we're in an undo/redo operation to prevent reordering
    internal var isUndoRedoOperation: Bool = false
    
    // PROFESSIONAL TYPOGRAPHY MANAGEMENT
    @Published var fontManager: FontManager = FontManager()
    
    // DEFAULT COLORS FOR NEW SHAPES
    @Published var defaultFillColor: VectorColor = .appleSystem(.systemBlue) // Default fill: macOS system blue
    @Published var defaultStrokeColor: VectorColor = .rgb(RGBColor(red: 1, green: 0, blue: 0)) // Default stroke: red
    @Published var defaultFillOpacity: Double = 1.0  // 100% opacity by default
    @Published var defaultStrokeOpacity: Double = 1.0  // 100% opacity by default
    @Published var defaultStrokeWidth: Double = 1.0  // Default stroke width for new shapes
    
    // DEFAULT STROKE STYLE PROPERTIES FOR NEW SHAPES
    @Published var defaultStrokePlacement: StrokePlacement = .center  // Default stroke placement for new shapes
    @Published var defaultStrokeLineJoin: CGLineJoin = .miter  // Default line join for new shapes
    @Published var defaultStrokeLineCap: CGLineCap = .butt  // Default line cap for new shapes
    @Published var defaultStrokeMiterLimit: Double = 10.0  // Default miter limit for new shapes
    
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
    

    
    init(settings: DocumentSettings = DocumentSettings()) {
        self.settings = settings
        
        // Initialize separate swatch arrays with defaults
        self.rgbSwatches = Self.createDefaultRGBSwatches()
        self.cmykSwatches = Self.createDefaultCMYKSwatches()
        self.hsbSwatches = Self.createDefaultHSBSwatches()
        
        self.selectedLayerIndex = nil // Will be set after layer creation
        self.selectedShapeIDs = []
        self.selectedTextIDs = [] // PROFESSIONAL TEXT SUPPORT
        self.textObjects = [] // PROFESSIONAL TEXT OBJECTS
        self.currentTool = .brush
        self.scalingAnchor = .center
        self.viewMode = .color
        self.zoomLevel = 1.0
        self.canvasOffset = .zero
        self.showRulers = settings.showRulers
        self.showGrid = settings.showGrid
        self.snapToGrid = settings.snapToGrid
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
        // Logging removed
        
        // Set up settings change observation
        setupSettingsObservation()
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
    
    // MARK: - Canvas Management (User's Brilliant Solution!)
    

    
    deinit {}
        
    
    private func applyScalingToShape(
        shapeId: UUID,
        scaleX: CGFloat,
        scaleY: CGFloat,
        initialTransform: CGAffineTransform,
        initialBounds: CGRect
    ) {
        // Find the shape across all layers
        for layerIndex in layers.indices {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeId }) {
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
                layers[layerIndex].shapes[shapeIndex].transform = newTransform
                
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
        let shape = layers[layerIndex].shapes[shapeIndex]
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
        layers[layerIndex].shapes[shapeIndex].path = transformedPath
        layers[layerIndex].shapes[shapeIndex].transform = .identity
        layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        Log.info("✅ Shape coordinates updated - object origin now follows object position", category: .fileOperations)
    }


    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case settings, layers, rgbSwatches, cmykSwatches, hsbSwatches, selectedLayerIndex, selectedShapeIDs, selectedTextIDs, textObjects, currentTool, viewMode, zoomLevel, canvasOffset, showRulers, snapToGrid, defaultFillColor, defaultStrokeColor, defaultFillOpacity, defaultStrokeOpacity, defaultStrokeWidth, defaultStrokePlacement, defaultStrokeLineJoin, defaultStrokeLineCap, defaultStrokeMiterLimit, unifiedObjects
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(DocumentSettings.self, forKey: .settings)
        layers = try container.decode([VectorLayer].self, forKey: .layers)
        
        // Load separate swatch arrays, fallback to defaults if not found
        rgbSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .rgbSwatches) ?? Self.createDefaultRGBSwatches()
        cmykSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .cmykSwatches) ?? Self.createDefaultCMYKSwatches()
        hsbSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .hsbSwatches) ?? Self.createDefaultHSBSwatches()
        
        selectedLayerIndex = try container.decodeIfPresent(Int.self, forKey: .selectedLayerIndex)
        selectedShapeIDs = try container.decode(Set<UUID>.self, forKey: .selectedShapeIDs)
        selectedTextIDs = try container.decodeIfPresent(Set<UUID>.self, forKey: .selectedTextIDs) ?? []
        textObjects = try container.decodeIfPresent([VectorText].self, forKey: .textObjects) ?? []
        currentTool = try container.decode(DrawingTool.self, forKey: .currentTool)
        viewMode = try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .color
        zoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        canvasOffset = try container.decode(CGPoint.self, forKey: .canvasOffset)
        showRulers = try container.decode(Bool.self, forKey: .showRulers)
        snapToGrid = try container.decode(Bool.self, forKey: .snapToGrid)
        undoStack = []
        redoStack = []
        fontManager = FontManager() // PROFESSIONAL FONT MANAGEMENT
        
        // DEFAULT COLORS FOR NEW SHAPES
        defaultFillColor = try container.decodeIfPresent(VectorColor.self, forKey: .defaultFillColor) ?? .white // Professional default
        defaultStrokeColor = try container.decodeIfPresent(VectorColor.self, forKey: .defaultStrokeColor) ?? .black // Professional default
        defaultFillOpacity = try container.decodeIfPresent(Double.self, forKey: .defaultFillOpacity) ?? 1.0
        defaultStrokeOpacity = try container.decodeIfPresent(Double.self, forKey: .defaultStrokeOpacity) ?? 1.0
        defaultStrokeWidth = try container.decodeIfPresent(Double.self, forKey: .defaultStrokeWidth) ?? 1.0
        defaultStrokePlacement = try container.decodeIfPresent(StrokePlacement.self, forKey: .defaultStrokePlacement) ?? .center
        defaultStrokeLineJoin = try container.decodeIfPresent(CGLineJoin.self, forKey: .defaultStrokeLineJoin) ?? .miter
        defaultStrokeLineCap = try container.decodeIfPresent(CGLineCap.self, forKey: .defaultStrokeLineCap) ?? .butt
        defaultStrokeMiterLimit = try container.decodeIfPresent(Double.self, forKey: .defaultStrokeMiterLimit) ?? 10.0
        
        // CRITICAL FIX: Load unified objects array to preserve order during undo/redo
        unifiedObjects = try container.decodeIfPresent([VectorObject].self, forKey: .unifiedObjects) ?? []
        
        // CRITICAL FIX: Only populate unified objects if they don't exist (for new documents)
        if unifiedObjects.isEmpty {
            populateUnifiedObjectsFromLayersPreservingOrder()
        }
    }
    

    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(settings, forKey: .settings)
        try container.encode(layers, forKey: .layers)
        
        // Save separate swatch arrays
        try container.encode(rgbSwatches, forKey: .rgbSwatches)
        try container.encode(cmykSwatches, forKey: .cmykSwatches)
        try container.encode(hsbSwatches, forKey: .hsbSwatches)
        
        try container.encodeIfPresent(selectedLayerIndex, forKey: .selectedLayerIndex)
        try container.encode(selectedShapeIDs, forKey: .selectedShapeIDs)
        try container.encode(selectedTextIDs, forKey: .selectedTextIDs)
        try container.encode(textObjects, forKey: .textObjects)
        try container.encode(currentTool, forKey: .currentTool)
        try container.encode(viewMode, forKey: .viewMode)
        try container.encode(zoomLevel, forKey: .zoomLevel)
        try container.encode(canvasOffset, forKey: .canvasOffset)
        try container.encode(showRulers, forKey: .showRulers)
        try container.encode(snapToGrid, forKey: .snapToGrid)
        try container.encode(defaultFillColor, forKey: .defaultFillColor)
        try container.encode(defaultStrokeColor, forKey: .defaultStrokeColor)
        try container.encode(defaultFillOpacity, forKey: .defaultFillOpacity)
        try container.encode(defaultStrokeOpacity, forKey: .defaultStrokeOpacity)
        try container.encode(defaultStrokeWidth, forKey: .defaultStrokeWidth)
        try container.encode(defaultStrokePlacement, forKey: .defaultStrokePlacement)
        try container.encode(defaultStrokeLineJoin, forKey: .defaultStrokeLineJoin)
        try container.encode(defaultStrokeLineCap, forKey: .defaultStrokeLineCap)
        try container.encode(defaultStrokeMiterLimit, forKey: .defaultStrokeMiterLimit)
        try container.encode(unifiedObjects, forKey: .unifiedObjects)
    }
    

    

    



    

    

    

    
    // MARK: - PROFESSIONAL STROKE OUTLINING
    /// Converts selected strokes to outlined filled paths ("Outline Stroke" feature)

    

    

    
    // MARK: - PROFESSIONAL PATHFINDER OPERATIONS
    
    /// Performs pathfinder operations following

    



    

    

    

    

    

}
