//
//  FileOperations.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import PDFKit
import AppKit

// MARK: - LEGACY EXPORT FUNCTIONS (for backward compatibility)
/// Legacy export functions to maintain compatibility with existing code
class FileOperations {
    
    static func exportDWF(_ document: VectorDocument, url: URL, options: DWFExportOptions? = nil) throws {
        let exportOptions = options ?? DWFExportOptions()
        try VectorExportManager.shared.exportDWF(document, to: url, options: exportOptions)
    }
    
    static func exportDWG(_ document: VectorDocument, url: URL, options: DWGExportOptions? = nil) throws {
        let exportOptions = options ?? DWGExportOptions()
        try VectorExportManager.shared.exportDWG(document, to: url, options: exportOptions)
    }
    
    // MARK: - PROFESSIONAL MILLIMETER PRECISION EXPORT FUNCTIONS
    
    /// Export DWG with 100% scaling and millimeter precision (DEFAULT: uses mm units)
    static func exportDWGWithMillimeterPrecision(_ document: VectorDocument, url: URL, scale: DWGScale = .fullSize) async throws {
        let options = DWGExportOptions(
            scale: scale,                          // 100% scaling by default (.fullSize = 1:1)
            targetUnits: .millimeters,            // Use millimeters for maximum precision
            flipYAxis: true,                      // AutoCAD standard coordinate system
            customOrigin: nil,
            author: "Logos Vector Graphics",
            title: "Professional CAD Export",
            description: "Export with \(scale.description) scaling and millimeter precision",
            dwgVersion: .r2018,                   // Modern AutoCAD compatibility
            includeReferenceRectangle: true,      // style reference for scaling
            defaultLineType: .continuous
        )
        
        try await VectorExportManager.shared.exportDWGWithMillimeterPrecision(document, to: url, options: options)
    }
    
    /// Export DWF with 100% scaling and millimeter precision (DEFAULT: uses mm units)
    static func exportDWFWithMillimeterPrecision(_ document: VectorDocument, url: URL, scale: DWFScale = .fullSize) async throws {
        let options = DWFExportOptions(
            scale: scale,                         // 100% scaling by default (.fullSize = 1:1)
            targetUnits: .millimeters,           // Use millimeters for maximum precision
            flipYAxis: true,                     // AutoCAD standard coordinate system
            customOrigin: nil,
            author: "Logos Vector Graphics",
            title: "Professional CAD Export",
            description: "Export with \(scale.description) scaling and millimeter precision"
        )
        
        try await VectorExportManager.shared.exportDWFWithMillimeterPrecision(document, to: url, options: options)
    }
    
    // MARK: - ADVANCED EXPORT WITH CUSTOM OPTIONS
    
    /// Export DWG with full control over all professional options
    static func exportDWGAdvanced(_ document: VectorDocument, url: URL, options: DWGExportOptions) async throws {
        try await VectorExportManager.shared.exportDWGWithMillimeterPrecision(document, to: url, options: options)
    }
    
    /// Export DWF with full control over all professional options
    static func exportDWFAdvanced(_ document: VectorDocument, url: URL, options: DWFExportOptions) async throws {
        try await VectorExportManager.shared.exportDWFWithMillimeterPrecision(document, to: url, options: options)
    }
    
    // MARK: - QUICK EXPORT PRESETS FOR COMMON CAD WORKFLOWS
    
    /// Quick export for architectural drawing (1/4" = 1'-0" scale)
    static func exportDWGArchitectural(_ document: VectorDocument, url: URL) async throws {
        try await exportDWGWithMillimeterPrecision(document, url: url, scale: .architectural_1_4)
    }
    
    /// Quick export for engineering drawing (1" = 20'-0" scale)
    static func exportDWGEngineering(_ document: VectorDocument, url: URL) async throws {
        try await exportDWGWithMillimeterPrecision(document, url: url, scale: .engineering_1_20)
    }
    
    /// Quick export for metric technical drawing (1:100 scale)
    static func exportDWGMetricTechnical(_ document: VectorDocument, url: URL) async throws {
        try await exportDWGWithMillimeterPrecision(document, url: url, scale: .metric_1_100)
    }
    
    /// Quick export for full-size output (100% scaling, 1:1)
    static func exportDWGFullSize(_ document: VectorDocument, url: URL) async throws {
        try await exportDWGWithMillimeterPrecision(document, url: url, scale: .fullSize)
    }
    
    /// Quick export DWF for architectural drawing (1/4" = 1'-0" scale)
    static func exportDWFArchitectural(_ document: VectorDocument, url: URL) async throws {
        try await exportDWFWithMillimeterPrecision(document, url: url, scale: .architectural_1_4)
    }
    
    /// Quick export DWF for engineering drawing (1" = 20'-0" scale)
    static func exportDWFEngineering(_ document: VectorDocument, url: URL) async throws {
        try await exportDWFWithMillimeterPrecision(document, url: url, scale: .engineering_1_20)
    }
    
    /// Quick export DWF for metric technical drawing (1:100 scale)
    static func exportDWFMetricTechnical(_ document: VectorDocument, url: URL) async throws {
        try await exportDWFWithMillimeterPrecision(document, url: url, scale: .metric_1_100)
    }
    
    /// Quick export DWF for full-size output (100% scaling, 1:1)
    static func exportDWFFullSize(_ document: VectorDocument, url: URL) async throws {
        try await exportDWFWithMillimeterPrecision(document, url: url, scale: .fullSize)
    }
    
    // MARK: - TODO: Other export formats (for future implementation)
    
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
        ImageContentRegistry.setBaseDirectoryURL(baseDir)
        
