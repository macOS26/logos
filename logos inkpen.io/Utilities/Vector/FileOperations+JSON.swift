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
        Log.info("💾 Exporting document to JSON: \(url.path)", category: .general)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        // Before encoding, ensure raster shapes carry link info by default
        // Rule: default to linked path; embedding happens via explicit menu action elsewhere.
        // We cannot mutate the live document here; instead, we rely on the model fields already being set
        // during import or explicit actions. We do, however, set the base directory for path resolution.
        let baseDir = url.deletingLastPathComponent()
        ImageContentRegistry.setBaseDirectory(baseDir)
        
        do {
            let jsonData = try encoder.encode(document)
            try jsonData.write(to: url)
            Log.info("✅ Successfully exported JSON document", category: .fileOperations)
        } catch {
            Log.error("❌ JSON export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }
    
    @MainActor
    static func exportToJSONData(_ document: VectorDocument) throws -> Data {
        Log.info("💾 Exporting document to JSON data", category: .general)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        do {
            let jsonData = try encoder.encode(document)
            Log.info("✅ Successfully exported JSON document data", category: .fileOperations)
            return jsonData
        } catch {
            Log.error("❌ JSON data export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }
    
    // MARK: - JSON Import
    
    static func importFromJSON(url: URL) throws -> VectorDocument {
        Log.info("📂 Importing document from JSON: \(url.path)", category: .general)
        
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let document = try decoder.decode(VectorDocument.self, from: jsonData)
            Log.info("✅ Successfully imported JSON document with \(document.layers.count) layers", category: .fileOperations)
            // After decoding, hydrate raster images from embedded data or linked paths
            ImageContentRegistry.setBaseDirectory(url.deletingLastPathComponent())
            // Use unified objects to hydrate all shapes
            for unifiedObject in document.unifiedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    _ = ImageContentRegistry.hydrateImageIfAvailable(for: shape)
                }
            }
            // Trigger UI refresh after hydration
            DispatchQueue.main.async {
                document.objectWillChange.send()
            }
            return document
        } catch {
            Log.error("❌ JSON import failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to import JSON: \(error.localizedDescription)", line: nil)
        }
    }
    
    // MARK: - Data-based methods for DocumentGroup
    
    static func importFromJSONData(_ data: Data) throws -> VectorDocument {
        Log.info("📂 Importing document from JSON data", category: .general)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let document = try decoder.decode(VectorDocument.self, from: data)
            Log.info("✅ Successfully imported JSON document with \(document.layers.count) layers", category: .fileOperations)
            // Note: Without a file URL, we cannot resolve relative paths. Embedded images will still load.
            ImageContentRegistry.setBaseDirectory(nil)
            // Use unified objects to hydrate all shapes
            for unifiedObject in document.unifiedObjects {
                if case .shape(let shape) = unifiedObject.objectType {
                    _ = ImageContentRegistry.hydrateImageIfAvailable(for: shape)
                }
            }
            // Trigger UI refresh after hydration
            DispatchQueue.main.async {
                document.objectWillChange.send()
            }
            return document
        } catch {
            Log.error("❌ JSON data import failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to import JSON: \(error.localizedDescription)", line: nil)
        }
    }
}
