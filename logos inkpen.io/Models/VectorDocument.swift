//
//  VectorDocument.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI

// MARK: - Units
enum MeasurementUnit: String, CaseIterable, Codable {
    case inches = "Inches"
    case centimeters = "Centimeters"
    case millimeters = "Millimeters"
    case points = "Points"
    case pixels = "Pixels"
    case picas = "Picas"
    
    var abbreviation: String {
        switch self {
        case .inches: return "in"
        case .centimeters: return "cm"
        case .millimeters: return "mm"
        case .points: return "pt"
        case .pixels: return "px"
        case .picas: return "pc"
        }
    }
    
    var pointsPerUnit: Double {
        switch self {
        case .inches: return 72.0
        case .centimeters: return 28.346
        case .millimeters: return 2.835
        case .points: return 1.0
        case .pixels: return 1.0 // Assuming 72 DPI
        case .picas: return 12.0
        }
    }
}

// MARK: - Document Settings
struct DocumentSettings: Codable, Hashable {
    var width: Double
    var height: Double
    var unit: MeasurementUnit
    var colorMode: ColorMode
    var resolution: Double // DPI
    var showRulers: Bool
    var showGrid: Bool
    var snapToGrid: Bool
    var gridSpacing: Double
    var backgroundColor: VectorColor
    
    init(width: Double = 11.0, height: Double = 8.5, unit: MeasurementUnit = .inches, colorMode: ColorMode = .rgb, resolution: Double = 72.0, showRulers: Bool = true, showGrid: Bool = false, snapToGrid: Bool = false, gridSpacing: Double = 0.125, backgroundColor: VectorColor = .white) {
        self.width = width
        self.height = height
        self.unit = unit
        self.colorMode = colorMode
        self.resolution = resolution
        self.showRulers = showRulers
        self.showGrid = showGrid
        self.snapToGrid = snapToGrid
        self.gridSpacing = gridSpacing
        self.backgroundColor = backgroundColor
    }
    
    var sizeInPoints: CGSize {
        let pointsPerUnit = unit.pointsPerUnit
        return CGSize(width: width * pointsPerUnit, height: height * pointsPerUnit)
    }
}

// MARK: - Zoom Request System
enum ZoomMode: Equatable {
    case zoomIn
    case zoomOut
    case fitToPage
    case actualSize
    case custom(CGPoint) // Custom zoom with focal point
}

struct ZoomRequest: Equatable {
    let targetZoom: CGFloat
    let mode: ZoomMode
    let timestamp: Date
    
    init(targetZoom: CGFloat, mode: ZoomMode) {
        self.targetZoom = targetZoom
        self.mode = mode
        self.timestamp = Date()
    }
}

// MARK: - Vector Document
class VectorDocument: ObservableObject, Codable {
    @Published var settings: DocumentSettings
    @Published var layers: [VectorLayer] = []
    @Published var layerIndex: Int = 0
    @Published var pasteboard: VectorLayer = VectorLayer(name: "Pasteboard")
    
    @Published var selectedLayerIndex: Int?
    @Published var selectedShapeIDs: Set<UUID> = []
    @Published var selectedTextIDs: Set<UUID> = [] // PROFESSIONAL TEXT SUPPORT
    
    // SIMPLIFIED SWATCH SYSTEM - Three separate modifiable arrays
    @Published var rgbSwatches: [VectorColor] = []
    @Published var cmykSwatches: [VectorColor] = []
    @Published var hsbSwatches: [VectorColor] = []
    
    // CRITICAL FIX: Shared state to prevent double transformations  
    @Published var isHandleScalingActive = false // Set by SelectionHandles, checked by canvas gesture
    @Published var textObjects: [VectorText] = [] // PROFESSIONAL TEXT OBJECTS
    @Published var currentTool: DrawingTool = .selection
    @Published var scalingAnchor: ScalingAnchor = .center // NEW: Scaling anchor point selection
    @Published var rotationAnchor: RotationAnchor = .center // NEW: Rotation anchor point selection
    @Published var shearAnchor: ShearAnchor = .center // NEW: Shear anchor point selection
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
    
    // PROFESSIONAL TYPOGRAPHY MANAGEMENT
    @Published var fontManager: FontManager = FontManager()
    
    // DEFAULT COLORS FOR NEW SHAPES
    @Published var defaultFillColor: VectorColor = .white // Professional default: white fill
    @Published var defaultStrokeColor: VectorColor = .black // Professional default: black stroke
    @Published var defaultFillOpacity: Double = 1.0  // 100% opacity by default
    @Published var defaultStrokeOpacity: Double = 1.0  // 100% opacity by default
    
    // ACTIVE COLOR STATE
    @Published var activeColorTarget: ColorTarget = .fill // Which color is currently active for editing
    
    private let maxUndoStackSize = 50
    

    
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
        self.currentTool = .selection
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
        
        // Set the selected layer index to working layer (not canvas or pasteboard)
        self.selectedLayerIndex = 2 // Working layer is now at index 2
        print("🎯 SELECTED LAYER INDEX: \(self.selectedLayerIndex ?? -1)")
        print("🎯 INITIALIZATION COMPLETE - Ready to draw!")
        print("=" + String(repeating: "=", count: 50))
        
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
    

    
    /// Creates Pasteboard, Canvas, and working layers in correct order (pasteboard behind everything)
    private func createCanvasAndWorkingLayers() {
        // CRITICAL DEBUG: Clear any existing layers first to ensure proper order
        layers.removeAll()
        
        // Create Pasteboard layer FIRST (index 0) - working area behind everything
        var pasteboardLayer = VectorLayer(name: "Pasteboard")
        pasteboardLayer.isLocked = true  // Pasteboard should be LOCKED to prevent interference
        
        // Calculate pasteboard size (10x larger than canvas, same aspect ratio)
        let canvasSize = settings.sizeInPoints
        let pasteboardSize = CGSize(width: canvasSize.width * 10, height: canvasSize.height * 10)
        
        // Calculate pasteboard position (centered on canvas)
        let pasteboardOrigin = CGPoint(
            x: (canvasSize.width - pasteboardSize.width) / 2,
            y: (canvasSize.height - pasteboardSize.height) / 2
        )
        
        let pasteboardRect = VectorShape.rectangle(
            at: pasteboardOrigin,
            size: pasteboardSize
        )
        var pasteboardShape = pasteboardRect
        pasteboardShape.fillStyle = FillStyle(color: .black, opacity: 0.2)  // 20% black
        pasteboardShape.strokeStyle = nil
        pasteboardShape.name = "Pasteboard Background"
        pasteboardLayer.addShape(pasteboardShape)
        layers.append(pasteboardLayer)
        print("📋 CREATED PASTEBOARD LAYER: Pasteboard (index 0) - BEHIND everything")
        
        // Create Canvas layer SECOND (index 1) - canvas layer, LOCKED by default
        var canvasLayer = VectorLayer(name: "Canvas")
        canvasLayer.isLocked = true  // Canvas should be locked by default
        let canvasRect = VectorShape.rectangle(
            at: CGPoint(x: 0, y: 0),
            size: settings.sizeInPoints
        )
        var backgroundShape = canvasRect
        backgroundShape.fillStyle = FillStyle(color: settings.backgroundColor, opacity: 1.0)
        backgroundShape.strokeStyle = nil
        backgroundShape.name = "Canvas Background"
        canvasLayer.addShape(backgroundShape)
        layers.append(canvasLayer)
        print("📋 CREATED CANVAS LAYER: Canvas (index 1)")
        
        // Create working layer THIRD (index 2) - for actual drawing
        layers.append(VectorLayer(name: "Layer 1"))
        print("📋 CREATED WORKING LAYER: Layer 1 (index 2)")
        
        // DEBUG: Print actual layer order to verify
        debugLayerOrder()
    }
    
    /// Debug function to print current layer order
    func debugLayerOrder() {
        print("🔍 CURRENT LAYER ORDER:")
        for (index, layer) in layers.enumerated() {
            print("   Index \(index): '\(layer.name)' - shapes: \(layer.shapes.count)")
        }
        print("   Layers panel shows these REVERSED (index \(layers.count-1) at top)")
    }
    
    /// Update pasteboard layer to match canvas size and center it
    func updatePasteboardLayer() {
        guard layers.count > 0,
              layers[0].name == "Pasteboard",
              let pasteboardShape = layers[0].shapes.first(where: { $0.name == "Pasteboard Background" }) else {
            print("⚠️ Cannot update pasteboard - pasteboard layer not found")
            return
        }
        
        let canvasSize = settings.sizeInPoints
        let pasteboardSize = CGSize(width: canvasSize.width * 10, height: canvasSize.height * 10)
        
        // Calculate pasteboard position (centered on canvas)
        let pasteboardOrigin = CGPoint(
            x: (canvasSize.width - pasteboardSize.width) / 2,
            y: (canvasSize.height - pasteboardSize.height) / 2
        )
        
        // Find the pasteboard shape and update it
        if let pasteboardIndex = layers[0].shapes.firstIndex(where: { $0.name == "Pasteboard Background" }) {
            let newPasteboardRect = VectorShape.rectangle(
                at: pasteboardOrigin,
                size: pasteboardSize
            )
            var updatedPasteboardShape = newPasteboardRect
            updatedPasteboardShape.fillStyle = FillStyle(color: .black, opacity: 0.2)  // 20% black
            updatedPasteboardShape.strokeStyle = nil
            updatedPasteboardShape.name = "Pasteboard Background"
            updatedPasteboardShape.id = pasteboardShape.id  // Keep the same ID
            
            layers[0].shapes[pasteboardIndex] = updatedPasteboardShape
            
            print("📐 Updated pasteboard: \(pasteboardSize) at \(pasteboardOrigin)")
        }
    }
    

    

    

    

    

    
    /// Gets document bounds using standard document size (no Canvas-specific logic)
    var documentBounds: CGRect {
        return CGRect(origin: .zero, size: settings.sizeInPoints)
    }
    

    
    /// Debug function to print current document state
    func debugCurrentState() {
        print("🔍 DOCUMENT DEBUG STATE:")
        print("   Total layers: \(layers.count)")
        print("   Selected layer index: \(selectedLayerIndex ?? -1)")
        for (index, layer) in layers.enumerated() {
            let marker = (selectedLayerIndex == index) ? "👈" : "  "
            print("   \(marker) Layer \(index): '\(layer.name)' - locked: \(layer.isLocked), visible: \(layer.isVisible), shapes: \(layer.shapes.count)")
        }
        print("   Selected shapes: \(selectedShapeIDs.count)")
        print("   Current tool: \(currentTool)")
    }
    
    // MARK: - Document Properties for Professional Export
    
