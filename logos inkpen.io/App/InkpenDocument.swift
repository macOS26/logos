//
//  InkpenDocument.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/23/25.
//

import SwiftUI
import UniformTypeIdentifiers
import Combine

// MARK: - InkpenDocument for DocumentGroup (ADDITION - not replacement)
struct InkpenDocument: FileDocument {
    var document: VectorDocument
    
    static var readableContentTypes: [UTType] { [.inkpen, .svg, .pdf] }
    static var writableContentTypes: [UTType] { [.inkpen, .svg, .pdf] }
    
    init() {
        self.document = VectorDocument()
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

                // Debug: Check unified objects before and after population
                Log.info("🔍 DEBUG: Unified objects BEFORE populate: \(self.document.unifiedObjects.count)", category: .fileOperations)

                // CRITICAL FIX: Populate unified objects system after SVG import for proper rendering
                // For SVG imports, we want to preserve the original stacking order from the SVG
                self.document.populateUnifiedObjectsFromLayersPreservingOrder()

                Log.info("🔍 DEBUG: Unified objects AFTER populate: \(self.document.unifiedObjects.count)", category: .fileOperations)

                // CRITICAL FIX: Reset all text objects' editing state when loading a document
                // This prevents text fields from incorrectly entering i-beam edit mode on document open
                var textCount = 0
                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                        textCount += 1
                    }
                }
                if textCount > 0 {
                    Log.info("🔄 Reset editing state for \(textCount) text objects (SVG import)", category: .fileOperations)
                }

                self.document.updateUnifiedObjectsOptimized()
                self.document.objectWillChange.send()

                Log.info("✅ SVG document loaded and unified system populated with \(self.document.unifiedObjects.count) objects", category: .fileOperations)
            } catch {
                Log.error("❌ Failed to load SVG document: \(error)", category: .error)
                throw error
            }
        } else if fileExtension == "pdf" {
            // For PDF files, use the data-based approach
            do {
                self.document = try FileOperations.importFromPDFData(data)

                // CRITICAL FIX: Populate unified objects system after PDF import for proper rendering
                // For PDF imports, we want to preserve the original stacking order from the PDF
                self.document.populateUnifiedObjectsFromLayersPreservingOrder()

                // CRITICAL FIX: Reset all text objects' editing state when loading a document
                // This prevents text fields from incorrectly entering i-beam edit mode on document open
                var textCount = 0
                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                        textCount += 1
                    }
                }
                if textCount > 0 {
                    Log.info("🔄 Reset editing state for \(textCount) text objects (PDF import)", category: .fileOperations)
                }

                self.document.updateUnifiedObjectsOptimized()
                self.document.objectWillChange.send()

                Log.info("✅ PDF document loaded and unified system populated with \(self.document.unifiedObjects.count) objects", category: .fileOperations)
            } catch {
                Log.error("❌ Failed to load PDF document: \(error)", category: .error)
                throw error
            }
        } else {
            // Handle InkPen/JSON file import
            do {
                let startDecode = CFAbsoluteTimeGetCurrent()
                self.document = try FileOperations.importFromJSONData(data)
                let endDecode = CFAbsoluteTimeGetCurrent()
                Log.info("⚡️ JSON DECODE: \((endDecode - startDecode) * 1000)ms for \(self.document.unifiedObjects.count) objects", category: .fileOperations)

                // CRITICAL FIX: Reset all text objects' editing state when loading a document
                // This prevents text fields from incorrectly entering i-beam edit mode on document open
                var textCount = 0
                for unifiedObj in self.document.unifiedObjects {
                    if case .shape(let shape) = unifiedObj.objectType, shape.isTextObject {
                        self.document.setTextEditingInUnified(id: shape.id, isEditing: false)
                        textCount += 1
                    }
                }
                Log.info("🔄 Reset editing state for \(textCount) text objects", category: .fileOperations)

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
                self.document.updateUnifiedObjectsOptimized()
                self.document.objectWillChange.send()

                Log.info("✅ JSON document loaded and unified system populated with \(self.document.unifiedObjects.count) objects", category: .fileOperations)
            } catch {
                Log.error("❌ Failed to load JSON document: \(error)", category: .error)
                throw error
            }
        }
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        // Debug logging to see what content type we're getting
        Log.info("🔍 SAVE DEBUG: contentType = \(configuration.contentType.identifier)", category: .fileOperations)
        Log.info("🔍 SAVE DEBUG: contentType description = \(configuration.contentType.description)", category: .fileOperations)
        
        // Check content type to determine export format
        if configuration.contentType == .svg ||
            configuration.contentType.conforms(to: .svg) ||
           configuration.contentType.identifier.contains("svg") {
            // Export as SVG using proper SVG exporter
            // Default to .lines for Save As operations
            do {
                let svgContent = try SVGExporter.shared.exportToSVG(document, includeBackground: false, textRenderingMode: .lines, includeInkpenData: true)
                let data = svgContent.data(using: .utf8) ?? Data()
                Log.info("✅ Successfully exported SVG document data (with embedded inkpen data)", category: .fileOperations)
                return FileWrapper(regularFileWithContents: data)
            } catch {
                Log.error("❌ Failed to save SVG document: \(error)", category: .error)
                throw error
            }
        } else if configuration.contentType == .pdf ||
                  configuration.contentType.conforms(to: .pdf) ||
                  configuration.contentType.identifier.contains("pdf") {
            // Export as PDF
            do {
                let pdfData = try FileOperations.generatePDFDataForExport(from: document, useCMYK: false, textRenderingMode: .lines, includeInkpenData: true, includeBackground: false)
                Log.info("✅ Successfully exported PDF document data", category: .fileOperations)
                return FileWrapper(regularFileWithContents: pdfData)
            } catch {
                Log.error("❌ Failed to save PDF document: \(error)", category: .error)
                throw error
            }
        } else {
            // Export as JSON (default for .inkpen and .json files)
            do {
                // Use the thread-safe exportToJSONData method
                let data = try FileOperations.exportToJSONData(document)
                Log.info("✅ Successfully exported JSON document data", category: .fileOperations)
                return FileWrapper(regularFileWithContents: data)
            } catch {
                Log.error("❌ Failed to save JSON document: \(error)", category: .error)
                throw error
            }
        }
    }
}