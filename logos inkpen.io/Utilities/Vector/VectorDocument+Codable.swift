import SwiftUI

extension VectorDocument {

    enum CodingKeys: CodingKey {
        case settings, layers, snapshot
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Update settings with current color defaults
        var settingsToSave = settings
        settingsToSave.fillColor = documentColorDefaults.fillColor
        settingsToSave.strokeColor = documentColorDefaults.strokeColor
        settingsToSave.customRgbSwatches = colorSwatches.rgb.isEmpty ? nil : colorSwatches.rgb
        settingsToSave.customCmykSwatches = colorSwatches.cmyk.isEmpty ? nil : colorSwatches.cmyk
        settingsToSave.customHsbSwatches = colorSwatches.hsb.isEmpty ? nil : colorSwatches.hsb

        // Save document content only (no UI state, no legacy arrays)
        try container.encode(settingsToSave, forKey: .settings)
        try container.encode(layers, forKey: .layers)
        try container.encode(snapshot, forKey: .snapshot)
    }
}
