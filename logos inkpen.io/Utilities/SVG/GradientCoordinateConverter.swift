import SwiftUI

// MARK: - Gradient Coordinate Converter
/// Utility for converting radial gradient coordinates between coordinate systems
struct GradientCoordinateConverter {
    
    // MARK: - Coordinate System Types
    enum CoordinateSystem: String {
        case objectBoundingBox = "objectBoundingBox"
        case userSpaceOnUse = "userSpaceOnUse"
    }
    
    // MARK: - Gradient Data Structures
    struct RadialGradient {
        let id: String
        let coordinateSystem: CoordinateSystem
        let cx: Double
        let cy: Double
        let r: Double
        let fx: Double?
        let fy: Double?
        let stops: [GradientStop]
    }
    
    struct GradientStop {
        let offset: Double // 0.0 to 1.0
        let color: String
    }
    
    struct BoundingBox {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
    
    // MARK: - Conversion Methods
    
    /// Convert from objectBoundingBox to userSpaceOnUse coordinates
    static func convertBoundingBoxToUserSpace(
        gradient: RadialGradient,
        boundingBox: BoundingBox
    ) -> RadialGradient {
        guard gradient.coordinateSystem == .objectBoundingBox else {
            return gradient
        }
        
        let newCx = boundingBox.x + (gradient.cx * boundingBox.width)
        let newCy = boundingBox.y + (gradient.cy * boundingBox.height)
        let newR = gradient.r * min(boundingBox.width, boundingBox.height)
        
        let newFx: Double?
        let newFy: Double?
        
        if let fx = gradient.fx, let fy = gradient.fy {
            newFx = boundingBox.x + (fx * boundingBox.width)
            newFy = boundingBox.y + (fy * boundingBox.height)
        } else {
            newFx = nil
            newFy = nil
        }
        
        return RadialGradient(
            id: gradient.id,
            coordinateSystem: .userSpaceOnUse,
            cx: newCx,
            cy: newCy,
            r: newR,
            fx: newFx,
            fy: newFy,
            stops: gradient.stops
        )
    }
    
    /// Convert from userSpaceOnUse to objectBoundingBox coordinates
    static func convertUserSpaceToBoundingBox(
        gradient: RadialGradient,
        boundingBox: BoundingBox
    ) -> RadialGradient {
        guard gradient.coordinateSystem == .userSpaceOnUse else {
            return gradient
        }
        
        let newCx = (gradient.cx - boundingBox.x) / boundingBox.width
        let newCy = (gradient.cy - boundingBox.y) / boundingBox.height
        let newR = gradient.r / min(boundingBox.width, boundingBox.height)
        
        let newFx: Double?
        let newFy: Double?
        
        if let fx = gradient.fx, let fy = gradient.fy {
            newFx = (fx - boundingBox.x) / boundingBox.width
            newFy = (fy - boundingBox.y) / boundingBox.height
        } else {
            newFx = nil
            newFy = nil
        }
        
        return RadialGradient(
            id: gradient.id,
            coordinateSystem: .objectBoundingBox,
            cx: newCx,
            cy: newCy,
            r: newR,
            fx: newFx,
            fy: newFy,
            stops: gradient.stops
        )
    }
    
    // MARK: - SVG Parsing
    
    /// Parse SVG content and extract radial gradients
    static func parseSVGGradients(from svgContent: String) -> [RadialGradient] {
        var gradients: [RadialGradient] = []
        
        // Simple regex-based parsing for radial gradients
        let gradientPattern = #"<radialGradient[^>]*id="([^"]*)"[^>]*gradientUnits="([^"]*)"[^>]*cx="([^"]*)"[^>]*cy="([^"]*)"[^>]*r="([^"]*)"[^>]*>(.*?)</radialGradient>"#
        
        guard let regex = try? NSRegularExpression(pattern: gradientPattern, options: [.dotMatchesLineSeparators]) else {
            Log.error("Failed to create regex for gradient pattern", category: .error)
            return []
        }
        let matches = regex.matches(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent))
        
