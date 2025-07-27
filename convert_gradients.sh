#!/bin/bash

# Gradient Coordinate Converter Script
# Converts radial gradient coordinates between objectBoundingBox and userSpaceOnUse

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Gradient Coordinate Converter"
    echo ""
    echo "Usage: $0 <input.svg> <output.svg> [--reverse]"
    echo ""
    echo "Arguments:"
    echo "  input.svg    - Input SVG file with radial gradients"
    echo "  output.svg   - Output SVG file with converted gradients"
    echo "  --reverse    - Convert from userSpaceOnUse to objectBoundingBox"
    echo ""
    echo "Examples:"
    echo "  $0 test_boundingbox_gradient.svg converted_userspace.svg"
    echo "  $0 test_userspace_gradient.svg converted_boundingbox.svg --reverse"
    echo ""
    echo "The tool will:"
    echo "  1. Parse the SVG viewBox or dimensions"
    echo "  2. Extract radial gradients"
    echo "  3. Convert coordinates between coordinate systems"
    echo "  4. Generate new SVG with converted gradients"
}

# Check if help is requested
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_usage
    exit 0
fi

# Check arguments
if [[ $# -lt 2 ]]; then
    print_error "Missing required arguments"
    show_usage
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
REVERSE=false

# Check for reverse flag
if [[ "$3" == "--reverse" ]]; then
    REVERSE=true
fi

# Validate input file
if [[ ! -f "$INPUT_FILE" ]]; then
    print_error "Input file '$INPUT_FILE' does not exist"
    exit 1
fi

# Check if input file is SVG
if [[ ! "$INPUT_FILE" =~ \.svg$ ]]; then
    print_warning "Input file doesn't have .svg extension"
fi

print_status "Input file: $INPUT_FILE"
print_status "Output file: $OUTPUT_FILE"
print_status "Reverse conversion: $REVERSE"

# Create temporary Swift file for compilation
TEMP_SWIFT_FILE="/tmp/gradient_converter_$$.swift"

# Create the Swift program
cat > "$TEMP_SWIFT_FILE" << 'EOF'
import Foundation

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
        
        let regex = try! NSRegularExpression(pattern: gradientPattern, options: [.dotMatchesLineSeparators])
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
            
            let fxRegex = try! NSRegularExpression(pattern: fxPattern)
            let fyRegex = try! NSRegularExpression(pattern: fyPattern)
            
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
        let regex = try! NSRegularExpression(pattern: stopPattern)
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
        // Look for viewBox attribute in the SVG tag
        let viewBoxPattern = #"<svg[^>]*viewBox="([^"]*)"[^>]*>"#
        let viewBoxRegex = try! NSRegularExpression(pattern: viewBoxPattern)
        
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
        
        // Fallback to width/height attributes in the SVG tag
        let widthPattern = #"<svg[^>]*width="([^"]*)"[^>]*>"#
        let heightPattern = #"<svg[^>]*height="([^"]*)"[^>]*>"#
        
        let widthRegex = try! NSRegularExpression(pattern: widthPattern)
        let heightRegex = try! NSRegularExpression(pattern: heightPattern)
        
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
    
    /// Generate SVG content for a single gradient
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
let inputFile = CommandLine.arguments[1]
let outputFile = CommandLine.arguments[2]
let reverse = CommandLine.arguments.count > 3 && CommandLine.arguments[3] == "--reverse"

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
EOF

# Compile and run the Swift program
print_status "Compiling Swift converter..."

if swift "$TEMP_SWIFT_FILE" "$INPUT_FILE" "$OUTPUT_FILE" $([[ "$REVERSE" == true ]] && echo "--reverse"); then
    print_success "Conversion completed successfully!"
    
    # Show file sizes
    INPUT_SIZE=$(wc -c < "$INPUT_FILE")
    OUTPUT_SIZE=$(wc -c < "$OUTPUT_FILE")
    print_status "Input file size: $INPUT_SIZE bytes"
    print_status "Output file size: $OUTPUT_SIZE bytes"
    
else
    print_error "Conversion failed"
    exit 1
fi

# Clean up
rm -f "$TEMP_SWIFT_FILE"

print_success "Done!" 