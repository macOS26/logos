//
//  FileOperations+PDFImport.swift
//  logos inkpen.io
//
//  PDF import functionality extracted from FileOperations.swift
//

import Foundation
import AppKit

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
        
        // VectorDocument init already created Pasteboard, Canvas and Working layers with backgrounds
        // We only need to update the canvas size in settings (already done above)
        
        // Add all imported shapes to the layer
        for shape in result.shapes {
            var importedShape = shape
            
            // Ensure the shape is editable
            importedShape.isLocked = false
            importedShape.isVisible = true
            
            // Add shape to unified system (layer index 2 for working layer)
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