        for match in matches {
            guard let id = extractValue(from: svgContent, range: match.range(at: 1)),
                  let gradientUnits = extractValue(from: svgContent, range: match.range(at: 2)),
                  let cxStr = extractValue(from: svgContent, range: match.range(at: 3)),
                  let cyStr = extractValue(from: svgContent, range: match.range(at: 4)),
                  let rStr = extractValue(from: svgContent, range: match.range(at: 5)),
                  let gradientContent = extractValue(from: svgContent, range: match.range(at: 6)),
                  let coordinateSystem = CoordinateSystem(rawValue: gradientUnits),
                  let cx = Double(cxStr),
                  let cy = Double(cyStr),
                  let r = Double(rStr) else {
                continue
            }
            
            // Parse focal point (fx, fy) if present
            let fxPattern = #"fx="([^"]*)"#
            let fyPattern = #"fy="([^"]*)"#
            
            guard let fxRegex = try? NSRegularExpression(pattern: fxPattern),
                  let fyRegex = try? NSRegularExpression(pattern: fyPattern) else {
                Log.error("Failed to create regex for fx/fy patterns", category: .error)
                continue
            }
            
            let fxMatch = fxRegex.firstMatch(in: svgContent, options: [], range: match.range)
            let fyMatch = fyRegex.firstMatch(in: svgContent, options: [], range: match.range)
            
            let fx = fxMatch.flatMap { Double(extractValue(from: svgContent, range: $0.range(at: 1)) ?? "") }
            let fy = fyMatch.flatMap { Double(extractValue(from: svgContent, range: $0.range(at: 1)) ?? "") }
            
            // Parse gradient stops
            let stops = parseGradientStops(from: gradientContent)
            
            let gradient = RadialGradient(
                id: id,
                coordinateSystem: coordinateSystem,
                cx: cx,
                cy: cy,
                r: r,
                fx: fx,
                fy: fy,
                stops: stops
            )
            
            gradients.append(gradient)
        }
        
        return gradients
    }
    
    /// Parse gradient stops from gradient content
    private static func parseGradientStops(from content: String) -> [GradientStop] {
        var stops: [GradientStop] = []
        
        let stopPattern = #"<stop[^>]*offset="([^"]*)"[^>]*stop-color="([^"]*)"[^>]*/>"#
        guard let regex = try? NSRegularExpression(pattern: stopPattern) else {
            Log.error("Failed to create regex for stop pattern", category: .error)
            return []
        }
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
        
        for match in matches {
            guard let offsetStr = extractValue(from: content, range: match.range(at: 1)),
                  let color = extractValue(from: content, range: match.range(at: 2)) else {
                continue
            }
            
            // Convert percentage to decimal
            let offset: Double
            if offsetStr.hasSuffix("%") {
                let percentage = Double(offsetStr.dropLast()) ?? 0
                offset = percentage / 100.0
            } else {
                offset = Double(offsetStr) ?? 0
            }
            
            stops.append(GradientStop(offset: offset, color: color))
        }
        
        return stops
    }
    
    /// Extract bounding box from SVG content
    static func parseBoundingBox(from svgContent: String) -> BoundingBox? {
        // Look for viewBox attribute
        let viewBoxPattern = #"viewBox="([^"]*)"#
        guard let viewBoxRegex = try? NSRegularExpression(pattern: viewBoxPattern) else {
            Log.error("Failed to create regex for viewBox pattern", category: .error)
            return nil
        }
        
        if let match = viewBoxRegex.firstMatch(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent)),
           let viewBoxStr = extractValue(from: svgContent, range: match.range(at: 1)) {
            let components = viewBoxStr.components(separatedBy: .whitespaces).compactMap { Double($0) }
            if components.count >= 4 {
                return BoundingBox(
                    x: components[0],
                    y: components[1],
                    width: components[2],
                    height: components[3]
                )
            }
        }
        
