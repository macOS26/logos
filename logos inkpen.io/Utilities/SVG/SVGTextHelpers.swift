//
//  SVGTextHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import SwiftUI

extension SVGParser {

    // MARK: - Text Processing Helper Methods

    // PERFORMANCE: Get or create cached NSFont to avoid repeated lookups
    internal func getCachedFont(family: String, size: Double) -> NSFont {
        let cacheKey = "\(family)-\(size)"
        if let cached = fontCache[cacheKey] {
            return cached
        }

        let nsFont = NSFont(name: family, size: size) ?? NSFont.systemFont(ofSize: size)
        fontCache[cacheKey] = nsFont
        return nsFont
    }

    // PERFORMANCE: Calculate text width using shared layout manager (reusable across all text boxes)
    internal func calculateTextWidth(for text: String, font: NSFont, alignment: TextAlignment) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment.nsTextAlignment

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)

        // CRITICAL: Reuse shared components instead of creating new ones
        sharedTextStorage.setAttributedString(attributedString)

        let glyphRange = sharedLayoutManager.glyphRange(for: sharedTextContainer)
        let boundingRect = sharedLayoutManager.boundingRect(forGlyphRange: glyphRange, in: sharedTextContainer)

        return ceil(boundingRect.width)
    }

    // Calculate the width of the longest line in multi-line text
    internal func calculateMaxLineWidth(for text: String, font: NSFont, alignment: TextAlignment) -> CGFloat {
        let lines = text.components(separatedBy: "\n")
        var maxWidth: CGFloat = 0

        for line in lines {
            let lineWidth = calculateTextWidth(for: line, font: font, alignment: alignment)
            maxWidth = max(maxWidth, lineWidth)
        }

        return maxWidth
    }

    // Extract a font-family from either the explicit attribute or inline style
    func extractFontFamily(from attributes: [String: String]) -> String? {
        if let explicit = attributes["font-family"], !explicit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicit
        }
        if let style = attributes["style"], !style.isEmpty {
            // Parse CSS-style declarations: key:value; key:value;
            let pairs = style.split(separator: ";")
            for pair in pairs {
                let parts = pair.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                if parts.count == 2, parts[0].lowercased() == "font-family" {
                    return parts[1]
                }
            }
        }
        return nil
    }

    // Normalize and validate font-family; if none of the candidates are installed, use Helvetica Neue
    func normalizeFontFamily(_ rawFamily: String?) -> String {
        // If not provided, default immediately
        guard let raw = rawFamily?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return "Helvetica Neue"
        }
        // Split by commas to support CSS font-family lists
        let candidates = raw.split(separator: ",").map { token -> String in
            let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
            // Strip single/double quotes
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        }
        let available = Set(NSFontManager.shared.availableFontFamilies.map { $0.lowercased() })
        for name in candidates {
            if available.contains(name.lowercased()) {
                return name
            }
        }
        // Nothing matched; fall back to Helvetica Neue
        return "Helvetica Neue"
    }
    
    // MARK: - SVG Alignment Parsing

    func detectTextAlignment(from tspans: [(content: String, attributes: [String: String], x: Double, y: Double)]) -> TextAlignment {
        guard tspans.count > 1 else { return .left }
        
        // Check for explicit text-anchor attribute
        if let firstTspan = tspans.first,
           let textAnchor = firstTspan.attributes["text-anchor"] {
            switch textAnchor.lowercased() {
            case "start": return .left
            case "middle": return .center
            case "end": return .right
            default: return .left
            }
        }
        
        // Analyze tspan x-coordinates to detect alignment pattern
        let lines = tspans.map { (x: $0.x, contentLength: $0.content.count) }
        
        // Sort by content length (longest first)
        let sortedByLength = lines.sorted { $0.contentLength > $1.contentLength }
        
        // Check center alignment pattern: shorter lines have larger x offsets
        if sortedByLength.count >= 2 {
            let longestLine = sortedByLength[0]
            guard let shortestLine = sortedByLength.last else { return .left }
            
            // Center alignment: shorter text has larger x offset
            if shortestLine.x > longestLine.x {
                let xDifference = abs(shortestLine.x - longestLine.x)
                // Significant difference suggests intentional centering
                if xDifference > 5.0 {
                    return .center
                }
            }
        }
        
        // Check if all x values are similar (left alignment)
        let xValues = lines.map { $0.x }
        let minX = xValues.min() ?? 0
        let maxX = xValues.max() ?? 0
        
        if abs(maxX - minX) < 5.0 {
            return .left
        }
        
        // Default to left alignment
        return .left
    }
    
    // MARK: - Text Element Parsing Methods
    
    func parseText(attributes: [String: String]) {
        currentTextContent = ""
        currentTextSpans.removeAll()
        isInMultiLineText = false
        
        // Merge class-based and inline styles for <text>
        var merged = attributes
        if let classAttr = attributes["class"], !classAttr.isEmpty {
            applyCSSClasses(classAttr, into: &merged)
        }
        if let style = attributes["style"], !style.isEmpty {
            let styleDict = parseStyleAttribute(style)
            for (k, v) in styleDict { merged[k] = v }
        }
        currentTextAttributes = merged
    }
    
    func finishTextElement() {
        // Handle multi-line text with tspan elements
        if isInMultiLineText && !currentTextSpans.isEmpty {
            let baseX = parseLength(currentTextAttributes["x"]) ?? 0
            let baseY = parseLength(currentTextAttributes["y"]) ?? 0
            let textOwnTransform = parseTransform(currentTextAttributes["transform"] ?? "")
            let finalTextTransform = currentTransform.concatenating(textOwnTransform)
            
            // CRITICAL FIX: Create ONE multi-line text object instead of multiple separate objects
            // Combine all tspan content into a single multi-line string
            var combinedContent: [String] = []
            var firstFontSize: Double = 12
            var firstFontFamily: String = "System Font"
            var firstFillColor: VectorColor = .black
            
            for (index, span) in currentTextSpans.enumerated() {
                let cleanContent = span.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanContent.isEmpty else { continue }
                
                // Use typography from the first non-empty tspan
                if index == 0 || (combinedContent.isEmpty) {
                    firstFontSize = parseLength(span.attributes["font-size"]) ?? 12
                    let rawFontFamily = extractFontFamily(from: span.attributes)
                    firstFontFamily = normalizeFontFamily(rawFontFamily)
                    let fill = span.attributes["fill"] ?? "black"
                    firstFillColor = parseColor(fill) ?? .black
                }
                
                combinedContent.append(cleanContent)
            }
            
            // Create a single multi-line text object
            if !combinedContent.isEmpty {
                let multiLineContent = combinedContent.joined(separator: "\n")

                // Parse alignment from the first tspan or CSS
                let textAlignment = detectTextAlignment(from: currentTextSpans)

                // Calculate line height as fontSize * 1.2
                let lineHeight = firstFontSize * 1.2

                let typography = TypographyProperties(
                    fontFamily: firstFontFamily,
                    fontSize: firstFontSize,
                    lineHeight: lineHeight,
                    lineSpacing: 0.0,
                    letterSpacing: 0.0,
                    alignment: textAlignment,
                    hasStroke: false,
                    strokeColor: .black,
                    strokeWidth: 0.0,
                    strokeOpacity: 1.0,
                    fillColor: firstFillColor,
                    fillOpacity: 1.0
                )

                // CRITICAL FIX: Adjust X position based on text-anchor for multi-line text
                // Check text-anchor from parent <text> element or first tspan
                let textAnchor = currentTextAttributes["text-anchor"]?.lowercased() ??
                                 currentTextSpans.first?.attributes["text-anchor"]?.lowercased() ??
                                 "start"
                var adjustedX = baseX

                if textAnchor == "middle" || textAnchor == "end" {
                    // PERFORMANCE: Use cached font and shared layout manager
                    let nsFont = getCachedFont(family: firstFontFamily, size: firstFontSize)
                    let maxLineWidth = calculateMaxLineWidth(for: multiLineContent, font: nsFont, alignment: textAlignment)

                    // Adjust x position based on anchor and widest line
                    if textAnchor == "middle" {
                        adjustedX -= maxLineWidth / 2.0
                    } else if textAnchor == "end" {
                        adjustedX -= maxLineWidth
                    }
                }

                // PERFORMANCE: Calculate ACTUAL text width using cached components (widest line + 2 characters)
                let nsFont = getCachedFont(family: firstFontFamily, size: firstFontSize)
                let maxLineWidth = calculateMaxLineWidth(for: multiLineContent, font: nsFont, alignment: textAlignment)

                // CRITICAL: Check if we have a text box bounds rect from parent group
                let actualWidth: CGFloat
                if let pendingRect = pendingTextBoxRect, pendingRect.width > 0 {
                    // Use the invisible rect's width as the text box width
                    actualWidth = pendingRect.width
                    pendingTextBoxRect = nil  // Clear after use
                } else {
                    // Fallback: Add width of 2 characters to prevent word wrapping
                    let twoCharWidth = calculateTextWidth(for: "  ", font: nsFont, alignment: textAlignment)
                    actualWidth = maxLineWidth + twoCharWidth
                }

                // Track maximum width across all text objects
                maxTextWidth = max(maxTextWidth, actualWidth)
                // Use lineHeight for height to accommodate descenders
                let actualHeight = lineHeight


                // CRITICAL FIX: SVG Y position is at text BASELINE
                // Adjust Y to account for line height: Y - (lineHeight - fontSize)
                let finalY = baseY - (firstFontSize)

                var textObject = VectorText(
                    content: multiLineContent,
                    typography: typography,
                    position: CGPoint(x: adjustedX, y: finalY),
                    transform: finalTextTransform,
                    areaSize: CGSize(width: actualWidth, height: actualHeight)
                )

                // Set bounds explicitly using actual dimensions
                textObject.bounds = CGRect(
                    x: adjustedX,
                    y: finalY,
                    width: actualWidth,
                    height: actualHeight
                )

                textObjects.append(textObject)
            }
        } else {
            // Handle single-line text
            guard !currentTextContent.isEmpty else { return }
            
            let x = parseLength(currentTextAttributes["x"]) ?? 0
            let y = parseLength(currentTextAttributes["y"]) ?? 0
            let fontSize = parseLength(currentTextAttributes["font-size"]) ?? 12
            let rawFontFamily = extractFontFamily(from: currentTextAttributes)
            let fontFamily = normalizeFontFamily(rawFontFamily)
            let fill = currentTextAttributes["fill"] ?? "black"
            let textOwnTransform = parseTransform(currentTextAttributes["transform"] ?? "")
            let finalTextTransform = currentTransform.concatenating(textOwnTransform)
            
            // Parse alignment for single-line text
            let textAlignment: TextAlignment
            let textAnchor = currentTextAttributes["text-anchor"]?.lowercased() ?? "start"
            switch textAnchor {
            case "start": textAlignment = .left
            case "middle": textAlignment = .center
            case "end": textAlignment = .right
            default: textAlignment = .left
            }

            // Calculate line height as fontSize * 1.2
            let lineHeight = fontSize * 1.2

            let typography = TypographyProperties(
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineHeight: lineHeight,
                lineSpacing: 0.0,
                letterSpacing: 0.0,
                alignment: textAlignment,
                hasStroke: false,
                strokeColor: .black,
                strokeWidth: 0.0,
                strokeOpacity: 1.0,
                fillColor: parseColor(fill) ?? .black,
                fillOpacity: 1.0
            )

            // CRITICAL FIX: Adjust X position based on text-anchor
            // SVG text-anchor uses the x position as:
            // - "start": x is at the left edge (our internal format)
            // - "middle": x is at the center - we need to subtract half the text width
            // - "end": x is at the right edge - we need to subtract the full text width
            let trimmedContent = currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines)

            // PERFORMANCE: Calculate text width once using cached components
            let nsFont = getCachedFont(family: fontFamily, size: fontSize)
            let textWidth = calculateTextWidth(for: trimmedContent, font: nsFont, alignment: textAlignment)

            // CRITICAL: Check if we have a text box bounds rect from parent group
            let actualWidth: CGFloat
            if let pendingRect = pendingTextBoxRect, pendingRect.width > 0 {
                // Use the invisible rect's width as the text box width
                actualWidth = pendingRect.width
                pendingTextBoxRect = nil  // Clear after use
            } else {
                // Fallback: Add width of 2 characters to prevent word wrapping
                let twoCharWidth = calculateTextWidth(for: "  ", font: nsFont, alignment: textAlignment)
                actualWidth = textWidth + twoCharWidth
            }

            // Track maximum width across all text objects
            maxTextWidth = max(maxTextWidth, actualWidth)

            var adjustedX = x
            if textAnchor == "middle" || textAnchor == "end" {
                // Adjust x position based on anchor (use text width, not padded width)
                if textAnchor == "middle" {
                    adjustedX -= textWidth / 2.0
                } else if textAnchor == "end" {
                    adjustedX -= textWidth
                }
            }

            // Use lineHeight for height to accommodate descenders
            let actualHeight = lineHeight

            // CRITICAL FIX: SVG Y position is at text BASELINE
            // Adjust Y to account for line height: Y - (lineHeight - fontSize)
            let finalY = y - (fontSize)

            var textObject = VectorText(
                content: trimmedContent,
                typography: typography,
                position: CGPoint(x: adjustedX, y: finalY),
                transform: finalTextTransform,
                areaSize: CGSize(width: actualWidth, height: actualHeight)
            )

            // Set bounds explicitly using actual dimensions
            textObject.bounds = CGRect(
                x: adjustedX,
                y: finalY,
                width: actualWidth,
                height: actualHeight
            )

            textObjects.append(textObject)
        }
        
        // Reset state
        currentTextContent = ""
        currentTextAttributes = [:]
        currentTextSpans.removeAll()
        isInMultiLineText = false
    }
}
