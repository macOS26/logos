//
//  InkPenQuickLookGenerator.swift
//  logos inkpen.io
//
//  QuickLook generator for .inkpen document files
//

import Foundation
import QuickLook
import AppKit

@objc class InkPenQuickLookGenerator: NSObject, QLPreviewGenerator {
    
    static let supportedTypes = ["com.toddbruss.logos-inkpen-io.document"]
    
    func generatePreview(of url: URL, to outputURL: URL, contentType: String, options: [String: Any]?) throws {
        guard contentType == "com.toddbruss.logos-inkpen-io.document" else {
            throw QuickLookError.unsupportedContentType
        }
        
        // Load the .inkpen document
        let document = try loadInkPenDocument(from: url)
        
        // Generate SVG preview
        let svgContent = generateSVGPreview(from: document)
        
        // Create preview image from SVG
        let previewImage = createPreviewImage(from: svgContent, size: CGSize(width: 800, height: 600))
        
        // Save as PNG for QuickLook
        try savePreviewImage(previewImage, to: outputURL)
        
        // Also generate thumbnail
        let thumbnailImage = createPreviewImage(from: svgContent, size: CGSize(width: 256, height: 256))
        try saveThumbnail(thumbnailImage, for: url)
    }
    
    private func loadInkPenDocument(from url: URL) throws -> VectorDocument {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(VectorDocument.self, from: data)
    }
    