        // Fallback to width/height attributes
        let widthPattern = #"width="([^"]*)"#
        let heightPattern = #"height="([^"]*)"#
        
        guard let widthRegex = try? NSRegularExpression(pattern: widthPattern),
              let heightRegex = try? NSRegularExpression(pattern: heightPattern) else {
            Log.error("Failed to create regex for width/height patterns", category: .error)
            return nil
        }
        
        let widthMatch = widthRegex.firstMatch(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent))
        let heightMatch = heightRegex.firstMatch(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent))
        
        if let widthStr = widthMatch.flatMap({ extractValue(from: svgContent, range: $0.range(at: 1)) }),
           let heightStr = heightMatch.flatMap({ extractValue(from: svgContent, range: $0.range(at: 1)) }),
           let width = Double(widthStr),
           let height = Double(heightStr) {
            return BoundingBox(x: 0, y: 0, width: width, height: height)
        }
        
        return nil
    }
    
    /// Extract value from string using NSRange
    private static func extractValue(from string: String, range: NSRange) -> String? {
        guard range.location != NSNotFound,
              let swiftRange = Range(range, in: string) else {
            return nil
        }
        return String(string[swiftRange])
    }
    
    // MARK: - SVG Generation
    
    /// Generate SVG content with converted gradients
    static func generateSVG(
        originalContent: String,
        convertedGradients: [RadialGradient],
        boundingBox: BoundingBox
    ) -> String {
        var result = originalContent
        
        for gradient in convertedGradients {
            let oldGradientPattern = #"<radialGradient[^>]*id="\#(gradient.id)"[^>]*>.*?</radialGradient>"#
            let newGradientContent = generateGradientSVG(gradient: gradient)
            
            guard let regex = try? NSRegularExpression(pattern: oldGradientPattern, options: [.dotMatchesLineSeparators]) else {
                Log.error("Failed to create regex for old gradient pattern", category: .error)
                continue
            }
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: newGradientContent
            )
        }
        
        return result
    }
    
    /// Generate SVG content for a single gradient
    private static func generateGradientSVG(gradient: RadialGradient) -> String {
        var content = #"<radialGradient id="\#(gradient.id)" gradientUnits="\#(gradient.coordinateSystem.rawValue)" cx="\#(gradient.cx)" cy="\#(gradient.cy)" r="\#(gradient.r)""#
        
        if let fx = gradient.fx, let fy = gradient.fy {
            content += #" fx="\#(fx)" fy="\#(fy)""#
        }
        
        content += ">\n"
        
        for stop in gradient.stops {
            let offsetPercent = Int(stop.offset * 100)
            content += #"  <stop offset="\#(offsetPercent)%" stop-color="\#(stop.color)" />\n"#
        }
        
        content += "</radialGradient>"
        return content
    }
}

// MARK: - Utility Functions for App Integration
extension GradientCoordinateConverter {
    /// Convert gradients in an SVG file and return the modified content
    
    // MARK: - Advanced Gradient Coordinate Parsing
    
