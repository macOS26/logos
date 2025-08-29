//
//  InkpenDocument.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - InkpenDocument for DocumentGroup (ADDITION - not replacement)
struct InkpenDocument: FileDocument {
    var document: VectorDocument
    
    static var readableContentTypes: [UTType] { [.inkpen, .svg] }
    
    init() {
        self.document = VectorDocument()
    }
    
    init(document: VectorDocument) {
        self.document = document
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        // Check if this is an SVG file by examining the file extension or content
        // For FileDocument, we need to check the file extension from the configuration
        let fileExtension = configuration.file.preferredFilename?.components(separatedBy: ".").last?.lowercased()
        
        if fileExtension == "svg" {
            // For SVG files, we need to create a temporary URL to pass to the import function
            // Since FileDocument doesn't provide direct URL access, we'll use the data-based approach
            // and let the import function handle the SVG parsing from data
            do {
                self.document = try FileOperations.importFromSVGData(data)
                
                // CRITICAL FIX: Populate unified objects system after SVG import for proper rendering
                // For SVG imports, we want to preserve the original stacking order from the SVG
                self.document.populateUnifiedObjectsFromLayersPreservingOrder()
                self.document.syncUnifiedObjectsAfterPropertyChange()
                self.document.objectWillChange.send()
                
                Log.info("✅ SVG document loaded and unified system populated with \(self.document.unifiedObjects.count) objects", category: .fileOperations)
            } catch {
                Log.error("❌ Failed to load SVG document: \(error)", category: .error)
                throw error
            }
        } else {
            // Handle InkPen/JSON file import
            do {
                self.document = try FileOperations.importFromJSONData(data)
                
                // CRITICAL FIX: Only populate unified objects if they weren't loaded from the JSON file
                // If unified objects exist in the saved file, preserve their exact ordering
                if self.document.unifiedObjects.isEmpty {
                    // File didn't have unified objects (legacy file) - populate from layers
                    self.document.populateUnifiedObjectsFromLayersPreservingOrder()
                    Log.info("📦 LEGACY IMPORT: Populated unified objects from layers (legacy file format)", category: .fileOperations)
                } else {
                    // File has unified objects - preserve the saved ordering
                    Log.info("📦 MODERN IMPORT: Preserving unified objects ordering from saved file (\(self.document.unifiedObjects.count) objects)", category: .fileOperations)
                }
                self.document.syncUnifiedObjectsAfterPropertyChange()
                self.document.objectWillChange.send()
                
                Log.info("✅ JSON document loaded and unified system populated with \(self.document.unifiedObjects.count) objects", category: .fileOperations)
            } catch {
                Log.error("❌ Failed to load JSON document: \(error)", category: .error)
                throw error
            }
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        do {
            let data = try FileOperations.exportToJSONData(document)
            return FileWrapper(regularFileWithContents: data)
        } catch {
            Log.error("❌ Failed to save document: \(error)", category: .error)
            throw error
        }
    }
}
