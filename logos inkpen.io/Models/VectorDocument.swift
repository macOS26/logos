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

// MARK: - Zoom Request System (Professional Adobe Illustrator Standards)
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
    @Published var layers: [VectorLayer]
    @Published var colorSwatches: [VectorColor]
    @Published var selectedLayerIndex: Int?
    @Published var selectedShapeIDs: Set<UUID>
    @Published var selectedTextIDs: Set<UUID> // PROFESSIONAL TEXT SUPPORT
    @Published var textObjects: [VectorText] // PROFESSIONAL TEXT OBJECTS
    @Published var currentTool: DrawingTool
    @Published var viewMode: ViewMode
    @Published var zoomLevel: Double
    @Published var canvasOffset: CGPoint
    @Published var zoomRequest: ZoomRequest? = nil // For coordinated zoom operations
    @Published var showRulers: Bool
    @Published var snapToGrid: Bool
    @Published var undoStack: [VectorDocument]
    @Published var redoStack: [VectorDocument]
    
    // PROFESSIONAL TYPOGRAPHY MANAGEMENT
    @Published var fontManager: FontManager = FontManager()
    
    // DEFAULT COLORS FOR NEW SHAPES (Adobe Illustrator Standards)
    @Published var defaultFillColor: VectorColor = .white // Professional default: white fill
    @Published var defaultStrokeColor: VectorColor = .black // Professional default: black stroke
    @Published var defaultFillOpacity: Double = 1.0  // 100% opacity by default
    @Published var defaultStrokeOpacity: Double = 1.0  // 100% opacity by default
    
    private let maxUndoStackSize = 50
    
    init(settings: DocumentSettings = DocumentSettings()) {
        self.settings = settings
        
        // Standard layer initialization (no special Canvas layer)
        self.layers = []
        
        // Load appropriate color swatches based on color mode
        self.colorSwatches = Self.getDefaultColorSwatchesForMode(settings.colorMode)
        
        self.selectedLayerIndex = nil // Will be set after layer creation
        self.selectedShapeIDs = []
        self.selectedTextIDs = [] // PROFESSIONAL TEXT SUPPORT
        self.textObjects = [] // PROFESSIONAL TEXT OBJECTS
        self.currentTool = .selection
        self.viewMode = .color
        self.zoomLevel = 1.0
        self.canvasOffset = .zero
        self.showRulers = settings.showRulers
        self.snapToGrid = settings.snapToGrid
        self.undoStack = []
        self.redoStack = []
        self.fontManager = FontManager() // PROFESSIONAL FONT MANAGEMENT
        
        // Add notification observers for scaling operations
        setupNotificationObservers()
        
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
    
    /// Professional document unit system (Adobe Illustrator standard)
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
    
    /// Calculate document bounds encompassing all content (Adobe Illustrator method)
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
        
        // If no content, use document settings as bounds (Adobe Illustrator behavior)
        if !hasContent {
            documentBounds = CGRect(origin: .zero, size: settings.sizeInPoints)
        }
        
        return documentBounds
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
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
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ApplyScaling"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleScalingNotification(notification)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("FinishScaling"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleFinishScalingNotification()
        }
    }
    
    private func handleScalingNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let shapeId = userInfo["shapeId"] as? UUID,
              let scaleX = userInfo["scaleX"] as? CGFloat,
              let scaleY = userInfo["scaleY"] as? CGFloat,
              let initialTransform = userInfo["initialTransform"] as? CGAffineTransform,
              let initialBounds = userInfo["initialBounds"] as? CGRect else {
            print("Invalid scaling notification data")
            return
        }
        
        applyScalingToShape(
            shapeId: shapeId,
            scaleX: scaleX,
            scaleY: scaleY,
            initialTransform: initialTransform,
            initialBounds: initialBounds
        )
    }
    
    private func handleFinishScalingNotification() {
        // Save the scaling operation to undo stack
        saveToUndoStack()
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
                // This ensures object origin stays with object (Adobe Illustrator behavior)
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
                
                // Force UI update
                objectWillChange.send()
                break
            }
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Adobe Illustrator behavior)
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
        case settings, layers, colorSwatches, selectedLayerIndex, selectedShapeIDs, selectedTextIDs, textObjects, currentTool, viewMode, zoomLevel, canvasOffset, showRulers, snapToGrid, defaultFillColor, defaultStrokeColor, defaultFillOpacity, defaultStrokeOpacity
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(DocumentSettings.self, forKey: .settings)
        layers = try container.decode([VectorLayer].self, forKey: .layers)
        colorSwatches = try container.decode([VectorColor].self, forKey: .colorSwatches)
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
        
        // DEFAULT COLORS FOR NEW SHAPES (Adobe Illustrator Standards)
        defaultFillColor = try container.decodeIfPresent(VectorColor.self, forKey: .defaultFillColor) ?? .white // Professional default
        defaultStrokeColor = try container.decodeIfPresent(VectorColor.self, forKey: .defaultStrokeColor) ?? .black // Professional default
        defaultFillOpacity = try container.decodeIfPresent(Double.self, forKey: .defaultFillOpacity) ?? 1.0
        defaultStrokeOpacity = try container.decodeIfPresent(Double.self, forKey: .defaultStrokeOpacity) ?? 1.0
        
        setupNotificationObservers()
    }
    

    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(settings, forKey: .settings)
        try container.encode(layers, forKey: .layers)
        try container.encode(colorSwatches, forKey: .colorSwatches)
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
    /// This is critical for Adobe Illustrator pathfinder operations
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
    
    /// PROFESSIONAL SELECT ALL (Adobe Illustrator Standard)
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
            newShape.id = UUID() // 🎯 CRITICAL: Generate new ID for duplicate (Adobe Illustrator standard)
            
            // PROFESSIONAL COORDINATE SYSTEM: Apply offset to actual coordinates instead of using transform
            // This ensures object origin follows object position (Adobe Illustrator behavior)
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
        colorSwatches = previousState.colorSwatches
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
        colorSwatches = nextState.colorSwatches
        selectedLayerIndex = nextState.selectedLayerIndex
        selectedShapeIDs = nextState.selectedShapeIDs
        currentTool = nextState.currentTool
        zoomLevel = nextState.zoomLevel
        canvasOffset = nextState.canvasOffset
        showRulers = nextState.showRulers
        snapToGrid = nextState.snapToGrid
    }
    
    // MARK: - Professional Text Management (Adobe Illustrator / FreeHand Standards)
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
                // Create duplicate with slight offset (Adobe Illustrator behavior)
                var duplicateText = originalText
                duplicateText.id = UUID() // New unique ID
                duplicateText.position = CGPoint(
                    x: originalText.position.x + 10, // 10pt offset
                    y: originalText.position.y + 10
                )
                duplicateText.updateBounds()
                
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
                textObjects[i].updateBounds()
            }
        }
    }
    
    // PROFESSIONAL TEXT TO OUTLINES CONVERSION (Critical Adobe Illustrator Feature)
    func convertSelectedTextToOutlines() {
        guard !selectedTextIDs.isEmpty else { return }
        saveToUndoStack()
        
        let selectedTexts = textObjects.filter { selectedTextIDs.contains($0.id) }
        var newShapeIDs: Set<UUID> = []
        
        for textObj in selectedTexts {
            if let outlineShape = textObj.convertToOutlines() {
                // Position the outline shape at the text position
                var positionedShape = outlineShape
                positionedShape.transform = positionedShape.transform.translatedBy(x: textObj.position.x, y: textObj.position.y)
                positionedShape.updateBounds()
                
                // Add to the current layer
                if let layerIndex = selectedLayerIndex {
                    layers[layerIndex].addShape(positionedShape)
                    newShapeIDs.insert(positionedShape.id)
                }
            }
        }
        
        // Remove the original text objects
        textObjects.removeAll { selectedTextIDs.contains($0.id) }
        selectedTextIDs.removeAll()
        
        // Select the new outline shapes
        selectedShapeIDs = newShapeIDs
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
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            textObjects[index].content = content
            textObjects[index].updateBounds()
        }
    }
    
    func setTextEditing(_ textID: UUID, isEditing: Bool) {
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            textObjects[index].isEditing = isEditing
        }
    }
    
    func updateTextTypography(_ textID: UUID, update: (inout TypographyProperties) -> Void) {
        if let index = textObjects.firstIndex(where: { $0.id == textID }) {
            saveToUndoStack()
            update(&textObjects[index].typography)
            textObjects[index].updateBounds()
        }
    }
    
    // CRITICAL PROFESSIONAL FEATURE: Text to Outlines Conversion (Adobe Illustrator / FreeHand)
    func convertTextToOutlines(_ textID: UUID) {
        saveToUndoStack()
        
        guard let textIndex = textObjects.firstIndex(where: { $0.id == textID }),
              let layerIndex = selectedLayerIndex else {
            print("❌ Failed to find text or layer for conversion")
            return
        }
        
        let textObject = textObjects[textIndex]
        
        print("🎯 Converting text '\(textObject.content)' to vector outlines...")
        
        // Create NSAttributedString with typography properties
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: textObject.typography.fontFamily, size: textObject.typography.fontSize) ?? NSFont.systemFont(ofSize: textObject.typography.fontSize),
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
                    let ascent = CTFontGetAscent(ctFont)
                    
                    // Convert each glyph to path elements
                    for glyphIndex in 0..<glyphCount {
                        let glyph = glyphs[glyphIndex]
                        let glyphPosition = positions[glyphIndex]
                        
                        if let glyphPath = CTFontCreatePathForGlyph(ctFont, glyph, nil) {
                            // CRITICAL FIX: Apply coordinate system transformation for SwiftUI
                            // Core Graphics uses bottom-left origin, SwiftUI uses top-left
                            var transform = CGAffineTransform(scaleX: 1.0, y: -1.0) // Flip Y-axis
                                .translatedBy(
                                    x: textObject.position.x + Double(glyphPosition.x) - 1,
                                    y: -(textObject.position.y - Double(lineOrigins[lineIndex].y) + 6) //ascent
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
            
            print("✅ Successfully converted text '\(textObject.content)' to single vector outline shape")
            print("🎯 Adobe Illustrator standard text-to-outlines conversion complete!")
        } else {
            print("❌ Failed to create outline paths for text '\(textObject.content)'")
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
    
    // MARK: - PROFESSIONAL STROKE OUTLINING (Adobe Illustrator Standard)
    
    /// Converts selected strokes to outlined filled paths ("Outline Stroke" feature)
    /// This is critical for professional vector graphics workflows
    func outlineSelectedStrokes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        let shapesToOutline = layers[layerIndex].shapes.filter { selectedShapeIDs.contains($0.id) && $0.strokeStyle != nil }
        var newShapeIDs: Set<UUID> = []
        
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
                // Create new shape with outlined path as fill
                var newShape = VectorShape(
                    name: "\(shape.name) Outlined",
                    path: VectorPath(cgPath: outlinedPath),
                    strokeStyle: nil, // Remove stroke since it's now a fill
                    fillStyle: FillStyle(
                        color: strokeStyle.color,
                        opacity: strokeStyle.opacity,
                        blendMode: strokeStyle.blendMode
                    )
                )
                
                // Preserve other properties
                newShape.transform = shape.transform
                newShape.opacity = shape.opacity
                newShape.isVisible = shape.isVisible
                newShape.isLocked = shape.isLocked
                newShape.updateBounds()
                
                // Add to layer
                layers[layerIndex].addShape(newShape)
                newShapeIDs.insert(newShape.id)
            }
        }
        
        // Remove original shapes if outlining was successful
        if !newShapeIDs.isEmpty {
            layers[layerIndex].shapes.removeAll { selectedShapeIDs.contains($0.id) }
            selectedShapeIDs = newShapeIDs
        }
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
    
    // MARK: - Professional Zoom Management (Adobe Illustrator Standards)
    
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
    
    // MARK: - Color Management
    func addColorSwatch(_ color: VectorColor) {
        if !colorSwatches.contains(color) {
            colorSwatches.append(color)
        }
    }
    
    func removeColorSwatch(_ color: VectorColor) {
        colorSwatches.removeAll { $0 == color }
    }
    
    // Load appropriate color swatches based on color mode
    static func getDefaultColorSwatchesForMode(_ colorMode: ColorMode) -> [VectorColor] {
        switch colorMode {
        case .rgb:
            return VectorColor.defaultColors
        case .cmyk:
            return VectorColor.defaultColors + createCMYKSwatches()
        case .pantone:
            return VectorColor.defaultColors + ColorManagement.loadPantoneColors().map { .pantone($0) }
        }
    }
    
    // Create professional CMYK color swatches
    static func createCMYKSwatches() -> [VectorColor] {
        var cmykColors: [VectorColor] = []
        
        // Standard CMYK color swatches
        let cmykValues = [
            (100, 0, 0, 0),    // Cyan
            (0, 100, 0, 0),    // Magenta
            (0, 0, 100, 0),    // Yellow
            (0, 0, 0, 100),    // Black
            (50, 0, 100, 0),   // Green
            (100, 100, 0, 0),  // Blue
            (0, 100, 100, 0),  // Red
            (25, 25, 25, 0),   // Light Gray
            (50, 50, 50, 0),   // Medium Gray
            (75, 75, 75, 0),   // Dark Gray
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
        
        return cmykColors
    }
    
    // Update color swatches when color mode changes
    func updateColorSwatchesForMode() {
        let currentSwatches = colorSwatches
        let defaultSwatches = Self.getDefaultColorSwatchesForMode(settings.colorMode)
        
        // Keep user-added colors and merge with new defaults
        var newSwatches = defaultSwatches
        
        // Add any existing colors that aren't in the defaults
        for existingColor in currentSwatches {
            if !newSwatches.contains(existingColor) {
                newSwatches.append(existingColor)
            }
        }
        
        self.colorSwatches = newSwatches
    }
    
    // MARK: - PROFESSIONAL PATHFINDER OPERATIONS (Adobe Illustrator Standards)
    
    /// Performs pathfinder operations following exact Adobe Illustrator behavior
    /// Returns true if the operation was successful, false otherwise
    func performPathfinderOperation(_ operation: PathfinderOperation) -> Bool {
        print("🎨 PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation: \(operation.rawValue)")
        
        // Get selected shapes in correct STACKING ORDER (Adobe Illustrator standard)
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
        // SHAPE MODES (Adobe Illustrator)
        case .unite:
            // UNITE: Combines all shapes, result takes color of TOPMOST object
            if let unitedPath = ProfessionalPathOperations.unite(paths) {
                let topmostShape = selectedShapes.last! // Last in array = topmost in stacking order
                let unitedShape = VectorShape(
                    name: "United Shape",
                    path: VectorPath(cgPath: unitedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [unitedShape]
                print("✅ UNITE: Created unified shape with topmost object's color")
            }
            
        case .minusFront:
            // MINUS FRONT: Front objects subtract from back object, result takes color of BACK object
            guard selectedShapes.count >= 2 else { 
                print("❌ MINUS FRONT requires at least 2 shapes")
                return false 
            }
            
            let backShape = selectedShapes.first!    // First in array = bottommost = back
            let frontShapes = Array(selectedShapes.dropFirst()) // All others = front
            
            print("🔪 MINUS FRONT: Back shape '\(backShape.name)' - Front shapes: \(frontShapes.map { $0.name })")
            
            var resultPath = backShape.path.cgPath
            
            // Subtract each front shape from the result
            for frontShape in frontShapes {
                if let subtractedPath = ProfessionalPathOperations.minusFront(frontShape.path.cgPath, from: resultPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(frontShape.name)' from result")
                }
            }
            
            // Result takes style of BACK object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Minus Front Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: backShape.strokeStyle,
                fillStyle: backShape.fillStyle,
                transform: .identity,
                opacity: backShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ MINUS FRONT: Result takes back object's color (\(backShape.name))")
            
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
            
            if let excludedPath = ProfessionalPathOperations.exclude(paths[0], paths[1]) {
                let topmostShape = selectedShapes.last! // Last = topmost
                let excludedShape = VectorShape(
                    name: "Excluded Shape",
                    path: VectorPath(cgPath: excludedPath),
                    strokeStyle: topmostShape.strokeStyle,
                    fillStyle: topmostShape.fillStyle,
                    transform: .identity,
                    opacity: topmostShape.opacity
                )
                resultShapes = [excludedShape]
                print("✅ EXCLUDE: Result takes topmost object's color (\(topmostShape.name))")
            }
        
        // PATHFINDER EFFECTS (Adobe Illustrator) - These retain original colors
        case .divide:
            // DIVIDE: Break into separate objects, each retains original color
            let dividedPaths = ProfessionalPathOperations.divide(paths)
            
            for (index, dividedPath) in dividedPaths.enumerated() {
                // Determine which original shape this divided piece belongs to
                let originalShape = determineOriginalShapeForDividedPiece(dividedPath, from: selectedShapes)
                
                let dividedShape = VectorShape(
                    name: "Divided Piece \(index + 1)",
                    path: VectorPath(cgPath: dividedPath),
                    strokeStyle: originalShape.strokeStyle,
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(dividedShape)
            }
            print("✅ DIVIDE: Created \(resultShapes.count) pieces with original colors")
            
        case .trim:
            // TRIM: Remove hidden parts, objects retain original colors, removes strokes
            let trimmedPaths = ProfessionalPathOperations.trim(paths)
            
            for (index, trimmedPath) in trimmedPaths.enumerated() {
                guard index < selectedShapes.count else { break }
                let originalShape = selectedShapes[index]
                
                let trimmedShape = VectorShape(
                    name: "Trimmed \(originalShape.name)",
                    path: VectorPath(cgPath: trimmedPath),
                    strokeStyle: nil, // TRIM removes strokes (Adobe Illustrator standard)
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(trimmedShape)
            }
            print("✅ TRIM: Created \(resultShapes.count) trimmed shapes, removed strokes")
            
        case .merge:
            // MERGE: Like trim but merges objects of same color, removes strokes
            let mergedPaths = ProfessionalPathOperations.merge(paths)
            
            for (index, mergedPath) in mergedPaths.enumerated() {
                // For merge, we assume same color objects get merged into one
                let representativeShape = selectedShapes.first!
                
                let mergedShape = VectorShape(
                    name: "Merged Shape \(index + 1)",
                    path: VectorPath(cgPath: mergedPath),
                    strokeStyle: nil, // MERGE removes strokes (Adobe Illustrator standard)
                    fillStyle: representativeShape.fillStyle,
                    transform: .identity,
                    opacity: representativeShape.opacity
                )
                resultShapes.append(mergedShape)
            }
            print("✅ MERGE: Created \(resultShapes.count) merged shapes, removed strokes")
            
        case .crop:
            // CROP: Use topmost shape to crop others, cropped objects retain original colors, removes strokes
            let croppedPaths = ProfessionalPathOperations.crop(paths)
            
            for (index, croppedPath) in croppedPaths.enumerated() {
                guard index < selectedShapes.count - 1 else { break } // Exclude topmost (crop shape)
                let originalShape = selectedShapes[index]
                
                let croppedShape = VectorShape(
                    name: "Cropped \(originalShape.name)",
                    path: VectorPath(cgPath: croppedPath),
                    strokeStyle: nil, // CROP removes strokes (Adobe Illustrator standard)
                    fillStyle: originalShape.fillStyle,
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(croppedShape)
            }
            print("✅ CROP: Created \(resultShapes.count) cropped shapes, removed strokes")
            
        case .outline:
            // OUTLINE: Convert fills to strokes/outlines
            let outlinedPaths = ProfessionalPathOperations.outline(paths)
            
            for (index, outlinedPath) in outlinedPaths.enumerated() {
                guard index < selectedShapes.count else { break }
                let originalShape = selectedShapes[index]
                
                // Convert fill to stroke (Adobe Illustrator "Outline" behavior)
                var outlineStroke: StrokeStyle?
                if let fillStyle = originalShape.fillStyle, fillStyle.color != .clear {
                    outlineStroke = StrokeStyle(
                        color: fillStyle.color,
                        width: 1.0,
                        lineCap: .round,
                        lineJoin: .round
                    )
                }
                
                let outlinedShape = VectorShape(
                    name: "Outlined \(originalShape.name)",
                    path: VectorPath(cgPath: outlinedPath),
                    strokeStyle: outlineStroke,
                    fillStyle: nil, // OUTLINE removes fills (Adobe Illustrator standard)
                    transform: .identity,
                    opacity: originalShape.opacity
                )
                resultShapes.append(outlinedShape)
            }
            print("✅ OUTLINE: Created \(resultShapes.count) outlined shapes")
            
        case .minusBack:
            // MINUS BACK: Back objects subtract from front object, result takes color of FRONT object
            guard selectedShapes.count >= 2 else {
                print("❌ MINUS BACK requires at least 2 shapes")
                return false
            }
            
            let frontShape = selectedShapes.last!     // Last in array = topmost = front
            let backShapes = Array(selectedShapes.dropLast()) // All others = back
            
            print("🔪 MINUS BACK: Front shape '\(frontShape.name)' - Back shapes: \(backShapes.map { $0.name })")
            
            var resultPath = frontShape.path.cgPath
            
            // Subtract each back shape from the result
            for backShape in backShapes {
                if let subtractedPath = ProfessionalPathOperations.minusBack(resultPath, from: backShape.path.cgPath) {
                    resultPath = subtractedPath
                    print("  ⚡ Subtracted '\(backShape.name)' from result")
                }
            }
            
            // Result takes style of FRONT object (Adobe Illustrator standard)
            let resultShape = VectorShape(
                name: "Minus Back Result",
                path: VectorPath(cgPath: resultPath),
                strokeStyle: frontShape.strokeStyle,
                fillStyle: frontShape.fillStyle,
                transform: .identity,
                opacity: frontShape.opacity
            )
            resultShapes = [resultShape]
            print("✅ MINUS BACK: Result takes front object's color (\(frontShape.name))")
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
        
        print("✅ PROFESSIONAL ADOBE ILLUSTRATOR pathfinder operation \(operation.rawValue) completed - created \(resultShapes.count) result shape(s)")
        return true
    }
    
    /// Determine which original shape a divided piece belongs to (for color assignment)
    private func determineOriginalShapeForDividedPiece(_ piece: CGPath, from originalShapes: [VectorShape]) -> VectorShape {
        // Get the center point of the piece
        let pieceBounds = piece.boundingBoxOfPath
        let pieceCenter = CGPoint(x: pieceBounds.midX, y: pieceBounds.midY)
        
        // Find which original shape contains this center point
        for shape in originalShapes {
            if shape.path.cgPath.contains(pieceCenter) {
                return shape
            }
        }
        
        // Fallback: use the first shape
        return originalShapes.first!
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
    
    // MARK: - Object Arrangement Methods (Adobe Illustrator Standards)
    
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
    
    // MARK: - Object Grouping Methods (Adobe Illustrator Standards)
    
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
    
    // MARK: - Lock/Unlock Methods (Adobe Illustrator Standards)
    
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
    
    // MARK: - Hide/Show Methods (Adobe Illustrator Standards)
    
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
    case convertAnchorPoint = "Convert Anchor Point"
    case bezierPen = "Bezier Pen"
    case font = "Font"
    case line = "Line"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case star = "Star"
    case polygon = "Polygon"
    case eyedropper = "Eyedropper"
    case hand = "Hand"
    case zoom = "Zoom"
    
    var iconName: String {
        switch self {
        case .selection: return "arrow.up.left"
        case .directSelection: return "cursorarrow.and.square.on.square.dashed"
        case .convertAnchorPoint: return "arrow.triangle.turn.up.right.diamond"
        case .bezierPen: return "pencil.tip"
        case .font: return "textformat"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .star: return "star"
        case .polygon: return "hexagon"
        case .eyedropper: return "eyedropper"
        case .hand: return "hand.raised"
        case .zoom: return "magnifyingglass"
        }
    }
    
    var cursor: NSCursor {
        switch self {
        case .selection: return .arrow
        case .directSelection: return .crosshair
        case .convertAnchorPoint: return .pointingHand
        case .bezierPen: return .crosshair
        case .font: return .iBeam
        case .line: return .crosshair
        case .rectangle: return .crosshair
        case .circle: return .crosshair
        case .star: return .crosshair
        case .polygon: return .crosshair
        case .eyedropper: return .crosshair
        case .hand: return .openHand
        case .zoom: return .crosshair
        }
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
