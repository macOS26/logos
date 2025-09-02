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
    internal func extractFontFamily(from attributes: [String: String]) -> String? {
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
    internal func normalizeFontFamily(_ rawFamily: String?) -> String {
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
    
    internal func parseFontWeight(from attributes: [String: String]) -> FontWeight {
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
    
    internal func detectTextAlignment(from tspans: [(content: String, attributes: [String: String], x: Double, y: Double)]) -> TextAlignment {
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
}