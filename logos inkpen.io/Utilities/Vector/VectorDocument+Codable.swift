import SwiftUI

extension VectorDocument {

    enum CodingKeys: CodingKey {
        case settings, layers, selectedLayerIndex, selectedShapeIDs, selectedTextIDs, selectedObjectIDs, currentTool, viewMode, zoomLevel, canvasOffset, unifiedObjects, warpEnvelopeCorners, warpBounds
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
