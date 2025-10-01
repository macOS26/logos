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
    func exportToSVG(_ document: VectorDocument, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs, includeInkpenData: Bool = false) throws -> String {
        let dpiScale: CGFloat = 1.0  // Standard 72 DPI
        return try exportSVGWithScale(document, dpiScale: dpiScale, isAutoDesk: false, includeBackground: includeBackground, textRenderingMode: textRenderingMode, includeInkpenData: includeInkpenData)
    }

    /// Export document to AutoDesk SVG (96 DPI)
    func exportToAutoDeskSVG(_ document: VectorDocument, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs) throws -> String {
        let dpiScale: CGFloat = 96.0 / 72.0  // Convert to 96 DPI for AutoDesk
        return try exportSVGWithScale(document, dpiScale: dpiScale, isAutoDesk: true, includeBackground: includeBackground, textRenderingMode: textRenderingMode)
    }
    
    /// Core SVG export function with DPI scaling
    private func exportSVGWithScale(_ document: VectorDocument, dpiScale: CGFloat, isAutoDesk: Bool, includeBackground: Bool = true, textRenderingMode: AppState.SVGTextRenderingMode = .glyphs, includeInkpenData: Bool = false) throws -> String {
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

        // Add inkpen metadata if requested
        if includeInkpenData {
            do {
                // Export document to JSON data
                let inkpenData = try FileOperations.exportToJSONData(document)
                // Convert to base64
                let base64String = inkpenData.base64EncodedString()
                // Add metadata element with inkpen namespace
                svg += "<metadata>\n"
                svg += "  <inkpen:document xmlns:inkpen=\"https://inkpen.io/ns\">\n"
                svg += "    \(base64String)\n"
                svg += "  </inkpen:document>\n"
                svg += "</metadata>\n"
                Log.info("📦 Embedded inkpen document in SVG metadata (\(base64String.count) chars)", category: .fileOperations)
            } catch {
                Log.error("⚠️ Failed to embed inkpen data: \(error)", category: .error)
                // Continue without embedding
            }
        }

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
                svg += exportTextShape(shape, dpiScale: 1.0, renderingMode: textRenderingMode)
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

    private func exportTextShape(_ shape: VectorShape, dpiScale: CGFloat, renderingMode: AppState.SVGTextRenderingMode) -> String {
        // Check if this is a text object - use accurate rendering
        guard let vectorText = VectorText.from(shape) else { return "" }

        // Dispatch to appropriate rendering method based on mode
        switch renderingMode {
        case .glyphs:
            return exportTextAsGlyphs(vectorText: vectorText, dpiScale: dpiScale)
        case .lines:
            return exportTextAsLines(vectorText: vectorText, dpiScale: dpiScale)
        }
    }

    /// Export text by individual glyphs (most accurate)
    /// Uses the SAME NSLayoutManager logic as PDF export for precise positioning
    private func exportTextAsGlyphs(vectorText: VectorText, dpiScale: CGFloat) -> String {
        guard !vectorText.content.isEmpty else { return "" }

        // Create the EXACT same NSLayoutManager setup as PDF export
        let nsFont = vectorText.typography.nsFont
        let ctFont = nsFont as CTFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
        paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,
            .kern: vectorText.typography.letterSpacing
        ]

        let attributedString = NSAttributedString(string: vectorText.content, attributes: attributes)

        // Create text storage and layout manager (SAME AS PDF)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // SAME container setup as PDF export
        let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
        let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        // Force complete layout
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: vectorText.content.count))
        layoutManager.ensureLayout(for: textContainer)

        var svg = ""
        var skippedGlyphCount = 0

        // Common text attributes for SVG
        let fillColor = vectorText.typography.fillColor.svgColor
        let fillOpacity = vectorText.typography.fillOpacity

        // Enumerate line fragments (SAME AS PDF)
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in

            // Draw each glyph individually with precise positioning (SAME AS PDF but SVG output)
            for glyphIndex in lineRange.location..<NSMaxRange(lineRange) {
                let glyph = layoutManager.cgGlyph(at: glyphIndex)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

                // CRITICAL FIX: Check if this is a rectangular placeholder glyph (missing character)
                // Same detection as PDF export
                if let glyphPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyph), nil) {
                    if self.isRectangleGlyph(glyphPath) {
                        // Skip this glyph - it's a missing character placeholder
                        skippedGlyphCount += 1
                        continue
                    }
                }

                // Get line fragment rects for this glyph (SAME AS PDF)
                var actualLineRect = CGRect.zero
                var actualUsedRect = CGRect.zero
                var effectiveRange = NSRange()
                actualLineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
                actualUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

                // Calculate glyph X position (SAME AS PDF)
                let glyphX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left, .justified:
                    glyphX = vectorText.position.x + actualUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    glyphX = vectorText.position.x + lineRect.origin.x + glyphLocation.x
                default:
                    glyphX = vectorText.position.x + actualUsedRect.origin.x + glyphLocation.x
                }

                // Calculate glyph Y position (SAME AS PDF)
                let glyphY = vectorText.position.y + actualLineRect.origin.y + glyphLocation.y

                // Get the character for this glyph
                let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
                if charIndex < vectorText.content.count {
                    let char = (vectorText.content as NSString).substring(with: NSRange(location: charIndex, length: 1))
                    let escapedChar = self.escapeXML(char)

                    // Apply DPI scaling
                    let x = glyphX * dpiScale
                    let y = glyphY * dpiScale
                    let fontSize = vectorText.typography.fontSize * dpiScale

                    // Export as individual text element with precise positioning
                    svg += "<text x=\"\(x)\" y=\"\(y)\""
                    svg += " font-family=\"\(vectorText.typography.fontFamily)\""
                    svg += " font-size=\"\(fontSize)\""

                    // Add font weight if not regular
                    if vectorText.typography.fontWeight != .regular {
                        let svgWeight = self.getSVGFontWeight(vectorText.typography.fontWeight)
                        svg += " font-weight=\"\(svgWeight)\""
                    }

                    // Add font style if italic
                    if vectorText.typography.fontStyle == .italic {
                        svg += " font-style=\"italic\""
                    }

                    svg += " fill=\"\(fillColor)\""
                    if fillOpacity != 1.0 {
                        svg += " fill-opacity=\"\(fillOpacity)\""
                    }

                    // Add stroke if present
                    if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                        svg += " stroke=\"\(vectorText.typography.strokeColor.svgColor)\""
                        svg += " stroke-width=\"\(vectorText.typography.strokeWidth * dpiScale)\""
                        if vectorText.typography.strokeOpacity != 1.0 {
                            svg += " stroke-opacity=\"\(vectorText.typography.strokeOpacity)\""
                        }
                    }

                    // Add letter spacing if not zero
                    if vectorText.typography.letterSpacing != 0 {
                        svg += " letter-spacing=\"\(vectorText.typography.letterSpacing * dpiScale)\""
                    }

                    svg += ">\(escapedChar)</text>\n"
                }
            }
        }

        if skippedGlyphCount > 0 {
            Log.info("✅ SVG RECTANGLE DETECTION: Skipped \(skippedGlyphCount) missing character placeholder(s)", category: .fileOperations)
        }

        return svg
    }

    /// Export text by lines using CTLine (better performance)
    private func exportTextAsLines(vectorText: VectorText, dpiScale: CGFloat) -> String {
        guard !vectorText.content.isEmpty else { return "" }

        // Create the EXACT same NSLayoutManager setup as PDF export
        let nsFont = vectorText.typography.nsFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
        paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,
            .kern: vectorText.typography.letterSpacing
        ]

        let attributedString = NSAttributedString(string: vectorText.content, attributes: attributes)

        // Create text storage and layout manager
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // SAME container setup
        let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
        let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        // Force complete layout
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: vectorText.content.count))
        layoutManager.ensureLayout(for: textContainer)

        var svg = ""

        // Common text attributes for SVG
        let fillColor = vectorText.typography.fillColor.svgColor
        let fillOpacity = vectorText.typography.fillOpacity

        // Enumerate line fragments
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            // Get text for this line
            let lineString = (vectorText.content as NSString).substring(with: lineRange)
            let escapedLine = self.escapeXML(lineString)

            // Calculate line position based on alignment
            let lineX: CGFloat
            switch vectorText.typography.alignment.nsTextAlignment {
            case .left, .justified:
                lineX = vectorText.position.x + lineUsedRect.origin.x
            case .center, .right:
                lineX = vectorText.position.x + lineRect.origin.x
            default:
                lineX = vectorText.position.x + lineUsedRect.origin.x
            }

            // Get baseline offset from first glyph in line (SAME AS PDF)
            let firstGlyphIndex = lineRange.location
            let glyphLocation = layoutManager.location(forGlyphAt: firstGlyphIndex)
            let lineY = vectorText.position.y + lineRect.origin.y + glyphLocation.y

            // Apply DPI scaling
            let x = lineX * dpiScale
            let y = lineY * dpiScale
            let fontSize = vectorText.typography.fontSize * dpiScale

            // Export as text element for this line
            svg += "<text x=\"\(x)\" y=\"\(y)\""
            svg += " font-family=\"\(vectorText.typography.fontFamily)\""
            svg += " font-size=\"\(fontSize)\""

            // Add font weight if not regular
            if vectorText.typography.fontWeight != .regular {
                let svgWeight = self.getSVGFontWeight(vectorText.typography.fontWeight)
                svg += " font-weight=\"\(svgWeight)\""
            }

            // Add font style if italic
            if vectorText.typography.fontStyle == .italic {
                svg += " font-style=\"italic\""
            }

            // Add text alignment
            let textAnchor = self.getSVGTextAnchor(vectorText.typography.alignment)
            svg += " text-anchor=\"\(textAnchor)\""

            svg += " fill=\"\(fillColor)\""
            if fillOpacity != 1.0 {
                svg += " fill-opacity=\"\(fillOpacity)\""
            }

            // Add stroke if present
            if vectorText.typography.hasStroke && vectorText.typography.strokeWidth > 0 {
                svg += " stroke=\"\(vectorText.typography.strokeColor.svgColor)\""
                svg += " stroke-width=\"\(vectorText.typography.strokeWidth * dpiScale)\""
                if vectorText.typography.strokeOpacity != 1.0 {
                    svg += " stroke-opacity=\"\(vectorText.typography.strokeOpacity)\""
                }
            }

            // Add letter spacing if not zero
            if vectorText.typography.letterSpacing != 0 {
                svg += " letter-spacing=\"\(vectorText.typography.letterSpacing * dpiScale)\""
            }

            svg += ">\(escapedLine)</text>\n"
        }

        return svg
    }

    /// OLD IMPLEMENTATION - REPLACED BY ACCURATE RENDERING ABOVE
    private func exportTextShape_OLD(_ shape: VectorShape, dpiScale: CGFloat) -> String {
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

    /// Helper method to detect if a glyph path is a rectangle (missing character placeholder)
    /// Same logic as PDF export
    private func isRectangleGlyph(_ path: CGPath) -> Bool {
        // Analyze the path structure
        var subpaths: [[CGPoint]] = []
        var currentPath: [CGPoint] = []
        var hasCurves = false

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                // Start a new subpath
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                }
                currentPath = [element.points[0]]

            case .addLineToPoint:
                // Add line point
                currentPath.append(element.points[0])

            case .addQuadCurveToPoint, .addCurveToPoint:
                // If we have curves, it's not a rectangle
                hasCurves = true

            case .closeSubpath:
                // Close current subpath
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = []
                }

            @unknown default:
                break
            }
        }

        // Add any remaining path
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }

        // Rectangles have no curves
        if hasCurves {
            return false
        }

        // Missing glyph rectangles typically have exactly 2 subpaths (outer and inner)
        if subpaths.count != 2 {
            return false
        }

        // Check if both subpaths are rectangles (4 or 5 points including close)
        for subpath in subpaths {
            if subpath.count < 4 || subpath.count > 5 {
                return false
            }

            // Check if points form a rectangle (all angles are 90 degrees)
            if !isRectangularPath(subpath) {
                return false
            }
        }

        // Check if one rectangle is inside the other (counter pattern)
        let bounds1 = boundingBox(of: subpaths[0])
        let bounds2 = boundingBox(of: subpaths[1])

        let isNested = (bounds1.contains(bounds2) || bounds2.contains(bounds1))

        return isNested
    }

    /// Helper to check if points form a rectangle
    private func isRectangularPath(_ points: [CGPoint]) -> Bool {
        guard points.count >= 4 else { return false }

        // Check that we have mostly horizontal and vertical lines
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]

            let dx = abs(p2.x - p1.x)
            let dy = abs(p2.y - p1.y)

            // Line should be mostly horizontal or vertical
            let isHorizontal = dy < 0.1 && dx > 0.1
            let isVertical = dx < 0.1 && dy > 0.1

            if !isHorizontal && !isVertical {
                return false
            }
        }

        return true
    }

    /// Helper to calculate bounding box of points
    private func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y

        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

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
