import SwiftUI
import Combine

extension FileOperations {

    static func exportToJSON(_ document: VectorDocument, url: URL) throws {

        let jsonData = try exportToJSONData(document)
        let baseDir = url.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDir, for: document)

        do {
            try jsonData.write(to: url)
        } catch {
            Log.error("❌ JSON export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }

    static func exportToJSONData(_ document: VectorDocument) throws -> Data {
        // Encode VectorDocument directly - no snapshot copy needed
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(document)
            return jsonData
        } catch {
            Log.error("❌ JSON data export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }

    static func importFromJSON(url: URL) throws -> VectorDocument {

        let jsonData = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try to decode as current format first
        if let document = try? decoder.decode(VectorDocument.self, from: jsonData) {
            // Log version for migration tracking
            Log.fileOperation("📦 Opened inkpen document version: \(document.snapshot.formatVersion)", level: .info)

            // Remove legacy background objects
            removeLegacyBackgroundObjects(from: document)

            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent(), for: document)
            for obj in document.snapshot.objects.values {
                if case .shape(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
                }
            }
            return document
        }

        // Fallback: Try migration from legacy format
        Log.fileOperation("⚠️ Current format failed, attempting legacy migration...", level: .warning)
        if let migratedDocument = InkpenMigrator.migrateLegacyDocument(from: jsonData) {
            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent(), for: migratedDocument)
            for obj in migratedDocument.snapshot.objects.values {
                if case .shape(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: migratedDocument)
                }
            }
            return migratedDocument
        }

        Log.error("❌ JSON import failed: Unable to decode as current or legacy format", category: .error)
        throw VectorImportError.parsingError("Failed to import JSON: Unable to decode document", line: nil)
    }

    static func importFromJSONData(_ data: Data, sourceURL: URL? = nil) throws -> VectorDocument {

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Try to decode as current format first
        if let document = try? decoder.decode(VectorDocument.self, from: data) {
            // Remove legacy background objects
            removeLegacyBackgroundObjects(from: document)

            // Set base directory for image hydration
            let baseDirectory = sourceURL?.deletingLastPathComponent()
            ImageContentRegistry.setBaseDirectory(baseDirectory, for: document)

            // Hydrate all images
            for obj in document.snapshot.objects.values {
                if case .shape(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
                } else if case .image(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
                }
            }
            return document
        }

        // Fallback: Try migration from legacy format
        Log.fileOperation("⚠️ Current format failed, attempting legacy migration...", level: .warning)
        if let migratedDocument = InkpenMigrator.migrateLegacyDocument(from: data) {
            // Set base directory for image hydration
            let baseDirectory = sourceURL?.deletingLastPathComponent()
            ImageContentRegistry.setBaseDirectory(baseDirectory, for: migratedDocument)

            // Hydrate all images (including legacy linked images)
            for obj in migratedDocument.snapshot.objects.values {
                if case .shape(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: migratedDocument)
                } else if case .image(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: migratedDocument)
                }
            }
            return migratedDocument
        }

        Log.error("❌ JSON data import failed: Unable to decode as current or legacy format", category: .error)
        throw VectorImportError.parsingError("Failed to import JSON: Unable to decode document", line: nil)
    }

    /// Remove legacy "Canvas Background" and "Pasteboard Background" objects from layers
    static func removeLegacyBackgroundObjects(from document: VectorDocument) {
        for layerIndex in 0..<document.snapshot.layers.count {
            var layer = document.snapshot.layers[layerIndex]

            // Find objects named "Canvas Background" or "Pasteboard Background"
            var objectsToRemove: [UUID] = []
            for objectID in layer.objectIDs {
                guard let obj = document.snapshot.objects[objectID] else { continue }

                // Extract shape from objectType
                let shapeName: String?
                switch obj.objectType {
                case .shape(let shape), .text(let shape), .image(let shape),
                     .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    shapeName = shape.name
                }

                print("🔍 Layer '\(layer.name)' object: '\(shapeName ?? "nil")'")

                if shapeName == "Canvas Background" || shapeName == "Pasteboard Background" {
                    objectsToRemove.append(objectID)
                    print("✅ Marked for removal: '\(shapeName!)'")
                }
            }

            // Remove from layer
            if !objectsToRemove.isEmpty {
                layer.objectIDs.removeAll { objectsToRemove.contains($0) }
                document.snapshot.layers[layerIndex] = layer

                // Remove from objects dictionary
                for objectID in objectsToRemove {
                    document.snapshot.objects.removeValue(forKey: objectID)
                }

                Log.fileOperation("🧹 Removed \(objectsToRemove.count) legacy background object(s) from layer '\(layer.name)'", level: .info)
            }
        }
    }
}
