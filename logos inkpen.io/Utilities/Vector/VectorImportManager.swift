//
//  VectorImportManager.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

/// PROFESSIONAL VECTOR GRAPHICS IMPORT MANAGER
class VectorImportManager {
    
    static let shared = VectorImportManager()
    
    private init() {}
    
    // MARK: - Main Import Interface
    
    /// Import file; routes to vector or raster import as appropriate
    func importVectorFile(from url: URL) async -> VectorImportResult {
        Log.fileOperation("🔄 Importing vector file: \(url.lastPathComponent)", level: .info)
        
        // Detect vector or raster
        if let raster = detectRaster(from: url) {
            return await importRaster(from: url, raster: raster)
        }
        
        // Detect vector format
        guard let format = detectFormat(from: url) else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.unsupportedFormat(.svg)],
                warnings: ["Could not detect file format"]
            )
        }
        
        Log.fileOperation("📋 Detected format: \(format.displayName)", level: .info)
        
        // Check if format is currently supported
        guard format.isCurrentlySupported else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.commercialLicenseRequired(format)],
                warnings: ["Professional CAD formats require commercial licensing"]
            )
        }
        
        // Import based on format
        switch format {
        case .svg:
            return await importSVG(from: url)
        case .pdf:
            return await importPDF(from: url)
        case .adobeIllustrator:
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.unsupportedFormat(.adobeIllustrator)],
                warnings: ["Adobe Illustrator format is no longer supported"]
            )
        case .dwf:
            return await importDWF(from: url)
        case .dxf, .dwg:
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.commercialLicenseRequired(format)],
                warnings: ["DWG/DXF support requires Open Design Alliance licensing"]
            )
        }
    }
    
    /// Import SVG with extreme value handling for radial gradients that cannot be reproduced
    /// Use this for SVGs with extreme coordinate values that cause rendering issues
    func importSVGWithExtremeValueHandling(from url: URL) async -> VectorImportResult {
        Log.fileOperation("🔄 Importing SVG with extreme value handling: \(url.lastPathComponent)", level: .info)
        
        // Detect file format
        guard let format = detectFormat(from: url) else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.unsupportedFormat(.svg)],
                warnings: ["Could not detect file format"]
            )
        }
        
        Log.fileOperation("📋 Detected format: \(format.displayName)", level: .info)
        
        // Check if format is currently supported
        guard format.isCurrentlySupported else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.commercialLicenseRequired(format)],
                warnings: ["Professional CAD formats require commercial licensing"]
            )
        }
        
        // Import based on format
        switch format {
        case .svg:
            return await importSVG(from: url, useExtremeValueHandling: true)
        case .pdf:
            return await importPDF(from: url)
        case .adobeIllustrator:
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.unsupportedFormat(.adobeIllustrator)],
                warnings: ["Adobe Illustrator format is no longer supported"]
            )
        case .dwf:
            return await importDWF(from: url)
        case .dxf, .dwg:
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.commercialLicenseRequired(format)],
                warnings: ["DWG/DXF support requires Open Design Alliance licensing"]
            )
        }
    }
    
    // MARK: - Format Detection
    
    private func detectFormat(from url: URL) -> VectorFileFormat? {
        let pathExtension = url.pathExtension.lowercased()
        
        // Primary detection by extension
        if let format = VectorFileFormat.allCases.first(where: { $0.rawValue == pathExtension }) {
            return format
        }
        
        // Secondary detection by content analysis
        guard let data = try? Data(contentsOf: url) else { return nil }
        
        return detectFormatByContent(data)
    }
    
    // MARK: - Raster Detection
    enum RasterFormat: String, CaseIterable {
        case png = "png"
        case jpg = "jpg"
        case jpeg = "jpeg"
        case tif = "tif"
        case tiff = "tiff"
        case gif = "gif"
        case bmp = "bmp"
        case heic = "heic"
        case webp = "webp"
    }
    
    private func detectRaster(from url: URL) -> RasterFormat? {
        let ext = url.pathExtension.lowercased()
        return RasterFormat.allCases.first { $0.rawValue == ext }
    }
    
    private func detectFormatByContent(_ data: Data) -> VectorFileFormat? {
        guard let string = String(data: data.prefix(1024), encoding: .utf8) else { return nil }
        
        // SVG detection
        if string.contains("<svg") || string.contains("<?xml") && string.contains("svg") {
            return .svg
        }
        
        // PDF detection
        if string.hasPrefix("%PDF-") {
            return .pdf
        }
        
        // AI file detection (contains embedded PDF)
        if string.contains("%!PS-Adobe") && string.contains("%%Creator:") && string.contains("Adobe Illustrator") {
            return .adobeIllustrator
        }
        
        // PostScript/EPS detection - treat as PDF for import
        if string.hasPrefix("%!PS-Adobe") {
            return .pdf
        }
        
        // DXF detection
        if string.contains("0\nSECTION") || string.contains("AUTOCAD") {
            return .dxf
        }
        
        // DWF detection (Design Web Format header)
        if string.hasPrefix("(DWF V") {
            return .dwf
        }
        
        return nil
    }
    
    // MARK: - SVG Import (Professional Standard)
    
    private func importSVG(from url: URL, useExtremeValueHandling: Bool = false) async -> VectorImportResult {
        var errors: [VectorImportError] = []
        var warnings: [String] = []
        var shapes: [VectorShape] = []
        
        Log.fileOperation("📊 Importing SVG using professional SVG parser...", level: .info)
        if useExtremeValueHandling {
            Log.fileOperation("🔧 Using extreme value handling for radial gradients", level: .info)
        }
        
        do {
            guard let data = try? Data(contentsOf: url) else {
                throw VectorImportError.fileNotFound
            }
            
            // Parse SVG using professional XML parser
            let svgContent = try parseSVGContent(data, useExtremeValueHandling: useExtremeValueHandling)
            shapes = svgContent.shapes
            // Text objects are now imported as shapes with isTextObject=true
            
            if !svgContent.missingFonts.isEmpty {
                warnings.append("Missing fonts: \(svgContent.missingFonts.joined(separator: ", "))")
            }
            
            let metadata = VectorImportMetadata(
                originalFormat: .svg,
                documentSize: svgContent.documentSize,
                colorSpace: svgContent.colorSpace,
                units: svgContent.units,
                dpi: svgContent.dpi,
                layerCount: 1, // SVG doesn't have layers like AI
                shapeCount: shapes.count,
                textObjectCount: 0, // Text is now stored as shapes
                importDate: Date(),
                sourceApplication: svgContent.creator,
                documentVersion: svgContent.version
            )
            
            Log.fileOperation("✅ SVG import successful: \(shapes.count) shapes", level: .info)
            
            return VectorImportResult(
                success: true,
                shapes: shapes,
                metadata: metadata,
                errors: errors,
                warnings: warnings
            )
            
        } catch {
            errors.append(.parsingError(error.localizedDescription, line: nil))
            Log.error("❌ SVG import failed: \(error)", category: .error)
            
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
    }

    // MARK: - Raster Import
    private func importRaster(from url: URL, raster: RasterFormat) async -> VectorImportResult {
        Log.fileOperation("🖼️ Importing raster image: \(url.lastPathComponent)", level: .info)
        guard let nsImage = NSImage(contentsOf: url) else {
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: [.parsingError("Failed to open image", line: nil)],
                warnings: []
            )
        }
        let size = nsImage.size
        var rectShape = VectorShape(
            name: "[IMG] \(url.lastPathComponent)",
            path: VectorPath(elements: [
                .move(to: VectorPoint(0, 0)),
                .line(to: VectorPoint(size.width, 0)),
                .line(to: VectorPoint(size.width, size.height)),
                .line(to: VectorPoint(0, size.height)),
                .close
            ], isClosed: true),
            strokeStyle: StrokeStyle(color: .clear, width: 0, placement: .center),
            fillStyle: FillStyle(color: .clear),
            transform: .identity
        )
        
        // CRITICAL FIX: Ensure bounds match the actual image dimensions
        // The bounds should be exactly the same as the image size
        rectShape.bounds = CGRect(origin: .zero, size: size)
        
        // DEBUG: Log the image import details
        Log.info("🖼️ IMAGE IMPORT DEBUG: \(url.lastPathComponent)", category: .general)
        Log.info("   📏 Image size: \(size)", category: .general)
        Log.info("   📊 Path bounds: \(rectShape.path.cgPath.boundingBoxOfPath)", category: .general)
        Log.info("   📊 Set bounds: \(rectShape.bounds)", category: .general)
        Log.info("   🔄 Transform: \(rectShape.transform)", category: .general)
        // Default behavior: store a linked path (relative to chosen base later on save)
        rectShape.linkedImagePath = url.path
        // Also store a security-scoped bookmark when possible (DocumentGroup sandbox)
        if let bookmark = try? url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
            rectShape.linkedImageBookmarkData = bookmark
        }
        ImageContentRegistry.register(image: nsImage, for: rectShape.id)
        let meta = VectorImportMetadata(
            originalFormat: .pdf, // placeholder; not used for raster
            documentSize: size,
            colorSpace: "sRGB",
            units: .pixels,
            dpi: 72,
            layerCount: 1,
            shapeCount: 1,
            textObjectCount: 0,
            importDate: Date(),
            sourceApplication: nil,
            documentVersion: nil
        )
        return VectorImportResult(success: true, shapes: [rectShape], metadata: meta, errors: [], warnings: [])
    }
    
    // MARK: - PDF Import (Professional Standard)
    
    private func importPDF(from url: URL) async -> VectorImportResult {
        var errors: [VectorImportError] = []
        let warnings: [String] = []
        var shapes: [VectorShape] = []
        
        Log.fileOperation("📊 Importing PDF using CoreGraphics professional parser...", level: .info)
        
        guard let pdfDocument = CGPDFDocument(url as CFURL) else {
            errors.append(.corruptedFile)
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
        
        // Import first page (can be extended for multi-page)
        guard let page = pdfDocument.page(at: 1) else {
            errors.append(.invalidStructure("No pages found"))
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
        
        // Extract vector paths from PDF
        do {
            let pdfContent = try extractPDFVectorContent(page)
            shapes = pdfContent.shapes
            
            let mediaBox = page.getBoxRect(.mediaBox)
            
            let metadata = VectorImportMetadata(
                originalFormat: .pdf,
                documentSize: mediaBox.size,
                colorSpace: "RGB", // PDF can contain multiple color spaces
                units: .points,
                dpi: 72.0,
                layerCount: 1,
                shapeCount: shapes.count,
                textObjectCount: pdfContent.textCount,
                importDate: Date(),
                sourceApplication: pdfContent.creator,
                documentVersion: pdfContent.version
            )
            
            Log.fileOperation("✅ PDF import successful: \(shapes.count) vector shapes", level: .info)
            
            return VectorImportResult(
                success: true,
                shapes: shapes,
                metadata: metadata,
                errors: errors,
                warnings: warnings
            )
            
        } catch {
            errors.append(.parsingError(error.localizedDescription, line: nil))
            Log.error("❌ PDF import failed: \(error)", category: .error)
            
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
    }
    
    // MARK: - AI/EPS/PS Import Methods (REMOVED - No longer supported)
    
    // MARK: - DWF Import (Design Web Format - Autodesk Published Standard)
    
    private func importDWF(from url: URL) async -> VectorImportResult {
        var errors: [VectorImportError] = []
        var warnings: [String] = []
        var shapes: [VectorShape] = []
        
        Log.fileOperation("📊 Importing DWF (Design Web Format)...", level: .info)
        Log.fileOperation("💡 DWF is Autodesk's published, open format for CAD/engineering drawings", level: .info)
        
        do {
            guard let data = try? Data(contentsOf: url) else {
                throw VectorImportError.fileNotFound
            }
            
            // Parse DWF using professional parser
            let dwfContent = try parseDWFContent(data)
            shapes = dwfContent.shapes
            
            if !dwfContent.missingFonts.isEmpty {
                warnings.append("Missing fonts: \(dwfContent.missingFonts.joined(separator: ", "))")
            }
            
            if dwfContent.hasEncryptedData {
                warnings.append("Some encrypted data sections were skipped")
            }
            
            if dwfContent.layerCount > 1 {
                warnings.append("Multiple layers detected - imported as flattened design")
            }
            
            let metadata = VectorImportMetadata(
                originalFormat: .dwf,
                documentSize: dwfContent.documentSize,
                colorSpace: dwfContent.colorSpace,
                units: dwfContent.units,
                dpi: dwfContent.dpi,
                layerCount: dwfContent.layerCount,
                shapeCount: shapes.count,
                textObjectCount: dwfContent.textCount,
                importDate: Date(),
                sourceApplication: dwfContent.sourceApplication,
                documentVersion: dwfContent.version
            )
            
            Log.fileOperation("✅ DWF import successful: \(shapes.count) vector shapes, \(dwfContent.layerCount) layers", level: .info)
            
            return VectorImportResult(
                success: true,
                shapes: shapes,
                metadata: metadata,
                errors: errors,
                warnings: warnings
            )
            
        } catch {
            errors.append(.parsingError(error.localizedDescription, line: nil))
            Log.error("❌ DWF import failed: \(error)", category: .error)
            
            return VectorImportResult(
                success: false,
                shapes: [],
                metadata: createDefaultMetadata(),
                errors: errors,
                warnings: warnings
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func createDefaultMetadata() -> VectorImportMetadata {
        return VectorImportMetadata(
            originalFormat: .svg,
            documentSize: CGSize(width: 8.5 * 72, height: 11 * 72), // Letter size in points
            colorSpace: "RGB",
            units: .points,
            dpi: 72.0,
            layerCount: 1,
            shapeCount: 0,
            textObjectCount: 0,
            importDate: Date(),
            sourceApplication: nil,
            documentVersion: nil
        )
    }
}