    private func generateSVGPreview(from document: VectorDocument) -> String {
        let documentSize = document.settings.sizeInPoints
        let width = documentSize.width
        let height = documentSize.height
        
        var svgContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)" xmlns="http://www.w3.org/2000/svg">
        <defs>
        """
        
        // Add gradient definitions if any
        svgContent += generateGradientDefinitions(from: document)
        
        svgContent += """
        </defs>
        <rect width="\(width)" height="\(height)" fill="\(document.settings.backgroundColor.svgColor)"/>
        """
        
        // Render all visible layers and shapes
        for layer in document.layers where layer.isVisible {
            for shape in layer.shapes where shape.isVisible {
                svgContent += generateShapeSVG(shape)
            }
        }
        
        // Render text objects
        for textObj in document.textObjects where textObj.isVisible {
            svgContent += generateTextSVG(textObj)
        }
        
        svgContent += "</svg>"
        return svgContent
    }
    
    private func generateGradientDefinitions(from document: VectorDocument) -> String {
        var definitions = ""
        
        // Add any gradient definitions here if needed
        // For now, return empty string
        return definitions
    }
    
    private func generateShapeSVG(_ shape: VectorShape) -> String {
        var svg = ""
        
        // Generate path data
        let pathData = generatePathData(from: shape.path)
        
        svg += "<path d=\"\(pathData)\""
        
        // Add fill
        if let fillStyle = shape.fillStyle {
            svg += " fill=\"\(fillStyle.color.svgColor)\""
            if fillStyle.opacity != 1.0 {
                svg += " fill-opacity=\"\(fillStyle.opacity)\""
            }
        } else {
            svg += " fill=\"none\""
        }
        
        // Add stroke
        if let strokeStyle = shape.strokeStyle {
            svg += " stroke=\"\(strokeStyle.color.svgColor)\""
            svg += " stroke-width=\"\(strokeStyle.width)\""
            if strokeStyle.opacity != 1.0 {
                svg += " stroke-opacity=\"\(strokeStyle.opacity)\""
            }
        }
        
        svg += "/>"
        return svg
    }
    
    private func generatePathData(from path: VectorPath) -> String {
        var pathData = ""
        
        for element in path.elements {
            switch element {
            case .move(let to):
                pathData += "M \(to.x) \(to.y) "
            case .line(let to):
                pathData += "L \(to.x) \(to.y) "
            case .curve(let to, let control1, let control2):
                pathData += "C \(control1.x) \(control1.y) \(control2.x) \(control2.y) \(to.x) \(to.y) "
            case .quadCurve(let to, let control):
                pathData += "Q \(control.x) \(control.y) \(to.x) \(to.y) "
            case .close:
                pathData += "Z "
            }
        }
        
        return pathData.trimmingCharacters(in: .whitespaces)
    }
    
    private func generateTextSVG(_ textObj: VectorText) -> String {
        let position = textObj.position
        let content = textObj.content.isEmpty ? "Text" : textObj.content
        
        var svg = "<text x=\"\(position.x)\" y=\"\(position.y)\""
        
        // Add font properties
        let fontSize = textObj.typography.fontSize
        svg += " font-family=\"\(textObj.typography.fontFamily)\""
        svg += " font-size=\"\(fontSize)\""
        
        // Add fill color
        svg += " fill=\"\(textObj.typography.fillColor.svgColor)\""
        
        // Add stroke if present
        if textObj.typography.strokeColor != .clear {
            svg += " stroke=\"\(textObj.typography.strokeColor.svgColor)\""
            svg += " stroke-width=\"\(textObj.typography.strokeWidth)\""
        }
        
        svg += ">\(content)</text>"
        return svg
    }
    
    private func createPreviewImage(from svgContent: String, size: CGSize) -> NSImage {
        // Create a simple preview using Core Graphics
        let image = NSImage(size: size)
        image.lockFocus()
        
        // Get the graphics context
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return NSImage(size: size)
        }
        
        // Set up the context
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        // For now, create a simple preview showing document info
        // In a full implementation, you'd parse the SVG and render it with Core Graphics
        createSimplePreview(context: context, size: size, svgContent: svgContent)
        
        image.unlockFocus()
        return image
    }
    
    private func createSimplePreview(context: CGContext, size: CGSize, svgContent: String) {
        // Create a simple preview showing that this is an Ink Pen document
        let rect = CGRect(origin: .zero, size: size)
        
        // Background
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.1).cgColor)
        context.fill(rect)
        
        // Border
        context.setStrokeColor(NSColor.systemBlue.cgColor)
        context.setLineWidth(2.0)
        context.stroke(rect.insetBy(dx: 1, dy: 1))
        
        // Text
        let text = "Ink Pen Document"
        let font = NSFont.systemFont(ofSize: 24, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemBlue
        ]
        
        let textSize = text.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: textAttributes)
        
        // Add a small icon
        let iconSize: CGFloat = 32
        let iconRect = CGRect(
            x: (size.width - iconSize) / 2,
            y: textRect.minY - iconSize - 20,
            width: iconSize,
            height: iconSize
        )
        
        // Draw a simple pen icon
        context.setFillColor(NSColor.systemBlue.cgColor)
        context.fillEllipse(in: iconRect)
        
        // Add file info
        let infoText = "Vector Graphics Document"
        let infoFont = NSFont.systemFont(ofSize: 12)
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: infoFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        
        let infoSize = infoText.size(withAttributes: infoAttributes)
        let infoRect = CGRect(
            x: (size.width - infoSize.width) / 2,
            y: textRect.maxY + 10,
            width: infoSize.width,
            height: infoSize.height
        )
        
        infoText.draw(in: infoRect, withAttributes: infoAttributes)
    }
    
    private func savePreviewImage(_ image: NSImage, to url: URL) throws {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw QuickLookError.imageGenerationFailed
        }
        
        try pngData.write(to: url)
    }
    
    private func saveThumbnail(_ image: NSImage, for documentURL: URL) throws {
        // Save thumbnail to QuickLook cache
        let thumbnailURL = getThumbnailURL(for: documentURL)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw QuickLookError.imageGenerationFailed
        }
        
        try pngData.write(to: thumbnailURL)
    }
    
    private func getThumbnailURL(for documentURL: URL) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let quickLookDir = cacheDir.appendingPathComponent("QuickLook")
        let thumbnailDir = quickLookDir.appendingPathComponent("Thumbnails")
        
        // Create directories if they don't exist
        try? FileManager.default.createDirectory(at: thumbnailDir, withIntermediateDirectories: true)
        
        let fileName = documentURL.lastPathComponent.replacingOccurrences(of: ".inkpen", with: ".png")
        return thumbnailDir.appendingPathComponent(fileName)
    }
}

// MARK: - QuickLook Error Types

enum QuickLookError: Error {
    case unsupportedContentType
    case imageGenerationFailed
    case documentLoadFailed
}

// MARK: - VectorColor SVG Extension

extension VectorColor {
    var svgColor: String {
        switch self {
        case .clear:
            return "none"
        case .black:
            return "#000000"
        case .white:
            return "#FFFFFF"
        case .red:
            return "#FF0000"
        case .green:
            return "#00FF00"
        case .blue:
            return "#0000FF"
        case .yellow:
            return "#FFFF00"
        case .cyan:
            return "#00FFFF"
        case .magenta:
            return "#FF00FF"
        case .gray:
            return "#808080"
        case .rgb(let r, let g, let b):
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        case .cmyk(let c, let m, let y, let k):
            // Convert CMYK to RGB for SVG
            let r = (1 - c) * (1 - k)
            let g = (1 - m) * (1 - k)
            let b = (1 - y) * (1 - k)
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        case .hsb(let h, let s, let b):
            // Convert HSB to RGB for SVG
            let rgb = hsbToRgb(h: h, s: s, b: b)
            return String(format: "#%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255))
        }
    }
    
    private func hsbToRgb(h: Double, s: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let hue = h * 360
        let saturation = s
        let brightness = b
        
        let c = brightness * saturation
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        
        let (r, g, b): (Double, Double, Double)
        
        switch Int(hue) / 60 {
        case 0:
            (r, g, b) = (c, x, 0)
        case 1:
            (r, g, b) = (x, c, 0)
        case 2:
            (r, g, b) = (0, c, x)
        case 3:
            (r, g, b) = (0, x, c)
        case 4:
            (r, g, b) = (x, 0, c)
        case 5:
            (r, g, b) = (c, 0, x)
        default:
            (r, g, b) = (0, 0, 0)
        }
        
        return (r + m, g + m, b + m)
    }
} 