    /// Professional document unit system
    var documentUnits: VectorUnit {
        get {
            switch settings.unit {
            case .inches: return .inches
            case .centimeters: return .millimeters // Map centimeters to millimeters for export
            case .millimeters: return .millimeters
            case .points: return .points
            case .pixels: return .points // Treat pixels as points for compatibility
            case .picas: return .points // Convert picas to points for compatibility
            }
        }
    }
    
    /// Calculate document bounds encompassing all content
    func getDocumentBounds() -> CGRect {
        var documentBounds = CGRect.zero
        var hasContent = false
        
        // Include all visible shapes from all layers
        for layer in layers {
            guard layer.isVisible else { continue }
            
            for shape in layer.shapes {
                guard shape.isVisible else { continue }
                
                let shapeBounds = shape.bounds
                if !hasContent {
                    documentBounds = shapeBounds
                    hasContent = true
                } else {
                    documentBounds = documentBounds.union(shapeBounds)
                }
            }
        }
        
        // Include all visible text objects
        for textObj in textObjects {
            guard textObj.isVisible else { continue }
            
            let textBounds = textObj.bounds
            if !hasContent {
                documentBounds = textBounds
                hasContent = true
            } else {
                documentBounds = documentBounds.union(textBounds)
            }
        }
        
        // If no content, use document settings as bounds
        if !hasContent {
            documentBounds = CGRect(origin: .zero, size: settings.sizeInPoints)
        }
        
        return documentBounds
    }
    
    deinit {}
    
    /// Set up observation for settings changes to update pasteboard
    private func setupSettingsObservation() {
        // Since settings is a struct, we can't directly observe individual properties
        // Instead, we'll provide a method that should be called when settings change
        print("🔧 Settings observation setup complete")
    }
    
    /// Call this method whenever document settings change to update pasteboard
    func onSettingsChanged() {
        // Update pasteboard when canvas size changes
        updatePasteboardLayer()
        
        // Update any other dependent elements
        objectWillChange.send()
        
        print("🔄 Settings changed - updated pasteboard layer")
    }
        
    
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
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        let shape = layers[layerIndex].shapes[shapeIndex]
        let transform = shape.transform
        
        // Don't apply identity transforms
        if transform.isIdentity {
            return
        }
        
        print("🔧 Applying transform to shape coordinates: \(shape.name)")
        
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
        
