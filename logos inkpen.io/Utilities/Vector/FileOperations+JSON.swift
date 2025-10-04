//
//  FileOperations+JSON.swift
//  logos inkpen.io
//
//  JSON import/export functionality extracted from FileOperations.swift
//

import SwiftUI
import Combine

extension FileOperations {
    
    // MARK: - JSON Export
    
    static func exportToJSON(_ document: VectorDocument, url: URL) throws {
        
        // Create a thread-safe copy of the data before encoding
        let jsonData = try exportToJSONData(document)
        
        // Before encoding, ensure raster shapes carry link info by default
        let baseDir = url.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDir)
        
        do {
            try jsonData.write(to: url)
        } catch {
            // Log.error("❌ JSON export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }
    
    static func exportToJSONData(_ document: VectorDocument) throws -> Data {

        // Create a thread-safe snapshot of the document data
        // This avoids accessing @Published properties from background thread
        let snapshot = DocumentSnapshot(from: document)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(snapshot)
            return jsonData
        } catch {
            // Log.error("❌ JSON data export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }
    
    // MARK: - JSON Import
    
    static func importFromJSON(url: URL) throws -> VectorDocument {
        
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let document = try decoder.decode(VectorDocument.self, from: jsonData)
            // After decoding, hydrate raster images from embedded data or linked paths
            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent())
            // Use unified objects to hydrate all shapes
            for unifiedObject in document.unifiedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape)
                }
            }
            // Don't trigger UI updates from background thread - let the caller handle it
            return document
        } catch {
            // Log.error("❌ JSON import failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to import JSON: \(error.localizedDescription)", line: nil)
        }
    }
    
    // MARK: - Data-based methods for DocumentGroup
    
    static func importFromJSONData(_ data: Data) throws -> VectorDocument {
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let document = try decoder.decode(VectorDocument.self, from: data)
            // Note: Without a file URL, we cannot resolve relative paths. Embedded images will still load.
            ImageContentRegistry.setBaseDirectory(nil)
            // Use unified objects to hydrate all shapes
            for unifiedObject in document.unifiedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    ImageContentRegistry.hydrateImageIfAvailable(for: shape)
                }
            }
            // Don't trigger UI updates from background thread - let the caller handle it
            return document
        } catch {
            // Log.error("❌ JSON data import failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to import JSON: \(error.localizedDescription)", line: nil)
        }
    }
}

// MARK: - Thread-Safe Document Snapshot

/// A thread-safe snapshot of VectorDocument that can be encoded without accessing @Published properties
private struct DocumentSnapshot: Codable {
    let settings: DocumentSettings
    let layers: [VectorLayer]
    let currentTool: DrawingTool
    let viewMode: ViewMode
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let unifiedObjects: [VectorObject]
    
    init(from document: VectorDocument) {
        // Create deep copies of all data to avoid any reference to @Published properties
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
