//
//  VectorDocument.swift
//  logos
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
    
    init(width: Double = 8.5, height: Double = 11.0, unit: MeasurementUnit = .inches, colorMode: ColorMode = .rgb, resolution: Double = 72.0, showRulers: Bool = true, showGrid: Bool = false, snapToGrid: Bool = false, gridSpacing: Double = 0.125, backgroundColor: VectorColor = .white) {
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

// MARK: - Vector Document
class VectorDocument: ObservableObject, Codable {
    @Published var settings: DocumentSettings
    @Published var layers: [VectorLayer]
    @Published var colorSwatches: [VectorColor]
    @Published var selectedLayerIndex: Int?
    @Published var selectedShapeIDs: Set<UUID>
    @Published var currentTool: DrawingTool
    @Published var viewMode: ViewMode
    @Published var zoomLevel: Double
    @Published var canvasOffset: CGPoint
    @Published var showRulers: Bool
    @Published var snapToGrid: Bool
    @Published var undoStack: [VectorDocument]
    @Published var redoStack: [VectorDocument]
    
    private let maxUndoStackSize = 50
    
    init(settings: DocumentSettings = DocumentSettings()) {
        self.settings = settings
        self.layers = [VectorLayer(name: "Layer 1")]
        self.colorSwatches = VectorColor.defaultColors
        self.selectedLayerIndex = 0
        self.selectedShapeIDs = []
        self.currentTool = .selection
        self.viewMode = .color
        self.zoomLevel = 1.0
        self.canvasOffset = .zero
        self.showRulers = settings.showRulers
        self.snapToGrid = settings.snapToGrid
        self.undoStack = []
        self.redoStack = []
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: CodingKey {
        case settings, layers, colorSwatches, selectedLayerIndex, selectedShapeIDs, currentTool, viewMode, zoomLevel, canvasOffset, showRulers, snapToGrid
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(DocumentSettings.self, forKey: .settings)
        layers = try container.decode([VectorLayer].self, forKey: .layers)
        colorSwatches = try container.decode([VectorColor].self, forKey: .colorSwatches)
        selectedLayerIndex = try container.decodeIfPresent(Int.self, forKey: .selectedLayerIndex)
        selectedShapeIDs = try container.decode(Set<UUID>.self, forKey: .selectedShapeIDs)
        currentTool = try container.decode(DrawingTool.self, forKey: .currentTool)
        viewMode = try container.decodeIfPresent(ViewMode.self, forKey: .viewMode) ?? .color
        zoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        canvasOffset = try container.decode(CGPoint.self, forKey: .canvasOffset)
        showRulers = try container.decode(Bool.self, forKey: .showRulers)
        snapToGrid = try container.decode(Bool.self, forKey: .snapToGrid)
        undoStack = []
        redoStack = []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(settings, forKey: .settings)
        try container.encode(layers, forKey: .layers)
        try container.encode(colorSwatches, forKey: .colorSwatches)
        try container.encodeIfPresent(selectedLayerIndex, forKey: .selectedLayerIndex)
        try container.encode(selectedShapeIDs, forKey: .selectedShapeIDs)
        try container.encode(currentTool, forKey: .currentTool)
        try container.encode(viewMode, forKey: .viewMode)
        try container.encode(zoomLevel, forKey: .zoomLevel)
        try container.encode(canvasOffset, forKey: .canvasOffset)
        try container.encode(showRulers, forKey: .showRulers)
        try container.encode(snapToGrid, forKey: .snapToGrid)
    }
    
    // MARK: - Layer Management
    func addLayer(name: String = "New Layer") {
        layers.append(VectorLayer(name: name))
        selectedLayerIndex = layers.count - 1
    }
    
    func removeLayer(at index: Int) {
        guard index >= 0 && index < layers.count && layers.count > 1 else { return }
        layers.remove(at: index)
        if selectedLayerIndex == index {
            selectedLayerIndex = min(index, layers.count - 1)
        } else if let selected = selectedLayerIndex, selected > index {
            selectedLayerIndex = selected - 1
        }
    }
    
    func moveLayer(from: Int, to: Int) {
        let layer = layers.remove(at: from)
        layers.insert(layer, at: to)
        selectedLayerIndex = to
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
    
    func duplicateSelectedShapes() {
        guard let layerIndex = selectedLayerIndex else { return }
        saveToUndoStack()
        
        let shapesToDuplicate = layers[layerIndex].shapes.filter { selectedShapeIDs.contains($0.id) }
        var newShapeIDs: Set<UUID> = []
        
        for shape in shapesToDuplicate {
            var newShape = shape
            newShape.transform = newShape.transform.translatedBy(x: 10, y: 10)
            newShape.updateBounds()
            layers[layerIndex].addShape(newShape)
            newShapeIDs.insert(newShape.id)
        }
        
        selectedShapeIDs = newShapeIDs
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
        
        // Save current state to undo stack
        saveToUndoStack()
        
        // Restore next state
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
    
    // MARK: - Color Management
    func addColorSwatch(_ color: VectorColor) {
        if !colorSwatches.contains(color) {
            colorSwatches.append(color)
        }
    }
    
    func removeColorSwatch(_ color: VectorColor) {
        colorSwatches.removeAll { $0 == color }
    }
}

// MARK: - Drawing Tools
enum DrawingTool: String, CaseIterable, Codable {
    case selection = "Selection"
    case directSelection = "Direct Selection"
    case convertAnchorPoint = "Convert Anchor Point"
    case bezierPen = "Bezier Pen"
    case line = "Line"
    case rectangle = "Rectangle"
    case circle = "Circle"
    case star = "Star"
    case polygon = "Polygon"
    case text = "Text"
    case eyedropper = "Eyedropper"
    case hand = "Hand"
    case zoom = "Zoom"
    
    var iconName: String {
        switch self {
        case .selection: return "arrow.up.left"
        case .directSelection: return "cursorarrow.and.square.on.square.dashed"
        case .convertAnchorPoint: return "arrow.triangle.turn.up.right.diamond"
        case .bezierPen: return "pencil.tip"
        case .line: return "line.diagonal"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .star: return "star"
        case .polygon: return "hexagon"
        case .text: return "textformat"
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
        case .line: return .crosshair
        case .rectangle: return .crosshair
        case .circle: return .crosshair
        case .star: return .crosshair
        case .polygon: return .crosshair
        case .text: return .iBeam
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