        print("✅ Shape coordinates updated - object origin now follows object position")
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case settings, layers, rgbSwatches, cmykSwatches, hsbSwatches, selectedLayerIndex, selectedShapeIDs, selectedTextIDs, textObjects, currentTool, viewMode, zoomLevel, canvasOffset, showRulers, snapToGrid, defaultFillColor, defaultStrokeColor, defaultFillOpacity, defaultStrokeOpacity
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
    }
    
    // MARK: - Layer Management
    
    /// Rename a layer at the specified index
    func renameLayer(at index: Int, to newName: String) {
        guard index >= 0 && index < layers.count else {
            print("❌ Invalid layer index for rename: \(index)")
            return
        }
        
        // Don't allow renaming Canvas layer
        if index == 0 && layers[index].name == "Canvas" {
            print("🚫 Cannot rename Canvas layer")
            return
        }
        
        let oldName = layers[index].name
        layers[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        saveToUndoStack()
        print("✏️ Renamed layer '\(oldName)' to '\(layers[index].name)'")
    }
    
    /// Duplicate a layer at the specified index
    func duplicateLayer(at index: Int) {
        guard index >= 0 && index < layers.count else {
            print("❌ Invalid layer index for duplicate: \(index)")
            return
        }
        
        // Don't allow duplicating Canvas layer
        if index == 0 && layers[index].name == "Canvas" {
            print("🚫 Cannot duplicate Canvas layer")
            return
        }
        
        saveToUndoStack()
        
        let originalLayer = layers[index]
        var duplicatedLayer = VectorLayer(name: "\(originalLayer.name) Copy")
        
        // Copy all properties
        duplicatedLayer.isVisible = originalLayer.isVisible
        duplicatedLayer.isLocked = originalLayer.isLocked
        duplicatedLayer.opacity = originalLayer.opacity
        
        // Deep copy all shapes with new IDs
        for shape in originalLayer.shapes {
            var duplicatedShape = shape
            duplicatedShape.id = UUID() // New unique ID
            duplicatedLayer.shapes.append(duplicatedShape)
        }
        
        // Insert the duplicated layer right after the original
        layers.insert(duplicatedLayer, at: index + 1)
        
        // Select the new layer
        selectedLayerIndex = index + 1
        
        print("📋 Duplicated layer '\(originalLayer.name)' to '\(duplicatedLayer.name)'")
    }
    
    /// Move a layer from one index to another
    func moveLayer(from sourceIndex: Int, to targetIndex: Int) {
        guard sourceIndex >= 0 && sourceIndex < layers.count,
              targetIndex >= 0 && targetIndex <= layers.count,  // Allow targetIndex == layers.count for "move to top"
              sourceIndex != targetIndex else {
            print("❌ Invalid layer indices for move: source=\(sourceIndex), target=\(targetIndex)")
            return
        }
        
        // PROTECT PASTEBOARD LAYER: Never allow Pasteboard layer to be moved
        if sourceIndex == 0 && layers[sourceIndex].name == "Pasteboard" {
            print("🚫 Cannot move Pasteboard layer - it must remain at the bottom")
            return
        }
        
        // PROTECT CANVAS LAYER: Never allow Canvas layer to be moved
        if sourceIndex == 1 && layers[sourceIndex].name == "Canvas" {
            print("🚫 Cannot move Canvas layer - it must remain above pasteboard")
            return
        }
        
        // PROTECT PASTEBOARD LAYER: Never allow moving to Pasteboard position
        if targetIndex == 0 {
            print("🚫 Cannot move layers to Pasteboard position (index 0)")
            return
        }
        
        // PROTECT CANVAS LAYER: Never allow moving to Canvas position
        if targetIndex == 1 && targetIndex < layers.count && layers[targetIndex].name == "Canvas" {
            print("🚫 Cannot move layers to Canvas position (index 1)")
            return
        }
        
        saveToUndoStack()
        
        let movingLayer = layers.remove(at: sourceIndex)
        
        // Handle insertion logic
        let adjustedTargetIndex: Int
        if targetIndex == layers.count {
            // Special case: move to top (append to end after removal)
            adjustedTargetIndex = layers.count
            print("🔝 Moving to top position (will be index \(adjustedTargetIndex))")
        } else if sourceIndex < targetIndex {
            // Moving forward in the array - adjust for removal
            adjustedTargetIndex = targetIndex - 1
        } else {
            // Moving backward in the array - no adjustment needed
            adjustedTargetIndex = targetIndex
        }
        
        layers.insert(movingLayer, at: adjustedTargetIndex)
        
        // Update selected layer index to follow the moved layer
        if selectedLayerIndex == sourceIndex {
            selectedLayerIndex = adjustedTargetIndex
        } else if let selectedIndex = selectedLayerIndex {
            // Adjust selection if it was affected by the move
            if sourceIndex < selectedIndex && adjustedTargetIndex >= selectedIndex {
                selectedLayerIndex = selectedIndex - 1
            } else if sourceIndex > selectedIndex && adjustedTargetIndex <= selectedIndex {
                selectedLayerIndex = selectedIndex + 1
            }
        }
        
        print("🔄 Moved layer '\(movingLayer.name)' from index \(sourceIndex) to \(adjustedTargetIndex)")
    }
    
    func addLayer(name: String = "New Layer") {
        layers.append(VectorLayer(name: name))
        selectedLayerIndex = layers.count - 1
    }
    
    func removeLayer(at index: Int) {
        // Allow deletion of any layer, just prevent deleting the last layer
        guard index >= 0 && index < layers.count && layers.count > 1 else { 
            print("⚠️ Cannot remove last remaining layer")
            return 
        }
        layers.remove(at: index)
        if selectedLayerIndex == index {
            selectedLayerIndex = min(index, layers.count - 1)
        } else if let selected = selectedLayerIndex, selected > index {
            selectedLayerIndex = selected - 1
        }
    }
    

    


    // MARK: - Shape Management
    func addShape(_ shape: VectorShape) {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        layers[layerIndex].addShape(shape)
        selectedShapeIDs = [shape.id]
    }
    
    func removeSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        layers[layerIndex].shapes.removeAll { selectedShapeIDs.contains($0.id) }
        selectedShapeIDs.removeAll()
    }
    
    /// Gets all currently selected shapes across all layers
    func getSelectedShapes() -> [VectorShape] {
        var selectedShapes: [VectorShape] = []
        
        for layer in layers {
            for shape in layer.shapes {
                if selectedShapeIDs.contains(shape.id) {
                    selectedShapes.append(shape)
                }
            }
        }
        
        return selectedShapes
    }
    
    /// Gets all currently selected shapes in correct STACKING ORDER (bottom→top)
    /// This is critical for pathfinder operations
    func getSelectedShapesInStackingOrder() -> [VectorShape] {
        var stackingOrderShapes: [VectorShape] = []
        
        // Process layers from bottom to top (first layer = bottom)
        for layer in layers {
            // Process shapes within layer from bottom to top (first shape = bottom)
            for shape in layer.shapes {
                if selectedShapeIDs.contains(shape.id) {
                    stackingOrderShapes.append(shape)
                }
            }
        }
        
        return stackingOrderShapes
    }
    
    /// Selects a shape by its ID (clears other selections)
    func selectShape(_ shapeID: UUID) {
        selectedShapeIDs = [shapeID]
        selectedTextIDs.removeAll() // Clear text selection (mutually exclusive)
    }
    
    /// Adds a shape to the current selection (multi-select)
    func addToSelection(_ shapeID: UUID) {
        selectedShapeIDs.insert(shapeID)
        selectedTextIDs.removeAll() // Clear text selection (mutually exclusive)
    }
    
    /// PROFESSIONAL SELECT ALL
    func selectAll() {
        guard let layerIndex = selectedLayerIndex else { return }
        
        // Select all visible, unlocked shapes on current layer
        var allShapeIDs: Set<UUID> = []
        for shape in layers[layerIndex].shapes {
            if shape.isVisible && !shape.isLocked {
                allShapeIDs.insert(shape.id)
            }
        }
        
        // Also select all visible, unlocked text objects
        var allTextIDs: Set<UUID> = []
        for textObj in textObjects {
            if textObj.isVisible && !textObj.isLocked {
                allTextIDs.insert(textObj.id)
            }
        }
        
        // Professional behavior: If shapes exist, select shapes; otherwise select text
        if !allShapeIDs.isEmpty {
            selectedShapeIDs = allShapeIDs
            selectedTextIDs.removeAll() // Mutually exclusive
            print("🎯 SELECT ALL: Selected \(allShapeIDs.count) shapes")
        } else if !allTextIDs.isEmpty {
            selectedTextIDs = allTextIDs
            selectedShapeIDs.removeAll() // Mutually exclusive
            print("🎯 SELECT ALL: Selected \(allTextIDs.count) text objects")
        } else {
            print("🎯 SELECT ALL: No selectable objects found")
        }
    }
    
    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        let shapesToDuplicate = layers[layerIndex].shapes.filter { selectedShapeIDs.contains($0.id) }
        var newShapeIDs: Set<UUID> = []
        
        for shape in shapesToDuplicate {
            var newShape = shape
            newShape.id = UUID() // 🎯 CRITICAL: Generate new ID for duplicate
            
            // PROFESSIONAL COORDINATE SYSTEM: Apply offset to actual coordinates instead of using transform
            // This ensures object origin follows object position
            let offsetTransform = CGAffineTransform(translationX: 10, y: 10)
            newShape = applyTransformToShapeCoordinates(shape: newShape, transform: offsetTransform)
            newShape.updateBounds()
            layers[layerIndex].addShape(newShape)
            newShapeIDs.insert(newShape.id)
        }
        
        selectedShapeIDs = newShapeIDs
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM: Apply transform to shape coordinates
    /// Returns a new shape with transformed coordinates and identity transform
    private func applyTransformToShapeCoordinates(shape: VectorShape, transform: CGAffineTransform) -> VectorShape {
        // Don't apply identity transforms
        if transform.isIdentity {
            return shape
        }
        
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
        
        // Create new shape with transformed path and identity transform
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        var newShape = shape
        newShape.path = transformedPath
        newShape.transform = .identity
        
        return newShape
    }
    
    // MARK: - Undo/Redo
    func saveToUndoStack() {
        // Create a copy of the current state
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            undoStack.append(copy)
            
            // Limit undo stack size
            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }
            
            // Clear redo stack when a new action is performed
            redoStack.removeAll()
        } catch {
            print("Error saving to undo stack: \(error)")
        }
    }
    
    func undo() {
        guard !undoStack.isEmpty else { return }
        
        // Save current state to redo stack
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            redoStack.append(copy)
        } catch {
            print("Error saving to redo stack: \(error)")
        }
        
        // Restore previous state
        let previousState = undoStack.removeLast()
        settings = previousState.settings
        layers = previousState.layers
        rgbSwatches = previousState.rgbSwatches
        cmykSwatches = previousState.cmykSwatches
        hsbSwatches = previousState.hsbSwatches
        selectedLayerIndex = previousState.selectedLayerIndex
        selectedShapeIDs = previousState.selectedShapeIDs
        currentTool = previousState.currentTool
        zoomLevel = previousState.zoomLevel
        canvasOffset = previousState.canvasOffset
        showRulers = previousState.showRulers
        snapToGrid = previousState.snapToGrid
    }
    
    func redo() {
        guard !redoStack.isEmpty else { return }
        
        // Save current state to undo stack WITHOUT clearing redo stack
        do {
            let data = try JSONEncoder().encode(self)
            let copy = try JSONDecoder().decode(VectorDocument.self, from: data)
            undoStack.append(copy)
            
            // Limit undo stack size
            if undoStack.count > maxUndoStackSize {
                undoStack.removeFirst()
            }
        } catch {
            print("Error saving to undo stack: \(error)")
        }
        
        // Restore next state (double-check the stack isn't empty)
        guard !redoStack.isEmpty else { 
            print("Warning: Redo stack became empty during redo operation")
            return 
        }
        let nextState = redoStack.removeLast()
        settings = nextState.settings
        layers = nextState.layers
        rgbSwatches = nextState.rgbSwatches
        cmykSwatches = nextState.cmykSwatches
        hsbSwatches = nextState.hsbSwatches
        selectedLayerIndex = nextState.selectedLayerIndex
        selectedShapeIDs = nextState.selectedShapeIDs
        currentTool = nextState.currentTool
        zoomLevel = nextState.zoomLevel
        canvasOffset = nextState.canvasOffset
        showRulers = nextState.showRulers
        snapToGrid = nextState.snapToGrid
    }
    
    // MARK: - Professional Text Management
    func addText(_ text: VectorText) {
        saveToUndoStack()
        textObjects.append(text)
        selectedTextIDs = [text.id]
        selectedShapeIDs.removeAll() // Clear shape selection (mutually exclusive)
    }
    
    func addTextToLayer(_ text: VectorText, layerIndex: Int?) {
        guard let layerIndex = layerIndex,
              layerIndex >= 0 && layerIndex < layers.count else {
            // Fallback to global text objects if no valid layer
            addText(text)
            return
        }
        
        saveToUndoStack()
        
        // Add text to global array (for rendering compatibility)
        textObjects.append(text)
        
        // Associate text with specific layer by storing layer reference
        // Note: We still use global textObjects for rendering, but track layer association
        var modifiedText = text
        modifiedText.layerIndex = layerIndex
        textObjects[textObjects.count - 1] = modifiedText
        
        selectedTextIDs = [text.id]
        selectedShapeIDs.removeAll() // Clear shape selection (mutually exclusive)
        selectedLayerIndex = layerIndex // Select the layer we added text to
        
        print("📝 Added editable text to layer \(layerIndex) (\(layers[layerIndex].name))")
    }
    
    func removeSelectedText() {
        saveToUndoStack()
        textObjects.removeAll { selectedTextIDs.contains($0.id) }
        selectedTextIDs.removeAll()
    }
    
    func duplicateSelectedText() {
        guard !selectedTextIDs.isEmpty else { return }
        saveToUndoStack()
        
        var newTextIDs: Set<UUID> = []
        
        for textID in selectedTextIDs {
            if let originalText = textObjects.first(where: { $0.id == textID }) {
                // Create duplicate with slight offset
                var duplicateText = originalText
                duplicateText.id = UUID() // New unique ID
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10, // 10pt offset
                    y: originalText.position.y + 10
                )
                // CRITICAL FIX: Don't call updateBounds() - preserve original bounds from ProfessionalTextCanvas
                // duplicateText.updateBounds() - REMOVED because it uses old single-line algorithm
                
                textObjects.append(duplicateText)
                newTextIDs.insert(duplicateText.id)
            }
        }
        
        // Select the duplicated text objects
        selectedTextIDs = newTextIDs
        print("✅ Duplicated \(newTextIDs.count) text objects")
    }
    

    
    func updateSelectedTextProperty<T>(_ keyPath: WritableKeyPath<VectorText, T>, value: T) {
        saveToUndoStack()
        for i in textObjects.indices {
            if selectedTextIDs.contains(textObjects[i].id) {
                textObjects[i][keyPath: keyPath] = value
                // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now
                // textObjects[i].updateBounds() - REMOVED because it uses old single-line algorithm
            }
        }
    }
    
    // PROFESSIONAL TEXT TO OUTLINES CONVERSION - USES WORKING PROFESSIONALTEXT IMPLEMENTATION
    func convertSelectedTextToOutlines() {
        guard !selectedTextIDs.isEmpty else { return }
        saveToUndoStack()
        
        let selectedTexts = textObjects.filter { selectedTextIDs.contains($0.id) }
        var newShapeIDs: Set<UUID> = []
        
        for textObj in selectedTexts {
            // CRITICAL: Use ProfessionalTextCanvas convertToPath logic instead of VectorText.convertToOutlines()
            let viewModel = ProfessionalTextViewModel(textObject: textObj, document: self)
            
            // Store current shape count to track new shapes
            let currentShapeCount = layers[selectedLayerIndex ?? 0].shapes.count
            
            // Call the new word-by-word convertToPath method
            viewModel.convertToPath()
            
            // Track new shapes created by conversion
            let newShapeCount = layers[selectedLayerIndex ?? 0].shapes.count
            if newShapeCount > currentShapeCount {
                let newShape = layers[selectedLayerIndex ?? 0].shapes[newShapeCount - 1]
                newShapeIDs.insert(newShape.id)
            }
        }
        
        // CHARACTER-BY-CHARACTER NORMALIZATION: Already done during Core Text processing
        if !newShapeIDs.isEmpty {
            selectedShapeIDs = newShapeIDs
            print("✅ TEXT TO OUTLINES: \(newShapeIDs.count) text object(s) converted with character-by-character normalization")
        }
        
        // Remove the original text objects
        textObjects.removeAll { selectedTextIDs.contains($0.id) }
        selectedTextIDs.removeAll()
        
        print("✅ TEXT TO OUTLINES COMPLETE: Bezier handles now visible with Direct Selection Tool (A)")
    }
    
    func selectTextAt(_ point: CGPoint) -> VectorText? {
        // Search from top to bottom (last drawn first)
        for textObj in textObjects.reversed() {
            if textObj.isVisible && !textObj.isLocked {
                let transformedBounds = textObj.bounds.applying(textObj.transform)
                if transformedBounds.contains(point) {
                    selectedTextIDs = [textObj.id]
                    selectedShapeIDs.removeAll() // Clear shape selection
                    return textObj
                }
            }
        }
        return nil
    }
    
    /// Clear all objects from the document for testing purposes
    func clearAllObjects() {
        saveToUndoStack()
        
        // Clear all shapes from all layers
        for layerIndex in layers.indices {
            layers[layerIndex].shapes.removeAll()
        }
        
        // Clear all text objects
        textObjects.removeAll()
        
        // Clear all selections
        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
        
        print("🧹 Cleared all objects from document")
    }
    
    func updateTextContent(_ textID: UUID, content: String) {
        // PERFORMANCE FIX: Don't save to undo stack on every keystroke - only when editing ends
        // saveToUndoStack() - REMOVED to prevent performance issues during typing
        
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            textObjects[index].content = content
            // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now
            // textObjects[index].updateBounds() - REMOVED because it uses old single-line algorithm
        }
    }
    
    func setTextEditing(_ textID: UUID, isEditing: Bool) {
        // PERFORMANCE FIX: No undo saving for text editing state changes
        // User doesn't want text changes saved to undo stack
        
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            textObjects[index].isEditing = isEditing
        }
    }
    
    func updateTextTypography(_ textID: UUID, update: (inout TypographyProperties) -> Void) {
        // PERFORMANCE FIX: No undo saving for typography changes - user doesn't want text changes saved
        // saveToUndoStack() - REMOVED per user request
        
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            update(&textObjects[index].typography)
            // CRITICAL FIX: Don't call updateBounds() - text canvas manages bounds now  
            // textObjects[index].updateBounds() - REMOVED because it uses old single-line algorithm
        }
    }
    
    // CRITICAL PROFESSIONAL FEATURE: Text to Outlines Conversion
    func convertTextToOutlines(_ textID: UUID) {
        saveToUndoStack()
        
        guard let textIndex = textObjects.firstIndex(where: { $0.id == textID }),
              let layerIndex = selectedLayerIndex else {
            print("❌ Failed to find text or layer for conversion")
            return
        }
        
        let textObject = textObjects[textIndex]
        
        // VALIDATION: Check for empty text content
        guard !textObject.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Cannot convert empty text to outlines. Please type some text first.")
            return
        }
        
        print("🎯 Converting text '\(textObject.content)' to vector outlines...")
        
        // CRITICAL FIX: Use the proper nsFont from typography which includes weight and style
        let attributes: [NSAttributedString.Key: Any] = [
            .font: textObject.typography.nsFont, // This includes proper weight and style
            .kern: textObject.typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: textObject.content, attributes: attributes)
        
        // Create CTFramesetter to generate paths
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        // Calculate text bounds
        let textBounds = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            nil
        )
        
        // Create frame path
        let framePath = CGPath(rect: CGRect(origin: .zero, size: textBounds), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), framePath, nil)
        
        // CRITICAL FIX: Extract all glyph paths and combine into single grouped shape
        var allPathElements: [PathElement] = []
        
        let lines = CTFrameGetLines(frame)
        let lineCount = CFArrayGetCount(lines)
        
        if lineCount > 0 {
            var lineOrigins = [CGPoint](repeating: .zero, count: lineCount)
            CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &lineOrigins)
            
            for lineIndex in 0..<lineCount {
                let line = unsafeBitCast(CFArrayGetValueAtIndex(lines, lineIndex), to: CTLine.self)
                let runs = CTLineGetGlyphRuns(line)
                let runCount = CFArrayGetCount(runs)
                
                for runIndex in 0..<runCount {
                    let run = unsafeBitCast(CFArrayGetValueAtIndex(runs, runIndex), to: CTRun.self)
                    let runAttributes = CTRunGetAttributes(run) as? [String: Any]
                    
                    guard let font = runAttributes?[NSAttributedString.Key.font.rawValue] as? NSFont else { continue }
                    
                    let glyphCount = CTRunGetGlyphCount(run)
                    if glyphCount == 0 { continue }
                    
                    var glyphs = [CGGlyph](repeating: 0, count: glyphCount)
                    var positions = [CGPoint](repeating: .zero, count: glyphCount)
                    
                    CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
                    CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
                    
                    // Convert NSFont to CTFont for proper path creation
                    let ctFont = CTFontCreateWithName(font.fontName as CFString, font.pointSize, nil)
                    let _ = CTFontGetAscent(ctFont)
                    
                    // Convert each glyph to path elements
                    for glyphIndex in 0..<glyphCount {
                        let glyph = glyphs[glyphIndex]
                        let glyphPosition = positions[glyphIndex]
                        
                        if let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
                            // CRITICAL FIX: Apply coordinate system transformation for SwiftUI
                            // Core Graphics uses bottom-left origin, SwiftUI uses top-left
                            var transform = CGAffineTransform(scaleX: 1.0, y: -1.0) // Flip Y-axis
                                .translatedBy(
                                    x: textObject.position.x + Double(glyphPosition.x),
                                    y: -textObject.position.y //- Double(lineOrigins[lineIndex].y)
                                )
                            
                            if let transformedPath = glyphPath.copy(using: &transform) {
                                // Convert transformed CGPath to VectorPath elements
                                let glyphElements = convertCGPathToVectorPathElements(transformedPath)
                                allPathElements.append(contentsOf: glyphElements)
                            }
                        }
                    }
                }
            }
        }
        
        // CRITICAL FIX: Create single grouped shape with all letters combined
        if !allPathElements.isEmpty {
            let vectorPath = VectorPath(elements: allPathElements, isClosed: false) // Let individual letters handle closing
            let outlineShape = VectorShape(
                name: "Text Outline: \(textObject.content)",
                path: vectorPath,
                strokeStyle: textObject.typography.hasStroke ? StrokeStyle(color: textObject.typography.strokeColor, width: textObject.typography.strokeWidth, opacity: textObject.typography.strokeOpacity) : nil,
                fillStyle: FillStyle(color: textObject.typography.fillColor, opacity: textObject.typography.fillOpacity),
                transform: .identity, // No additional transform needed
                isGroup: false // Single unified shape, not a group
            )
            
            // Add to current layer
            layers[layerIndex].shapes.append(outlineShape)
            
            // Remove original text object
            textObjects.remove(at: textIndex)
            selectedTextIDs.remove(textID)
            
            // Select the created outline shape
            selectedShapeIDs = [outlineShape.id]
        }
        // Force UI update
        objectWillChange.send()
    }
    
    // Helper function to convert CGPath to VectorPath elements
    private func convertCGPathToVectorPathElements(_ cgPath: CGPath) -> [PathElement] {
        var elements: [PathElement] = []
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(Double(point.x), Double(point.y))))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control: VectorPoint(Double(control.x), Double(control.y))
                ))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(Double(point.x), Double(point.y)),
                    control1: VectorPoint(Double(control1.x), Double(control1.y)),
                    control2: VectorPoint(Double(control2.x), Double(control2.y))
                ))
                
            case .closeSubpath:
                elements.append(.close)
                
            @unknown default:
                break
            }
        }
        
        return elements
    }
    
    // Helper function to convert CGPath to VectorPath
    private func convertCGPathToVectorPath(_ cgPath: CGPath, offset: CGPoint = .zero) -> VectorPath {
        var elements: [PathElement] = []
        
        cgPath.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            
            switch element.type {
            case .moveToPoint:
                let point = element.points[0]
                elements.append(.move(to: VectorPoint(point.x + offset.x, point.y + offset.y)))
                
            case .addLineToPoint:
                let point = element.points[0]
                elements.append(.line(to: VectorPoint(point.x + offset.x, point.y + offset.y)))
                
            case .addQuadCurveToPoint:
                let control = element.points[0]
                let point = element.points[1]
                elements.append(.quadCurve(
                    to: VectorPoint(point.x + offset.x, point.y + offset.y),
                    control: VectorPoint(control.x + offset.x, control.y + offset.y)
                ))
                
            case .addCurveToPoint:
                let control1 = element.points[0]
                let control2 = element.points[1]
                let point = element.points[2]
                elements.append(.curve(
                    to: VectorPoint(point.x + offset.x, point.y + offset.y),
                    control1: VectorPoint(control1.x + offset.x, control1.y + offset.y),
                    control2: VectorPoint(control2.x + offset.x, control2.y + offset.y)
                ))
                
            case .closeSubpath:
                elements.append(.close)
                
            @unknown default:
                break
            }
        }
        
        return VectorPath(elements: elements, isClosed: elements.contains { if case .close = $0 { return true }; return false })
    }
    
    // MARK: - PROFESSIONAL STROKE OUTLINING
    /// Converts selected strokes to outlined filled paths ("Outline Stroke" feature)
    /// This is critical for professional vector graphics workflows
    func outlineSelectedStrokes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        let shapesToOutline = layers[layerIndex].shapes.filter { selectedShapeIDs.contains($0.id) && $0.strokeStyle != nil }
        var newShapeIDs: Set<UUID> = []
        var originalShapeIDs: Set<UUID> = []
        
        for shape in shapesToOutline {
            guard let strokeStyle = shape.strokeStyle,
                  PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: strokeStyle) else {
                continue
            }
            
            // Create outlined stroke path
            if let outlinedPath = PathOperations.outlineStroke(
                path: shape.path.cgPath,
                strokeStyle: strokeStyle
            ) {
                // 1. Create new shape with outlined stroke path as fill
                var strokeShape = VectorShape(
                    name: "\(shape.name) Stroke",
                    path: VectorPath(cgPath: outlinedPath),
                    strokeStyle: nil, // No stroke since it's now a fill
                    fillStyle: FillStyle(
                        color: strokeStyle.color,
                        opacity: strokeStyle.opacity,
                        blendMode: strokeStyle.blendMode
                    )
                )
                
                // Preserve transform and visibility properties
                strokeShape.transform = shape.transform
                strokeShape.opacity = shape.opacity
                strokeShape.isVisible = shape.isVisible
                strokeShape.isLocked = shape.isLocked
                strokeShape.updateBounds()
                
                // 2. Create or update original shape to have just the fill (no stroke)
                if shape.fillStyle != nil && shape.fillStyle?.color != .clear {
                    // Keep the original shape with fill only
                    var fillShape = shape
                    fillShape.strokeStyle = nil // Remove stroke from original
                    fillShape.name = "\(shape.name) Fill"
                    fillShape.updateBounds()
                    
                    // Find the index of the original shape
                    if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                        // Replace original shape with fill-only version
                        layers[layerIndex].shapes[shapeIndex] = fillShape
                        originalShapeIDs.insert(fillShape.id)
                        
                        // Add stroke shape ABOVE the fill shape
                        layers[layerIndex].shapes.insert(strokeShape, at: shapeIndex + 1)
                        newShapeIDs.insert(strokeShape.id)
                    }
                } else {
                    // No fill, just replace with stroke outline
                    if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
                        layers[layerIndex].shapes[shapeIndex] = strokeShape
                        newShapeIDs.insert(strokeShape.id)
                    }
                }
            }
        }
        
        // Select only the stroke shapes (not the fill shapes)
        selectedShapeIDs = newShapeIDs
    }
    
    /// Checks if outline stroke operation is available for current selection
    var canOutlineStrokes: Bool {
        guard let layerIndex = selectedLayerIndex else { return false }
        
        let shapesWithStrokes = layers[layerIndex].shapes.filter {
            selectedShapeIDs.contains($0.id) && $0.strokeStyle != nil
        }
        
        return !shapesWithStrokes.isEmpty && shapesWithStrokes.allSatisfy { shape in
            guard let strokeStyle = shape.strokeStyle else { return false }
            return PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: strokeStyle)
        }
    }
    
    /// Gets count of selected shapes that have strokes and can be outlined
    var outlineableStrokesCount: Int {
        guard let layerIndex = selectedLayerIndex else { return 0 }
        
        return layers[layerIndex].shapes.filter { shape in
            selectedShapeIDs.contains(shape.id) &&
            shape.strokeStyle != nil &&
            PathOperations.canOutlineStroke(path: shape.path.cgPath, strokeStyle: shape.strokeStyle!)
        }.count
    }
    
    // MARK: - Professional Zoom Management
    
    /// Request a coordinated zoom operation that maintains proper focal point
    func requestZoom(to targetZoom: CGFloat, mode: ZoomMode) {
        let request = ZoomRequest(targetZoom: targetZoom, mode: mode)
        zoomRequest = request
        print("🔍 ZOOM REQUEST: \(mode) → \(String(format: "%.1f", targetZoom * 100))%")
    }
    
    /// Clear zoom request after processing
    func clearZoomRequest() {
        zoomRequest = nil
    }
    
    // MARK: - Color Management - SIMPLIFIED
    func addColorToCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            if !rgbSwatches.contains(color) {
                rgbSwatches.append(color)
            }
        case .cmyk:
            if !cmykSwatches.contains(color) {
                cmykSwatches.append(color)
            }
        case .pms:
            if !hsbSwatches.contains(color) {
                hsbSwatches.append(color)
            }
        }
    }
    
    func addColorSwatch(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }
    
    func addColorToSwatches(_ color: VectorColor) {
        addColorToCurrentMode(color)
    }
    
    func removeColorFromCurrentMode(_ color: VectorColor) {
        switch settings.colorMode {
        case .rgb:
            rgbSwatches.removeAll { $0 == color }
        case .cmyk:
            cmykSwatches.removeAll { $0 == color }
        case .pms:
            hsbSwatches.removeAll { $0 == color }
        }
    }
    
    func setActiveColor(_ color: VectorColor) {
        switch activeColorTarget {
        case .fill:
            defaultFillColor = color
        case .stroke:
            defaultStrokeColor = color
        }
        
        // Apply to selected shapes if any
        guard let layerIndex = selectedLayerIndex else { return }
        
        for shapeID in selectedShapeIDs {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                saveToUndoStack()
                switch activeColorTarget {
                case .fill:
                    if layers[layerIndex].shapes[shapeIndex].fillStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(color: color)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].fillStyle?.color = color
                    }
                case .stroke:
                    if layers[layerIndex].shapes[shapeIndex].strokeStyle == nil {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(color: color)
                    } else {
                        layers[layerIndex].shapes[shapeIndex].strokeStyle?.color = color
                    }
                }
            }
        }
    }
    
    func removeColorSwatch(_ color: VectorColor) {
        removeColorFromCurrentMode(color)
    }
    

    
    // SIMPLIFIED - No longer needed with separate arrays
    func updateColorSwatchesForMode() {
        // Nothing to do - each mode maintains its own array
        print("🎨 Color mode switched to \(settings.colorMode.rawValue)")
    }
    
    // SIMPLIFIED - Create default arrays for each mode
    static func createDefaultRGBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        let rgbColors: [VectorColor] = [
            .rgb(RGBColor(red: 1, green: 0, blue: 0)),     // Red
            .rgb(RGBColor(red: 0, green: 1, blue: 0)),     // Green
            .rgb(RGBColor(red: 0, green: 0, blue: 1)),     // Blue
            .rgb(RGBColor(red: 1, green: 1, blue: 0)),     // Yellow
            .rgb(RGBColor(red: 1, green: 0, blue: 1)),     // Magenta
            .rgb(RGBColor(red: 0, green: 1, blue: 1)),     // Cyan
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5)), // Gray
            .rgb(RGBColor(red: 1, green: 0.5, blue: 0)),   // Orange
            .rgb(RGBColor(red: 0.5, green: 0, blue: 0.5)), // Purple
            .rgb(RGBColor(red: 0, green: 0.5, blue: 0)),   // Dark Green
            .rgb(RGBColor(red: 0, green: 0, blue: 0.5)),   // Dark Blue
            .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0)), // Olive
        ]
        
        let systemColors: [VectorColor] = [
            .appleSystem(.systemBlue),
            .appleSystem(.systemRed),
            .appleSystem(.systemGreen),
            .appleSystem(.systemYellow),
            .appleSystem(.systemOrange),
            .appleSystem(.systemPurple),
            .appleSystem(.systemPink),
            .appleSystem(.systemTeal),
            .appleSystem(.systemIndigo),
            .appleSystem(.systemBrown),
            .appleSystem(.systemGray),
            .appleSystem(.systemGray2),
            .appleSystem(.systemGray3),
            .appleSystem(.label),
            .appleSystem(.secondaryLabel),
            .appleSystem(.link)
        ]
        
        return basicColors + rgbColors + systemColors
    }
    
    static func createDefaultCMYKSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        var cmykColors: [VectorColor] = []
        
        // Professional CMYK color swatches for print production
        let cmykValues = [
            // Primary CMYK colors
            (100, 0, 0, 0),    // Cyan 100%
            (0, 100, 0, 0),    // Magenta 100%
            (0, 0, 100, 0),    // Yellow 100%
            (0, 0, 0, 100),    // Black 100%
            
            // Secondary colors (print mixing)
            (100, 100, 0, 0),  // Blue (C+M)
            (0, 100, 100, 0),  // Red (M+Y)
            (100, 0, 100, 0),  // Green (C+Y)
            
            // Professional print colors
            (100, 0, 0, 25),   // Dark Cyan
            (0, 100, 0, 25),   // Dark Magenta
            (0, 0, 100, 25),   // Dark Yellow
            
            // Grays (K-only for proper neutral grays)
            (0, 0, 0, 25),     // 25% Gray
            (0, 0, 0, 50),     // 50% Gray
            (0, 0, 0, 75),     // 75% Gray
            
            // Rich blacks for professional printing
            (30, 30, 30, 100), // Rich Black (recommended)
            (40, 40, 40, 100), // Super Rich Black
            
            // Professional skin tones (CMYK)
            (0, 30, 45, 0),    // Light Skin
            (0, 40, 60, 10),   // Medium Skin
            (0, 50, 75, 25),   // Dark Skin
        ]
        
        for (c, m, y, k) in cmykValues {
            let cmykColor = CMYKColor(
                cyan: Double(c) / 100.0,
                magenta: Double(m) / 100.0,
                yellow: Double(y) / 100.0,
                black: Double(k) / 100.0
            )
            cmykColors.append(.cmyk(cmykColor))
        }
        
        return basicColors + cmykColors
    }
    
    static func createDefaultHSBSwatches() -> [VectorColor] {
        let basicColors: [VectorColor] = [.black, .white, .clear]
        
        // Create HSB spectrum colors
        var hsbColors: [VectorColor] = []
        
        // Primary hues (every 30 degrees) at full saturation and brightness
        for hue in stride(from: 0, to: 360, by: 30) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 1.0, brightness: 1.0)
            hsbColors.append(.hsb(hsbColor))
        }
        
        // Add some desaturated versions
        for hue in stride(from: 0, to: 360, by: 60) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.5, brightness: 0.8)
            hsbColors.append(.hsb(hsbColor))
        }
        
        // Add some darker versions
        for hue in stride(from: 0, to: 360, by: 90) {
            let hsbColor = HSBColorModel(hue: Double(hue), saturation: 0.8, brightness: 0.5)
            hsbColors.append(.hsb(hsbColor))
        }
        
        return basicColors + hsbColors
    }
    
    // MARK: - PROFESSIONAL PATHFINDER OPERATIONS
    
    /// Performs pathfinder operations following exact Adobe Illustrator behavior
    /// Returns true if the operation was successful, false otherwise
    func performPathfinderOperation(_ operation: PathfinderOperation) -> Bool {
        
        // Get selected shapes in correct STACKING ORDER
        let selectedShapes = getSelectedShapesInStackingOrder()
        guard !selectedShapes.isEmpty else {
            print("❌ No shapes selected for pathfinder operation")
            return false
        }
        
        print("📚 STACKING ORDER: Processing \(selectedShapes.count) shapes")
        for (index, shape) in selectedShapes.enumerated() {
            print("  \(index): \(shape.name) (bottom→top)")
        }
        
        // Convert shapes to CGPaths
        let paths = selectedShapes.map { $0.path.cgPath }
        
        // Validate operation can be performed
        guard ProfessionalPathOperations.canPerformOperation(operation, on: paths) else {
            print("❌ Cannot perform \(operation.rawValue) on selected shapes")
            return false
        }
        
        // Save to undo stack before making changes
        saveToUndoStack()
        
        // Perform the operation using EXACT ADOBE ILLUSTRATOR BEHAVIOR
        var resultShapes: [VectorShape] = []
        
        switch operation {
        // SHAPE MODES
        case .union:
            // UNION: Combines exactly two shapes, result takes color of TOPMOST object
            if let unionPath = ProfessionalPathOperations.union(paths) {
                let topmostShape = selectedShapes.last! // Last in array = topmost in stacking order
                let unionShape = VectorShape(
                    name: "Union Shape",
                    path: VectorPath(cgPath: unionPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unionShape]
                print("✅ UNION: Created unified shape with topmost object's color")
            }
            
        case .minusFront:
            // PUNCH: Front objects subtract from back object, result takes color of BACK object
            guard selectedShapes.count >= 2 else { 
                print("❌ PUNCH requires at least 2 shapes")
                return false 
            }
            
            let backShape = selectedShapes.first!    // First in array = bottommost = back
            let frontShapes = Array(selectedShapes.dropFirst()) // All others = front
            
            print("🔪 PUNCH: Back shape '\(backShape.name)' - Front shapes: \(frontShapes.map { $0.name })")
            
            var resultPath = backShape.path.cgPath
            
            // Subtract each front shape from the result
            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(frontShape.name)' from result")
                }
            }
            
            // Result takes style of BACK object
            let resultShape = VectorShape(
                name: "Punch Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ PUNCH: Result takes back object's color (\(backShape.name))")
            
        case .intersect:
            // INTERSECT: Keep only overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ INTERSECT requires exactly 2 shapes")
                return false
            }
            
            if let intersectedPath = ProfessionalPathOperations.intersect(paths[0], paths[1]) {
                let topmostShape = selectedShapes.last! // Last = topmost
                let intersectedShape = VectorShape(
                    name: "Intersected Shape",
                    path: VectorPath(cgPath: intersectedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [intersectedShape]
                print("✅ INTERSECT: Result takes topmost object's color (\(topmostShape.name))")
            }
            
        case .exclude:
            // EXCLUDE: Remove overlapping areas, result takes color of TOPMOST object
            guard selectedShapes.count == 2 else {
                print("❌ EXCLUDE requires exactly 2 shapes")
                return false
            }
            
            let excludedPaths = ProfessionalPathOperations.exclude(paths[0], paths[1])
            let topmostShape = selectedShapes.last! // Last = topmost
            
            for (index, excludedPath) in excludedPaths.enumerated() {
                let excludedShape = VectorShape(
                    name: "Excluded Shape \(index + 1)",
                    path: VectorPath(cgPath: excludedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes.append(excludedShape)
            }
            print("✅ EXCLUDE: Created \(resultShapes.count) pieces with topmost object's color (\(topmostShape.name))")
        
        // PATHFINDER EFFECTS - These retain original colors
        case .mosaic:
            // MOSAIC: CoreGraphics-based alternative to Divide with curve preservation and perfect color fidelity
            let mosaicResults = CoreGraphicsPathOperations.splitWithShapeTracking(paths, using: .winding)
            
            // Mosaic: Each resulting piece maintains the color of its original shape (like stained glass)
            var shapeCounters: [Int: Int] = [:]
            
            for (mosaicPath, originalShapeIndex) in mosaicResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex]!
                
                let mosaicShape = VectorShape(
                    name: pieceNumber > 1 ? "Mosaic \(originalShape.name) (\(pieceNumber))" : "Mosaic \(originalShape.name)",
                    path: VectorPath(cgPath: mosaicPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mosaicShape)
            }
            print("✅ MOSAIC: Created \(resultShapes.count) pieces - TRUE stained glass effect (ALL visible areas preserved)")
            
        case .cut:
            // CUT: CoreGraphics-based alternative to Trim with curve preservation
            let cutResults = CoreGraphicsPathOperations.cutWithShapeTracking(paths, using: .winding)
            
            // Cut: Each resulting piece maintains the color of its original shape (with curves preserved)
            var shapeCounters: [Int: Int] = [:]
            
            for (cutPath, originalShapeIndex) in cutResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex]!
                
                let cutShape = VectorShape(
                    name: pieceNumber > 1 ? "Cut \(originalShape.name) (\(pieceNumber))" : "Cut \(originalShape.name)",
                    path: VectorPath(cgPath: cutPath),
                    strokeStyle: nil, // CUT removes strokes
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(cutShape)
            }
            
            print("✅ CUT: Created \(resultShapes.count) cut shapes with curves preserved, removed strokes")
            
        case .merge:
            // MERGE: Merge - cut all shapes first (maintain appearance), then merge same colors
            let colors = selectedShapes.compactMap { $0.fillStyle?.color ?? .clear }
            
            guard colors.count == selectedShapes.count else {
                print("❌ MERGE: Could not extract colors from all shapes")
                return false
            }
            
            let mergeResults = ProfessionalPathOperations.professionalMergeWithShapeTracking(paths, colors: colors)
            
            // Merge: Cut-first approach maintains appearance, then same colors get unified, removes strokes
            var shapeCounters: [Int: Int] = [:]
            
            for (mergedPath, originalShapeIndex) in mergeResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                // Track how many pieces we've created from this original shape
                shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                let pieceNumber = shapeCounters[originalShapeIndex]!
                
                let mergedShape = VectorShape(
                    name: pieceNumber > 1 ? "Merged \(originalShape.name) (\(pieceNumber))" : "Merged \(originalShape.name)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil, // MERGE removes strokes
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(mergedShape)
            }
            print("✅ MERGE: Created \(resultShapes.count) color-unified shapes with maintained appearance, removed strokes")
            
        case .crop:
            // CROP: Use topmost shape to crop others, then trim. Top shape becomes invisible.
            let cropResults = ProfessionalPathOperations.professionalCropWithShapeTracking(paths)
            
            // Crop: Each resulting piece maintains the color of its original shape
            var shapeCounters: [Int: Int] = [:]
            
            for (croppedPath, originalShapeIndex, isInvisibleCropShape) in cropResults {
                guard originalShapeIndex < selectedShapes.count else { continue }
                
                let originalShape = selectedShapes[originalShapeIndex]
                
                if isInvisibleCropShape {
                    // Top shape becomes invisible (no fill, no stroke)
                    let invisibleCropShape = VectorShape(
                        name: "Crop Boundary (\(originalShape.name))",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil, // No stroke
                        fillStyle: nil,   // No fill - invisible
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(invisibleCropShape)
                    print("   ✅ Created invisible crop boundary from \(originalShape.name)")
                } else {
                    // Track how many pieces we've created from this original shape
                    shapeCounters[originalShapeIndex] = (shapeCounters[originalShapeIndex] ?? 0) + 1
                    let pieceNumber = shapeCounters[originalShapeIndex]!
                    
                    let croppedShape = VectorShape(
                        name: pieceNumber > 1 ? "Cropped \(originalShape.name) (\(pieceNumber))" : "Cropped \(originalShape.name)",
                        path: VectorPath(cgPath: croppedPath),
                        strokeStyle: nil, // CROP removes strokes
                        fillStyle: originalShape.fillStyle,
                        transform: .identity,
                        opacity: originalShape.opacity
                    )
                    resultShapes.append(croppedShape)
                }
            }
            
            print("✅ CROP: Created \(resultShapes.count) shapes (includes invisible crop boundary), removed strokes")
            
        case .dieline:
            // DIELINE: Apply Divide then convert all results to 1px black strokes with no fill
            let dielinePaths = ProfessionalPathOperations.dieline(paths)
            
            for (index, dielinePath) in dielinePaths.enumerated() {
                let dielineShape = VectorShape(
                    name: "Dieline \(index + 1)",
                    path: VectorPath(cgPath: dielinePath),
                    strokeStyle: StrokeStyle(
                        color: .black,
                        width: 1.0,
                        lineCap: .round,
                        lineJoin: .round
                    ),
                    fillStyle: nil, // DIELINE has no fill - only 1px black stroke
                    transform: .identity,
                    opacity: 1.0
                )
                resultShapes.append(dielineShape)
            }
            print("✅ DIELINE: Created \(resultShapes.count) dieline shapes")
            
        case .separate:
            // SEPARATE: Break compound paths into individual components
            var separatedShapes: [VectorShape] = []
            
            for (shapeIndex, shape) in selectedShapes.enumerated() {
                let components = CoreGraphicsPathOperations.componentsSeparated(shape.path.cgPath, using: .winding)
                
                if components.count <= 1 {
                    // No separation needed, keep original
                    separatedShapes.append(shape)
                    print("   Shape \(shapeIndex + 1): No components to separate")
                } else {
                    // Create separate shapes for each component
                    for (componentIndex, component) in components.enumerated() {
                        let separatedShape = VectorShape(
                            name: components.count > 1 ? "\(shape.name) Component \(componentIndex + 1)" : shape.name,
                            path: VectorPath(cgPath: component),
                            strokeStyle: shape.strokeStyle,
                            fillStyle: shape.fillStyle,
                            transform: shape.transform,
                            opacity: shape.opacity
                        )
                        separatedShapes.append(separatedShape)
                    }
                    print("   Shape \(shapeIndex + 1): Separated into \(components.count) components")
                }
            }
            
            resultShapes = separatedShapes
            print("✅ SEPARATE: Created \(resultShapes.count) individual shapes from \(selectedShapes.count) compound paths")
            
        case .kick:
            // KICK: Back objects subtract from front object, result takes color of FRONT object
            guard selectedShapes.count >= 2 else {
                print("❌ KICK requires at least 2 shapes")
                return false
            }
            
            let frontShape = selectedShapes.last!     // Last in array = topmost = front
            let backShapes = Array(selectedShapes.dropLast()) // All others = back
            
            print("🔪 KICK: Front shape '\(frontShape.name)' - Back shapes: \(backShapes.map { $0.name })")
            
            var resultPath = frontShape.path.cgPath
            
            // Subtract each back shape from the result
            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.kick(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(backShape.name)' from result")
                }
            }
            
            // Result takes style of FRONT object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Kick Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ KICK: Result takes front object's color (\(frontShape.name))")
        }
        
        guard !resultShapes.isEmpty else {
            print("❌ Pathfinder operation \(operation.rawValue) produced no results")
            return false
        }
        
        // Remove original selected shapes
        removeSelectedShapes()
        
        // Add new result shapes and select them
        for resultShape in resultShapes {
            addShape(resultShape)
            selectedShapeIDs.insert(resultShape.id)
        }
        
        return true
    }
    


    // MARK: - Drag and Drop Object Movement Between Layers
    
    /// Move a shape from one layer to another
    func moveShapeToLayer(shapeId: UUID, fromLayerIndex: Int, toLayerIndex: Int) {
        guard fromLayerIndex >= 0 && fromLayerIndex < layers.count,
              toLayerIndex >= 0 && toLayerIndex < layers.count,
              fromLayerIndex != toLayerIndex else {
            print("❌ Invalid layer indices for shape move: from=\(fromLayerIndex), to=\(toLayerIndex)")
            return
        }
        
        // Don't allow moving to locked layers
        if layers[toLayerIndex].isLocked {
            print("🚫 Cannot move objects to locked layer '\(layers[toLayerIndex].name)'")
            return
        }
        
        // Don't allow moving from locked layers unless it's a selection operation
        if layers[fromLayerIndex].isLocked {
            print("🚫 Cannot move objects from locked layer '\(layers[fromLayerIndex].name)'")
            return
        }
        
        // Find and remove the shape from source layer
        guard let shapeIndex = layers[fromLayerIndex].shapes.firstIndex(where: { $0.id == shapeId }) else {
            print("❌ Shape not found in source layer \(fromLayerIndex)")
            return
        }
        
        saveToUndoStack()
        
        let shape = layers[fromLayerIndex].shapes.remove(at: shapeIndex)
        layers[toLayerIndex].shapes.append(shape)
        
        // Update selection to follow the moved shape
        selectedShapeIDs = [shapeId]
        selectedLayerIndex = toLayerIndex
        
        print("✅ Moved shape '\(shape.name)' from layer '\(layers[fromLayerIndex].name)' to '\(layers[toLayerIndex].name)'")
    }
    
    /// Move a text object to a specific layer (conceptually)
    func moveTextToLayer(textId: UUID, toLayerIndex: Int) {
        guard toLayerIndex >= 0 && toLayerIndex < layers.count else {
            print("❌ Invalid layer index for text move: \(toLayerIndex)")
            return
        }
        
        // Don't allow moving to locked layers
        if layers[toLayerIndex].isLocked {
            print("🚫 Cannot move text to locked layer '\(layers[toLayerIndex].name)'")
            return
        }
        
        guard let textIndex = textObjects.firstIndex(where: { $0.id == textId }) else {
            print("❌ Text object not found")
            return
        }
        
        saveToUndoStack()
        
        // Update the text object's layer association
        textObjects[textIndex].layerIndex = toLayerIndex
        
        // Update selection to the target layer
        selectedTextIDs = [textId]
        selectedShapeIDs.removeAll()
        selectedLayerIndex = toLayerIndex
        
        print("✅ Moved text object to layer '\(layers[toLayerIndex].name)'")
    }
    
    /// Handle dropping a draggable object onto a layer
    func handleObjectDrop(_ draggableObject: DraggableVectorObject, ontoLayerIndex: Int) {
        switch draggableObject.objectType {
        case .shape:
            moveShapeToLayer(
                shapeId: draggableObject.objectId,
                fromLayerIndex: draggableObject.sourceLayerIndex,
                toLayerIndex: ontoLayerIndex
            )
        case .text:
            moveTextToLayer(
                textId: draggableObject.objectId,
                toLayerIndex: ontoLayerIndex
            )
        }
    }
    
    // MARK: - Object Arrangement Methods
    
    /// Bring selected shapes to front
    func bringSelectedToFront() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Get selected shapes and remove them from current positions
        var shapes = layers[layerIndex].shapes
        let selectedShapes = shapes.filter { selectedShapeIDs.contains($0.id) }
        shapes.removeAll { selectedShapeIDs.contains($0.id) }
        
        // Add selected shapes to the end (front)
        shapes.append(contentsOf: selectedShapes)
        
        layers[layerIndex].shapes = shapes
        print("⬆️⬆️ Brought to front \(selectedShapeIDs.count) objects")
    }
    
    /// Bring selected shapes forward
    func bringSelectedForward() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Move each selected shape forward by one position
        var shapes = layers[layerIndex].shapes
        
        // Process from back to front to avoid index conflicts
        for i in (0..<shapes.count).reversed() {
            if selectedShapeIDs.contains(shapes[i].id) && i < shapes.count - 1 {
                shapes.swapAt(i, i + 1)
            }
        }
        
        layers[layerIndex].shapes = shapes
        print("⬆️ Brought forward \(selectedShapeIDs.count) objects")
    }
    
    /// Send selected shapes backward
    func sendSelectedBackward() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Move each selected shape backward by one position
        var shapes = layers[layerIndex].shapes
        
        // Process from front to back to avoid index conflicts
        for i in 0..<shapes.count {
            if selectedShapeIDs.contains(shapes[i].id) && i > 0 {
                shapes.swapAt(i, i - 1)
            }
        }
        
        layers[layerIndex].shapes = shapes
        print("⬇️ Sent backward \(selectedShapeIDs.count) objects")
    }
    
    /// Send selected shapes to back
    func sendSelectedToBack() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Get selected shapes and remove them from current positions
        var shapes = layers[layerIndex].shapes
        let selectedShapes = shapes.filter { selectedShapeIDs.contains($0.id) }
        shapes.removeAll { selectedShapeIDs.contains($0.id) }
        
        // Insert selected shapes at the beginning (back)
        shapes.insert(contentsOf: selectedShapes, at: 0)
        
        layers[layerIndex].shapes = shapes
        print("⬇️⬇️ Sent to back \(selectedShapeIDs.count) objects")
    }
    
    // MARK: - Object Grouping Methods
    
    /// Group selected objects
    func groupSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes
        let selectedShapes = layers[layerIndex].shapes.filter { selectedShapeIDs.contains($0.id) }
        
        // Create group from selected shapes
        let groupShape = VectorShape.group(from: selectedShapes, name: "Group")
        
        // Remove individual shapes
        layers[layerIndex].shapes.removeAll { selectedShapeIDs.contains($0.id) }
        
        // Add group
        layers[layerIndex].shapes.append(groupShape)
        selectedShapeIDs = [groupShape.id]
        
        print("📦 Grouped \(selectedShapes.count) objects into group '\(groupShape.name)'")
    }
    
    /// Flatten selected objects (preserves individual colors, enables transform tools)
    func flattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes in stacking order
        let selectedShapes = getSelectedShapesInStackingOrder()
        
        // Calculate overall bounding box for the flattened group
        var combinedBounds = CGRect.zero
        for shape in selectedShapes {
            let shapeBounds = shape.bounds
            if combinedBounds == .zero {
                combinedBounds = shapeBounds
            } else {
                combinedBounds = combinedBounds.union(shapeBounds)
            }
        }
        
        // Create flattened group - preserves all individual shapes and their colors
        // Uses isGroup=true so it transforms as a unit with Scale/Rotate/Shear tools
        // But stores individual shapes in groupedShapes to preserve colors during rendering
        let flattenedShape = VectorShape(
            name: "Flattened Group",
            path: VectorPath(cgPath: CGPath(rect: combinedBounds, transform: nil)), // Invisible container path
            strokeStyle: nil, // No stroke on container - individual shapes have their own
            fillStyle: nil,   // No fill on container - individual shapes have their own
            transform: .identity,
            isGroup: true,    // This makes it work with transform tools as a single unit
            groupedShapes: selectedShapes, // PRESERVE all individual shapes and their colors
            isCompoundPath: false
        )
        
        // Remove original shapes
        removeSelectedShapes()
        
        // Add flattened group
        layers[layerIndex].shapes.append(flattenedShape)
        selectedShapeIDs = [flattenedShape.id]
        
        print("🎨 Flattened \(selectedShapes.count) objects - preserving all colors, enabling transform tools")
    }
    
    /// Ungroup selected objects
    func ungroupSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        var newSelectedShapeIDs: Set<UUID> = []
        var shapesToRemove: [UUID] = []
        var shapesToAdd: [VectorShape] = []
        
        // Process each selected shape
        for shapeID in selectedShapeIDs {
            if let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                let shape = layers[layerIndex].shapes[shapeIndex]
                
                // Check if this shape is a group
                if shape.isGroupContainer {
                    // Extract grouped shapes
                    for groupedShape in shape.groupedShapes {
                        shapesToAdd.append(groupedShape)
                        newSelectedShapeIDs.insert(groupedShape.id)
                    }
                    
                    // Mark group for removal
                    shapesToRemove.append(shapeID)
                    
                    print("📦 Ungrouped '\(shape.name)' containing \(shape.groupedShapes.count) objects")
                } else {
                    // Not a group, keep it selected
                    newSelectedShapeIDs.insert(shapeID)
                }
            }
        }
        
        // Remove groups
        layers[layerIndex].shapes.removeAll { shapesToRemove.contains($0.id) }
        
        // Add ungrouped shapes
        layers[layerIndex].shapes.append(contentsOf: shapesToAdd)
        
        // Update selection
        selectedShapeIDs = newSelectedShapeIDs
        
        if !shapesToRemove.isEmpty {
            print("📦 Ungrouped \(shapesToRemove.count) groups, added \(shapesToAdd.count) objects")
        } else {
            print("📦 No groups found in selection")
        }
    }
    
    /// Unflatten selected objects (restore flattened groups to individual shapes)
    func unflattenSelectedObjects() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first,
              let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == selectedShapeID }) else { return }
        
        let flattenedGroup = layers[layerIndex].shapes[shapeIndex]
        
        // Only unflatten actual groups (flattened shapes)
        guard flattenedGroup.isGroup && !flattenedGroup.groupedShapes.isEmpty else { return }
        
        saveToUndoStack()
        
        // Restore original individual shapes with all their colors preserved
        let restoredShapes = flattenedGroup.groupedShapes
        var newSelectedIDs: Set<UUID> = []
        
        // Generate new IDs for the restored shapes to avoid conflicts
        var shapesToAdd: [VectorShape] = []
        for originalShape in restoredShapes {
            var restoredShape = originalShape
            restoredShape.id = UUID() // New ID to avoid conflicts
            shapesToAdd.append(restoredShape)
            newSelectedIDs.insert(restoredShape.id)
        }
        
        // Remove flattened group
        layers[layerIndex].shapes.remove(at: shapeIndex)
        
        // Add restored individual shapes
        layers[layerIndex].shapes.append(contentsOf: shapesToAdd)
        selectedShapeIDs = newSelectedIDs
        
        print("🎨 Unflattened group - restored \(shapesToAdd.count) individual shapes with original colors")
    }
    
    // MARK: - Compound Path Methods
    
    /// Make compound path from selected objects  
    func makeCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes in stacking order
        let selectedShapes = getSelectedShapesInStackingOrder()
        
        // Combine all paths into a single compound path using even-odd fill rule
        let compoundPath = CGMutablePath()
        for shape in selectedShapes {
            compoundPath.addPath(shape.path.cgPath)
        }
        
        // Create compound path shape with even-odd fill rule to create holes
        let compoundShape = VectorShape(
            name: "Compound Path",
            path: VectorPath(cgPath: compoundPath, fillRule: .evenOdd), // CRITICAL: Even-odd fill rule for holes
            strokeStyle: selectedShapes.last?.strokeStyle, // Use topmost shape's stroke
            fillStyle: selectedShapes.last?.fillStyle,     // Use topmost shape's fill
            transform: .identity,
            isCompoundPath: true
        )
        
        // Remove original shapes
        removeSelectedShapes()
        
        // Add compound path
        layers[layerIndex].shapes.append(compoundShape)
        selectedShapeIDs = [compoundShape.id]
        
        print("🔗 Made compound path from \(selectedShapes.count) objects")
    }
    
    /// Make looping path from selected objects (uses winding fill rule instead of even-odd)
    func makeLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count > 1 else { return }
        
        saveToUndoStack()
        
        // Get selected shapes in stacking order
        let selectedShapes = getSelectedShapesInStackingOrder()
        
        // Combine all paths into a single compound path using winding fill rule
        let loopingPath = CGMutablePath()
        for shape in selectedShapes {
            loopingPath.addPath(shape.path.cgPath)
        }
        
        // Create looping path shape with winding fill rule for overlapping fills
        let loopingShape = VectorShape(
            name: "Looping Path",
            path: VectorPath(cgPath: loopingPath, fillRule: .winding), // CRITICAL: Winding fill rule for overlapping fills
            strokeStyle: selectedShapes.last?.strokeStyle, // Use topmost shape's stroke
            fillStyle: selectedShapes.last?.fillStyle,     // Use topmost shape's fill
            transform: .identity,
            isCompoundPath: true // Use same flag as compound path for compatibility
        )
        
        // Remove original shapes
        removeSelectedShapes()
        
        // Add looping path
        layers[layerIndex].shapes.append(loopingShape)
        selectedShapeIDs = [loopingShape.id]
        
        print("🔄 Made looping path from \(selectedShapes.count) objects using winding fill rule")
    }
    
    /// Release compound path back to individual paths
    func releaseCompoundPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first,
              let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == selectedShapeID }),
              layers[layerIndex].shapes[shapeIndex].isCompoundPath else { return }
        
        saveToUndoStack()
        
        let compoundShape = layers[layerIndex].shapes[shapeIndex]
        
        // Extract individual subpaths from compound path
        let subpaths = extractSubpaths(from: compoundShape.path.cgPath)
        
        // Create individual shapes from each subpath
        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []
        
        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: compoundShape.strokeStyle,
                fillStyle: compoundShape.fillStyle,
                transform: compoundShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }
        
        // Remove compound path
        layers[layerIndex].shapes.remove(at: shapeIndex)
        
        // Add individual paths
        layers[layerIndex].shapes.append(contentsOf: newShapes)
        selectedShapeIDs = newSelectedIDs
        
        print("🔗 Released compound path into \(newShapes.count) individual paths")
    }
    
    /// Release looping path back to individual paths
    func releaseLoopingPath() {
        guard let layerIndex = selectedLayerIndex,
              selectedShapeIDs.count == 1,
              let selectedShapeID = selectedShapeIDs.first,
              let shapeIndex = layers[layerIndex].shapes.firstIndex(where: { $0.id == selectedShapeID }),
              layers[layerIndex].shapes[shapeIndex].isCompoundPath else { return }
        
        saveToUndoStack()
        
        let loopingShape = layers[layerIndex].shapes[shapeIndex]
        
        // Extract individual subpaths from looping path
        let subpaths = extractSubpaths(from: loopingShape.path.cgPath)
        
        // Create individual shapes from each subpath
        var newShapes: [VectorShape] = []
        var newSelectedIDs: Set<UUID> = []
        
        for (index, subpath) in subpaths.enumerated() {
            let individualShape = VectorShape(
                name: "Path \(index + 1)",
                path: VectorPath(cgPath: subpath),
                strokeStyle: loopingShape.strokeStyle,
                fillStyle: loopingShape.fillStyle,
                transform: loopingShape.transform,
                isCompoundPath: false
            )
            newShapes.append(individualShape)
            newSelectedIDs.insert(individualShape.id)
        }
        
        // Remove looping path
        layers[layerIndex].shapes.remove(at: shapeIndex)
        
        // Add individual paths
        layers[layerIndex].shapes.append(contentsOf: newShapes)
        selectedShapeIDs = newSelectedIDs
        
        print("🔄 Released looping path into \(newShapes.count) individual paths")
    }
    
    // Helper function to extract individual subpaths from a compound CGPath
    private func extractSubpaths(from cgPath: CGPath) -> [CGPath] {
        var subpaths: [CGPath] = []
        var currentPath = CGMutablePath()
        
        cgPath.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                // If we have a current path, save it and start a new one
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = CGMutablePath()
                }
                currentPath.move(to: element.points[0])
                
            case .addLineToPoint:
                currentPath.addLine(to: element.points[0])
                
            case .addQuadCurveToPoint:
                currentPath.addQuadCurve(to: element.points[1], control: element.points[0])
                
            case .addCurveToPoint:
                currentPath.addCurve(to: element.points[2], control1: element.points[0], control2: element.points[1])
                
            case .closeSubpath:
                currentPath.closeSubpath()
                
            @unknown default:
                break
            }
        }
        
        // Don't forget the last path if it exists
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }
        
        return subpaths
    }
    
    // MARK: - Warp Object Methods
    
    /// Unwrap selected warp object back to its original shape
    func unwrapWarpObject() {
        guard !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        for layerIndex in layers.indices {
            for shapeIndex in layers[layerIndex].shapes.indices {
                let shape = layers[layerIndex].shapes[shapeIndex]
                
                if selectedShapeIDs.contains(shape.id) && shape.isWarpObject {
                    if let unwrappedShape = shape.unwrapWarpObject() {
                        // Replace warp object with unwrapped shape
                        layers[layerIndex].shapes[shapeIndex] = unwrappedShape
                        
                        // Update selection to the unwrapped shape
                        selectedShapeIDs.remove(shape.id)
                        selectedShapeIDs.insert(unwrappedShape.id)
                        
                        print("✅ UNWRAPPED WARP OBJECT: \(shape.name) → \(unwrappedShape.name)")
                    }
                }
            }
        }
        
        objectWillChange.send()
    }
    
    /// Expand selected warp object to permanently apply the warp transformation
    func expandWarpObject() {
        guard !selectedShapeIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        for layerIndex in layers.indices {
            for shapeIndex in layers[layerIndex].shapes.indices {
                let shape = layers[layerIndex].shapes[shapeIndex]
                
                if selectedShapeIDs.contains(shape.id) && shape.isWarpObject {
                    if let expandedShape = shape.expandWarpObject() {
                        // Replace warp object with expanded shape
                        layers[layerIndex].shapes[shapeIndex] = expandedShape
                        
                        // Update selection to the expanded shape
                        selectedShapeIDs.remove(shape.id)
                        selectedShapeIDs.insert(expandedShape.id)
                        
                        print("✅ EXPANDED WARP OBJECT: \(shape.name) → \(expandedShape.name)")
                    }
                }
            }
        }
        
        objectWillChange.send()
    }
    
    // MARK: - Lock/Unlock Methods
    
    /// Lock selected objects
    func lockSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Lock selected shapes
        for layerIndex in layers.indices {
            for shapeIndex in layers[layerIndex].shapes.indices {
                if selectedShapeIDs.contains(layers[layerIndex].shapes[shapeIndex].id) {
                    layers[layerIndex].shapes[shapeIndex].isLocked = true
                }
            }
        }
        
        // Lock selected text objects
        for textIndex in textObjects.indices {
            if selectedTextIDs.contains(textObjects[textIndex].id) {
                textObjects[textIndex].isLocked = true
            }
        }
        
        print("🔒 Locked \(selectedShapeIDs.count) shapes and \(selectedTextIDs.count) text objects")
        
        // Clear selection since locked objects can't be selected
        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }
    
    /// Unlock all objects on current layer
    func unlockAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }
        
        saveToUndoStack()
        
        var unlockedCount = 0
        
        // Unlock all shapes on current layer
        for shapeIndex in layers[layerIndex].shapes.indices {
            if layers[layerIndex].shapes[shapeIndex].isLocked {
                layers[layerIndex].shapes[shapeIndex].isLocked = false
                unlockedCount += 1
            }
        }
        
        // Unlock all text objects (they're global)
        for textIndex in textObjects.indices {
            if textObjects[textIndex].isLocked {
                textObjects[textIndex].isLocked = false
                unlockedCount += 1
            }
        }
        
        print("🔓 Unlocked \(unlockedCount) objects")
    }
    
    // MARK: - Hide/Show Methods
    
    /// Hide selected objects
    func hideSelectedObjects() {
        guard !selectedShapeIDs.isEmpty || !selectedTextIDs.isEmpty else { return }
        
        saveToUndoStack()
        
        // Hide selected shapes
        for layerIndex in layers.indices {
            for shapeIndex in layers[layerIndex].shapes.indices {
                if selectedShapeIDs.contains(layers[layerIndex].shapes[shapeIndex].id) {
                    layers[layerIndex].shapes[shapeIndex].isVisible = false
                }
            }
        }
        
        // Hide selected text objects
        for textIndex in textObjects.indices {
            if selectedTextIDs.contains(textObjects[textIndex].id) {
                textObjects[textIndex].isVisible = false
            }
        }
        
        print("👁️‍🗨️ Hidden \(selectedShapeIDs.count) shapes and \(selectedTextIDs.count) text objects")
        
        // Clear selection since hidden objects can't be selected
        selectedShapeIDs.removeAll()
        selectedTextIDs.removeAll()
    }
    
    /// Show all objects on current layer
    func showAllObjects() {
        guard let layerIndex = selectedLayerIndex else { return }
        
        saveToUndoStack()
        
        var shownCount = 0
        
        // Show all shapes on current layer
        for shapeIndex in layers[layerIndex].shapes.indices {
            if !layers[layerIndex].shapes[shapeIndex].isVisible {
                layers[layerIndex].shapes[shapeIndex].isVisible = true
                shownCount += 1
            }
        }
        
        // Show all text objects (they're global)
        for textIndex in textObjects.indices {
            if !textObjects[textIndex].isVisible {
                textObjects[textIndex].isVisible = true
                shownCount += 1
            }
        }
        
        print("👁️ Shown \(shownCount) objects")
    }
}

