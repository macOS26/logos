import Foundation

struct
DocumentSnapshot: Equatable, Codable {
    var formatVersion: String = "1.0.27"
    var objects: [UUID: VectorObject]
    var layers: [Layer]  // In stack order
    var settings: DocumentSettings
    var colorSwatches: ColorSwatches
    var gridSettings: GridSettings

    init(
        formatVersion: String = "1.0.27",
        objects: [UUID: VectorObject] = [:],
        layers: [Layer] = [],
        settings: DocumentSettings = DocumentSettings(),
        colorSwatches: ColorSwatches = .empty,
        gridSettings: GridSettings = .default
    ) {
        self.formatVersion = formatVersion
        self.objects = objects
        self.layers = layers
        self.settings = settings
        self.colorSwatches = colorSwatches
        self.gridSettings = gridSettings
    }
}
