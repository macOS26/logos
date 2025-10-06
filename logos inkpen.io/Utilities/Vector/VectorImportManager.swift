//
//  VectorImportManager.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

/// PROFESSIONAL VECTOR GRAPHICS IMPORT MANAGER
class VectorImportManager {
    
    static let shared = VectorImportManager()
    
    private init() {}
    
    // MARK: - Main Import Interface
    
    /// Import file; routes to vector or raster import as appropriate
    func importVectorFile(from url: URL) async -> VectorImportResult {
        
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
        }
    }
    
    /// Import SVG with extreme value handling for radial gradients that cannot be reproduced
    /// Use this for SVGs with extreme coordinate values that cause rendering issues
    func importSVGWithExtremeValueHandling(from url: URL) async -> VectorImportResult {
        
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
        
        // treat as PDF for import
        if string.hasPrefix("%!PS-Adobe") {
            return .pdf
        }
        
        return nil
    }
    
    // MARK: - SVG Import (Professional Standard)
    
    private func importSVG(from url: URL, useExtremeValueHandling: Bool = false) async -> VectorImportResult {
        var errors: [VectorImportError] = []
        var warnings: [String] = []
        var shapes: [VectorShape] = []

        if useExtremeValueHandling {
        }

        do {
            guard let data = try? Data(contentsOf: url) else {
                throw VectorImportError.fileNotFound
            }

            // CRITICAL OPTIMIZATION: Check for embedded inkpen metadata FIRST
            // This avoids parsing the entire SVG if it's a native inkpen document
            if let svgString = String(data: data, encoding: .utf8) {
                // Quick check for inkpen metadata before full parsing (handle namespace attribute)
                if let range = svgString.range(of: "<inkpen:document"),
                   let endRange = svgString.range(of: "</inkpen:document>") {

                    // Extract the base64 content - find the closing > of the opening tag first
                    if let openTagEnd = svgString.range(of: ">", range: range.upperBound..<endRange.lowerBound) {

                        // Extract everything between > and </inkpen:document>
                        let base64Data = String(svgString[openTagEnd.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)


                        // Extract document size from SVG (we still need this for the metadata)
                        var documentSize = CGSize(width: 8.5 * 72, height: 11 * 72) // Default
                        if let widthRange = svgString.range(of: "width=\""),
                           let widthEnd = svgString.range(of: "\"", range: widthRange.upperBound..<svgString.endIndex),
                           let width = Double(svgString[widthRange.upperBound..<widthEnd.lowerBound]) {
                            documentSize.width = width
                        }
                        if let heightRange = svgString.range(of: "height=\""),
                           let heightEnd = svgString.range(of: "\"", range: heightRange.upperBound..<svgString.endIndex),
                           let height = Double(svgString[heightRange.upperBound..<heightEnd.lowerBound]) {
                            documentSize.height = height
                        }


                        let metadata = VectorImportMetadata(
                            originalFormat: .svg,
                            documentSize: documentSize,
                            viewBoxSize: nil,
                            colorSpace: "RGB",
                            units: .points,
                            dpi: 72.0,
                            layerCount: 1,
                            shapeCount: 0,  // We didn't parse shapes
                            textObjectCount: 0,
                            importDate: Date(),
                            sourceApplication: "Inkpen.io",
                            documentVersion: nil,
                            inkpenMetadata: base64Data
                        )

                        return VectorImportResult(
                            success: true,
                            shapes: [],  // Empty - will be restored from metadata
                            metadata: metadata,
                            errors: errors,
                            warnings: warnings
                        )
                    }
                }
            }

            // No inkpen metadata found - parse as regular SVG

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
                viewBoxSize: svgContent.viewBoxSize,
                colorSpace: svgContent.colorSpace,
                units: svgContent.units,
                dpi: svgContent.dpi,
                layerCount: 1, // SVG doesn't have layers like AI
                shapeCount: shapes.count,
                textObjectCount: 0, // Text is now stored as shapes
                importDate: Date(),
                sourceApplication: svgContent.creator,
                documentVersion: svgContent.version,
                inkpenMetadata: svgContent.inkpenMetadata
            )
            
            
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
            viewBoxSize: nil,  // Raster images don't have viewBox
            colorSpace: "sRGB",
            units: .pixels,
            dpi: 72,
            layerCount: 1,
            shapeCount: 1,
            textObjectCount: 0,
            importDate: Date(),
            sourceApplication: nil,
            documentVersion: nil,
            inkpenMetadata: nil
        )
        return VectorImportResult(success: true, shapes: [rectShape], metadata: meta, errors: [], warnings: [])
    }
    
    // MARK: - PDF Import (Professional Standard)
    
    private func importPDF(from url: URL) async -> VectorImportResult {
        var errors: [VectorImportError] = []
        let warnings: [String] = []
        var shapes: [VectorShape] = []
        
        
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

        // CRITICAL OPTIMIZATION: Check for embedded inkpen metadata FIRST
        // This avoids parsing the entire PDF if it's a native inkpen document
        var inkpenMetadata: String? = nil

        if let pdfDoc = page.document, let catalog = pdfDoc.catalog {
            var metadataRef: CGPDFStreamRef?

            // Try to get the Metadata stream from the catalog
            if CGPDFDictionaryGetStream(catalog, "Metadata", &metadataRef),
               let metadataStream = metadataRef {

                var format: CGPDFDataFormat = .raw
                if let data = CGPDFStreamCopyData(metadataStream, &format) {
                    if let xmpString = String(data: data as Data, encoding: .utf8) {

                        // Parse XMP to extract inkpen:document element
                        if let range = xmpString.range(of: "<inkpen:document>"),
                           let endRange = xmpString.range(of: "</inkpen:document>") {
                            let startIndex = range.upperBound
                            let endIndex = endRange.lowerBound
                            let base64Data = String(xmpString[startIndex..<endIndex])
                            inkpenMetadata = base64Data
                        }
                    }
                }
            }
        }

        let mediaBox = page.getBoxRect(.mediaBox)

        // If we found inkpen metadata, return it immediately without parsing vector content
        if let metadata = inkpenMetadata {

            let importMetadata = VectorImportMetadata(
                originalFormat: .pdf,
                documentSize: mediaBox.size,
                viewBoxSize: nil,
                colorSpace: "RGB",
                units: .points,
                dpi: 72.0,
                layerCount: 1,
                shapeCount: 0,  // We didn't parse shapes
                textObjectCount: 0,
                importDate: Date(),
                sourceApplication: "Inkpen.io",
                documentVersion: nil,
                inkpenMetadata: metadata
            )

            return VectorImportResult(
                success: true,
                shapes: [],  // Empty - will be restored from metadata
                metadata: importMetadata,
                errors: errors,
                warnings: warnings
            )
        }

        // No inkpen metadata found - parse as regular PDF

        // Extract vector paths from PDF
        do {
            let pdfContent = try extractPDFVectorContent(page)
            shapes = pdfContent.shapes

            let metadata = VectorImportMetadata(
                originalFormat: .pdf,
                documentSize: mediaBox.size,
                viewBoxSize: nil,  // PDF doesn't have viewBox
                colorSpace: "RGB", // PDF can contain multiple color spaces
                units: .points,
                dpi: 72.0,
                layerCount: 1,
                shapeCount: shapes.count,
                textObjectCount: pdfContent.textCount,
                importDate: Date(),
                sourceApplication: pdfContent.creator,
                documentVersion: pdfContent.version,
                inkpenMetadata: inkpenMetadata
            )
            
            
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
    
    
    
    private func createDefaultMetadata() -> VectorImportMetadata {
        return VectorImportMetadata(
            originalFormat: .svg,
            documentSize: CGSize(width: 8.5 * 72, height: 11 * 72), // Letter size in points
            viewBoxSize: nil,  // Default has no viewBox
            colorSpace: "RGB",
            units: .points,
            dpi: 72.0,
            layerCount: 1,
            shapeCount: 0,
            textObjectCount: 0,
            importDate: Date(),
            sourceApplication: nil,
            documentVersion: nil,
            inkpenMetadata: nil
        )
    }
}
