//
//  SVGStyleParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/2/25.
//  Extracted from SVGParser.swift for better organization
//

import SwiftUI

extension SVGParser {
    
    // MARK: - Style Parsing Helper Methods
    
    func parseStrokeStyle(_ attributes: [String: String]) -> StrokeStyle? {
        // Check for stroke-width: 0 or 0px first - this means no stroke
        if let strokeWidth = attributes["stroke-width"] {
            let width = parseLength(strokeWidth) ?? 1.0
            if width == 0.0 {
                return nil // No stroke when width is 0
            }
        }
        
        let stroke = attributes["stroke"] ?? "none"
        guard stroke != "none" else { return nil }
        
        // Check for gradient reference: url(#gradientId)
        if stroke.hasPrefix("url(#") && stroke.hasSuffix(")") {
            let gradientId = String(stroke.dropFirst(5).dropLast(1)) // Remove "url(#" and ")"
            
                    if let gradient = gradientDefinitions[gradientId] {
            let width = parseLength(attributes["stroke-width"]) ?? 1.0
            let opacity = parseLength(attributes["stroke-opacity"]) ?? 1.0
            return StrokeStyle(gradient: gradient, width: width, placement: .center, opacity: opacity)
        }
        // Log.error("❌ Gradient reference not found for stroke: \(gradientId)", category: .error)
        // Fallback to black if gradient not found
        let width = parseLength(attributes["stroke-width"]) ?? 1.0
        let opacity = parseLength(attributes["stroke-opacity"]) ?? 1.0
        return StrokeStyle(color: .black, width: width, placement: .center, opacity: opacity)
        }
        
        let color = parseColor(stroke) ?? .black
        let width = parseLength(attributes["stroke-width"]) ?? 1.0
        let opacity = parseLength(attributes["stroke-opacity"]) ?? 1.0
        
        return StrokeStyle(color: color, width: width, placement: .center, opacity: opacity)
    }
    
    func parseFillStyle(_ attributes: [String: String]) -> FillStyle? {
        let fill = attributes["fill"] ?? "black"
        guard fill != "none" else { return nil }
        
        // Check for gradient reference: url(#gradientId)
        if fill.hasPrefix("url(#") && fill.hasSuffix(")") {
            let gradientId = String(fill.dropFirst(5).dropLast(1)) // Remove "url(#" and ")"
            
            if let gradient = gradientDefinitions[gradientId] {
                let opacity = parseLength(attributes["fill-opacity"]) ?? 1.0
                return FillStyle(gradient: gradient, opacity: opacity)
            }
            // Log.error("❌ Gradient reference not found for fill: \(gradientId)", category: .error)
            // Fallback to black if gradient not found
            return FillStyle(color: .black, opacity: parseLength(attributes["fill-opacity"]) ?? 1.0)
        }
        
        let color = parseColor(fill) ?? .black
        let opacity = parseLength(attributes["fill-opacity"]) ?? 1.0
        
        // Parse fill-rule for complex paths
        let fillRule = attributes["fill-rule"] ?? "nonzero"
        
        let fillStyle = FillStyle(color: color, opacity: opacity)
        
        // Handle fill-rule property (critical for complex shapes)
        if fillRule == "evenodd" {
            // Mark this somehow - we'll need to handle this in the path rendering
            // For now, create the fill style but we'll need to modify VectorPath to support this
        }
        
        return fillStyle
    }
    
