//
//  FileOperations+PDFImport.swift
//  logos inkpen.io
//
//  PDF import functionality extracted from FileOperations.swift
//

import SwiftUI

extension FileOperations {
    
    // MARK: - PDF Import
    
    /// Import PDF from data for FileDocument protocol
    static func importFromPDFData(_ data: Data) throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from PDF data", level: .info)
        
        // Create a temporary file to use with the existing PDF import infrastructure
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("pdf")
        
        do {
            try data.write(to: tempURL)
            let document = try importFromPDFSync(url: tempURL)
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
            
            Log.fileOperation("✅ PDF data import completed", level: .info)
            
            return document
        } catch {
            // Clean up temporary file on error
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
    
    /// Synchronous version of PDF import for FileDocument protocol
    static func importFromPDFSync(url: URL) throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from PDF (sync): \(url.path)", level: .info)
        
        // Use a semaphore to make the async call synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var resultDocument: VectorDocument?
        var resultError: Error?
        
        Task {
            do {
                resultDocument = try await importFromPDF(url: url)
            } catch {
                resultError = error
            }
            semaphore.signal()
        }
        
        semaphore.wait()
        
        if let error = resultError {
            throw error
        }
        
        guard let document = resultDocument else {
            throw VectorImportError.parsingError("Failed to import PDF: Unknown error", line: nil)
        }
        
        return document
    }
    
    /// Async PDF import method
    static func importFromPDF(url: URL) async throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from PDF: \(url.path)", level: .info)
        
        let result = await VectorImportManager.shared.importVectorFile(from: url)

        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown PDF import error"
            throw VectorImportError.parsingError("Failed to import PDF: \(errorMessage)", line: nil)
        }

        // Check if PDF contains embedded inkpen metadata
        if let inkpenMetadata = result.metadata.inkpenMetadata {
            Log.info("📦 Found embedded inkpen document in PDF, using native data", category: .fileOperations)

            // Decode base64 and parse as JSON
            guard let inkpenData = Data(base64Encoded: inkpenMetadata) else {
                Log.error("❌ Failed to decode inkpen metadata from base64", category: .error)
                throw VectorImportError.parsingError("Invalid inkpen metadata encoding", line: nil)
            }

            // Parse as inkpen document
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let inkpenDocument = try decoder.decode(VectorDocument.self, from: inkpenData)

            // Return the original inkpen document
            Log.info("✅ Successfully restored inkpen document from PDF metadata", category: .fileOperations)
            return inkpenDocument
        }

        // Create a new VectorDocument from the imported shapes
        let document = VectorDocument()
        
        // Use document dimensions from PDF file metadata
        let pdfDocumentSize = result.metadata.documentSize
        let canvasWidth = pdfDocumentSize.width
        let canvasHeight = pdfDocumentSize.height
        
        // Set document size based on PDF dimensions
        document.settings.width = canvasWidth / 72.0 // Convert to inches
        document.settings.height = canvasHeight / 72.0
        document.settings.unit = .inches

        Log.fileOperation("🎯 PDF IMPORT USING DOCUMENT DIMENSIONS:", level: .info)
        Log.info("   PDF document size: \(pdfDocumentSize)", category: .general)
        Log.info("   Canvas size: \(canvasWidth) × \(canvasHeight) pts", category: .general)

        // CRITICAL FIX: Update the canvas background to match the PDF dimensions
        // VectorDocument init already created Pasteboard, Canvas and Working layers with default 8.5x11 size
        // We need to update them to match the actual PDF size
        document.updateCanvasLayer()
        document.updatePasteboardLayer()
        
        // Add all imported shapes to the layer
        for shape in result.shapes {
            var importedShape = shape

            // Ensure the shape is editable
            importedShape.isLocked = false
            importedShape.isVisible = true

            // Register embedded images in ImageContentRegistry
            if let imageData = importedShape.embeddedImageData {
                Log.info("PDF IMPORT: 🔍 Found embedded image data for '\(importedShape.name)' - \(imageData.count) bytes", category: .debug)
                if let nsImage = NSImage(data: imageData) {
                    ImageContentRegistry.register(image: nsImage, for: importedShape.id)
                    Log.info("📸 REGISTERED image '\(importedShape.name)' ID: \(importedShape.id) - Size: \(nsImage.size)", category: .fileOperations)
                    Log.info("PDF IMPORT: ✅ Successfully registered image in ImageContentRegistry", category: .general)
                } else {
                    Log.error("PDF IMPORT: ❌ Failed to create NSImage from \(imageData.count) bytes of data", category: .error)
                    Log.error("❌ Could not create NSImage from embedded data for '\(importedShape.name)'", category: .error)
                }
            } else {
                Log.info("PDF IMPORT: ℹ️ Shape '\(importedShape.name)' has no embedded image data", category: .general)
            }

            // Add shape to unified system (layer index 2 for working layer)
            if importedShape.isTextObject {
                Log.info("📝 PDF Import: Adding text shape '\(importedShape.name)' to layer 2", category: .general)
                Log.info("   Text content: '\((importedShape.textContent ?? "").prefix(30))'", category: .general)
                Log.info("   Position: \(importedShape.textPosition ?? .zero)", category: .general)
                Log.info("   Bounds: \(importedShape.bounds), Area: \(importedShape.areaSize ?? .zero)", category: .general)
            }
            document.addShapeToUnifiedSystem(importedShape, layerIndex: 2)
        }

        // Select the working layer which contains imported shapes
        document.selectedLayerIndex = 2 // Working layer is at index 2
        
        // Log warnings if any
        for warning in result.warnings {
            Log.fileOperation("⚠️ PDF Import Warning: \(warning)", level: .info)
        }
        
        Log.info("✅ Successfully imported PDF document with \(result.shapes.count) shapes", category: .fileOperations)
        Log.fileOperation("📐 Canvas sized to document dimensions: \(canvasWidth) × \(canvasHeight) pts", level: .info)
        return document
    }
}
