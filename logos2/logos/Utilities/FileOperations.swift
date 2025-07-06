//
//  FileOperations.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import CoreGraphics
import UniformTypeIdentifiers
import ImageIO

class FileOperations {
    
    // MARK: - SVG Export
    static func exportToSVG(_ document: VectorDocument, url: URL) throws {
        let svgContent = generateSVGContent(document)
        try svgContent.write(to: url, atomically: true, encoding: .utf8)
    }
    
    private static func generateSVGContent(_ document: VectorDocument) -> String {
        let settings = document.settings
        let size = settings.sizeInPoints
        
        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(size.width)" height="\(size.height)" viewBox="0 0 \(size.width) \(size.height)" xmlns="http://www.w3.org/2000/svg">
        """
        
        // Add background
        if settings.backgroundColor != .clear {
            svg += """
            \n  <rect width="100%" height="100%" fill="\(colorToHex(settings.backgroundColor))"/>
            """
        }
        
        // Add layers
        for layer in document.layers {
            if layer.isVisible {
                svg += generateLayerSVG(layer)
            }
        }
        
        svg += "\n</svg>"
        return svg
    }
    
    private static func generateLayerSVG(_ layer: VectorLayer) -> String {
        var layerSVG = ""
        
        if layer.opacity < 1.0 {
            layerSVG += "\n  <g opacity=\"\(layer.opacity)\">"
        }
        
        for shape in layer.shapes {
            if shape.isVisible {
                layerSVG += generateShapeSVG(shape)
            }
        }
        
        if layer.opacity < 1.0 {
            layerSVG += "\n  </g>"
        }
        
        return layerSVG
    }
    
    private static func generateShapeSVG(_ shape: VectorShape) -> String {
        let pathData = PathOperations.pathToSVGString(shape.path.cgPath)
        var shapeSVG = "\n  <path d=\"\(pathData)\""
        
        // Add fill
        if let fillStyle = shape.fillStyle {
            if fillStyle.color == .clear {
                shapeSVG += " fill=\"none\""
            } else {
                shapeSVG += " fill=\"\(colorToHex(fillStyle.color))\""
                if fillStyle.opacity < 1.0 {
                    shapeSVG += " fill-opacity=\"\(fillStyle.opacity)\""
                }
            }
        }
        
        // Add stroke
        if let strokeStyle = shape.strokeStyle {
            if strokeStyle.color != .clear {
                shapeSVG += " stroke=\"\(colorToHex(strokeStyle.color))\""
                shapeSVG += " stroke-width=\"\(strokeStyle.width)\""
                
                // Add stroke placement (SVG doesn't directly support inside/outside, so we approximate)
                switch strokeStyle.placement {
                case .inside:
                    shapeSVG += " stroke-width=\"\(strokeStyle.width * 2)\""
                case .outside:
                    shapeSVG += " stroke-width=\"\(strokeStyle.width * 2)\""
                case .center:
                    break
                }
                
                // Add dash pattern
                if !strokeStyle.dashPattern.isEmpty {
                    let dashString = strokeStyle.dashPattern.map { String($0) }.joined(separator: ",")
                    shapeSVG += " stroke-dasharray=\"\(dashString)\""
                }
            }
        }
        
        // Add transform
        if shape.transform != .identity {
            let t = shape.transform
            shapeSVG += " transform=\"matrix(\(t.a),\(t.b),\(t.c),\(t.d),\(t.tx),\(t.ty))\""
        }
        
        // Add opacity
        if shape.opacity < 1.0 {
            shapeSVG += " opacity=\"\(shape.opacity)\""
        }
        
        shapeSVG += "/>"
        return shapeSVG
    }
    
    // MARK: - PDF Export
    static func exportToPDF(_ document: VectorDocument, url: URL) throws {
        let settings = document.settings
        let pageSize = settings.sizeInPoints
        var mediaBox = CGRect(origin: .zero, size: pageSize)
        
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw FileOperationError.pdfCreationFailed
        }
        
        pdfContext.beginPDFPage(nil)
        
        // Draw background
        if settings.backgroundColor != .clear {
            pdfContext.setFillColor(settings.backgroundColor.cgColor)
            pdfContext.fill(CGRect(origin: .zero, size: pageSize))
        }
        
        // Draw layers
        for layer in document.layers {
            if layer.isVisible {
                drawLayerToPDF(layer, context: pdfContext)
            }
        }
        
        pdfContext.endPDFPage()
        pdfContext.closePDF()
    }
    
    private static func drawLayerToPDF(_ layer: VectorLayer, context: CGContext) {
        context.saveGState()
        
        if layer.opacity < 1.0 {
            context.setAlpha(layer.opacity)
        }
        
        for shape in layer.shapes {
            if shape.isVisible {
                drawShapeToPDF(shape, context: context)
            }
        }
        
        context.restoreGState()
    }
    
    private static func drawShapeToPDF(_ shape: VectorShape, context: CGContext) {
        context.saveGState()
        
        // Apply transform
        if shape.transform != .identity {
            context.concatenate(shape.transform)
        }
        
        // Set opacity
        if shape.opacity < 1.0 {
            context.setAlpha(shape.opacity)
        }
        
        let path = shape.path.cgPath
        
        // Draw fill
        if let fillStyle = shape.fillStyle, fillStyle.color != .clear {
            context.setFillColor(fillStyle.color.cgColor)
            context.setAlpha(fillStyle.opacity)
            context.addPath(path)
            context.fillPath()
        }
        
        // Draw stroke
        if let strokeStyle = shape.strokeStyle, strokeStyle.color != .clear {
            context.setStrokeColor(strokeStyle.color.cgColor)
            context.setLineWidth(strokeStyle.width)
            context.setLineCap(strokeStyle.lineCap)
            context.setLineJoin(strokeStyle.lineJoin)
            context.setMiterLimit(strokeStyle.miterLimit)
            
            if !strokeStyle.dashPattern.isEmpty {
                let cgFloatPattern = strokeStyle.dashPattern.map { CGFloat($0) }
                context.setLineDash(phase: 0, lengths: cgFloatPattern)
            }
            
            context.addPath(path)
            context.strokePath()
        }
        
        context.restoreGState()
    }
    
    // MARK: - PNG Export
    static func exportToPNG(_ document: VectorDocument, url: URL, scale: CGFloat = 1.0) throws {
        let settings = document.settings
        let size = CGSize(width: settings.sizeInPoints.width * scale, height: settings.sizeInPoints.height * scale)
        
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw FileOperationError.imageCreationFailed
        }
        
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FileOperationError.imageCreationFailed
        }
        
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: 0, y: size.height / scale)
        context.scaleBy(x: 1, y: -1)
        
        // Draw background
        if settings.backgroundColor != .clear {
            context.setFillColor(settings.backgroundColor.cgColor)
            context.fill(CGRect(origin: .zero, size: settings.sizeInPoints))
        }
        
        // Draw layers
        for layer in document.layers {
            if layer.isVisible {
                drawLayerToPDF(layer, context: context)
            }
        }
        
        guard let cgImage = context.makeImage() else {
            throw FileOperationError.imageCreationFailed
        }
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw FileOperationError.imageCreationFailed
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        
        if !CGImageDestinationFinalize(destination) {
            throw FileOperationError.imageCreationFailed
        }
    }
    
    // MARK: - JSON Export/Import
    static func exportToJSON(_ document: VectorDocument, url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(document)
        try data.write(to: url)
    }
    
    static func importFromJSON(url: URL) throws -> VectorDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(VectorDocument.self, from: data)
    }
    
    // MARK: - Helper Functions
    private static func colorToHex(_ color: VectorColor) -> String {
        switch color {
        case .rgb(let rgb):
            let r = Int(rgb.red * 255)
            let g = Int(rgb.green * 255)
            let b = Int(rgb.blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        case .cmyk(let cmyk):
            let rgb = cmyk.rgbColor
            let r = Int(rgb.red * 255)
            let g = Int(rgb.green * 255)
            let b = Int(rgb.blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        case .pantone(let pantone):
            let rgb = pantone.rgbEquivalent
            let r = Int(rgb.red * 255)
            let g = Int(rgb.green * 255)
            let b = Int(rgb.blue * 255)
            return String(format: "#%02X%02X%02X", r, g, b)
        case .black:
            return "#000000"
        case .white:
            return "#FFFFFF"
        case .clear:
            return "transparent"
        }
    }
    
    // MARK: - Pantone Color Import
    static func importPantoneColors(from url: URL) throws -> [PantoneColor] {
        // This would parse a Pantone color file (e.g., .ase, .aco)
        // For now, return a sample set
        return [
            PantoneColor(
                name: "PANTONE Red 032 C",
                number: "032 C",
                rgbEquivalent: RGBColor(red: 0.89, green: 0.18, blue: 0.22),
                cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.95, yellow: 0.87, black: 0.0)
            ),
            PantoneColor(
                name: "PANTONE Blue 072 C",
                number: "072 C",
                rgbEquivalent: RGBColor(red: 0.0, green: 0.32, blue: 0.73),
                cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.68, yellow: 0.0, black: 0.0)
            ),
            PantoneColor(
                name: "PANTONE Yellow 012 C",
                number: "012 C",
                rgbEquivalent: RGBColor(red: 1.0, green: 0.87, blue: 0.0),
                cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.13, yellow: 1.0, black: 0.0)
            )
        ]
    }
}

// MARK: - Error Types
enum FileOperationError: Error, LocalizedError {
    case pdfCreationFailed
    case imageCreationFailed
    case imageImportFailed
    case unsupportedFormat
    case fileNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .pdfCreationFailed:
            return "Failed to create PDF file"
        case .imageCreationFailed:
            return "Failed to create image file"
        case .imageImportFailed:
            return "Failed to import image"
        case .unsupportedFormat:
            return "Unsupported file format"
        case .fileNotFound:
            return "File not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}

// MARK: - File Format Detection
extension FileOperations {
    static func detectFileFormat(from url: URL) -> FileFormat? {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "svg":
            return .svg
        case "pdf":
            return .pdf
        case "png":
            return .png
        case "jpg", "jpeg":
            return .jpeg
        case "json":
            return .json
        case "ai":
            return .illustrator
        case "eps":
            return .eps
        default:
            return nil
        }
    }
}

enum FileFormat: String, CaseIterable {
    case svg = "SVG"
    case pdf = "PDF"
    case png = "PNG"
    case jpeg = "JPEG"
    case json = "JSON"
    case illustrator = "Adobe Illustrator"
    case eps = "EPS"
    
    var fileExtension: String {
        switch self {
        case .svg: return "svg"
        case .pdf: return "pdf"
        case .png: return "png"
        case .jpeg: return "jpg"
        case .json: return "json"
        case .illustrator: return "ai"
        case .eps: return "eps"
        }
    }
    
    var utType: UTType {
        switch self {
        case .svg: return UTType(filenameExtension: "svg")!
        case .pdf: return .pdf
        case .png: return .png
        case .jpeg: return .jpeg
        case .json: return .json
        case .illustrator: return UTType(filenameExtension: "ai")!
        case .eps: return UTType(filenameExtension: "eps")!
        }
    }
}
