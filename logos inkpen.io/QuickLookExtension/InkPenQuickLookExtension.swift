//
//  InkPenQuickLookExtension.swift
//  InkPenQuickLookExtension
//
//  QuickLook extension for .inkpen files
//

import Foundation
import QuickLook

class InkPenQuickLookExtension: NSObject, QLPreviewingController {
    
    func providePreview(for request: QLFilePreviewRequest, completionHandler handler: @escaping (QLPreviewReply?, Error?) -> Void) {
        
        // Check if this is an .inkpen file
        guard request.fileURL.pathExtension.lowercased() == "inkpen" else {
            handler(nil, NSError(domain: "InkPenQuickLook", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unsupported file type"]))
            return
        }
        
        do {
            // Load the .inkpen document
            let data = try Data(contentsOf: request.fileURL)
            let decoder = JSONDecoder()
            let document = try decoder.decode(VectorDocument.self, from: data)
            
            // Generate SVG preview
            let svgContent = generateSVGPreview(from: document)
            
            // Create preview reply with SVG content
            let reply = QLPreviewReply(dataOfContentType: UTType.svg, contentSize: CGSize(width: 800, height: 600)) { (reply) -> Data? in
                return svgContent.data(using: .utf8)
            }
            
            handler(reply, nil)
            
        } catch {
            handler(nil, error)
        }
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