//
//  DocumentSettings.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Document Settings
struct DocumentSettings: Codable, Hashable {
    var width: Double
    var height: Double
    var unit: MeasurementUnit  // Saved with document - remembers pixels/inches/cm etc
    var colorMode: ColorMode
    var resolution: Double // DPI
    var showRulers: Bool
    var showGrid: Bool
    var snapToGrid: Bool
    var snapToPoint: Bool
    var gridSpacing: Double
    var backgroundColor: VectorColor
    var selectedLayerId: UUID?
    var selectedLayerName: String?

    // Document-specific colors and custom swatches (only user-added swatches)
    var fillColor: VectorColor?
    var strokeColor: VectorColor?
    var customRgbSwatches: [VectorColor]?
    var customCmykSwatches: [VectorColor]?
    var customHsbSwatches: [VectorColor]?

    // FIX: Store actual document size in points to prevent coordinate system corruption
    private var _sizeInPoints: CGSize?
    
    init(width: Double = 11.0, height: Double = 8.5, unit: MeasurementUnit = .inches, colorMode: ColorMode = .rgb, resolution: Double = 72.0, showRulers: Bool? = nil, showGrid: Bool? = nil, snapToGrid: Bool? = nil, snapToPoint: Bool? = nil, gridSpacing: Double = 0.125, backgroundColor: VectorColor = .white, selectedLayerId: UUID? = nil, selectedLayerName: String? = "Layer 1", fillColor: VectorColor? = nil, strokeColor: VectorColor? = nil, customRgbSwatches: [VectorColor]? = nil, customCmykSwatches: [VectorColor]? = nil, customHsbSwatches: [VectorColor]? = nil) {
        self.width = width
        self.height = height
        self.unit = unit
        self.colorMode = colorMode
        self.resolution = resolution
        // Load display settings from UserDefaults if not explicitly provided
        // Show Rulers defaults to true if user hasn't set it
        if let showRulersValue = showRulers {
            self.showRulers = showRulersValue
        } else {
            // Check if user has ever set this value
            if UserDefaults.standard.object(forKey: "showRulers") != nil {
                self.showRulers = UserDefaults.standard.bool(forKey: "showRulers")
            } else {
                self.showRulers = true // Default ON
            }
        }

        // Other settings default to false if user hasn't set them
        self.showGrid = showGrid ?? UserDefaults.standard.bool(forKey: "showGrid")
        self.snapToGrid = snapToGrid ?? UserDefaults.standard.bool(forKey: "snapToGrid")
        self.snapToPoint = snapToPoint ?? UserDefaults.standard.bool(forKey: "snapToPoint")
        self.gridSpacing = gridSpacing
        self.backgroundColor = backgroundColor
        self.selectedLayerId = selectedLayerId
        self.selectedLayerName = selectedLayerName ?? "Layer 1"

        // Initialize document-specific colors and custom swatches
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.customRgbSwatches = customRgbSwatches
        self.customCmykSwatches = customCmykSwatches
        self.customHsbSwatches = customHsbSwatches
    }
    
    // MARK: - Custom Decoding for Backward Compatibility
    enum CodingKeys: String, CodingKey {
        case width, height, unit, colorMode, resolution, showRulers, showGrid, snapToGrid, snapToPoint, gridSpacing, backgroundColor, selectedLayerId, selectedLayerName
        case fillColor, strokeColor, customRgbSwatches, customCmykSwatches, customHsbSwatches
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        width = try container.decode(Double.self, forKey: .width)
        height = try container.decode(Double.self, forKey: .height)
        unit = try container.decode(MeasurementUnit.self, forKey: .unit)
        colorMode = try container.decode(ColorMode.self, forKey: .colorMode)
        resolution = try container.decode(Double.self, forKey: .resolution)
        showRulers = try container.decode(Bool.self, forKey: .showRulers)
        showGrid = try container.decode(Bool.self, forKey: .showGrid)
        snapToGrid = try container.decode(Bool.self, forKey: .snapToGrid)
        snapToPoint = try container.decodeIfPresent(Bool.self, forKey: .snapToPoint) ?? false
        gridSpacing = try container.decode(Double.self, forKey: .gridSpacing)
        backgroundColor = try container.decode(VectorColor.self, forKey: .backgroundColor)
        selectedLayerId = try container.decodeIfPresent(UUID.self, forKey: .selectedLayerId)
        selectedLayerName = try container.decodeIfPresent(String.self, forKey: .selectedLayerName) ?? "Layer 1"

        // Decode document-specific colors and custom swatches
        fillColor = try container.decodeIfPresent(VectorColor.self, forKey: .fillColor)
        strokeColor = try container.decodeIfPresent(VectorColor.self, forKey: .strokeColor)
        customRgbSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .customRgbSwatches)
        customCmykSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .customCmykSwatches)
        customHsbSwatches = try container.decodeIfPresent([VectorColor].self, forKey: .customHsbSwatches)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(width, forKey: .width)
        try container.encode(height, forKey: .height)
        try container.encode(unit, forKey: .unit)
        try container.encode(colorMode, forKey: .colorMode)
        try container.encode(resolution, forKey: .resolution)
        try container.encode(showRulers, forKey: .showRulers)
        try container.encode(showGrid, forKey: .showGrid)
        try container.encode(snapToGrid, forKey: .snapToGrid)
        try container.encode(snapToPoint, forKey: .snapToPoint)
        try container.encode(gridSpacing, forKey: .gridSpacing)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(selectedLayerId, forKey: .selectedLayerId)
        try container.encode(selectedLayerName, forKey: .selectedLayerName)

        // Encode document-specific colors and custom swatches
        try container.encodeIfPresent(fillColor, forKey: .fillColor)
        try container.encodeIfPresent(strokeColor, forKey: .strokeColor)
        try container.encodeIfPresent(customRgbSwatches, forKey: .customRgbSwatches)
        try container.encodeIfPresent(customCmykSwatches, forKey: .customCmykSwatches)
        try container.encodeIfPresent(customHsbSwatches, forKey: .customHsbSwatches)
    }
    
    var sizeInPoints: CGSize {
        // FIX: Use stored size in points if available, otherwise calculate from current unit
        if let storedSize = _sizeInPoints {
            return storedSize
        } else {
            let pointsPerUnit = unit.pointsPerUnit
            return CGSize(width: width * pointsPerUnit, height: height * pointsPerUnit)
        }
    }
    
    // FIX: Method to update unit while preserving document size in points
    mutating func changeUnit(to newUnit: MeasurementUnit) {
        // Store current size in points before changing unit
        let currentSizeInPoints = sizeInPoints
        
        // Update the unit
        unit = newUnit
        
        // Update width and height to match the new unit while preserving actual size
        let newPointsPerUnit = newUnit.pointsPerUnit
        width = currentSizeInPoints.width / newPointsPerUnit
        height = currentSizeInPoints.height / newPointsPerUnit
        
        // Store the preserved size in points
        _sizeInPoints = currentSizeInPoints
        
        print("🔄 Unit changed to \(newUnit.rawValue) - Document size preserved: \(String(format: "%.1f", currentSizeInPoints.width))×\(String(format: "%.1f", currentSizeInPoints.height)) points")
    }

    /// Set the document size in points, updating width/height according to current unit
    /// and persisting the points value to avoid unit conversion drift.
    mutating func setSizeInPoints(_ newSize: CGSize) {
        _sizeInPoints = newSize
        let ppu = unit.pointsPerUnit
        width = newSize.width / ppu
        height = newSize.height / ppu
    }
}