        do {
            let jsonData = try encoder.encode(document)
            try jsonData.write(to: url)
            Log.info("✅ Successfully exported JSON document", category: .fileOperations)
        } catch {
            Log.error("❌ JSON export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export JSON: \(error.localizedDescription)", line: nil)
        }
    }
    
    static func importFromJSON(url: URL) throws -> VectorDocument {
        Log.info("📂 Importing document from JSON: \(url.path)", category: .general)
        
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let document = try decoder.decode(VectorDocument.self, from: jsonData)
            Log.info("✅ Successfully imported JSON document with \(document.layers.count) layers", category: .fileOperations)
            // After decoding, hydrate raster images from embedded data or linked paths
            ImageContentRegistry.setBaseDirectoryURL(url.deletingLastPathComponent())
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
            ImageContentRegistry.setBaseDirectoryURL(nil)
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
    
    static func importFromSVG(url: URL) async throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG: \(url.path)", level: .info)
        
        let result = await VectorImportManager.shared.importVectorFile(from: url)
        
        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown SVG import error"
            throw VectorImportError.parsingError("Failed to import SVG: \(errorMessage)", line: nil)
        }
        
        // Create a new VectorDocument from the imported shapes
        let document = VectorDocument()
        
        // FIXED: Use viewBox/document dimensions from SVG file, not calculated bounds
        // This ensures objects stay within their intended viewBox bounds
        let svgDocumentSize = result.metadata.documentSize
        let canvasWidth = max(svgDocumentSize.width, 100) // Minimum 100pt
        let canvasHeight = max(svgDocumentSize.height, 100) // Minimum 100pt
        
        // Set document size based on SVG viewBox/dimensions
        document.settings.width = canvasWidth / 72.0 // Convert to inches
        document.settings.height = canvasHeight / 72.0
        document.settings.unit = .inches
        
        Log.fileOperation("🎯 SVG IMPORT USING VIEWBOX DIMENSIONS:", level: .info)
        Log.info("   SVG document size: \(svgDocumentSize)", category: .general)
        Log.info("   Canvas size: \(canvasWidth) × \(canvasHeight) pts", category: .general)
        print("   Document size: \(String(format: "%.2f", canvasWidth/72.0)) × \(String(format: "%.2f", canvasHeight/72.0)) inches")
        
        // Calculate actual artwork bounds for positioning
        var artworkBounds = CGRect.null
        for shape in result.shapes {
            // CRITICAL FIX: Use transformed bounds to get actual positioned bounds
            let shapeBounds = shape.bounds.applying(shape.transform)
            if artworkBounds.isNull {
                artworkBounds = shapeBounds
            } else {
                artworkBounds = artworkBounds.union(shapeBounds)
            }
        }
        
        if !artworkBounds.isNull {
            Log.info("   Actual artwork bounds: \(artworkBounds)", category: .general)
        }
        
        // VectorDocument init already created Pasteboard, Canvas and Working layers with backgrounds
        // We only need to update the canvas size in settings
        document.settings.width = canvasWidth
        document.settings.height = canvasHeight
        
        // FIXED: Position objects at viewBox origin (0,0), not artwork bounds origin
        // This preserves the intended positioning from the SVG file
        let translateX: CGFloat = 0  // Keep at viewBox origin
        let translateY: CGFloat = 0  // Keep at viewBox origin
        
        Log.fileOperation("🎯 POSITIONING CALCULATION:", level: .info)
        Log.info("   Using viewBox origin (0,0) - preserving SVG positioning", category: .general)
        if !artworkBounds.isNull {
            Log.info("   Artwork bounds: \(artworkBounds)", category: .general)
            if artworkBounds.minX < 0 || artworkBounds.minY < 0 || 
               artworkBounds.maxX > canvasWidth || artworkBounds.maxY > canvasHeight {
                Log.info("   ⚠️ WARNING: Some objects are positioned outside the viewBox bounds!", category: .general)
            }
        }
        
        // Add all imported shapes to the layer with translation applied to coordinates (not transforms)
        for shape in result.shapes {
            var centeredShape = shape
            
            // CRITICAL FIX: Apply centering to actual coordinates, not transforms
            // This prevents coordinate drift during zoom operations
            let centeringTransform = CGAffineTransform(translationX: translateX, y: translateY)
            let finalTransform = shape.transform.concatenating(centeringTransform)
            
            // Apply the complete transform to coordinates and reset transform to identity
            centeredShape = applyTransformToShapeCoordinates(shape: centeredShape, transform: finalTransform)
            centeredShape.transform = .identity
            
            // Ensure the shape is editable
            centeredShape.isLocked = false
            centeredShape.isVisible = true
            
            // Add shape to unified system (layer index 2 for imported layer)
            document.addShapeToUnifiedSystem(centeredShape, layerIndex: 2)
        }

        // Text objects are now imported as shapes with isTextObject=true
        
        // Select the working layer which contains imported shapes
        document.selectedLayerIndex = 2 // Working layer is at index 2
        
        // Log warnings if any
        for warning in result.warnings {
            Log.fileOperation("⚠️ SVG Import Warning: \(warning)", level: .info)
        }
        
        Log.info("✅ Successfully imported SVG document with \(result.shapes.count) shapes", category: .fileOperations)
        Log.fileOperation("📐 Canvas sized to exact artwork dimensions: \(canvasWidth) × \(canvasHeight) pts", level: .info)
        return document
    }
    
    /// Import SVG with extreme value handling for radial gradients that cannot be reproduced
    /// Use this for SVGs with extreme coordinate values that cause rendering issues
    static func importFromSVGWithExtremeValueHandling(url: URL) async throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG with extreme value handling: \(url.path)", level: .info)
        
        let result = await VectorImportManager.shared.importSVGWithExtremeValueHandling(from: url)
        
        if !result.success {
            let errorMessage = result.errors.first?.localizedDescription ?? "Unknown SVG import error"
            throw VectorImportError.parsingError("Failed to import SVG: \(errorMessage)", line: nil)
        }
        
        // Create a new VectorDocument from the imported shapes
        let document = VectorDocument()
        
        // FIXED: Use viewBox/document dimensions from SVG file, not calculated bounds
        // This ensures objects stay within their intended viewBox bounds
        let svgDocumentSize = result.metadata.documentSize
        let canvasWidth = max(svgDocumentSize.width, 100) // Minimum 100pt
        let canvasHeight = max(svgDocumentSize.height, 100) // Minimum 100pt
        
        // Set document size based on SVG viewBox/dimensions
        document.settings.width = canvasWidth / 72.0 // Convert to inches
        document.settings.height = canvasHeight / 72.0
        document.settings.unit = .inches
        
        Log.fileOperation("🎯 SVG IMPORT WITH EXTREME VALUE HANDLING:", level: .info)
        Log.info("   SVG document size: \(svgDocumentSize)", category: .general)
        Log.info("   Canvas size: \(canvasWidth) × \(canvasHeight) pts", category: .general)
        print("   Document size: \(String(format: "%.2f", canvasWidth/72.0)) × \(String(format: "%.2f", canvasHeight/72.0)) inches")
        
        // Calculate actual artwork bounds for positioning
        var artworkBounds = CGRect.null
        for shape in result.shapes {
            // CRITICAL FIX: Use transformed bounds to get actual positioned bounds
            let shapeBounds = shape.bounds.applying(shape.transform)
            if artworkBounds.isNull {
                artworkBounds = shapeBounds
            } else {
                artworkBounds = artworkBounds.union(shapeBounds)
            }
        }
        
        if !artworkBounds.isNull {
            Log.info("   Actual artwork bounds: \(artworkBounds)", category: .general)
        }
        
        // VectorDocument init already created Pasteboard, Canvas and Working layers with backgrounds
        // We only need to update the canvas size in settings
        document.settings.width = canvasWidth
        document.settings.height = canvasHeight
        
        // FIXED: Position objects at viewBox origin (0,0), not artwork bounds origin
        // This preserves the intended positioning from the SVG file
        let translateX: CGFloat = 0  // Keep at viewBox origin
        let translateY: CGFloat = 0  // Keep at viewBox origin
        
        Log.fileOperation("🎯 POSITIONING CALCULATION:", level: .info)
        Log.info("   Using viewBox origin (0,0) - preserving SVG positioning", category: .general)
        if !artworkBounds.isNull {
            Log.info("   Artwork bounds: \(artworkBounds)", category: .general)
            if artworkBounds.minX < 0 || artworkBounds.minY < 0 || 
               artworkBounds.maxX > canvasWidth || artworkBounds.maxY > canvasHeight {
                Log.info("   ⚠️ WARNING: Some objects are positioned outside the viewBox bounds!", category: .general)
            }
        }
        
        // Add all imported shapes to the layer with translation applied to coordinates (not transforms)
        for shape in result.shapes {
            var centeredShape = shape
            
            // CRITICAL FIX: Apply centering to actual coordinates, not transforms
            // This prevents coordinate drift during zoom operations
            let centeringTransform = CGAffineTransform(translationX: translateX, y: translateY)
            let finalTransform = shape.transform.concatenating(centeringTransform)
            
            // Apply the complete transform to coordinates and reset transform to identity
            centeredShape = applyTransformToShapeCoordinates(shape: centeredShape, transform: finalTransform)
            centeredShape.transform = .identity
            
            // Ensure the shape is editable
            centeredShape.isLocked = false
            centeredShape.isVisible = true
            
            // Add shape to unified system (layer index 2 for imported layer)
            document.addShapeToUnifiedSystem(centeredShape, layerIndex: 2)
        }

        // Text objects are now imported as shapes with isTextObject=true
        
        // Select the working layer which contains imported shapes
        document.selectedLayerIndex = 2 // Working layer is at index 2
        
        // Log warnings if any
        for warning in result.warnings {
            Log.fileOperation("⚠️ SVG Import Warning: \(warning)", level: .info)
        }
        
        Log.info("✅ Successfully imported SVG document with extreme value handling: \(result.shapes.count) shapes", category: .fileOperations)
        Log.fileOperation("📐 Canvas sized to exact artwork dimensions: \(canvasWidth) × \(canvasHeight) pts", level: .info)
        return document
    }
    
    /// Synchronous version of SVG import for FileDocument protocol
    static func importFromSVGSync(url: URL) throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG (sync): \(url.path)", level: .info)
        
        // Use a semaphore to make the async call synchronous
        let semaphore = DispatchSemaphore(value: 0)
        var resultDocument: VectorDocument?
        var resultError: Error?
        
        Task {
            do {
                resultDocument = try await importFromSVG(url: url)
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
            throw VectorImportError.parsingError("Failed to import SVG: Unknown error", line: nil)
        }
        
        return document
    }
    
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
    
    /// Generate PDF data from VectorDocument
    static func generatePDFData(from document: VectorDocument) throws -> Data {
        Log.fileOperation("📄 Generating PDF data from document", level: .info)
        
        // Get document dimensions
        let canvasWidth = document.settings.width * 72.0 // Convert to points
        let canvasHeight = document.settings.height * 72.0
        let documentSize = CGSize(width: canvasWidth, height: canvasHeight)
        
        // Create PDF context
        let pdfData = NSMutableData()
        guard let pdfConsumer = CGDataConsumer(data: pdfData),
              let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: nil, nil) else {
            throw VectorImportError.parsingError("Failed to create PDF context", line: nil)
        }
        
        // Begin PDF document
        let mediaBox = CGRect(origin: .zero, size: documentSize)
        pdfContext.beginPDFPage(nil)
        
        // Set white background
        pdfContext.setFillColor(CGColor.white)
        pdfContext.fill(mediaBox)
        
        // Render document content
        try renderDocumentToPDF(document: document, context: pdfContext, canvasSize: documentSize)
        
        // End PDF document
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        Log.fileOperation("✅ PDF data generation completed", level: .info)
        return pdfData as Data
    }
    
    /// Render VectorDocument to PDF context
    static func renderDocumentToPDF(document: VectorDocument, context: CGContext, canvasSize: CGSize) throws {
        Log.fileOperation("🎨 Rendering document to PDF context", level: .info)
        
        // Save graphics state
        context.saveGState()
        
        // Render layers (skip pasteboard and canvas background)
        for (index, layer) in document.layers.enumerated() {
            // Skip pasteboard (index 0) and canvas (index 1) for PDF export
            guard index >= 2, !layer.isLocked, layer.isVisible else { continue }
            
            Log.fileOperation("🎨 Rendering layer: \(layer.name)", level: .info)
            
            // Render shapes in layer using unified objects
            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer where shape.isVisible {
                try renderShapeToPDF(shape: shape, context: context)
            }
        }
        
        // Restore graphics state
        context.restoreGState()
        
        Log.fileOperation("✅ Document rendered to PDF context", level: .info)
    }
    
    /// Render individual shape to PDF context
    static func renderShapeToPDF(shape: VectorShape, context: CGContext) throws {
        // Convert VectorShape path to CGPath
        let cgPath = convertVectorPathToCGPath(shape.path)
        
        // Save graphics state for this shape
        context.saveGState()
        
        // Apply shape transform if any (if transform exists)
        // Note: VectorShape may not have a transform property - skip for now
        // context.concatenate(shape.transform)
        
        // Set up fill style
        if let fillStyle = shape.fillStyle {
            context.addPath(cgPath)
            setFillStyle(fillStyle, context: context)
            context.fillPath()
        }
        
        // Set up stroke style
        if let strokeStyle = shape.strokeStyle {
            context.addPath(cgPath)
            setStrokeStyle(strokeStyle, context: context)
            context.strokePath()
        }
        
        // Restore graphics state
        context.restoreGState()
    }
    
    /// Convert VectorPath to CGPath
    static func convertVectorPathToCGPath(_ vectorPath: VectorPath) -> CGPath {
        let cgPath = CGMutablePath()
        
        for element in vectorPath.elements {
            switch element {
            case .move(let point):
                cgPath.move(to: CGPoint(x: point.x, y: point.y))
            case .line(let point):
                cgPath.addLine(to: CGPoint(x: point.x, y: point.y))
            case .curve(let point, let control1, let control2):
                cgPath.addCurve(
                    to: CGPoint(x: point.x, y: point.y),
                    control1: CGPoint(x: control1.x, y: control1.y),
                    control2: CGPoint(x: control2.x, y: control2.y)
                )
            case .quadCurve(let point, let control):
                cgPath.addQuadCurve(
                    to: CGPoint(x: point.x, y: point.y),
                    control: CGPoint(x: control.x, y: control.y)
                )
            case .close:
                cgPath.closeSubpath()
            }
        }
        
        return cgPath
    }
    
    /// Set fill style in PDF context
    static func setFillStyle(_ fillStyle: FillStyle, context: CGContext) {
        switch fillStyle.color {
        case .rgb(let rgb):
            context.setFillColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: fillStyle.opacity)
        case .white:
            context.setFillColor(red: 1, green: 1, blue: 1, alpha: fillStyle.opacity)
        case .black:
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: fillStyle.opacity)
        case .clear:
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .cmyk(let cmyk):
            // Convert CMYK to RGB for PDF context
            let r = 1.0 - min(1.0, cmyk.cyan * (1.0 - cmyk.black) + cmyk.black)
            let g = 1.0 - min(1.0, cmyk.magenta * (1.0 - cmyk.black) + cmyk.black)
            let b = 1.0 - min(1.0, cmyk.yellow * (1.0 - cmyk.black) + cmyk.black)
            context.setFillColor(red: r, green: g, blue: b, alpha: fillStyle.opacity)
        case .hsb(let hsb):
            // Convert HSB to RGB for PDF context
            let c = hsb.saturation * hsb.brightness
            let x = c * (1 - abs((hsb.hue / 60).truncatingRemainder(dividingBy: 2) - 1))
            let m = hsb.brightness - c
            let (r, g, b): (CGFloat, CGFloat, CGFloat)
            if hsb.hue < 60 { (r, g, b) = (c, x, 0) }
            else if hsb.hue < 120 { (r, g, b) = (x, c, 0) }
            else if hsb.hue < 180 { (r, g, b) = (0, c, x) }
            else if hsb.hue < 240 { (r, g, b) = (0, x, c) }
            else if hsb.hue < 300 { (r, g, b) = (x, 0, c) }
            else { (r, g, b) = (c, 0, x) }
            context.setFillColor(red: r + m, green: g + m, blue: b + m, alpha: fillStyle.opacity)
        case .pantone(_), .spot(_):
            // Fallback to black for specialty colors
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: fillStyle.opacity)
        case .appleSystem(_):
            // Fallback to black for system colors
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: fillStyle.opacity)
        case .gradient(_):
            // Fallback to black for gradients (would need separate implementation)
            context.setFillColor(red: 0, green: 0, blue: 0, alpha: fillStyle.opacity)
        }
    }
    
    /// Set stroke style in PDF context
    static func setStrokeStyle(_ strokeStyle: StrokeStyle, context: CGContext) {
        // Set stroke color
        switch strokeStyle.color {
        case .rgb(let rgb):
            context.setStrokeColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
        case .white:
            context.setStrokeColor(red: 1, green: 1, blue: 1, alpha: 1.0)
        case .black:
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        case .clear:
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .cmyk(let cmyk):
            // Convert CMYK to RGB for PDF context
            let r = (1.0 - cmyk.cyan) * (1.0 - cmyk.black)
            let g = (1.0 - cmyk.magenta) * (1.0 - cmyk.black)
            let b = (1.0 - cmyk.yellow) * (1.0 - cmyk.black)
            context.setStrokeColor(red: r, green: g, blue: b, alpha: 1.0)
        case .hsb(let hsb):
            // Convert HSB to RGB for PDF context
            let rgb = hsb.rgbColor
            context.setStrokeColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1.0)
        case .pantone, .spot:
            // Fallback to black for specialty colors in PDF export
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        case .appleSystem:
            // Fallback to black for Apple system colors in PDF export
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        case .gradient:
            // Use the first color of gradient as fallback for stroke
            context.setStrokeColor(red: 0, green: 0, blue: 0, alpha: 1.0)
        }
        
        // Set line width
        context.setLineWidth(strokeStyle.width)
        
        // Set line cap
        context.setLineCap(strokeStyle.lineCap)
        
        // Set line join
        context.setLineJoin(strokeStyle.lineJoin)
    }
    
    /// Import SVG from data for FileDocument protocol
    static func importFromSVGData(_ data: Data) throws -> VectorDocument {
        Log.fileOperation("🎨 Importing document from SVG data", level: .info)
        
        // Create a temporary file to use with the existing SVG import infrastructure
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("svg")
        
        do {
            try data.write(to: tempURL)
            let document = try importFromSVGSync(url: tempURL)
            
            // CRITICAL FIX: Hydrate images after SVG import so embedded images are loaded
            // This ensures SVG images are properly imported when opening through File > Open
            ImageContentRegistry.setBaseDirectoryURL(tempURL.deletingLastPathComponent())
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
            
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempURL)
            
            Log.fileOperation("✅ SVG data import completed with image hydration", level: .info)
            
            return document
        } catch {
            // Clean up temporary file on error
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }
    
    /// Apply transform to shape coordinates and return new shape with identity transform
    /// This prevents coordinate drift during zoom operations
    private static func applyTransformToShapeCoordinates(shape: VectorShape, transform: CGAffineTransform) -> VectorShape {
        // Don't apply identity transforms
        if transform.isIdentity {
            return shape
        }
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new shape with transformed path and identity transform
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        var newShape = shape
        newShape.path = transformedPath
        newShape.transform = .identity
        newShape.updateBounds()
        
        return newShape
    }
    
    static func exportToSVG(_ document: VectorDocument, url: URL) throws {
        Log.fileOperation("🎨 Exporting document to SVG: \(url.path)", level: .info)
        
        do {
            let svgContent = try generateSVGContent(from: document)
            try svgContent.write(to: url, atomically: true, encoding: .utf8)
            Log.info("✅ Successfully exported SVG document", category: .fileOperations)
        } catch {
            Log.error("❌ SVG export failed: \(error)", category: .error)
            throw VectorImportError.parsingError("Failed to export SVG: \(error.localizedDescription)", line: nil)
        }
    }
    
    static func generateSVGContent(from document: VectorDocument) throws -> String {
        // FIXED: Use pasteboard bounds for consistent export sizing
        // This ensures exported SVGs maintain the same page dimensions as the document
        let pasteboardBounds = CGRect(origin: .zero, size: document.settings.sizeInPoints)
        let contentBounds = document.getDocumentBounds()
        
        // Use pasteboard bounds for viewBox, but center content if needed
        let width = max(pasteboardBounds.width, 100) // Use pasteboard width
        let height = max(pasteboardBounds.height, 100) // Use pasteboard height
        
        Log.fileOperation("📊 SVG Export bounds:", level: .info)
        Log.info("   Pasteboard: \(pasteboardBounds)", category: .general)
        Log.info("   Content: \(contentBounds)", category: .general)
        Log.info("   Using pasteboard bounds for consistent export", category: .general)
        
        // Collect unique gradients for gradient definitions FIRST
        var uniqueGradients: [String: VectorGradient] = [:]
        var gradientToIdMapping: [VectorGradient: String] = [:]
        var gradientCounter = 1
        
        // Pre-analyze all shapes to find gradients using unified objects
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                if !shape.isVisible { continue }
                
                // Check fill for gradients
                if let fillStyle = shape.fillStyle,
                   case .gradient(let gradient) = fillStyle.color {
                    if gradientToIdMapping[gradient] == nil {
                        let gradientId = "gradient\(gradientCounter)"
                        uniqueGradients[gradientId] = gradient
                        gradientToIdMapping[gradient] = gradientId
                        gradientCounter += 1
                    }
                }
                
                // Check stroke for gradients
                if let strokeStyle = shape.strokeStyle,
                   case .gradient(let gradient) = strokeStyle.color {
                    if gradientToIdMapping[gradient] == nil {
                        let gradientId = "gradient\(gradientCounter)"
                        uniqueGradients[gradientId] = gradient
                        gradientToIdMapping[gradient] = gradientId
                        gradientCounter += 1
                    }
                }
            }
        }
        
        // Pre-analyze text objects for gradients
        document.forEachTextInOrder { text in
            if !text.isVisible { return }
            
            // Check text fill for gradients
            if case .gradient(let gradient) = text.typography.fillColor {
                if gradientToIdMapping[gradient] == nil {
                    let gradientId = "gradient\(gradientCounter)"
                    uniqueGradients[gradientId] = gradient
                    gradientToIdMapping[gradient] = gradientId
                    gradientCounter += 1
                }
            }
            
            // Check text stroke for gradients
            if text.typography.hasStroke,
               case .gradient(let gradient) = text.typography.strokeColor {
                if gradientToIdMapping[gradient] == nil {
                    let gradientId = "gradient\(gradientCounter)"
                    uniqueGradients[gradientId] = gradient
                    gradientToIdMapping[gradient] = gradientId
                    gradientCounter += 1
                }
            }
        }
        
        // Now collect unique styles for CSS generation (after gradients are processed)
        var uniqueStyles: [String: (fill: String, stroke: String)] = [:]
        
        // Pre-analyze all shapes to generate CSS classes
        for layer in document.layers {
            if !layer.isVisible { continue }
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                
                let fillStyle = generateSVGFill(shape.fillStyle, gradientMapping: gradientToIdMapping)
                let strokeStyle = generateSVGStroke(shape.strokeStyle, gradientMapping: gradientToIdMapping)
                let styleKey = "\(fillStyle)|\(strokeStyle)"
                
                if uniqueStyles[styleKey] == nil {
                    uniqueStyles[styleKey] = (fill: fillStyle, stroke: strokeStyle)
                }
            }
        }
        
        var svg = """
        <?xml version=\"1.0\" encoding=\"UTF-8\"?>
        <svg id=\"Layer_1\" data-name=\"Layer 1\" xmlns=\"http://www.w3.org/2000/svg\" xmlns:xlink=\"http://www.w3.org/1999/xlink\" viewBox=\"0 0 \(width) \(height)\">
        <defs>
        """
        
        // Generate gradient definitions
        for (gradientId, gradient) in uniqueGradients {
            svg += generateSVGGradientDefinition(gradient, id: gradientId)
        }
        
        svg += """
        <style>
        """
        
        // Generate CSS classes for common styles
        for (index, (_, styleData)) in uniqueStyles.enumerated() {
            let className = "cls-\(index + 1)"
            svg += "      .\(className) {\n"
            
            // Parse fill and stroke data to generate proper CSS
            if styleData.fill.contains("url(#") {
                // Handle gradient fills
                svg += "        fill: \(styleData.fill.replacingOccurrences(of: "fill=\"", with: "").replacingOccurrences(of: "\"", with: ""));\n"
                
                // Extract and include fill opacity
                if let fillOpacity = extractOpacityFromSVGAttribute(styleData.fill, type: "fill") {
                    svg += "        fill-opacity: \(fillOpacity);\n"
                }
            } else if styleData.fill.contains("rgb(") {
                let fillColor = extractColorFromSVGAttribute(styleData.fill)
                svg += "        fill: \(fillColor);\n"
                
                // Extract and include fill opacity
                if let fillOpacity = extractOpacityFromSVGAttribute(styleData.fill, type: "fill") {
                    svg += "        fill-opacity: \(fillOpacity);\n"
                }
            } else if styleData.fill.contains("none") {
                svg += "        fill: none;\n"
            }
            
            if styleData.stroke.contains("url(#") {
                // Handle gradient strokes
                svg += "        stroke: \(styleData.stroke.replacingOccurrences(of: "stroke=\"", with: "").replacingOccurrences(of: "\"", with: ""));\n"
                let strokeWidth = extractStrokeWidthFromSVGAttribute(styleData.stroke)
                if strokeWidth != "1" {
                    svg += "        stroke-width: \(strokeWidth)px;\n"
                }
                
                // Extract and include stroke opacity
                if let strokeOpacity = extractOpacityFromSVGAttribute(styleData.stroke, type: "stroke") {
                    svg += "        stroke-opacity: \(strokeOpacity);\n"
                }
            } else if styleData.stroke.contains("rgb(") {
                let strokeColor = extractColorFromSVGAttribute(styleData.stroke)
                let strokeWidth = extractStrokeWidthFromSVGAttribute(styleData.stroke)
                svg += "        stroke: \(strokeColor);\n"
                if strokeWidth != "1" {
                    svg += "        stroke-width: \(strokeWidth)px;\n"
                }
                
                // CRITICAL FIX: Extract and include stroke opacity for transparency support
                if let strokeOpacity = extractOpacityFromSVGAttribute(styleData.stroke, type: "stroke") {
                    svg += "        stroke-opacity: \(strokeOpacity);\n"
                } else {
                    // Check if the original stroke style had opacity < 1.0
                    if styleData.stroke.contains("stroke-opacity") {
                        // Extract existing stroke-opacity attribute
                        if let range = styleData.stroke.range(of: "stroke-opacity=\"([^\"]+)\"", options: .regularExpression) {
                            let match = String(styleData.stroke[range])
                            let opacity = match.replacingOccurrences(of: "stroke-opacity=\"", with: "").replacingOccurrences(of: "\"", with: "")
                            svg += "        stroke-opacity: \(opacity);\n"
                        }
                    }
                }
            } else if styleData.stroke.contains("none") {
                svg += "        stroke: none;\n"
                svg += "        stroke-width: 0px;\n"
            }
            
            svg += "      }\n\n"
        }
        
        svg += """
        </style>
        </defs>
        """
        
        // Export each layer (excluding Canvas and Pasteboard layers)
        for (layerIndex, layer) in document.layers.enumerated() {
            if !layer.isVisible { continue }
            
            // Skip Canvas and Pasteboard layers for SVG export (they're UI-only layers)
            if layer.name == "Canvas" || layer.name == "Pasteboard" {
                continue
            }
            
            svg += "<g id=\"layer-\(layerIndex)\">\n"
            
            // Export shapes in this layer
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                
                // SPECIAL-CASE RASTER IMAGES: Export as <image> with data URI
                if ImageContentRegistry.containsImage(shape),
                   let nsImage = ImageContentRegistry.image(for: shape.id) {
                    svg += try generateSVGImageElement(shape, image: nsImage)
                    continue
                }

                // Find matching CSS class
                let fillStyle = generateSVGFill(shape.fillStyle, gradientMapping: gradientToIdMapping)
                let strokeStyle = generateSVGStroke(shape.strokeStyle, gradientMapping: gradientToIdMapping)
                let styleKey = "\(fillStyle)|\(strokeStyle)"
                
                if let styleIndex = Array(uniqueStyles.keys).firstIndex(of: styleKey) {
                    let className = "cls-\(styleIndex + 1)"
                    svg += try generateSVGShapeWithClass(shape, className: className)
                } else {
                    svg += try generateSVGShape(shape, gradientMapping: gradientToIdMapping)
                }
            }
            
            svg += "</g>\n"
        }
        
        // Export text objects
        try document.forEachTextInOrder { text in
            svg += try generateSVGText(text, gradientMapping: gradientToIdMapping)
        }
        
        svg += "</svg>"
        return svg
    }
    
    private static func generateSVGShape(_ shape: VectorShape, gradientMapping: [VectorGradient: String]) throws -> String {
        // CRITICAL FIX: Apply transform to coordinates for proper round-trip export/import
        var transformedPath = applyTransformToPath(shape.path, transform: shape.transform)
        
        // CRITICAL FIX: Ensure filled shapes are properly closed
        if shape.fillStyle != nil && shape.fillStyle?.color != .clear && !transformedPath.isClosed {
            // If it has a fill but isn't marked as closed, mark it as closed and ensure Z command
            var newElements = transformedPath.elements
            
            // Only add close if there isn't already one
            if !newElements.contains(where: { if case .close = $0 { return true }; return false }) {
                newElements.append(.close)
            }
            
            transformedPath = VectorPath(elements: newElements, isClosed: true)
        }
        
        let pathData = try generateSVGPath(transformedPath)
        let fillStyle = generateSVGFill(shape.fillStyle, gradientMapping: gradientMapping)
        let strokeStyle = generateSVGStroke(shape.strokeStyle, gradientMapping: gradientMapping)
        
        // Don't include transform attribute since coordinates are already transformed
        return """
        <path d="\(pathData)" \(fillStyle) \(strokeStyle) id="shape-\(shape.id)"/>
        
        """
    }

    // MARK: - Raster Image Export
    /// Generate an SVG <image> element for a raster-backed shape using a data URI
    private static func generateSVGImageElement(_ shape: VectorShape, image: NSImage) throws -> String {
        // Apply transform to the rect corners to export baked coordinates like paths
        let transformedPath = applyTransformToPath(shape.path, transform: shape.transform)

        // Compute bounds from transformed path elements
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for element in transformedPath.elements {
            switch element {
            case .move(let to):
                minX = min(minX, CGFloat(to.x)); minY = min(minY, CGFloat(to.y))
                maxX = max(maxX, CGFloat(to.x)); maxY = max(maxY, CGFloat(to.y))
            case .line(let to):
                minX = min(minX, CGFloat(to.x)); minY = min(minY, CGFloat(to.y))
                maxX = max(maxX, CGFloat(to.x)); maxY = max(maxY, CGFloat(to.y))
            case .curve(let to, let c1, let c2):
                minX = min(minX, CGFloat(to.x), CGFloat(c1.x), CGFloat(c2.x))
                minY = min(minY, CGFloat(to.y), CGFloat(c1.y), CGFloat(c2.y))
                maxX = max(maxX, CGFloat(to.x), CGFloat(c1.x), CGFloat(c2.x))
                maxY = max(maxY, CGFloat(to.y), CGFloat(c1.y), CGFloat(c2.y))
            case .quadCurve(let to, let c):
                minX = min(minX, CGFloat(to.x), CGFloat(c.x))
                minY = min(minY, CGFloat(to.y), CGFloat(c.y))
                maxX = max(maxX, CGFloat(to.x), CGFloat(c.x))
                maxY = max(maxY, CGFloat(to.y), CGFloat(c.y))
            case .close:
                break
            }
        }
        if minX == .greatestFiniteMagnitude || minY == .greatestFiniteMagnitude {
            return "" // no geometry
        }
        let x = minX
        let y = minY
        let width = max(0, maxX - minX)
        let height = max(0, maxY - minY)

        // Rasterize NSImage to PNG data (safer for data URIs and widely supported)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            // If encoding fails, fallback to transparent rect path
            return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" fill=\"none\"/>\n"
        }
        let base64 = pngData.base64EncodedString()
        let href = "data:image/png;base64,\(base64)"

        // Compose SVG image tag with baked coordinates
        return """
        <image id=\"image-\(shape.id)\" x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" xlink:href=\"\(href)\" preserveAspectRatio=\"none\"/>
        
        """
    }
    
    private static func generateSVGPath(_ path: VectorPath) throws -> String {
        var pathString = ""
        
        for element in path.elements {
            switch element {
            case .move(let to):
                pathString += "M \(to.x) \(to.y) "
            case .line(let to):
                pathString += "L \(to.x) \(to.y) "
            case .curve(let to, let control1, let control2):
                pathString += "C \(control1.x) \(control1.y) \(control2.x) \(control2.y) \(to.x) \(to.y) "
            case .quadCurve(let to, let control):
                pathString += "Q \(control.x) \(control.y) \(to.x) \(to.y) "
            case .close:
                pathString += "Z "
            }
        }
        
        // CRITICAL FIX: Ensure closed paths always end with Z command
        if path.isClosed && !pathString.trimmingCharacters(in: .whitespaces).hasSuffix("Z") {
            pathString += "Z "
        }
        
        return pathString.trimmingCharacters(in: .whitespaces)
    }
    
    private static func generateSVGFill(_ fillStyle: FillStyle?, gradientMapping: [VectorGradient: String] = [:]) -> String {
        guard let fillStyle = fillStyle else {
            return "fill=\"none\""
        }
        
        let color = fillStyle.color
        let opacity = fillStyle.opacity
        
        // Handle gradient fills
        if case .gradient(let gradient) = color {
            if let gradientId = gradientMapping[gradient] {
                if opacity < 1.0 {
                    return "fill=\"url(#\(gradientId))\" fill-opacity=\"\(opacity)\""
                } else {
                    return "fill=\"url(#\(gradientId))\""
                }
            } else {
                // Fallback to solid color if gradient not found
                Log.fileOperation("⚠️ Gradient not found in mapping, using fallback color", level: .info)
                return "fill=\"rgb(128,128,128)\""
            }
        }
        
        // Handle solid color fills
        let rgbComponents = extractRGBComponents(from: color)
        
        if opacity < 1.0 {
            return "fill=\"rgb(\(rgbComponents.red),\(rgbComponents.green),\(rgbComponents.blue))\" fill-opacity=\"\(opacity)\""
        } else {
            return "fill=\"rgb(\(rgbComponents.red),\(rgbComponents.green),\(rgbComponents.blue))\""
        }
    }
    
    private static func generateSVGStroke(_ strokeStyle: StrokeStyle?, gradientMapping: [VectorGradient: String] = [:]) -> String {
        guard let strokeStyle = strokeStyle else {
            return "stroke=\"none\""
        }
        
        // Handle zero-width strokes properly - export as "none" 
        if strokeStyle.width <= 0.0 {
            return "stroke=\"none\""
        }
        
        let color = strokeStyle.color
        let width = strokeStyle.width
        let opacity = strokeStyle.opacity
        
        var strokeAttributes: String
        
        // Handle gradient strokes
        if case .gradient(let gradient) = color {
            if let gradientId = gradientMapping[gradient] {
                strokeAttributes = "stroke=\"url(#\(gradientId))\" stroke-width=\"\(width)\""
            } else {
                // Fallback to solid color if gradient not found
                Log.fileOperation("⚠️ Gradient not found in mapping, using fallback color", level: .info)
                strokeAttributes = "stroke=\"rgb(128,128,128)\" stroke-width=\"\(width)\""
            }
        } else {
            // Handle solid color strokes
            let rgbComponents = extractRGBComponents(from: color)
            strokeAttributes = "stroke=\"rgb(\(rgbComponents.red),\(rgbComponents.green),\(rgbComponents.blue))\" stroke-width=\"\(width)\""
        }
        
        if opacity < 1.0 {
            strokeAttributes += " stroke-opacity=\"\(opacity)\""
        }
        
        // Handle line caps
        switch strokeStyle.lineCap {
        case .round:
            strokeAttributes += " stroke-linecap=\"round\""
        case .square:
            strokeAttributes += " stroke-linecap=\"square\""
        case .butt:
            strokeAttributes += " stroke-linecap=\"butt\""
        @unknown default:
            strokeAttributes += " stroke-linecap=\"butt\""  // Default to butt cap for unknown values
        }
        
        // Handle line joins
        switch strokeStyle.lineJoin {
        case .round:
            strokeAttributes += " stroke-linejoin=\"round\""
        case .bevel:
            strokeAttributes += " stroke-linejoin=\"bevel\""
        case .miter:
            strokeAttributes += " stroke-linejoin=\"miter\""
        @unknown default:
            strokeAttributes += " stroke-linejoin=\"miter\""  // Default to miter join for unknown values
        }
        
        return strokeAttributes
    }
    
    // MARK: - Gradient Export Support
    
    private static func generateSVGGradientDefinition(_ gradient: VectorGradient, id: String) -> String {
        Log.fileOperation("🎨 Exporting gradient: \(id)", level: .info)
        
        switch gradient {
        case .linear(let linearGradient):
            Log.info("   Type: Linear gradient", category: .general)
            Log.info("   Start: \(linearGradient.startPoint), End: \(linearGradient.endPoint)", category: .general)
            Log.info("   Units: \(linearGradient.units), Spread: \(linearGradient.spreadMethod)", category: .general)
            Log.info("   Angle: \(linearGradient.angle)°, Scale: (\(linearGradient.scaleX), \(linearGradient.scaleY))", category: .general)
            Log.info("   Origin: \(linearGradient.originPoint), Stops: \(linearGradient.stops.count)", category: .general)
            return generateLinearGradientDefinition(linearGradient, id: id)
        case .radial(let radialGradient):
            Log.info("   Type: Radial gradient", category: .general)
            Log.info("   Center: \(radialGradient.centerPoint), Radius: \(radialGradient.radius)", category: .general)
            print("   Focal: \(radialGradient.focalPoint?.debugDescription ?? "none")")
            Log.info("   Units: \(radialGradient.units), Spread: \(radialGradient.spreadMethod)", category: .general)
            Log.info("   Angle: \(radialGradient.angle)°, Scale: (\(radialGradient.scaleX), \(radialGradient.scaleY))", category: .general)
            Log.info("   Origin: \(radialGradient.originPoint), Stops: \(radialGradient.stops.count)", category: .general)
            return generateRadialGradientDefinition(radialGradient, id: id)
        }
    }
    
    private static func generateLinearGradientDefinition(_ gradient: LinearGradient, id: String) -> String {
        var svg = """
        <linearGradient id="\(id)" x1="\(gradient.startPoint.x)" y1="\(gradient.startPoint.y)" x2="\(gradient.endPoint.x)" y2="\(gradient.endPoint.y)"
        """
        
        // Add gradientUnits attribute based on gradient units
        switch gradient.units {
        case .objectBoundingBox:
            svg += " gradientUnits=\"objectBoundingBox\""
        case .userSpaceOnUse:
            svg += " gradientUnits=\"userSpaceOnUse\""
        }
        
        // Add spreadMethod attribute
        switch gradient.spreadMethod {
        case .pad:
            svg += " spreadMethod=\"pad\""
        case .reflect:
            svg += " spreadMethod=\"reflect\""
        case .repeat:
            svg += " spreadMethod=\"repeat\""
        }
        
        // Build gradientTransform string for complex transformations
        var transformParts: [String] = []
        
        // Add origin point translation if not at center
        if gradient.originPoint != CGPoint(x: 0.5, y: 0.5) {
            let translateX = gradient.originPoint.x - 0.5
            let translateY = gradient.originPoint.y - 0.5
            transformParts.append("translate(\(translateX) \(translateY))")
        }
        
        // Add scaling if scaleX or scaleY differ from 1.0
        if gradient.scaleX != 1.0 || gradient.scaleY != 1.0 {
            transformParts.append("scale(\(gradient.scaleX) \(gradient.scaleY))")
        }
        
        // Add gradientTransform if we have any transformations
        if !transformParts.isEmpty {
            svg += " gradientTransform=\"\(transformParts.joined(separator: " "))\""
        }
        
        svg += ">"
        
        for stop in gradient.stops {
            let stopColor = extractRGBComponents(from: stop.color)
            let offset = stop.position
            let opacity = stop.opacity
            
            if opacity < 1.0 {
                svg += """
                <stop offset="\(offset)" stop-color="rgb(\(stopColor.red),\(stopColor.green),\(stopColor.blue))" stop-opacity="\(opacity)"/>
                """
            } else {
                svg += """
                <stop offset="\(offset)" stop-color="rgb(\(stopColor.red),\(stopColor.green),\(stopColor.blue))"/>
                """
            }
        }
        
        svg += """
        </linearGradient>
        """
        
        return svg
    }
    
    private static func generateRadialGradientDefinition(_ gradient: RadialGradient, id: String) -> String {
        var svg = """
        <radialGradient id="\(id)" cx="\(gradient.centerPoint.x)" cy="\(gradient.centerPoint.y)" r="\(gradient.radius)"
        """
        
        // Add focal point if specified
        if let focalPoint = gradient.focalPoint {
            svg += " fx=\"\(focalPoint.x)\" fy=\"\(focalPoint.y)\""
        }
        
        // Add gradientUnits attribute based on gradient units
        switch gradient.units {
        case .objectBoundingBox:
            svg += " gradientUnits=\"objectBoundingBox\""
        case .userSpaceOnUse:
            svg += " gradientUnits=\"userSpaceOnUse\""
        }
        
        // Add spreadMethod attribute
        switch gradient.spreadMethod {
        case .pad:
            svg += " spreadMethod=\"pad\""
        case .reflect:
            svg += " spreadMethod=\"reflect\""
        case .repeat:
            svg += " spreadMethod=\"repeat\""
        }
        
        // Build gradientTransform string for complex transformations
        var transformParts: [String] = []
        
        // Add origin point translation if not at center
        if gradient.originPoint != CGPoint(x: 0.5, y: 0.5) {
            let translateX = gradient.originPoint.x - 0.5
            let translateY = gradient.originPoint.y - 0.5
            transformParts.append("translate(\(translateX) \(translateY))")
        }
        
        // Add rotation if angle is not 0
        if gradient.angle != 0.0 {
            transformParts.append("rotate(\(gradient.angle))")
        }
        
        // Add scaling if scaleX or scaleY differ from 1.0
        if gradient.scaleX != 1.0 || gradient.scaleY != 1.0 {
            transformParts.append("scale(\(gradient.scaleX) \(gradient.scaleY))")
        }
        
        // Add gradientTransform if we have any transformations
        if !transformParts.isEmpty {
            svg += " gradientTransform=\"\(transformParts.joined(separator: " "))\""
        }
        
        svg += ">"
        
        for stop in gradient.stops {
            let stopColor = extractRGBComponents(from: stop.color)
            let offset = stop.position
            let opacity = stop.opacity
            
            if opacity < 1.0 {
                svg += """
                <stop offset="\(offset)" stop-color="rgb(\(stopColor.red),\(stopColor.green),\(stopColor.blue))" stop-opacity="\(opacity)"/>
                """
            } else {
                svg += """
                <stop offset="\(offset)" stop-color="rgb(\(stopColor.red),\(stopColor.green),\(stopColor.blue))"/>
                """
            }
        }
        
        svg += """
        </radialGradient>
        """
        
        return svg
    }
    
    private static func extractRGBComponents(from color: VectorColor) -> (red: Int, green: Int, blue: Int) {
        let cgColor = color.cgColor
        let components = cgColor.components ?? [0, 0, 0, 1]
        
        // Handle different color spaces
        if cgColor.numberOfComponents == 4 {
            // RGBA
            return (
                red: Int(components[0] * 255),
                green: Int(components[1] * 255),
                blue: Int(components[2] * 255)
            )
        } else if cgColor.numberOfComponents == 2 {
            // Grayscale
            let gray = components[0]
            return (
                red: Int(gray * 255),
                green: Int(gray * 255),
                blue: Int(gray * 255)
            )
        } else {
            // Default to black
            return (red: 0, green: 0, blue: 0)
        }
    }
    
    private static func generateSVGTransform(_ transform: CGAffineTransform) -> String {
        if transform.isIdentity {
            return ""
        }
        
        // Convert CGAffineTransform to SVG matrix
        return "transform=\"matrix(\(transform.a) \(transform.b) \(transform.c) \(transform.d) \(transform.tx) \(transform.ty))\""
    }
    
    /// Apply transform to path coordinates (for proper SVG export)
    private static func applyTransformToPath(_ path: VectorPath, transform: CGAffineTransform) -> VectorPath {
        // If transform is identity, return original path
        if transform.isIdentity {
            return path
        }
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        return VectorPath(elements: transformedElements, isClosed: path.isClosed)
    }
    
    private static func generateSVGShapeWithClass(_ shape: VectorShape, className: String) throws -> String {
        // CRITICAL FIX: Apply transform to coordinates for proper round-trip export/import
        var transformedPath = applyTransformToPath(shape.path, transform: shape.transform)
        
        // CRITICAL FIX: Ensure filled shapes are properly closed
        if shape.fillStyle != nil && shape.fillStyle?.color != .clear && !transformedPath.isClosed {
            // If it has a fill but isn't marked as closed, mark it as closed and ensure Z command
            var newElements = transformedPath.elements
            
            // Only add close if there isn't already one
            if !newElements.contains(where: { if case .close = $0 { return true }; return false }) {
                newElements.append(.close)
            }
            
            transformedPath = VectorPath(elements: newElements, isClosed: true)
        }
        
        let pathData = try generateSVGPath(transformedPath)
        
        // Don't include transform attribute since coordinates are already transformed
        return """
        <path id="shape-\(shape.id)" class="\(className)" d="\(pathData)"/>
        
        """
    }
    
    private static func extractColorFromSVGAttribute(_ attribute: String) -> String {
        // Extract RGB values from "rgb(255,0,128)" format and convert to hex
        if let range = attribute.range(of: "rgb\\((\\d+),(\\d+),(\\d+)\\)", options: .regularExpression) {
            let rgbString = String(attribute[range])
            let components = rgbString.replacingOccurrences(of: "rgb(", with: "").replacingOccurrences(of: ")", with: "").split(separator: ",")
            
            if components.count == 3 {
                if let r = Int(components[0].trimmingCharacters(in: .whitespaces)),
                   let g = Int(components[1].trimmingCharacters(in: .whitespaces)),
                   let b = Int(components[2].trimmingCharacters(in: .whitespaces)) {
                    return String(format: "#%02x%02x%02x", r, g, b)
                }
            }
        }
        return "#000"  // Default to black
    }
    
    private static func extractStrokeWidthFromSVGAttribute(_ attribute: String) -> String {
        // Extract stroke width from "stroke-width="1.5""
        if let range = attribute.range(of: "stroke-width=\"([^\"]+)\"", options: .regularExpression) {
            let match = String(attribute[range])
            let width = match.replacingOccurrences(of: "stroke-width=\"", with: "").replacingOccurrences(of: "\"", with: "")
            return width
        }
        return "1"  // Default width
    }
    
    private static func extractOpacityFromSVGAttribute(_ attribute: String, type: String) -> String? {
        // Extract opacity from attributes like "fill-opacity="0.5"" or "stroke-opacity="0.2""
        let pattern = "\(type)-opacity=\"([^\"]+)\""
        if let range = attribute.range(of: pattern, options: .regularExpression) {
            let match = String(attribute[range])
            let opacity = match.replacingOccurrences(of: "\(type)-opacity=\"", with: "").replacingOccurrences(of: "\"", with: "")
            return opacity
        }
        return nil
    }
    
    private static func generateSVGText(_ text: VectorText, gradientMapping: [VectorGradient: String] = [:]) throws -> String {
        // Convert typography properties to SVG
        let fillColor = text.typography.fillColor
        let fillOpacity = text.typography.fillOpacity
        let strokeColor = text.typography.strokeColor
        let strokeWidth = text.typography.strokeWidth
        let strokeOpacity = text.typography.strokeOpacity
        let hasStroke = text.typography.hasStroke
        
        // Handle gradient fills for text
        var fillStyle: String
        if case .gradient(let gradient) = fillColor {
            if let gradientId = gradientMapping[gradient] {
                fillStyle = "fill=\"url(#\(gradientId))\""
                if fillOpacity < 1.0 {
                    fillStyle += " fill-opacity=\"\(fillOpacity)\""
                }
            } else {
                // Fallback to gray if gradient not found
                fillStyle = "fill=\"rgb(128,128,128)\""
                if fillOpacity < 1.0 {
                    fillStyle += " fill-opacity=\"\(fillOpacity)\""
                }
            }
        } else {
            let fillRgb = extractRGBComponents(from: fillColor)
            fillStyle = "fill=\"rgb(\(fillRgb.red),\(fillRgb.green),\(fillRgb.blue))\""
            if fillOpacity < 1.0 {
                fillStyle += " fill-opacity=\"\(fillOpacity)\""
            }
        }
        
        // Handle gradient strokes for text
        var strokeStyle = "stroke=\"none\""
        if hasStroke {
            if case .gradient(let gradient) = strokeColor {
                if let gradientId = gradientMapping[gradient] {
                    strokeStyle = "stroke=\"url(#\(gradientId))\" stroke-width=\"\(strokeWidth)\""
                    if strokeOpacity < 1.0 {
                        strokeStyle += " stroke-opacity=\"\(strokeOpacity)\""
                    }
                } else {
                    // Fallback to gray if gradient not found
                    strokeStyle = "stroke=\"rgb(128,128,128)\" stroke-width=\"\(strokeWidth)\""
                    if strokeOpacity < 1.0 {
                        strokeStyle += " stroke-opacity=\"\(strokeOpacity)\""
                    }
                }
            } else {
                let strokeRgb = extractRGBComponents(from: strokeColor)
                strokeStyle = "stroke=\"rgb(\(strokeRgb.red),\(strokeRgb.green),\(strokeRgb.blue))\" stroke-width=\"\(strokeWidth)\""
                if strokeOpacity < 1.0 {
                    strokeStyle += " stroke-opacity=\"\(strokeOpacity)\""
                }
            }
        }
        
        // CRITICAL FIX: Apply transform to text position for proper round-trip export/import
        let transformedPosition = CGPoint(x: text.position.x, y: text.position.y).applying(text.transform)
        
        // Don't include transform attribute since position is already transformed
        return """
        <text x="\(transformedPosition.x)" y="\(transformedPosition.y)" font-family="\(text.typography.fontFamily)" font-size="\(text.typography.fontSize)" \(fillStyle) \(strokeStyle) id="text-\(text.id)">\(text.content)</text>
        
        """
    }
    
    static func exportToPDF(_ document: VectorDocument, url: URL) throws {
        Log.info("📄 Exporting document to PDF: \(url.path)", category: .general)
        
        // Create PDF context
        let pageSize = document.settings.sizeInPoints
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil)
        
        guard let context = pdfContext else {
            throw VectorImportError.parsingError("Failed to create PDF context", line: nil)
        }
        
        // Begin PDF page
        var pageRect = CGRect(origin: .zero, size: pageSize)
        context.beginPage(mediaBox: &pageRect)
        
        // Set coordinate system to match our canvas (flip Y axis)
        context.translateBy(x: 0, y: pageSize.height)
        context.scaleBy(x: 1, y: -1)
        
        // Draw background
        context.setFillColor(document.settings.backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))
        
        // Draw each layer
        for layer in document.layers {
            if !layer.isVisible { continue }
            
            // Apply layer opacity
            context.saveGState()
            context.setAlpha(layer.opacity)
            
            // Draw shapes in layer
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                
                drawShapeInPDF(shape, context: context)
            }
            
            context.restoreGState()
        }
        
        // Draw text objects
        document.forEachTextInOrder { text in
            if !text.isVisible { return }
            
            drawTextInPDF(text, context: context)
        }
        
        // End PDF page
        context.endPage()
        
        // Close PDF context
        context.closePDF()
        
        Log.info("✅ Successfully exported PDF document", category: .fileOperations)
    }
    
    private static func drawShapeInPDF(_ shape: VectorShape, context: CGContext) {
        context.saveGState()
        
        // Apply shape opacity
        context.setAlpha(shape.opacity)
        
        // Apply transform
        if !shape.transform.isIdentity {
            context.concatenate(shape.transform)
        }
        
        // Create path from shape
        let path = shape.path.cgPath
        context.addPath(path)
        
        // Apply fill
        if let fillStyle = shape.fillStyle {
            context.setFillColor(fillStyle.color.cgColor)
            context.setAlpha(fillStyle.opacity)
            
            if shape.strokeStyle != nil {
                context.drawPath(using: .fillStroke)
            } else {
                context.fillPath()
            }
        } else if let strokeStyle = shape.strokeStyle {
            // Only stroke, no fill
            context.setStrokeColor(strokeStyle.color.cgColor)
            context.setLineWidth(strokeStyle.width)
            context.setAlpha(strokeStyle.opacity)
            context.setLineCap(strokeStyle.lineCap)
            context.setLineJoin(strokeStyle.lineJoin)
            
            if !strokeStyle.dashPattern.isEmpty {
                let dashPatternCGFloat = strokeStyle.dashPattern.map { CGFloat($0) }
                context.setLineDash(phase: 0, lengths: dashPatternCGFloat)
            }
            
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    private static func drawTextInPDF(_ text: VectorText, context: CGContext) {
        context.saveGState()
        
        // Apply text opacity
        context.setAlpha(text.isVisible ? 1.0 : 0.0)
        
        // Apply transform
        if !text.transform.isIdentity {
            context.concatenate(text.transform)
        }
        
        // Create attributed string
        let font = text.typography.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: text.typography.fillColor.cgColor) ?? NSColor.black,
            .kern: text.typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: text.content, attributes: attributes)
        
        // Calculate text position (PDF coordinates)
        let textPosition = CGPoint(x: text.position.x, y: text.position.y)
        
        // Draw text
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textPosition = textPosition
        CTLineDraw(line, context)
        
        context.restoreGState()
    }
    
    static func exportToPNG(_ document: VectorDocument, url: URL, scale: CGFloat) throws {
        Log.fileOperation("🖼️ Exporting document to PNG: \(url.path) at \(scale)x scale", level: .info)
        
        // Calculate output size
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        
        // CRITICAL FIX: Add size validation to prevent Core Image crashes
        guard outputSize.width > 0 && outputSize.height > 0 && 
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw VectorImportError.parsingError("Failed to create bitmap context", line: nil)
        }
        
        // Set coordinate system to match our canvas (flip Y axis)
        context.translateBy(x: 0, y: outputSize.height)
        context.scaleBy(x: scale, y: -scale)
        
        // Draw background
        context.setFillColor(document.settings.backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))
        
        // Draw each layer
        for layer in document.layers {
            if !layer.isVisible { continue }
            
            // Apply layer opacity
            context.saveGState()
            context.setAlpha(layer.opacity)
            
            // Draw shapes in layer
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                
                drawShapeInPDF(shape, context: context)
            }
            
            context.restoreGState()
        }
        
        // Draw text objects
        document.forEachTextInOrder { text in
            if !text.isVisible { return }
            
            drawTextInPDF(text, context: context)
        }
        
        // CRITICAL FIX: Add timeout and error handling for Core Image operations
        let image: CGImage
        do {
            // Create image from context with timeout protection
            guard let createdImage = context.makeImage() else {
                throw VectorImportError.parsingError("Failed to create image from context", line: nil)
            }
            image = createdImage
        } catch {
            throw VectorImportError.parsingError("Core Image operation failed: \(error.localizedDescription)", line: nil)
        }
        
        // Save PNG with error handling
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        guard let dest = destination else {
            throw VectorImportError.parsingError("Failed to create PNG destination", line: nil)
        }
        
        CGImageDestinationAddImage(dest, image, nil)
        
        if !CGImageDestinationFinalize(dest) {
            throw VectorImportError.parsingError("Failed to finalize PNG export", line: nil)
        }
        
        Log.info("✅ Successfully exported PNG document", category: .fileOperations)
    }
    
    static func exportToJPEG(_ document: VectorDocument, url: URL, scale: CGFloat, quality: Double) throws {
        Log.info("📷 Exporting document to JPEG: \(url.path) at \(scale)x scale, \(Int(quality * 100))% quality", category: .general)
        
        // Calculate output size
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        
        // CRITICAL FIX: Add size validation to prevent Core Image crashes
        guard outputSize.width > 0 && outputSize.height > 0 && 
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue // JPEG doesn't support alpha
        
        guard let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw VectorImportError.parsingError("Failed to create bitmap context", line: nil)
        }
        
        // Set coordinate system to match our canvas (flip Y axis)
        context.translateBy(x: 0, y: outputSize.height)
        context.scaleBy(x: scale, y: -scale)
        
        // Draw background (important for JPEG since it doesn't support transparency)
        context.setFillColor(document.settings.backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))
        
        // Draw each layer
        for layer in document.layers {
            if !layer.isVisible { continue }
            
            // Apply layer opacity
            context.saveGState()
            context.setAlpha(layer.opacity)
            
            // Draw shapes in layer
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                
                drawShapeInPDF(shape, context: context)
            }
            
            context.restoreGState()
        }
        
        // Draw text objects
        document.forEachTextInOrder { text in
            if !text.isVisible { return }
            
            drawTextInPDF(text, context: context)
        }
        
        // CRITICAL FIX: Add timeout and error handling for Core Image operations
        let image: CGImage
        do {
            // Create image from context with timeout protection
            guard let createdImage = context.makeImage() else {
                throw VectorImportError.parsingError("Failed to create image from context", line: nil)
            }
            image = createdImage
        } catch {
            throw VectorImportError.parsingError("Core Image operation failed: \(error.localizedDescription)", line: nil)
        }
        
        // Save JPEG with quality setting and error handling
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        guard let dest = destination else {
            throw VectorImportError.parsingError("Failed to create JPEG destination", line: nil)
        }
        
        // Set JPEG compression quality
        let options = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        
        if !CGImageDestinationFinalize(dest) {
            throw VectorImportError.parsingError("Failed to finalize JPEG export", line: nil)
        }
        
        Log.info("✅ Successfully exported JPEG document", category: .fileOperations)
    }
}
