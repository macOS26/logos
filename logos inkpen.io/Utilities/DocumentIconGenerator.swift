//
//  DocumentIconGenerator.swift
//  logos inkpen.io
//
//  Generates document icons and previews for .inkpen files
//

import Foundation
import AppKit
import UniformTypeIdentifiers
import CoreGraphics

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
        // Check if document has any art content
        let hasArtContent = documentHasArtContent(document)
        
        if hasArtContent {
            // Render actual SVG content of the art
            renderSVGArtPreview(context: context, rect: rect, document: document)
        } else {
            // Use fallback preview when no art content
            renderFallbackPreview(context: context, rect: rect)
        }
    }
    
    private func documentHasArtContent(_ document: VectorDocument) -> Bool {
        // Check if document has any visible shapes or text
        let hasVisibleShapes = document.layers.contains { layer in
            layer.isVisible && layer.shapes.contains { shape in
                shape.isVisible
            }
        }
        
        let hasVisibleText = document.textObjects.contains { textObj in
            textObj.isVisible
        }
        
        return hasVisibleShapes || hasVisibleText
    }
    
    private func renderSVGArtPreview(context: CGContext, rect: CGRect, document: VectorDocument) {
        // Generate SVG content from the document's art
        let svgContent = generateSVGPreview(for: document)
        
        // Convert SVG content to Data
        guard let svgData = svgContent.data(using: .utf8) else {
            renderFallbackPreview(context: context, rect: rect)
            return
        }
        
        // Create SVG document using the existing SVG class
        guard let svg = SVG(svgData) else {
            renderFallbackPreview(context: context, rect: rect)
            return
        }
        
        // Save current context state
        context.saveGState()
        
        // Set up context for SVG rendering
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // Calculate scale to fit SVG in preview rect while maintaining aspect ratio
        let svgSize = svg.size
        let scaleX = rect.width / svgSize.width
        let scaleY = rect.height / svgSize.height
        let scale = min(scaleX, scaleY)
        
        // Calculate centered position
        let scaledWidth = svgSize.width * scale
        let scaledHeight = svgSize.height * scale
        let x = rect.midX - scaledWidth / 2
        let y = rect.midY - scaledHeight / 2
        
        // Apply transform to center and scale the SVG
        context.translateBy(x: x, y: y)
        context.scaleBy(x: scale, y: scale)
        
        // Render the SVG to the context
        svg.renderToVectorContext(context, targetSize: svgSize)
        
        // Restore context state
        context.restoreGState()
    }
    
    private func renderFallbackPreview(context: CGContext, rect: CGRect) {
        // Create a fallback preview for empty documents
        let centerX = rect.midX
        let centerY = rect.midY
        
        // Background - light gray to indicate empty state
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.1).cgColor)
        context.fill(rect)
        
        // Draw a document icon to indicate this is an empty document
        let iconSize = min(rect.width, rect.height) * 0.3
        let iconRect = CGRect(
            x: centerX - iconSize / 2,
            y: centerY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        
        // Draw a simple document icon
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.3).cgColor)
        context.setStrokeColor(NSColor.systemGray.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        
        // Document shape
        let documentRect = iconRect.insetBy(dx: iconSize * 0.1, dy: iconSize * 0.1)
        context.fill(documentRect)
        context.stroke(documentRect)
        
        // Document fold corner
        let foldSize = iconSize * 0.15
        let foldRect = CGRect(
            x: documentRect.maxX - foldSize,
            y: documentRect.minY,
            width: foldSize,
            height: foldSize
        )
        
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.2).cgColor)
        context.fill(foldRect)
        
        // Add "Empty" text
        let text = "Empty"
        let font = NSFont.systemFont(ofSize: iconSize * 0.2, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemGray.withAlphaComponent(0.6)
        ]
        
        let textSize = text.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: centerX - textSize.width / 2,
            y: centerY + iconSize * 0.4,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: textAttributes)
    }
    
    // MARK: - SVG Preview Generation
    
    func generateSVGPreview(for document: VectorDocument) -> String {
        // Use the existing SVG export code from FileOperations but with custom modifications
        do {
            let baseSVG = try FileOperations.generateSVGContent(from: document)
            return modifySVGForPreview(baseSVG, document: document)
        } catch {
            // Fallback to simple preview if SVG generation fails
            return generateSimpleSVGPreview(for: document)
        }
    }
    
    private func modifySVGForPreview(_ baseSVG: String, document: VectorDocument) -> String {
        // Parse the base SVG to modify it for preview
        var modifiedSVG = baseSVG
        
        // Remove background/canvas elements
        modifiedSVG = removeBackgroundElements(from: modifiedSVG)
        
        // Fix Y-axis inversion by applying a transform
        modifiedSVG = fixYAxisInversion(in: modifiedSVG, document: document)
        
        // Remove padding by adjusting viewBox to content bounds
        modifiedSVG = removePadding(from: modifiedSVG, document: document)
        
        // Add "Ink Pen" text
        modifiedSVG = addInkPenText(to: modifiedSVG, document: document)
        
        return modifiedSVG
    }
    
    private func removeBackgroundElements(from svg: String) -> String {
        // Remove background rectangles and canvas elements
        var modifiedSVG = svg
        
        // Remove background rect elements
        let backgroundPatterns = [
            #"<rect[^>]*fill="[^"]*white[^"]*"[^>]*/>"#,
            #"<rect[^>]*fill="[^"]*#FFFFFF[^"]*"[^>]*/>"#,
            #"<rect[^>]*fill="[^"]*#ffffff[^"]*"[^>]*/>"#,
            #"<rect[^>]*fill="[^"]*rgb\(255,255,255\)[^"]*"[^>]*/>"#,
            #"<rect[^>]*class="[^"]*background[^"]*"[^>]*/>"#,
            #"<rect[^>]*id="[^"]*background[^"]*"[^>]*/>"#
        ]
        
        for pattern in backgroundPatterns {
            modifiedSVG = modifiedSVG.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        
        return modifiedSVG
    }
    
    private func fixYAxisInversion(in svg: String, document: VectorDocument) -> String {
        // Apply Y-axis flip to fix mirror image issue
        let documentSize = document.settings.sizeInPoints
        let height = documentSize.height
        
        // Add a transform to flip the Y-axis
        // Find the opening svg tag and add transform attribute
        if let range = svg.range(of: #"<svg[^>]*>"#, options: .regularExpression) {
            let svgTag = String(svg[range])
            let transformAttribute = " transform=\"scale(1,-1) translate(0,-\(height))\""
            
            // Insert transform attribute before the closing >
            if let closingBracketRange = svgTag.range(of: ">") {
                let newSvgTag = svgTag.replacingCharacters(in: closingBracketRange, with: transformAttribute + ">")
                return svg.replacingCharacters(in: range, with: newSvgTag)
            }
        }
        
        return svg
    }
    
    private func removePadding(from svg: String, document: VectorDocument) -> String {
        // Calculate content bounds and adjust viewBox to remove padding
        let contentBounds = document.getDocumentBounds()
        let minX = contentBounds.minX
        let minY = contentBounds.minY
        let width = contentBounds.width
        let height = contentBounds.height
        
        // Update viewBox to match content bounds
        if let range = svg.range(of: #"viewBox="[^"]*""#, options: .regularExpression) {
            let newViewBox = "viewBox=\"\(minX) \(minY) \(width) \(height)\""
            return svg.replacingCharacters(in: range, with: newViewBox)
        }
        
        return svg
    }
    
    private func addInkPenText(to svg: String, document: VectorDocument) -> String {
        // Add "Ink Pen" text near the bottom using a marker font
        let contentBounds = document.getDocumentBounds()
        let textX = contentBounds.midX
        let textY = contentBounds.maxY - 20 // 20 points from bottom
        
        let inkPenText = """
        
        <!-- Ink Pen Text -->
        <text x="\(textX)" y="\(textY)" 
              font-family="Marker Felt, Arial, sans-serif" 
              font-size="16" 
              fill="#666666" 
              text-anchor="middle" 
              opacity="0.7">Ink Pen</text>
        """
        
        // Insert before closing </svg> tag
        return svg.replacingOccurrences(of: "</svg>", with: "\(inkPenText)\n</svg>")
    }
    
    private func generateSimpleSVGPreview(for document: VectorDocument) -> String {
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
        let definitions = ""
        
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
    
    // MARK: - Inkpen Preview Generation
    
    /// Generate SVG preview content for Inkpen files
    /// This can be used for QuickLook, file previews, or other preview systems
    func generateInkpenPreview(for document: VectorDocument) -> String {
        // Check if document has any art content
        let hasArtContent = documentHasArtContent(document)
        
        if hasArtContent {
            // Generate full SVG content from the document's art
            return generateSVGPreview(for: document)
        } else {
            // Generate a simple placeholder SVG for empty documents
            return generateEmptyDocumentSVG(for: document)
        }
    }
    
    private func generateEmptyDocumentSVG(for document: VectorDocument) -> String {
        let documentSize = document.settings.sizeInPoints
        let width = documentSize.width
        let height = documentSize.height
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <style>
                    .empty-text { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 24px; fill: #8E8E93; }
                    .empty-icon { fill: #C7C7CC; stroke: #8E8E93; stroke-width: 1; }
                </style>
            </defs>
            
            <!-- Background -->
            <rect width="\(width)" height="\(height)" fill="\(document.settings.backgroundColor.svgColor)"/>
            
            <!-- Empty document icon -->
            <g transform="translate(\(width/2 - 50), \(height/2 - 60))">
                <!-- Document shape -->
                <rect x="0" y="0" width="100" height="120" class="empty-icon" fill="rgba(199,199,204,0.3)"/>
                <!-- Document fold corner -->
                <path d="M 80 0 L 100 20 L 80 20 Z" class="empty-icon" fill="rgba(142,142,147,0.2)"/>
                <!-- Empty text -->
                <text x="50" y="160" text-anchor="middle" class="empty-text">Empty Document</text>
            </g>
        </svg>
        """
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
        case .rgb(let rgbColor):
            return String(format: "#%02X%02X%02X", 
                         Int(rgbColor.red * 255), 
                         Int(rgbColor.green * 255), 
                         Int(rgbColor.blue * 255))
        case .cmyk(let cmykColor):
            // Convert CMYK to RGB for SVG
            let r = (1 - cmykColor.cyan) * (1 - cmykColor.black)
            let g = (1 - cmykColor.magenta) * (1 - cmykColor.black)
            let b = (1 - cmykColor.yellow) * (1 - cmykColor.black)
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        case .hsb(let hsbColor):
            // Convert HSB to RGB for SVG
            let rgb = hsbToRgb(h: hsbColor.hue, s: hsbColor.saturation, b: hsbColor.brightness)
            return String(format: "#%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255))
        case .pantone(let pantoneColor):
            return String(format: "#%02X%02X%02X", 
                         Int(pantoneColor.rgbEquivalent.red * 255), 
                         Int(pantoneColor.rgbEquivalent.green * 255), 
                         Int(pantoneColor.rgbEquivalent.blue * 255))
        case .spot(let spotColor):
            return String(format: "#%02X%02X%02X", 
                         Int(spotColor.rgbEquivalent.red * 255), 
                         Int(spotColor.rgbEquivalent.green * 255), 
                         Int(spotColor.rgbEquivalent.blue * 255))
        case .appleSystem(let systemColor):
            return String(format: "#%02X%02X%02X", 
                         Int(systemColor.rgbEquivalent.red * 255), 
                         Int(systemColor.rgbEquivalent.green * 255), 
                         Int(systemColor.rgbEquivalent.blue * 255))
        case .gradient(let gradient):
            // For gradients, return the first stop color as a fallback
            return gradient.stops.first?.color.svgColor ?? "#000000"
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