// MARK: - Drawing Tools
enum DrawingTool: String, CaseIterable, Codable {
    case selection = "Selection"
    case directSelection = "Direct Selection"
    case bezierPen = "Bezier Pen"
    case freehand = "Freehand"
    case convertAnchorPoint = "Convert Anchor Point"
    case scale = "Scale"
    case rotate = "Rotate"
    case shear = "Shear"
    case warp = "Warp"
    case font = "Font"
    case line = "Line"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case star = "Star"
    case polygon = "Polygon"
    case eyedropper = "Eyedropper"
    case hand = "Hand"
    case zoom = "Zoom"
    case gradient = "Gradient"
    
    var iconName: String {
        switch self {
        case .selection: return "arrow.up.left"
        case .scale: return "arrow.up.left.and.down.right.and.arrow.up.right.and.down.left"
        case .rotate: return "arrow.clockwise"
        case .shear: return "rectangle.slash"
        case .warp: return "skew"
        case .directSelection: return "cursorarrow.and.square.on.square.dashed"
        case .convertAnchorPoint: return "chevron.up"
        case .bezierPen: return "beziercurve"
        case .freehand: return "scribble"
        case .font: return "textformat"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .star: return "star"
        case .polygon: return "hexagon"
        case .eyedropper: return "eyedropper"
        case .hand: return "hand.raised"
        case .zoom: return "magnifyingglass"
        case .gradient: return "circle.lefthalf.filled"
        }
    }
    