    func parseColor(_ colorString: String) -> VectorColor? {
        let color = colorString.trimmingCharacters(in: .whitespaces)
        
        if color.hasPrefix("#") {
            // Hex color
            let hex = String(color.dropFirst())
            if hex.count == 6 {
                let r = Double(Int(hex.prefix(2), radix: 16) ?? 0) / 255.0
                let g = Double(Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
                let b = Double(Int(hex.suffix(2), radix: 16) ?? 0) / 255.0
                // SVG colors are always in sRGB, so we need to convert to P3
                return .rgb(convertSRGBToP3(red: r, green: g, blue: b))
            } else if hex.count == 3 {
                // Short hex format #RGB -> #RRGGBB
                let r = Double(Int(String(hex.prefix(1)), radix: 16) ?? 0) / 15.0
                let g = Double(Int(String(hex.dropFirst().prefix(1)), radix: 16) ?? 0) / 15.0
                let b = Double(Int(String(hex.suffix(1)), radix: 16) ?? 0) / 15.0
                // SVG colors are always in sRGB, so we need to convert to P3
                return .rgb(convertSRGBToP3(red: r, green: g, blue: b))
            }
        } else if color.hasPrefix("rgb(") {
            // RGB color
            let content = color.dropFirst(4).dropLast()
            let components = content.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if components.count >= 3 {
                // SVG colors are always in sRGB, so we need to convert to P3
                return .rgb(convertSRGBToP3(red: components[0]/255.0, green: components[1]/255.0, blue: components[2]/255.0))
            }
        } else {
            // Named colors
            switch color.lowercased() {
            case "black": return .black
            case "white": return .white
            case "red": return .rgb(convertSRGBToP3(red: 1, green: 0, blue: 0))
            case "green": return .rgb(convertSRGBToP3(red: 0, green: 1, blue: 0))
            case "blue": return .rgb(convertSRGBToP3(red: 0, green: 0, blue: 1))
            case "yellow": return .rgb(convertSRGBToP3(red: 1, green: 1, blue: 0))
            case "cyan": return .rgb(convertSRGBToP3(red: 0, green: 1, blue: 1))
            case "magenta": return .rgb(convertSRGBToP3(red: 1, green: 0, blue: 1))
            case "orange": return .rgb(convertSRGBToP3(red: 1, green: 0.5, blue: 0))
            case "purple": return .rgb(convertSRGBToP3(red: 0.5, green: 0, blue: 1))
            case "lime": return .rgb(convertSRGBToP3(red: 0, green: 1, blue: 0))
            case "navy": return .rgb(convertSRGBToP3(red: 0, green: 0, blue: 0.5))
            case "teal": return .rgb(convertSRGBToP3(red: 0, green: 0.5, blue: 0.5))
            case "silver": return .rgb(convertSRGBToP3(red: 0.75, green: 0.75, blue: 0.75))
            case "gray", "grey": return .rgb(convertSRGBToP3(red: 0.5, green: 0.5, blue: 0.5))
            case "maroon": return .rgb(convertSRGBToP3(red: 0.5, green: 0, blue: 0))
            case "olive": return .rgb(convertSRGBToP3(red: 0.5, green: 0.5, blue: 0))
            case "aqua": return .rgb(convertSRGBToP3(red: 0, green: 1, blue: 1))
            case "fuchsia": return .rgb(convertSRGBToP3(red: 1, green: 0, blue: 1))
            default: return .black
            }
        }
        
        return nil
    }
    
    /// Convert sRGB color values to Display P3 color space
    private func convertSRGBToP3(red: Double, green: Double, blue: Double, alpha: Double = 1.0) -> RGBColor {
        // Create sRGB CGColor
        let srgbComponents: [CGFloat] = [CGFloat(red), CGFloat(green), CGFloat(blue), CGFloat(alpha)]
        guard let srgbColor = CGColor(colorSpace: ColorManager.shared.sRGBCG, components: srgbComponents) else {
            // Fallback to direct values if conversion fails
            return RGBColor(red: red, green: green, blue: blue, alpha: alpha, colorSpace: .displayP3)
        }

        // Convert to Display P3
        let p3Color = ColorManager.shared.toWorking(srgbColor)

        // Extract P3 components
        if let components = p3Color.components, components.count >= 3 {
            return RGBColor(
                red: Double(components[0]),
                green: Double(components[1]),
                blue: Double(components[2]),
                alpha: components.count > 3 ? Double(components[3]) : alpha,
                colorSpace: .displayP3
            )
        }

        // Fallback to direct values if conversion fails
        return RGBColor(red: red, green: green, blue: blue, alpha: alpha, colorSpace: .displayP3)
    }

    func parseLength(_ value: String?) -> Double? {
        guard let value = value else { return nil }
        
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // Handle "0" or "0px" etc. - all should return 0
        if trimmed == "0" {
            return 0.0
        }
        
        // Remove common SVG units and convert to points
        if trimmed.hasSuffix("px") {
            return Double(String(trimmed.dropLast(2)))
        } else if trimmed.hasSuffix("pt") {
            return Double(String(trimmed.dropLast(2)))
        } else if trimmed.hasSuffix("mm") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 2.834645669  // mm to points
        } else if trimmed.hasSuffix("cm") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 28.346456693 // cm to points
        } else if trimmed.hasSuffix("in") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 72.0         // inches to points
        } else if trimmed.hasSuffix("em") {
            return (Double(String(trimmed.dropLast(2))) ?? 0) * 16.0         // em to points (approximate)
        } else if trimmed.hasSuffix("%") {
            return (Double(String(trimmed.dropLast(1))) ?? 0) / 100.0        // percentage
        } else {
            return Double(trimmed)
        }
    }
}
