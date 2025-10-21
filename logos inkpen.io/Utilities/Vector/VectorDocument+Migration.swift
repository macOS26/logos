import SwiftUI

extension VectorDocument {

    // MARK: - Migration Helpers

    /// Migrate legacy data to new structure after loading
    func migrateToNewStructure() {
        // Build objects dictionary from unifiedObjects array
        let objectsDict = buildObjectsDictionary()

        // Convert legacy VectorLayers to new Layers
        let newLayersArray = convertLegacyLayers()

        // Populate snapshot
        snapshot = DocumentSnapshot(
            objects: objectsDict,
            layers: newLayersArray,
            settings: settings,
            colorSwatches: colorSwatches,
            gridSettings: gridSettings
        )
    }

    /// Build objects dictionary from unifiedObjects array
    private func buildObjectsDictionary() -> [UUID: VectorObject] {
        var dict: [UUID: VectorObject] = [:]
        for object in unifiedObjects {
            dict[object.id] = object
        }
        return dict
    }

    /// Convert legacy VectorLayer to new Layer format
    private func convertLegacyLayers() -> [Layer] {
        return layers.enumerated().map { (index, vectorLayer) in
            // Get all objects for this layer
            let objectsForLayer = unifiedObjects.filter { $0.layerIndex == index }
            let objectIDs = objectsForLayer.map { $0.id }

            // Convert VectorLayer color to LayerColor
            let layerColor = convertColorToLayerColor(vectorLayer.color)

            return Layer(
                id: vectorLayer.id,
                name: vectorLayer.name,
                objectIDs: objectIDs,
                isVisible: vectorLayer.isVisible,
                isLocked: vectorLayer.isLocked,
                opacity: vectorLayer.opacity,
                blendMode: vectorLayer.blendMode,
                color: layerColor
            )
        }
    }

    /// Convert SwiftUI Color to LayerColor
    private func convertColorToLayerColor(_ color: Color) -> LayerColor {
        let colorString = color.description.lowercased()

        // Match against known layer colors
        if colorString.contains("maroon") { return .maroon }
        if colorString.contains("red") { return .red }
        if colorString.contains("vermillion") { return .vermillion }
        if colorString.contains("rust") { return .rust }
        if colorString.contains("orange") { return .orange }
        if colorString.contains("amber") { return .amber }
        if colorString.contains("yellow") { return .yellow }
        if colorString.contains("chartreuse") { return .chartreuse }
        if colorString.contains("lime") { return .lime }
        if colorString.contains("green") { return .green }
        if colorString.contains("emerald") { return .emerald }
        if colorString.contains("spring") { return .spring }
        if colorString.contains("ocean") { return .ocean }
        if colorString.contains("cyan") { return .cyan }
        if colorString.contains("sky") { return .sky }
        if colorString.contains("blue") { return .blue }
        if colorString.contains("azure") { return .azure }
        if colorString.contains("indigo") { return .indigo }
        if colorString.contains("violet") { return .violet }
        if colorString.contains("orchid") { return .orchid }
        if colorString.contains("purple") { return .purple }
        if colorString.contains("magenta") { return .magenta }
        if colorString.contains("pink") { return .pink }
        if colorString.contains("rose") { return .rose }
        if colorString.contains("gray") { return .gray }

        return .blue  // Default
    }
}
