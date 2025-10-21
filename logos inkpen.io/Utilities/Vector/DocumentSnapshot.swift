import Foundation

struct DocumentSnapshot: Equatable, Codable {
    var objects: [UUID: VectorObject]
    var layers: [Layer]  // In stack order
    var settings: DocumentSettings
    var colorSwatches: ColorSwatches
    var gridSettings: GridSettings

    init(
        objects: [UUID: VectorObject] = [:],
        layers: [Layer] = [],
        settings: DocumentSettings = DocumentSettings(),
        colorSwatches: ColorSwatches = .empty,
        gridSettings: GridSettings = .default
    ) {
        self.objects = objects
        self.layers = layers
        self.settings = settings
        self.colorSwatches = colorSwatches
        self.gridSettings = gridSettings
    }
}