    /// Parse gradient coordinate with enhanced SVG compatibility and proper userSpaceOnUse handling
    /// This version includes extreme value handling for radial gradients that cannot be reproduced
    static func parseGradientCoordinate(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, useExtremeValueHandling: Bool = false, viewBoxWidth: Double = 100.0, viewBoxHeight: Double = 100.0) -> Double {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        
        // Handle percentage values (most common in SVG gradients)
        if trimmed.hasSuffix("%") {
            let percentValue = Double(String(trimmed.dropLast(1))) ?? 0.0
            return percentValue / 100.0
        }
        
        // Handle absolute values
        if let absoluteValue = Double(trimmed) {
            if gradientUnits == .userSpaceOnUse {
                // CRITICAL FIX: For userSpaceOnUse, normalize to viewBox dimensions (0-1 range)
                // This creates proper shape-relative coordinates
                let normalizer = isXCoordinate ? viewBoxWidth : viewBoxHeight
                if normalizer > 0 {
                    let normalizedValue = absoluteValue / normalizer
                    
                    // ENHANCED EXTREME VALUE HANDLING: For coordinates way outside the viewBox
                    let finalValue: Double
                    if useExtremeValueHandling {
                        // EXTREME VALUE MODE: Use your radial gradient code for values outside 0-1
                        if normalizedValue < 0.0 || normalizedValue > 1.0 {
                            // Use your specialized radial gradient handling for out-of-bounds values
                            // Map extreme values to reasonable 0-1 range
                            if normalizedValue < 0.0 {
                                // Negative coordinates: map to 0.0-0.5 range
                                finalValue = 0.5 + (normalizedValue * 0.5)
                                Log.fileOperation("🚨 EXTREME NEGATIVE COORDINATE: \(absoluteValue) → \(normalizedValue) → \(finalValue)", level: .info)
                            } else {
                                // Values > 1.0: map to 0.5-1.0 range
                                finalValue = 0.5 + ((normalizedValue - 1.0) * 0.5)
                                Log.fileOperation("🚨 EXTREME LARGE COORDINATE: \(absoluteValue) → \(normalizedValue) → \(finalValue)", level: .info)
                            }
                        } else {
                            // Coordinates within 0-1 range: use as-is
                            finalValue = normalizedValue
                            Log.info("✅ NORMAL COORDINATE: \(absoluteValue) → \(normalizedValue)", category: .fileOperations)
                        }
                    } else {
                        // STANDARD MODE: Preserve normalized value even if outside 0-1; clamping happens later
                        finalValue = normalizedValue
                        Log.info("✅ STANDARD COORDINATE: \(absoluteValue) → \(normalizedValue) (preserved)", category: .fileOperations)
                    }
                    
                    // Ensure final value is within 0-1 range
                    let clampedValue = max(0.0, min(1.0, finalValue))
                    
                    let modeLabel = useExtremeValueHandling ? "EXTREME VALUE" : "STANDARD"
                    Log.fileOperation("🔧 \(modeLabel) CONVERSION: \(absoluteValue) → \(normalizedValue) → \(finalValue) → \(clampedValue) (userSpaceOnUse → objectBoundingBox)", level: .info)
                    Log.info("   Formula: \(absoluteValue) / \(normalizer)", category: .general)
                    Log.info("   Using viewBox: \(viewBoxWidth) × \(viewBoxHeight)", category: .general)
                    Log.info("   Mapping: \(normalizedValue < 0.0 || normalizedValue > 1.0 ? (useExtremeValueHandling ? "outside 0-1→proportional mapping" : "outside 0-1→0.5") : "within 0-1 range")", category: .general)
                    return clampedValue
                } else {
                    Log.fileOperation("⚠️ Invalid viewBox dimension, using absolute coordinate", level: .info)
                    return absoluteValue
                }
            } else {
                // For objectBoundingBox, values should be in 0-1 range
                if absoluteValue > 1.0 {
                    // If value is > 1, assume it needs normalization
                    return min(absoluteValue / 100.0, 1.0)
                }
                return absoluteValue
            }
        }
        
        // Default fallback
        return 0.0
    }
    
    /// ENHANCED RADIAL GRADIENT COORDINATE PARSING FOR EXTREME VALUES
    /// This specialized version handles radial gradients with extreme values that cannot be reproduced
    /// Use this option for radial files that have coordinates way outside normal bounds
    static func parseRadialGradientCoordinateExtreme(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, viewBoxWidth: Double = 100.0, viewBoxHeight: Double = 100.0) -> Double {
        return parseGradientCoordinate(value, gradientUnits: gradientUnits, isXCoordinate: isXCoordinate, useExtremeValueHandling: true, viewBoxWidth: viewBoxWidth, viewBoxHeight: viewBoxHeight)
    }
} 
