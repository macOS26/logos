import Foundation

/// Handles migration of legacy inkpen file formats to current version
struct InkpenMigrator {

    /// Attempts to migrate legacy inkpen data to current format
    /// - Parameter data: The raw JSON data from the file
    /// - Returns: A migrated VectorDocument, or nil if migration fails
    static func migrateLegacyDocument(from data: Data) -> VectorDocument? {
        // Try to decode as legacy 1.0 format
        do {
            let legacyDoc = try decodeLegacy1_0(from: data)
            Log.fileOperation("🔄 Migrating document from version 1.0 to 1.0.27", level: .info)
            return migrate1_0_to_1_0_27(legacyDoc)
        } catch {
            Log.error("❌ Legacy migration failed: \(error)", category: .error)
            return nil
        }
    }

    // MARK: - Legacy 1.0 Format

    private struct Legacy1_0Document: Codable {
        var canvasOffset: [Double]?
        var currentTool: String?
        var layers: [Legacy1_0Layer]
        var settings: Legacy1_0Settings
        var unifiedObjects: [Legacy1_0Object]
        var viewMode: String?
        var zoomLevel: Double?
    }

    private struct Legacy1_0Layer: Codable {
        var color: String?
        var id: String
        var isLocked: Bool?
        var name: String
        var opacity: Double?
        var blendMode: String?
        var isVisible: Bool?
    }

    private struct Legacy1_0Settings: Codable {
        var backgroundColor: AnyCodable?  // Can be String or dictionary
        var colorMode: String?
        var fillColor: AnyCodable?
        var strokeColor: AnyCodable?
        var gridSpacing: Double?
        var height: Double
        var width: Double
        var resolution: Double?
        var selectedLayerId: String?
        var selectedLayerName: String?
        var showGrid: Bool?
        var showRulers: Bool?
        var snapToGrid: Bool?
        var snapToPoint: Bool?
        var unit: String?
        var groupExpansionState: [AnyCodable]?  // Mixed array of String/Bool
        var layerExpansionState: [AnyCodable]?  // Mixed array of String/Bool
        var customRgbSwatches: [AnyCodable]?  // Can be [[String: Double]] or nested dictionaries
        var customCmykSwatches: [AnyCodable]?
        var customHsbSwatches: [AnyCodable]?
    }

    private struct Legacy1_0Object: Codable {
        var id: String
        var layerIndex: Int
        var orderID: Int?
        var objectType: AnyCodable
    }

    // Helper to handle dynamic JSON structures
    private struct AnyCodable: Codable {
        let value: Any

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()

            if let dict = try? container.decode([String: AnyCodable].self) {
                value = dict.mapValues { $0.value }
            } else if let array = try? container.decode([AnyCodable].self) {
                value = array.map { $0.value }
            } else if let string = try? container.decode(String.self) {
                value = string
            } else if let double = try? container.decode(Double.self) {
                value = double
            } else if let bool = try? container.decode(Bool.self) {
                value = bool
            } else {
                value = NSNull()
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()

            switch value {
            case let dict as [String: Any]:
                try container.encode(dict.mapValues { AnyCodable(value: $0) })
            case let array as [Any]:
                try container.encode(array.map { AnyCodable(value: $0) })
            case let string as String:
                try container.encode(string)
            case let double as Double:
                try container.encode(double)
            case let bool as Bool:
                try container.encode(bool)
            default:
                try container.encodeNil()
            }
        }

        private init(value: Any) {
            self.value = value
        }
    }

