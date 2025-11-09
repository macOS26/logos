import Foundation

/// Handles migration of inkpen documents from older versions to current version
/// WARNING: Uses legacy format structures from LegacyFormats.swift
struct InkpenMigrator {

    /// Migrates a document from any version to the current version (1.0.27)
    static func migrate(data: Data) throws -> VectorDocument {
        // First, try to decode as current format
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try current format first
        if let document = try? decoder.decode(VectorDocument.self, from: data) {
            Log.fileOperation("📦 Document already in current format: \(document.snapshot.formatVersion)", level: .info)
            return document
        }

        // Try to decode as legacy format
        do {
            let legacyDoc = try decoder.decode(LegacyDocument_v1_0.self, from: data)
            Log.fileOperation("📦 Migrating document from version 1.0 to 1.0.27", level: .info)
            return migrateFrom_v1_0(legacyDoc)
        } catch {
            Log.error("❌ Failed to decode as legacy format: \(error)", category: .error)
            throw VectorImportError.parsingError("Unable to migrate document: \(error.localizedDescription)", line: nil)
        }
    }

    /// Migrates from version 1.0 to 1.0.27
    private static func migrateFrom_v1_0(_ legacy: LegacyDocument_v1_0) -> VectorDocument {
        let document = VectorDocument()

        // Migrate settings
        document.snapshot.settings = legacy.settings

        // Migrate layers (convert old layer structure to new)
        var newLayers: [Layer] = []
        for oldLayer in legacy.layers {
            let layer = Layer(
                id: oldLayer.id,
                name: oldLayer.name,
                objectIDs: [], // Will be populated from objects
                isVisible: true,
                isLocked: oldLayer.isLocked ?? false,
                opacity: 1.0,
                blendMode: .normal,
                color: LayerColor(name: oldLayer.color)
            )
            newLayers.append(layer)
        }
        document.snapshot.layers = newLayers

        // Migrate objects
        var objectsDict: [UUID: VectorObject] = [:]

        for oldObj in legacy.unifiedObjects {
            let newObj = VectorObject(
                id: oldObj.id,
                layerIndex: oldObj.layerIndex,
                objectType: oldObj.objectType
            )
            objectsDict[oldObj.id] = newObj

            // Add object ID to the appropriate layer
            if oldObj.layerIndex >= 0 && oldObj.layerIndex < newLayers.count {
                document.snapshot.layers[oldObj.layerIndex].objectIDs.append(oldObj.id)
            }
        }

        document.snapshot.objects = objectsDict

        // Migrate view state
        if let offset = legacy.canvasOffset {
            document.viewState.canvasOffset = CGPoint(x: offset[0], y: offset[1])
        }
        document.viewState.zoomLevel = legacy.zoomLevel ?? 1.0

        // Migrate current tool
        if let toolString = legacy.currentTool {
            document.viewState.currentTool = DrawingTool(rawValue: toolString) ?? .selection
        }

        // Migrate view mode
        if let viewModeString = legacy.viewMode {
            document.viewState.viewMode = ViewMode(rawValue: viewModeString) ?? .color
        }

        // Set format version
        document.snapshot.formatVersion = "1.0.27"

        Log.fileOperation("✅ Successfully migrated document from v1.0 to v1.0.27", level: .info)
        return document
    }
}
