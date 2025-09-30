//
//  SVGExporter.swift
//  logos inkpen.io
//
//  Created by Claude on 9/10/25.
//

import SwiftUI

/// Professional SVG Exporter that generates clean, compliant SVG files
class SVGExporter {
    
    static let shared = SVGExporter()
    
    private init() {}
    
    /// Export document to standard SVG (72 DPI)
    func exportToSVG(_ document: VectorDocument, includeBackground: Bool = true) throws -> String {
        let dpiScale: CGFloat = 1.0  // Standard 72 DPI
        return try exportSVGWithScale(document, dpiScale: dpiScale, isAutoDesk: false, includeBackground: includeBackground)
    }
    
    /// Export document to AutoDesk SVG (96 DPI)
    func exportToAutoDeskSVG(_ document: VectorDocument, includeBackground: Bool = true) throws -> String {
        let dpiScale: CGFloat = 96.0 / 72.0  // Convert to 96 DPI for AutoDesk
        return try exportSVGWithScale(document, dpiScale: dpiScale, isAutoDesk: true, includeBackground: includeBackground)
    }
    
    /// Core SVG export function with DPI scaling
    private func exportSVGWithScale(_ document: VectorDocument, dpiScale: CGFloat, isAutoDesk: Bool, includeBackground: Bool = true) throws -> String {
        // Get document dimensions in points (72 DPI)
        let originalSize = document.settings.sizeInPoints
        
        // For AutoDesk: We need to declare the SVG as 96 DPI
        // This means the width/height attributes represent pixels at 96 DPI
        // But the viewBox coordinates remain in 72 DPI space
        // AutoDesk will interpret 1 pixel = 1/96 inch
        let scaledWidth = originalSize.width * dpiScale
        let scaledHeight = originalSize.height * dpiScale
        
        // ViewBox stays in original 72 DPI coordinate space
        // This ensures all path coordinates remain unchanged
        let viewBoxWidth = originalSize.width
        let viewBoxHeight = originalSize.height
        
        // Start building SVG content
        // Width/height in pixels at target DPI, viewBox in 72 DPI coordinates
        // Add px units for AutoDesk to make it explicit these are pixel values
        // Format as integers when they're whole numbers to avoid ".0"
        let widthStr = formatSVGNumber(scaledWidth)
        let heightStr = formatSVGNumber(scaledHeight)
        let viewBoxWidthStr = formatSVGNumber(viewBoxWidth)
        let viewBoxHeightStr = formatSVGNumber(viewBoxHeight)
        
        let widthAttr = isAutoDesk ? "\(widthStr)px" : widthStr
        let heightAttr = isAutoDesk ? "\(heightStr)px" : heightStr
        
        var svg = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(widthAttr)" height="\(heightAttr)" viewBox="0 0 \(viewBoxWidthStr) \(viewBoxHeightStr)"
             version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink"
             style="background-color: transparent;">
        """
        
        // Add defs section for gradients, patterns, and clipping paths
        svg += "\n<defs>\n"
        svg += generateGradientDefs(from: document) // No scaling in defs
        svg += generateClipPathDefs(from: document) // Add clipping path definitions
        svg += "</defs>\n"
        
        // No transform needed - viewBox and width/height handle the scaling
        
        // Export layers
        for (layerIndex, layer) in document.layers.enumerated() {
            if !layer.isVisible { continue }
            // ALWAYS skip Pasteboard - it's never exported
            if layer.name == "Pasteboard" { continue }
            // Skip Canvas layer if not including background
            if !includeBackground && layer.name == "Canvas" {
                Log.info("📋 SVG EXPORT: Skipping Canvas layer (includeBackground=false)", category: .fileOperations)
                continue
            }

            Log.info("📋 SVG EXPORT: Including layer '\(layer.name)' (includeBackground=\(includeBackground))", category: .fileOperations)
            svg += "<!-- Layer: \(layer.name) -->\n"
            svg += "<g id=\"layer_\(layerIndex)\" opacity=\"\(layer.opacity)\">\n"
            
            // Export shapes in this layer
            let shapesInLayer = document.getShapesForLayer(layerIndex)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                svg += exportShape(shape, dpiScale: 1.0)
            }
            
            svg += "</g>\n"
        }
        
        // Export text objects
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               shape.isTextObject && shape.isVisible {
                // Skip text objects on Pasteboard (always) or Canvas (if not including background)
                let layer = document.layers[safe: unifiedObject.layerIndex]
                if layer?.name == "Pasteboard" {
                    continue // ALWAYS skip Pasteboard
                }
                if !includeBackground && layer?.name == "Canvas" {
                    continue // Skip Canvas only if not including background
                }
                svg += exportTextShape(shape, dpiScale: 1.0)
            }
        }
        
        // Close SVG
        svg += "</svg>"
        
        return svg
    }
    
    // MARK: - Shape Export
    
    private func exportShape(_ shape: VectorShape, dpiScale: CGFloat) -> String {
        var svg = ""

        // Skip clipping path shapes as they're handled in defs
        if shape.isClippingPath {
            return ""
        }

        // Check if this is a group
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            svg += "<g id=\"group_\(shape.id.uuidString)\">\n"

            // Export each shape in the group
            for groupedShape in shape.groupedShapes {
                svg += exportShape(groupedShape, dpiScale: dpiScale)
            }

            svg += "</g>\n"
            return svg
        }

        // Check if this is an image
        if let image = ImageContentRegistry.image(for: shape.id) ??
                       ImageContentRegistry.hydrateImageIfAvailable(for: shape) {
            return exportImageShape(shape, image: image, dpiScale: dpiScale)
        }

        // Export as path
        let pathData = generatePathData(from: shape.path, transform: shape.transform)

        svg += "<path d=\"\(pathData)\""
        
        // Add clip-path reference if this shape is clipped
        if let clipId = shape.clippedByShapeID {
            svg += " clip-path=\"url(#clip_\(clipId.uuidString))\""
        }
        
        // Add fill
        if let fillStyle = shape.fillStyle {
            if case .gradient(let gradient) = fillStyle.color {
                svg += " fill=\"url(#gradient_\(gradient.hashValue))\""
            } else {
                svg += " fill=\"\(fillStyle.color.svgColor)\""
            }
            if fillStyle.opacity != 1.0 {
                svg += " fill-opacity=\"\(fillStyle.opacity)\""
            }
        } else {
            svg += " fill=\"none\""
        }
        
        // Add stroke
        if let strokeStyle = shape.strokeStyle {
            if case .gradient(let gradient) = strokeStyle.color {
                svg += " stroke=\"url(#gradient_\(gradient.hashValue))\""
            } else {
                svg += " stroke=\"\(strokeStyle.color.svgColor)\""
            }
            svg += " stroke-width=\"\(strokeStyle.width)\""
            if strokeStyle.opacity != 1.0 {
                svg += " stroke-opacity=\"\(strokeStyle.opacity)\""
            }
        }
        
        svg += "/>\n"
        
        return svg
    }
    
    // MARK: - Text Export
    
    private func exportTextShape(_ shape: VectorShape, dpiScale: CGFloat) -> String {
        guard let textContent = shape.textContent,
              let typography = shape.typography else { return "" }

        var svg = ""

        // Check if this is area text (text with a box)
        if let areaSize = shape.areaSize, areaSize.width > 0, areaSize.height > 0 {
            // Export text box as a rectangle and position text inside

            // Get the text box position
            let boxPosition: CGPoint
            if shape.transform != .identity {
                boxPosition = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            } else if let textPos = shape.textPosition {
                boxPosition = textPos
            } else {
                boxPosition = CGPoint(x: shape.bounds.minX, y: shape.bounds.minY)
            }

            // Apply DPI scaling to box dimensions
            let boxX = boxPosition.x * dpiScale
            let boxY = boxPosition.y * dpiScale
            let boxWidth = areaSize.width * dpiScale
            let boxHeight = areaSize.height * dpiScale

            // Export the text box as a rectangle with stroke and no fill
            svg += "<rect x=\"\(boxX)\" y=\"\(boxY)\" width=\"\(boxWidth)\" height=\"\(boxHeight)\""
            svg += " fill=\"none\" stroke=\"#808080\" stroke-width=\"1\"/>\n"

            // Calculate text position inside the box
            let fontSize = typography.fontSize * dpiScale

            // For center alignment, position text at center of box
            var textX: CGFloat
            switch typography.alignment {
            case .center:
                textX = boxX + (boxWidth / 2)
            case .right:
                textX = boxX + boxWidth - 20
            default: // .left
                textX = boxX + 20
            }

            // Position text vertically centered in the box
            // SVG y coordinate is the baseline, so we need to account for that
            let textY = boxY + (boxHeight / 2) + (fontSize / 3)

            // Export the text element
            svg += "<text x=\"\(textX)\" y=\"\(textY)\""
            svg += " font-family=\"\(typography.fontFamily)\""
            svg += " font-size=\"\(fontSize)\""

            // Add font weight if not regular
            if typography.fontWeight != .regular {
                let svgWeight = getSVGFontWeight(typography.fontWeight)
                svg += " font-weight=\"\(svgWeight)\""
            }

            // Add font style if italic
            if typography.fontStyle == .italic {
                svg += " font-style=\"italic\""
            }

            // Add text alignment
            let textAnchor = getSVGTextAnchor(typography.alignment)
            svg += " text-anchor=\"\(textAnchor)\""

            // Add dominant baseline for consistent vertical alignment
            svg += " dominant-baseline=\"alphabetic\""

            // Add fill color
            svg += " fill=\"\(typography.fillColor.svgColor)\""

            if typography.fillOpacity != 1.0 {
                svg += " fill-opacity=\"\(typography.fillOpacity)\""
            }

            // Add stroke if present
            if typography.hasStroke && typography.strokeWidth > 0 {
                svg += " stroke=\"\(typography.strokeColor.svgColor)\""
                svg += " stroke-width=\"\(typography.strokeWidth * dpiScale)\""
                if typography.strokeOpacity != 1.0 {
                    svg += " stroke-opacity=\"\(typography.strokeOpacity)\""
                }
            }

            // Add letter spacing if not zero
            if typography.letterSpacing != 0 {
                svg += " letter-spacing=\"\(typography.letterSpacing * dpiScale)\""
            }

            svg += ">\(escapeXML(textContent))</text>\n"

        } else {
            // Point text (no box) - use original positioning logic
            let position: CGPoint

            // First check if we have bounds with a transform
            if shape.transform != .identity {
                // If there's a transform, use it for positioning
                position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
            } else if let textPos = shape.textPosition {
                // Use the original text position if available
                position = textPos
            } else {
                // Fallback to bounds center for better default positioning
                // This helps when text doesn't have explicit position set
                position = CGPoint(
                    x: shape.bounds.midX,
                    y: shape.bounds.midY
                )
            }

            // Apply DPI scaling
            let x = position.x * dpiScale

            // REVERT TO CORRECT BASELINE: Add font size to y for SVG baseline positioning
            // In SVG, y coordinate is the baseline where text sits
            // We need to add fontSize to convert from top-left to baseline
            let fontSize = typography.fontSize * dpiScale
            let y = (position.y + fontSize) * dpiScale

            svg = "<text x=\"\(x)\" y=\"\(y)\""
            svg += " font-family=\"\(typography.fontFamily)\""
            svg += " font-size=\"\(fontSize)\""

            // Add font weight if not regular
            if typography.fontWeight != .regular {
                let svgWeight = getSVGFontWeight(typography.fontWeight)
                svg += " font-weight=\"\(svgWeight)\""
            }

            // Add font style if italic
            if typography.fontStyle == .italic {
                svg += " font-style=\"italic\""
            }

            // Add text alignment
            let textAnchor = getSVGTextAnchor(typography.alignment)
            svg += " text-anchor=\"\(textAnchor)\""

            // Add dominant baseline for consistent vertical alignment
            svg += " dominant-baseline=\"alphabetic\""

            // Add fill color
            svg += " fill=\"\(typography.fillColor.svgColor)\""

            if typography.fillOpacity != 1.0 {
                svg += " fill-opacity=\"\(typography.fillOpacity)\""
            }

            // Add stroke if present
            if typography.hasStroke && typography.strokeWidth > 0 {
                svg += " stroke=\"\(typography.strokeColor.svgColor)\""
                svg += " stroke-width=\"\(typography.strokeWidth * dpiScale)\""
                if typography.strokeOpacity != 1.0 {
                    svg += " stroke-opacity=\"\(typography.strokeOpacity)\""
                }
            }

            // Add letter spacing if not zero
            if typography.letterSpacing != 0 {
                svg += " letter-spacing=\"\(typography.letterSpacing * dpiScale)\""
            }

            svg += ">\(escapeXML(textContent))</text>\n"
        }

        return svg
    }
    
    // MARK: - Helper Methods for Text Export
    
    private func getSVGFontWeight(_ weight: FontWeight) -> String {
        switch weight {
        case .thin: return "100"
        case .ultraLight: return "200"
        case .light: return "300"
        case .regular: return "400"
        case .medium: return "500"
        case .semibold: return "600"
        case .bold: return "700"
        case .heavy: return "800"
        case .black: return "900"
        }
    }
    
    private func getSVGTextAnchor(_ alignment: TextAlignment) -> String {
        switch alignment {
        case .left: return "start"
        case .center: return "middle"
        case .right: return "end"
        case .justified: return "start"  // SVG doesn't support justified, use start
        }
    }
    
    // MARK: - Image Export
    
    private func exportImageShape(_ shape: VectorShape, image: NSImage, dpiScale: CGFloat) -> String {
        // CRITICAL FIX: Apply the shape's transform to get the correct position
        // The shape.bounds is the untransformed bounds, but we need the transformed position
        let transformedBounds: CGRect
        if shape.transform != .identity {
            // Apply the transform to the bounds to get the actual position
            transformedBounds = shape.bounds.applying(shape.transform)
        } else {
            transformedBounds = shape.bounds
        }
        
        // Apply dpi scaling to the transformed bounds
        let x = transformedBounds.minX * dpiScale
        let y = transformedBounds.minY * dpiScale
        let width = transformedBounds.width * dpiScale
        let height = transformedBounds.height * dpiScale
        
        var href: String
        
        // Check if shape has embedded image data
        if let embeddedData = shape.embeddedImageData {
            // Use the embedded data directly
            href = "data:image/png;base64,\(embeddedData.base64EncodedString())"
        } else if let linkedPath = shape.linkedImagePath {
            // Use the linked path
            href = linkedPath
        } else {
            // Convert current image to base64
            guard let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                return ""
            }
            let base64 = pngData.base64EncodedString()
            href = "data:image/png;base64,\(base64)"
        }
        
        var svg = ""
        
        // If the image is clipped, wrap it in a group with the clip-path applied to the group
        // This matches Adobe Illustrator's approach and ensures proper alignment
        if let clipId = shape.clippedByShapeID {
            // Use a group element with the clip-path applied
            svg += "<g clip-path=\"url(#clip_\(clipId.uuidString))\">\n"
            svg += "  <image x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" xlink:href=\"\(href)\" preserveAspectRatio=\"none\"/>\n"
            svg += "</g>\n"
        } else {
            // No clipping - export image directly
            svg += "<image x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" xlink:href=\"\(href)\" preserveAspectRatio=\"none\"/>\n"
        }
        
        return svg
    }
    
    // MARK: - Path Generation
    
    private func generatePathData(from path: VectorPath, transform: CGAffineTransform) -> String {
        var pathData = ""
        
        for element in path.elements {
            switch element {
            case .move(let to):
                let point = to.cgPoint.applying(transform)
                pathData += "M\(point.x),\(point.y) "
                
            case .line(let to):
                let point = to.cgPoint.applying(transform)
                pathData += "L\(point.x),\(point.y) "
                
            case .curve(let to, let control1, let control2):
                let toPoint = to.cgPoint.applying(transform)
                let c1 = control1.cgPoint.applying(transform)
                let c2 = control2.cgPoint.applying(transform)
                pathData += "C\(c1.x),\(c1.y) \(c2.x),\(c2.y) \(toPoint.x),\(toPoint.y) "
                
            case .quadCurve(let to, let control):
                let toPoint = to.cgPoint.applying(transform)
                let c = control.cgPoint.applying(transform)
                pathData += "Q\(c.x),\(c.y) \(toPoint.x),\(toPoint.y) "
                
            case .close:
                pathData += "Z "
            }
        }
        
        return pathData.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Gradient Definitions
    
    private func generateGradientDefs(from document: VectorDocument) -> String {
        var defs = ""
        var processedGradients = Set<Int>()
        
        // Collect all unique gradients
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                // Check fill gradient
                if let fillStyle = shape.fillStyle,
                   case .gradient(let gradient) = fillStyle.color {
                    let hash = gradient.hashValue
                    if !processedGradients.contains(hash) {
                        processedGradients.insert(hash)
                        defs += generateGradientDef(gradient, id: "gradient_\(hash)")
                    }
                }
                
                // Check stroke gradient
                if let strokeStyle = shape.strokeStyle,
                   case .gradient(let gradient) = strokeStyle.color {
                    let hash = gradient.hashValue
                    if !processedGradients.contains(hash) {
                        processedGradients.insert(hash)
                        defs += generateGradientDef(gradient, id: "gradient_\(hash)")
                    }
                }
            }
        }
        
        return defs
    }
    
    private func generateClipPathDefs(from document: VectorDocument) -> String {
        var defs = ""
        var processedClipPaths = Set<UUID>()
        
        // Collect all clipping paths
        for unifiedObject in document.unifiedObjects {
            if case .shape(let clipShape) = unifiedObject.objectType {
                // Check if this shape is a clipping path
                if clipShape.isClippingPath && !processedClipPaths.contains(clipShape.id) {
                    processedClipPaths.insert(clipShape.id)
                    
                    // CRITICAL: Always apply the clip shape's transform to ensure proper positioning
                    // The clip path must be in the same coordinate space as the elements it clips
                    let pathData = generatePathData(from: clipShape.path, transform: clipShape.transform)
                    
                    // Use clipPathUnits="userSpaceOnUse" for absolute coordinates in document space
                    defs += "<clipPath id=\"clip_\(clipShape.id.uuidString)\" clipPathUnits=\"userSpaceOnUse\">\n"
                    defs += "  <path d=\"\(pathData)\"/>\n"
                    defs += "</clipPath>\n"
                }
            }
        }
        
        return defs
    }
    
    private func generateGradientDef(_ gradient: VectorGradient, id: String) -> String {
        switch gradient {
        case .linear(let linearGradient):
            return generateLinearGradientDef(linearGradient, id: id)
        case .radial(let radialGradient):
            return generateRadialGradientDef(radialGradient, id: id)
        }
    }
    
    private func generateLinearGradientDef(_ gradient: LinearGradient, id: String) -> String {
        var svg = "<linearGradient id=\"\(id)\""
        
        // Calculate gradient vector from angle
        let angle = gradient.angle * .pi / 180
        let x1 = 0.5 - cos(angle) * 0.5
        let y1 = 0.5 - sin(angle) * 0.5
        let x2 = 0.5 + cos(angle) * 0.5
        let y2 = 0.5 + sin(angle) * 0.5
        
        svg += " x1=\"\(x1 * 100)%\" y1=\"\(y1 * 100)%\""
        svg += " x2=\"\(x2 * 100)%\" y2=\"\(y2 * 100)%\">\n"
        
        // Add stops
        for stop in gradient.stops {
            svg += "<stop offset=\"\(stop.position * 100)%\" stop-color=\"\(stop.color.svgColor)\"/>\n"
        }
        
        svg += "</linearGradient>\n"
        
        return svg
    }
    
    private func generateRadialGradientDef(_ gradient: RadialGradient, id: String) -> String {
        var svg = "<radialGradient id=\"\(id)\""
        svg += " cx=\"50%\" cy=\"50%\" r=\"50%\">\n"
        
        // Add stops
        for stop in gradient.stops {
            svg += "<stop offset=\"\(stop.position * 100)%\" stop-color=\"\(stop.color.svgColor)\"/>\n"
        }
        
        svg += "</radialGradient>\n"
        
        return svg
    }
    
    // MARK: - Utilities
    
    /// Format numbers for SVG - use integers when possible to avoid ".0"
    private func formatSVGNumber(_ value: CGFloat) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    private func escapeXML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}

// Note: VectorColor.svgColor extension already exists in the codebase