    private static func decodeLegacy1_0(from data: Data) throws -> Legacy1_0Document {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Legacy1_0Document.self, from: data)
    }

    private static func migrate1_0_to_1_0_27(_ legacy: Legacy1_0Document) -> VectorDocument {
        // Create new document with 1.0.27 format
        let document = VectorDocument()

        // Migrate settings
        document.settings.width = legacy.settings.width
        document.settings.height = legacy.settings.height
        document.settings.resolution = legacy.settings.resolution ?? 72

        if let unit = legacy.settings.unit {
            document.settings.unit = MeasurementUnit(rawValue: unit) ?? .inches
        }

        document.settings.showGrid = legacy.settings.showGrid ?? false
        document.settings.showRulers = legacy.settings.showRulers ?? true
        document.settings.snapToGrid = legacy.settings.snapToGrid ?? false
        document.settings.snapToPoint = legacy.settings.snapToPoint ?? false

        // Migrate layers
        var migratedLayers: [Layer] = []
        for legacyLayer in legacy.layers {
            let layer = Layer(
                id: UUID(uuidString: legacyLayer.id) ?? UUID(),
                name: legacyLayer.name,
                objectIDs: [],
                isVisible: legacyLayer.isVisible ?? true,
                isLocked: legacyLayer.isLocked ?? false,
                opacity: legacyLayer.opacity ?? 1.0,
                blendMode: BlendMode(rawValue: legacyLayer.blendMode ?? "Normal") ?? .normal,
                color: LayerColor(name: legacyLayer.color ?? "gray")
            )
            migratedLayers.append(layer)
        }

        // Sort objects by orderID to get correct Z-order
        let sortedObjects = legacy.unifiedObjects.sorted { obj1, obj2 in
            let order1 = obj1.orderID ?? 0
            let order2 = obj2.orderID ?? 0
            return order1 < order2
        }

        // Re-encode and decode sortedObjects through current VectorObject format
        // This is a workaround to convert the legacy format to current format
        // IMPORTANT: After sorting by orderID, objects are in back-to-front order
        if let objectsData = try? JSONEncoder().encode(sortedObjects),
           let jsonArray = try? JSONSerialization.jsonObject(with: objectsData) as? [[String: Any]] {

            // Process objects IN ORDER (already sorted by orderID)
            for (index, jsonObject) in jsonArray.enumerated() {
                if let objectData = try? JSONSerialization.data(withJSONObject: jsonObject),
                   var vectorObject = try? JSONDecoder().decode(VectorObject.self, from: objectData) {

                    // Convert legacy .shape with image data to .image type
                    if case .shape(let shape) = vectorObject.objectType {
                        let hasImage = shape.linkedImagePath != nil || shape.linkedImageBookmarkData != nil || shape.embeddedImageData != nil

                        if index == 2 {
                            Log.fileOperation("  [\(index)] DEBUG: name=\(shape.name), hasLinkedPath=\(shape.linkedImagePath != nil), hasBookmark=\(shape.linkedImageBookmarkData != nil), hasEmbedded=\(shape.embeddedImageData != nil)", level: .info)
                        }

                        if hasImage {
                            vectorObject = VectorObject(
                                id: vectorObject.id,
                                layerIndex: vectorObject.layerIndex,
                                objectType: .image(shape)
                            )
                            let imageType = shape.embeddedImageData != nil ? "embedded" : (shape.linkedImagePath != nil ? "linked path" : "bookmark")
                            Log.fileOperation("  [\(index)] Converted \(imageType) image to .image type: \(vectorObject.id)", level: .info)
                        }
                    } else if case .image(let shape) = vectorObject.objectType {
                        if index == 2 {
                            Log.fileOperation("  [\(index)] DEBUG: Already .image type, name=\(shape.name)", level: .info)
                        }
                    }

                    // Add object to snapshot
                    document.snapshot.objects[vectorObject.id] = vectorObject

                    // Add object ID to appropriate layer
                    let layerIndex = vectorObject.layerIndex
                    if layerIndex >= 0 && layerIndex < migratedLayers.count {
                        migratedLayers[layerIndex].objectIDs.append(vectorObject.id)
                        Log.fileOperation("  [\(index)] orderID → Layer \(layerIndex): \(vectorObject.id)", level: .debug)
                    }
                } else {
                    Log.fileOperation("⚠️ Failed to decode object at index \(index)", level: .warning)
                }
            }

            // Log final layer object counts
            for (layerIdx, layer) in migratedLayers.enumerated() {
                Log.fileOperation("  Layer \(layerIdx) '\(layer.name)': \(layer.objectIDs.count) objects", level: .info)
            }
        }

        document.snapshot.layers = migratedLayers
        document.snapshot.formatVersion = "1.0.27"

        // Migrate view state
        if let canvasOffset = legacy.canvasOffset, canvasOffset.count >= 2 {
            document.viewState.canvasOffset = CGPoint(x: canvasOffset[0], y: canvasOffset[1])
        }

        if let zoomLevel = legacy.zoomLevel {
            document.viewState.zoomLevel = zoomLevel
        }

        // Set layer expansion state: collapse layers with > 20 objects
        for layer in migratedLayers {
            if layer.objectIDs.count > 20 {
                document.settings.layerExpansionState[layer.id] = false
                Log.fileOperation("  📦 Collapsed layer '\(layer.name)' (\(layer.objectIDs.count) objects)", level: .debug)
            }
        }

        Log.fileOperation("✅ Successfully migrated document to version 1.0.27", level: .info)

        return document
    }

    /// Hydrates linked images after migration
    /// - Parameters:
    ///   - document: The migrated document
    ///   - sourceURL: The URL of the source .inkpen file
    static func hydrateLinkedImages(in document: VectorDocument, from sourceURL: URL?) {
        guard let sourceURL = sourceURL else { return }

        let baseDirectory = sourceURL.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDirectory, for: document)

        var imagesHydrated = 0
        for obj in document.snapshot.objects.values {
            if case .shape(let shape) = obj.objectType {
                if ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document) != nil {
                    imagesHydrated += 1
                }
            } else if case .image(let shape) = obj.objectType {
                if ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document) != nil {
                    imagesHydrated += 1
                }
            }
        }

        if imagesHydrated > 0 {
            Log.fileOperation("  🖼️ Hydrated \(imagesHydrated) linked image(s)", level: .info)
        }
    }
}
