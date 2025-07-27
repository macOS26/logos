import Foundation

// MARK: - Gradient Coordinate Converter
struct GradientCoordinateConverter {
    
    enum CoordinateSystem: String {
        case objectBoundingBox = "objectBoundingBox"
        case userSpaceOnUse = "userSpaceOnUse"
    }
    
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
        let offset: Double
        let color: String
    }
    
    struct BoundingBox {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
    
    // Convert from objectBoundingBox to userSpaceOnUse coordinates
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
    
    // Parse bounding box from SVG content
    static func parseBoundingBox(from svgContent: String) -> BoundingBox? {
        // Look for viewBox attribute in the SVG tag
        let viewBoxPattern = #"<svg[^>]*viewBox="([^"]*)"[^>]*>"#
        let viewBoxRegex = try! NSRegularExpression(pattern: viewBoxPattern)
        
        if let match = viewBoxRegex.firstMatch(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent)) {
            let range = match.range(at: 1)
            if range.location != NSNotFound {
                let start = svgContent.index(svgContent.startIndex, offsetBy: range.location)
                let end = svgContent.index(start, offsetBy: range.length)
                let viewBoxStr = String(svgContent[start..<end])
                
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
        }
        
        return nil
    }
    
    // Parse SVG content and extract radial gradients
    static func parseSVGGradients(from svgContent: String) -> [RadialGradient] {
        var gradients: [RadialGradient] = []
        
        // Simple regex-based parsing for radial gradients
        let gradientPattern = #"<radialGradient[^>]*id="([^"]*)"[^>]*gradientUnits="([^"]*)"[^>]*cx="([^"]*)"[^>]*cy="([^"]*)"[^>]*r="([^"]*)"[^>]*>(.*?)</radialGradient>"#
        
        let regex = try! NSRegularExpression(pattern: gradientPattern, options: [.dotMatchesLineSeparators])
        let matches = regex.matches(in: svgContent, options: [], range: NSRange(svgContent.startIndex..., in: svgContent))
        
        for match in matches {
            let idRange = match.range(at: 1)
            let gradientUnitsRange = match.range(at: 2)
            let cxRange = match.range(at: 3)
            let cyRange = match.range(at: 4)
            let rRange = match.range(at: 5)
            let gradientContentRange = match.range(at: 6)
            
            guard idRange.location != NSNotFound,
                  gradientUnitsRange.location != NSNotFound,
                  cxRange.location != NSNotFound,
                  cyRange.location != NSNotFound,
                  rRange.location != NSNotFound,
                  gradientContentRange.location != NSNotFound else {
                continue
            }
            
            let id = String(svgContent[svgContent.index(svgContent.startIndex, offsetBy: idRange.location)..<svgContent.index(svgContent.startIndex, offsetBy: idRange.location + idRange.length)])
            let gradientUnits = String(svgContent[svgContent.index(svgContent.startIndex, offsetBy: gradientUnitsRange.location)..<svgContent.index(svgContent.startIndex, offsetBy: gradientUnitsRange.location + gradientUnitsRange.length)])
            let cxStr = String(svgContent[svgContent.index(svgContent.startIndex, offsetBy: cxRange.location)..<svgContent.index(svgContent.startIndex, offsetBy: cxRange.location + cxRange.length)])
            let cyStr = String(svgContent[svgContent.index(svgContent.startIndex, offsetBy: cyRange.location)..<svgContent.index(svgContent.startIndex, offsetBy: cyRange.location + cyRange.length)])
            let rStr = String(svgContent[svgContent.index(svgContent.startIndex, offsetBy: rRange.location)..<svgContent.index(svgContent.startIndex, offsetBy: rRange.location + rRange.length)])
            let gradientContent = String(svgContent[svgContent.index(svgContent.startIndex, offsetBy: gradientContentRange.location)..<svgContent.index(svgContent.startIndex, offsetBy: gradientContentRange.location + gradientContentRange.length)])
            
            guard let coordinateSystem = CoordinateSystem(rawValue: gradientUnits),
                  let cx = Double(cxStr),
                  let cy = Double(cyStr),
                  let r = Double(rStr) else {
                continue
            }
            
            // Parse focal point (fx, fy) if present
            let fxPattern = #"fx="([^"]*)"#
            let fyPattern = #"fy="([^"]*)"#
            
            let fxRegex = try! NSRegularExpression(pattern: fxPattern)
            let fyRegex = try! NSRegularExpression(pattern: fyPattern)
            
            let fxMatch = fxRegex.firstMatch(in: svgContent, options: [], range: match.range)
            let fyMatch = fyRegex.firstMatch(in: svgContent, options: [], range: match.range)
            
            let fx = fxMatch.flatMap { match -> Double? in
                let range = match.range(at: 1)
                if range.location != NSNotFound {
                    let start = svgContent.index(svgContent.startIndex, offsetBy: range.location)
                    let end = svgContent.index(start, offsetBy: range.length)
                    return Double(String(svgContent[start..<end]))
                }
                return nil
            }
            
            let fy = fyMatch.flatMap { match -> Double? in
                let range = match.range(at: 1)
                if range.location != NSNotFound {
                    let start = svgContent.index(svgContent.startIndex, offsetBy: range.location)
                    let end = svgContent.index(start, offsetBy: range.length)
                    return Double(String(svgContent[start..<end]))
                }
                return nil
            }
            
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
    
    // Parse gradient stops from gradient content
    private static func parseGradientStops(from content: String) -> [GradientStop] {
        var stops: [GradientStop] = []
        
        let stopPattern = #"<stop[^>]*offset="([^"]*)"[^>]*stop-color="([^"]*)"[^>]*/>"#
        let regex = try! NSRegularExpression(pattern: stopPattern)
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
        
        for match in matches {
            let offsetRange = match.range(at: 1)
            let colorRange = match.range(at: 2)
            
            guard offsetRange.location != NSNotFound,
                  colorRange.location != NSNotFound else {
                continue
            }
            
            let offsetStr = String(content[content.index(content.startIndex, offsetBy: offsetRange.location)..<content.index(content.startIndex, offsetBy: offsetRange.location + offsetRange.length)])
            let color = String(content[content.index(content.startIndex, offsetBy: colorRange.location)..<content.index(content.startIndex, offsetBy: colorRange.location + colorRange.length)])
            
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
    
    // Convert from userSpaceOnUse to objectBoundingBox coordinates
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
    
    // Generate SVG content with converted gradients
    static func generateSVG(
        originalContent: String,
        convertedGradients: [RadialGradient],
        boundingBox: BoundingBox
    ) -> String {
        var result = originalContent
        
        for gradient in convertedGradients {
            let oldGradientPattern = #"<radialGradient[^>]*id="\#(gradient.id)"[^>]*>.*?</radialGradient>"#
            let newGradientContent = generateGradientSVG(gradient: gradient)
            
            let regex = try! NSRegularExpression(pattern: oldGradientPattern, options: [.dotMatchesLineSeparators])
            result = regex.stringByReplacingMatches(
                in: result,
                options: [],
                range: NSRange(result.startIndex..., in: result),
                withTemplate: newGradientContent
            )
        }
        
        return result
    }
    
    // Generate SVG content for a single gradient
    private static func generateGradientSVG(gradient: RadialGradient) -> String {
        var content = #"<radialGradient id="\#(gradient.id)" gradientUnits="\#(gradient.coordinateSystem.rawValue)" cx="\#(gradient.cx)" cy="\#(gradient.cy)" r="\#(gradient.r)""#
        
        if let fx = gradient.fx, let fy = gradient.fy {
            content += #" fx="\#(fx)" fy="\#(fy)""#
        }
        
        content += ">\n"
        
        for stop in gradient.stops {
            let offsetPercent = Int(stop.offset * 100)
            content += "      <stop offset=\"\(offsetPercent)%\" stop-color=\"\(stop.color)\"/>\n"
        }
        
        content += "    </radialGradient>"
        return content
    }
}

// Main execution
let args = CommandLine.arguments

guard args.count >= 3 else {
    print("Usage: \(args[0]) <input.svg> <output.svg> [--reverse]")
    exit(1)
}

let inputFile = args[1]
let outputFile = args[2]
let reverse = args.count > 3 && args[3] == "--reverse"

do {
    let inputContent = try String(contentsOfFile: inputFile)
    
    // Parse bounding box
    guard let boundingBox = GradientCoordinateConverter.parseBoundingBox(from: inputContent) else {
        print("Error: Could not parse bounding box from SVG")
        exit(1)
    }
    
    print("Bounding Box: x=\(boundingBox.x), y=\(boundingBox.y), width=\(boundingBox.width), height=\(boundingBox.height)")
    
    // Parse gradients
    let gradients = GradientCoordinateConverter.parseSVGGradients(from: inputContent)
    
    if gradients.isEmpty {
        print("Warning: No radial gradients found in SVG")
        try inputContent.write(toFile: outputFile, atomically: true, encoding: .utf8)
        print("Copied original file to output")
        exit(0)
    }
    
    print("Found \(gradients.count) radial gradient(s)")
    
    // Convert gradients
    let convertedGradients = gradients.map { gradient in
        if reverse {
            return GradientCoordinateConverter.convertUserSpaceToBoundingBox(
                gradient: gradient,
                boundingBox: boundingBox
            )
        } else {
            return GradientCoordinateConverter.convertBoundingBoxToUserSpace(
                gradient: gradient,
                boundingBox: boundingBox
            )
        }
    }
    
    // Print conversion details
    for (original, converted) in zip(gradients, convertedGradients) {
        print("\nGradient: \(original.id)")
        print("  Original: \(original.coordinateSystem.rawValue) - cx:\(original.cx), cy:\(original.cy), r:\(original.r)")
        print("  Converted: \(converted.coordinateSystem.rawValue) - cx:\(converted.cx), cy:\(converted.cy), r:\(converted.r)")
    }
    
    // Generate output SVG
    let outputContent = GradientCoordinateConverter.generateSVG(
        originalContent: inputContent,
        convertedGradients: convertedGradients,
        boundingBox: boundingBox
    )
    
    try outputContent.write(toFile: outputFile, atomically: true, encoding: .utf8)
    print("\nSuccessfully converted gradients and saved to: \(outputFile)")
    
} catch {
    print("Error: \(error)")
    exit(1)
} 