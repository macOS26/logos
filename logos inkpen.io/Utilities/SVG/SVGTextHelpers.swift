//
//  SVGTextHelpers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import Foundation
import AppKit

extension SVGParser {
    
    // MARK: - Text Processing Helper Methods
    
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
        Log.fileOperation("⚠️ Font not found in system: \(raw). Falling back to Helvetica Neue.", level: .info)
        return "Helvetica Neue"
    }
    
    // MARK: - SVG Font Weight and Alignment Parsing
    
    func parseFontWeight(from attributes: [String: String]) -> FontWeight {
        // Check explicit font-weight attribute first
        if let weightValue = attributes["font-weight"] {
            switch weightValue.lowercased() {
            case "100": return .thin
            case "200": return .ultraLight
            case "300": return .light
            case "400", "normal": return .regular
            case "500": return .medium
            case "600": return .semibold
            case "700", "bold": return .bold
            case "800": return .heavy  // CRITICAL FIX: 800 maps to Heavy
            case "900", "black": return .black
            case "thin": return .thin
            case "ultralight": return .ultraLight
            case "light": return .light
            case "regular": return .regular
            case "medium": return .medium
            case "semibold": return .semibold
            case "heavy": return .heavy
            default: return .regular
            }
        }
        
        // Check font-family for embedded weight (e.g., "Avenir-Heavy")
        if let fontFamily = attributes["font-family"] {
            let lowerFamily = fontFamily.lowercased()
            if lowerFamily.contains("-heavy") || lowerFamily.contains(" heavy") {
                return .heavy
            } else if lowerFamily.contains("-bold") || lowerFamily.contains(" bold") {
                return .bold
            } else if lowerFamily.contains("-medium") || lowerFamily.contains(" medium") {
                return .medium
            } else if lowerFamily.contains("-light") || lowerFamily.contains(" light") {
                return .light
            }
        }
        
        return .regular  // Default
    }
    
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
            let shortestLine = sortedByLength.last!
            
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
        Log.fileOperation("🔤 Starting text element parsing", level: .info)
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
                
                // Parse font weight and alignment from the first tspan or CSS
                let fontWeight = parseFontWeight(from: currentTextSpans.first?.attributes ?? currentTextAttributes)
                let textAlignment = detectTextAlignment(from: currentTextSpans)
                
                let typography = TypographyProperties(
                    fontFamily: firstFontFamily,
                    fontWeight: fontWeight,  // FIXED: Use parsed font weight
                    fontStyle: .normal,
                    fontSize: firstFontSize,
                    lineHeight: firstFontSize * 1.2, // Standard line spacing
                    lineSpacing: 0.0,
                    letterSpacing: 0.0,
                    alignment: textAlignment,  // FIXED: Use detected alignment
                    hasStroke: false,
                    strokeColor: .black,
                    strokeWidth: 0.0,
                    strokeOpacity: 1.0,
                    fillColor: firstFillColor,
                    fillOpacity: 1.0
                )
                
                let textObject = VectorText(
                    content: multiLineContent,
                    typography: typography,
                    position: CGPoint(x: baseX, y: baseY),
                    transform: finalTextTransform,
                    isPointText: false,  // This is area text (multi-line)
                    areaSize: nil        // Will be calculated automatically
                )
                
                textObjects.append(textObject)
                Log.fileOperation("📝 Created single multi-line text object with \(combinedContent.count) lines: '\(multiLineContent.prefix(50))'", level: .info)
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
            
            // Parse font weight and alignment for single-line text
            let fontWeight = parseFontWeight(from: currentTextAttributes)
            let textAlignment = TextAlignment.left  // Single line defaults to left
            
            let typography = TypographyProperties(
                fontFamily: fontFamily,
                fontWeight: fontWeight,  // FIXED: Use parsed font weight
                fontStyle: .normal,
                fontSize: fontSize,
                lineHeight: fontSize,
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
            
            let textObject = VectorText(
                content: currentTextContent.trimmingCharacters(in: .whitespacesAndNewlines),
                typography: typography,
                position: CGPoint(x: x, y: y),
                transform: finalTextTransform
            )
            
            textObjects.append(textObject)
            Log.fileOperation("📝 Created single-line text object: '\(textObject.content)'", level: .info)
        }
        
        // Reset state
        currentTextContent = ""
        currentTextAttributes = [:]
        currentTextSpans.removeAll()
        isInMultiLineText = false
    }
}