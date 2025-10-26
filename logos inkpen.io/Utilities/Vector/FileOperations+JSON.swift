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

        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let document = try decoder.decode(VectorDocument.self, from: jsonData)
            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent(), for: document)
            for obj in document.snapshot.objects.values {
                if case .shape(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
                }
            }
            return document
        } catch {
            Log.error("❌ JSON import failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to import JSON: \(error.localizedDescription)", line: nil)
        }
    }

    static func importFromJSONData(_ data: Data) throws -> VectorDocument {

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let document = try decoder.decode(VectorDocument.self, from: data)
            ImageContentRegistry.setBaseDirectory(nil, for: document)
            for obj in document.snapshot.objects.values {
                if case .shape(let shape) = obj.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape, in: document)
                }
            }
            return document
        } catch {
            Log.error("❌ JSON data import failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to import JSON: \(error.localizedDescription)", line: nil)
        }
    }
}