    var cursor: NSCursor {
        switch self {
        case .selection: return .arrow
        case .scale: return .crosshair
        case .rotate: return .crosshair
        case .shear: return .crosshair
        case .warp: return .crosshair
        case .directSelection: return .crosshair
        case .convertAnchorPoint: return .pointingHand
        case .bezierPen: return .crosshair
        case .freehand: return .crosshair
        case .font: return .iBeam
        case .line: return .crosshair
        case .rectangle: return .crosshair
        case .circle: return .crosshair
        case .star: return .crosshair
        case .polygon: return .crosshair
        case .eyedropper: return .crosshair
        case .hand: return .openHand
        case .zoom: return .crosshair
        case .gradient: return .crosshair
        }
    }
}

// MARK: - Transformation Anchor Modes
enum ScalingAnchor: String, CaseIterable, Codable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    
    var iconName: String {
        switch self {
        case .center: return "plus.circle"
        case .topLeft: return "arrow.up.left.circle"
        case .topRight: return "arrow.up.right.circle"
        case .bottomLeft: return "arrow.down.left.circle"
        case .bottomRight: return "arrow.down.right.circle"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

enum RotationAnchor: String, CaseIterable, Codable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    
    var iconName: String {
        switch self {
        case .center: return "plus.circle"
        case .topLeft: return "arrow.up.left.circle"
        case .topRight: return "arrow.up.right.circle"
        case .bottomLeft: return "arrow.down.left.circle"
        case .bottomRight: return "arrow.down.right.circle"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

enum ShearAnchor: String, CaseIterable, Codable {
    case center = "Center"
    case topLeft = "Top Left"
    case topRight = "Top Right"
    case bottomLeft = "Bottom Left"
    case bottomRight = "Bottom Right"
    
    var iconName: String {
        switch self {
        case .center: return "plus.circle"
        case .topLeft: return "arrow.up.left.circle"
        case .topRight: return "arrow.up.right.circle"
        case .bottomLeft: return "arrow.down.left.circle"
        case .bottomRight: return "arrow.down.right.circle"
        }
    }
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - View Modes
enum ViewMode: String, CaseIterable, Codable {
    case color = "Color View"
    case keyline = "Keyline View"
    
    var iconName: String {
        switch self {
        case .color: return "paintbrush.fill"
        case .keyline: return "square.dashed"
        }
    }
    
    var description: String {
        switch self {
        case .color: return "Show full artwork with fills and strokes"
        case .keyline: return "Show outlines only (keylines)"
        }
    }
}
