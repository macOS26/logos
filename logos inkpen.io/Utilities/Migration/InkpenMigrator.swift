import Foundation

/// Handles migration of legacy inkpen file formats to current version
struct InkpenMigrator {

    /// Attempts to migrate legacy inkpen data to current format
    /// - Parameter data: The raw JSON data from the file
    /// - Returns: A migrated VectorDocument, or nil if migration fails
    static func migrateLegacyDocument(from data: Data) -> VectorDocument? {
        // Try to decode as legacy 1.0 format
        if let legacyDoc = try? decodeLegacy1_0(from: data) {
            Log.fileOperation("🔄 Migrating document from version 1.0 to 1.0.27", level: .info)
            return migrate1_0_to_1_0_27(legacyDoc)
        }

        return nil
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
        var color: String
        var id: String
        var isLocked: Bool?
        var name: String
        var opacity: Double?
        var blendMode: String?
        var isVisible: Bool?
    }

    private struct Legacy1_0Settings: Codable {
        var backgroundColor: String?
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
        var groupExpansionState: [String]?
        var layerExpansionState: [String]?
        var customRgbSwatches: [[String: Double]]?
        var customCmykSwatches: [[String: Double]]?
        var customHsbSwatches: [[String: Double]]?
    }

    private struct Legacy1_0Object: Codable {
        var id: String
        var layerIndex: Int
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
                color: LayerColor(name: legacyLayer.color)
            )
            migratedLayers.append(layer)
        }

        // Re-encode and decode unifiedObjects through current VectorObject format
        // This is a workaround to convert the legacy format to current format
        // IMPORTANT: Legacy format is front-to-back, current format is back-to-front
        if let objectsData = try? JSONEncoder().encode(legacy.unifiedObjects),
           let jsonArray = try? JSONSerialization.jsonObject(with: objectsData) as? [[String: Any]] {

            // Process objects IN REVERSE ORDER because:
            // - Legacy unifiedObjects: front-to-back (index 0 = frontmost)
            // - Current objectIDs: back-to-front (index 0 = backmost)
            for (index, jsonObject) in jsonArray.reversed().enumerated() {
                if let objectData = try? JSONSerialization.data(withJSONObject: jsonObject),
                   let vectorObject = try? JSONDecoder().decode(VectorObject.self, from: objectData) {

                    // Add object to snapshot
                    document.snapshot.objects[vectorObject.id] = vectorObject

                    // Add object ID to appropriate layer IN REVERSE ORDER
                    let layerIndex = vectorObject.layerIndex
                    if layerIndex >= 0 && layerIndex < migratedLayers.count {
                        migratedLayers[layerIndex].objectIDs.append(vectorObject.id)
                        Log.fileOperation("  [rev \(index)] → Layer \(layerIndex): \(vectorObject.id)", level: .debug)
                    }
                } else {
                    Log.fileOperation("⚠️ Failed to decode object at reverse index \(index)", level: .warning)
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

        Log.fileOperation("✅ Successfully migrated document to version 1.0.27", level: .info)

        return document
    }
}
