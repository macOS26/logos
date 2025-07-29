//
//  DocumentIconGenerator.swift
//  logos inkpen.io
//
//  Generates document icons and previews for .inkpen files
//

import Foundation
import AppKit
import UniformTypeIdentifiers

class DocumentIconGenerator {
    
    static let shared = DocumentIconGenerator()
    
    private init() {}
    
    // MARK: - Document Icon Generation
    
    func generateDocumentIcon(for document: VectorDocument, size: CGSize = CGSize(width: 256, height: 256)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return NSImage(size: size)
        }
        
        // Create a professional document icon
        createDocumentIcon(context: context, size: size, document: document)
        
        image.unlockFocus()
        return image
    }
    
    private func createDocumentIcon(context: CGContext, size: CGSize, document: VectorDocument) {
        let rect = CGRect(origin: .zero, size: size)
        
        // Background - white paper with shadow
        context.setFillColor(NSColor.white.cgColor)
        context.fill(rect)
        
        // Add subtle shadow
        context.setShadow(offset: CGSize(width: 2, height: -2), blur: 4, color: NSColor.black.withAlphaComponent(0.2).cgColor)
        context.fill(rect.insetBy(dx: 4, dy: 4))
        context.setShadow(offset: .zero, blur: 0, color: nil)
        
        // Document border
        context.setStrokeColor(NSColor.systemGray.cgColor)
        context.setLineWidth(1.0)
        context.stroke(rect.insetBy(dx: 4, dy: 4))
        
        // Add a small preview of the document content
        let previewRect = rect.insetBy(dx: 20, dy: 40)
        createDocumentPreview(context: context, rect: previewRect, document: document)
        
        // Add "Ink Pen" text at the bottom
        let text = "Ink Pen"
        let font = NSFont.systemFont(ofSize: 14, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemBlue
        ]
        
        let textSize = text.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: (size.width - textSize.width) / 2,
            y: 10,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: textAttributes)
    }
    
    private func createDocumentPreview(context: CGContext, rect: CGRect, document: VectorDocument) {
        // Create a simple preview showing document content
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.1).cgColor)
        context.fill(rect)
        
        // Add some sample shapes to show it's a vector document
        let centerX = rect.midX
        let centerY = rect.midY
        let radius = min(rect.width, rect.height) * 0.15
        
        // Draw a sample circle
        context.setFillColor(NSColor.systemBlue.withAlphaComponent(0.3).cgColor)
        context.fillEllipse(in: CGRect(x: centerX - radius, y: centerY - radius, width: radius * 2, height: radius * 2))
        
        // Draw a sample rectangle
        let rectSize = radius * 1.5
        context.setFillColor(NSColor.systemGreen.withAlphaComponent(0.3).cgColor)
        context.fill(CGRect(x: centerX + radius * 0.5, y: centerY - rectSize/2, width: rectSize, height: rectSize))
        
        // Draw a sample line
        context.setStrokeColor(NSColor.systemRed.cgColor)
        context.setLineWidth(2.0)
        context.move(to: CGPoint(x: centerX - radius * 1.5, y: centerY + radius))
        context.addLine(to: CGPoint(x: centerX + radius * 1.5, y: centerY - radius))
        context.strokePath()
    }
    
    // MARK: - SVG Preview Generation
    
    func generateSVGPreview(for document: VectorDocument) -> String {
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
    
    // MARK: - File Icon Management
    
    func setCustomIcon(for url: URL, document: VectorDocument) {
        let icon = generateDocumentIcon(for: document)
        
        // Set the custom icon for the file
        NSWorkspace.shared.setIcon(icon, forFile: url.path, options: [])
    }
    
    func clearCustomIcon(for url: URL) {
        // Clear the custom icon and use default
        NSWorkspace.shared.setIcon(nil, forFile: url.path, options: [])
    }
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