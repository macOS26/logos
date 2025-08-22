//
//  DocumentSettings.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation

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
    var freehandSmoothingTolerance: Double // Curve fitting tolerance for freehand tool
    var brushThickness: Double // Default brush stroke thickness
    var brushPressureSensitivity: Double // How much pressure affects thickness (0.0-1.0)
    var brushTaper: Double // Amount of tapering at start/end (0.0-1.0)
    
    // Advanced Smoothing Settings
    var advancedSmoothingEnabled: Bool // Enable advanced curve smoothing algorithms
    var chaikinSmoothingIterations: Int // Number of Chaikin smoothing iterations (1-3)
    var realTimeSmoothingEnabled: Bool // Enable real-time smoothing during drawing
    var realTimeSmoothingStrength: Double // Real-time smoothing strength (0.0-1.0)
    var adaptiveTensionEnabled: Bool // Enable adaptive curve tension based on curvature
    var preserveSharpCorners: Bool // Preserve sharp corners during simplification
    
    // FIX: Store actual document size in points to prevent coordinate system corruption
    private var _sizeInPoints: CGSize?
    
    init(width: Double = 11.0, height: Double = 8.5, unit: MeasurementUnit = .inches, colorMode: ColorMode = .rgb, resolution: Double = 72.0, showRulers: Bool = true, showGrid: Bool = false, snapToGrid: Bool = false, gridSpacing: Double = 0.125, backgroundColor: VectorColor = .white, freehandSmoothingTolerance: Double = 2.0, brushThickness: Double = 10.0, brushPressureSensitivity: Double = 0.5, brushTaper: Double = 0.3, advancedSmoothingEnabled: Bool = true, chaikinSmoothingIterations: Int = 1, realTimeSmoothingEnabled: Bool = true, realTimeSmoothingStrength: Double = 0.3, adaptiveTensionEnabled: Bool = true, preserveSharpCorners: Bool = true) {
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
        self.freehandSmoothingTolerance = freehandSmoothingTolerance
        self.brushThickness = brushThickness
        self.brushPressureSensitivity = brushPressureSensitivity
        self.brushTaper = brushTaper
        
        // Advanced Smoothing Settings
        self.advancedSmoothingEnabled = advancedSmoothingEnabled
        self.chaikinSmoothingIterations = chaikinSmoothingIterations
        self.realTimeSmoothingEnabled = realTimeSmoothingEnabled
        self.realTimeSmoothingStrength = realTimeSmoothingStrength
        self.adaptiveTensionEnabled = adaptiveTensionEnabled
        self.preserveSharpCorners = preserveSharpCorners
    }
    
    // MARK: - Custom Decoding for Backward Compatibility
    enum CodingKeys: String, CodingKey {
        case width, height, unit, colorMode, resolution, showRulers, showGrid, snapToGrid, gridSpacing, backgroundColor
        case freehandSmoothingTolerance, brushThickness, brushPressureSensitivity, brushTaper
        case advancedSmoothingEnabled, chaikinSmoothingIterations, realTimeSmoothingEnabled, realTimeSmoothingStrength, adaptiveTensionEnabled, preserveSharpCorners
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
        gridSpacing = try container.decode(Double.self, forKey: .gridSpacing)
        backgroundColor = try container.decode(VectorColor.self, forKey: .backgroundColor)
        
        // NEW FIELD: Use default value if not present in older documents
        freehandSmoothingTolerance = try container.decodeIfPresent(Double.self, forKey: .freehandSmoothingTolerance) ?? 2.0
        
        // BRUSH SETTINGS: Use default values if not present in older documents
        brushThickness = try container.decodeIfPresent(Double.self, forKey: .brushThickness) ?? 10.0
        brushPressureSensitivity = try container.decodeIfPresent(Double.self, forKey: .brushPressureSensitivity) ?? 0.5
        brushTaper = try container.decodeIfPresent(Double.self, forKey: .brushTaper) ?? 0.3
        
        // ADVANCED SMOOTHING SETTINGS: Use default values if not present in older documents
        advancedSmoothingEnabled = try container.decodeIfPresent(Bool.self, forKey: .advancedSmoothingEnabled) ?? true
        chaikinSmoothingIterations = try container.decodeIfPresent(Int.self, forKey: .chaikinSmoothingIterations) ?? 1
        realTimeSmoothingEnabled = try container.decodeIfPresent(Bool.self, forKey: .realTimeSmoothingEnabled) ?? true
        realTimeSmoothingStrength = try container.decodeIfPresent(Double.self, forKey: .realTimeSmoothingStrength) ?? 0.3
        adaptiveTensionEnabled = try container.decodeIfPresent(Bool.self, forKey: .adaptiveTensionEnabled) ?? true
        preserveSharpCorners = try container.decodeIfPresent(Bool.self, forKey: .preserveSharpCorners) ?? true
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
        try container.encode(gridSpacing, forKey: .gridSpacing)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(freehandSmoothingTolerance, forKey: .freehandSmoothingTolerance)
        try container.encode(brushThickness, forKey: .brushThickness)
        try container.encode(brushPressureSensitivity, forKey: .brushPressureSensitivity)
        try container.encode(brushTaper, forKey: .brushTaper)
        try container.encode(advancedSmoothingEnabled, forKey: .advancedSmoothingEnabled)
        try container.encode(chaikinSmoothingIterations, forKey: .chaikinSmoothingIterations)
        try container.encode(realTimeSmoothingEnabled, forKey: .realTimeSmoothingEnabled)
        try container.encode(realTimeSmoothingStrength, forKey: .realTimeSmoothingStrength)
        try container.encode(adaptiveTensionEnabled, forKey: .adaptiveTensionEnabled)
        try container.encode(preserveSharpCorners, forKey: .preserveSharpCorners)
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
    
    /// Create settings with professional defaults
    static func professional(width: CGFloat, height: CGFloat, unit: MeasurementUnit, dpi: Double = 72) -> DocumentSettings {
        return DocumentSettings(
            width: width,
            height: height,
            unit: unit,
            colorMode: .rgb,
            resolution: dpi,
            showRulers: true,
            showGrid: false,
            snapToGrid: true,
            gridSpacing: unit == .pixels ? 10 : 0.125,
            backgroundColor: VectorColor.white
        )
    }
}
