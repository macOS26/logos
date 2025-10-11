import SwiftUI
import Combine

extension FileOperations {


    static func exportToJSON(_ document: VectorDocument, url: URL) throws {

        let jsonData = try exportToJSONData(document)

        let baseDir = url.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDir)

        do {
            try jsonData.write(to: url)
        } catch {
            Log.error("❌ JSON export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }

    static func exportToJSONData(_ document: VectorDocument) throws -> Data {

        let snapshot = DocumentSnapshot(from: document)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(snapshot)
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
            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent())
            for unifiedObject in document.unifiedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape)
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
            ImageContentRegistry.setBaseDirectory(nil)
            for unifiedObject in document.unifiedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape)
                }
            }
            return document
        } catch {
            Log.error("❌ JSON data import failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to import JSON: \(error.localizedDescription)", line: nil)
        }
    }
}


private struct DocumentSnapshot: Codable {
    let settings: DocumentSettings
    let layers: [VectorLayer]
    let currentTool: DrawingTool
    let viewMode: ViewMode
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let unifiedObjects: [VectorObject]

    init(from document: VectorDocument) {
        self.settings = document.settings
        self.layers = document.layers
        self.currentTool = document.currentTool
        self.viewMode = document.viewMode
        self.zoomLevel = document.zoomLevel
        self.canvasOffset = document.canvasOffset
        self.unifiedObjects = document.unifiedObjects
    }

    enum CodingKeys: CodingKey {
        case settings, layers, currentTool, viewMode, zoomLevel, canvasOffset, unifiedObjects
    }
}
