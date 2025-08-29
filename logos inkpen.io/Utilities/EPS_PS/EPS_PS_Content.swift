//
//  EPSContent.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI
import CoreGraphics

struct EPSContent {
    let shapes: [VectorShape]
    let boundingBox: CGRect
    let colorSpace: String
    let textCount: Int
    let creator: String?
    let version: String?
}

func parseEPSContent(_ url: URL) throws -> EPSContent {
    Log.fileOperation("🔧 UPDATED EPS parser with binary support v2.0...", level: .info)
    
    guard let data = try? Data(contentsOf: url) else {
        throw VectorImportError.fileNotFound
    }
    
    // Try to handle binary EPS files with comprehensive error handling
    let fileContent: String
    
    Log.fileOperation("📋 EPS file size: \(data.count) bytes", level: .info)
    
    if let utf8Content = String(data: data, encoding: .utf8) {
        fileContent = utf8Content
        Log.fileOperation("📋 Successfully decoded EPS as UTF-8", level: .info)
    } else {
        Log.fileOperation("📋 UTF-8 decoding failed, trying ISO Latin-1", level: .info)
        
        if let latinContent = String(data: data, encoding: .isoLatin1) {
            // Try ISO Latin-1 encoding for binary EPS files
            fileContent = latinContent
            Log.fileOperation("📋 Successfully decoded EPS as ISO Latin-1", level: .info)
        } else {
            Log.fileOperation("📋 ISO Latin-1 decoding failed, trying binary extraction", level: .info)
            
            do {
                // Try to extract PostScript portion from binary EPS
                fileContent = try extractPostScriptFromBinaryEPS(data: data)
                Log.fileOperation("📋 Successfully extracted PostScript from binary EPS", level: .info)
            } catch {
                Log.error("📋 Binary extraction failed: \(error)", category: .error)
                
                // Ultimate fallback: create a placeholder
                Log.fileOperation("📋 Creating placeholder content for unsupported EPS format", level: .info)
                fileContent = createPlaceholderEPSContent(fileSize: data.count)
            }
        }
    }
    
    var shapes: [VectorShape] = []
    var boundingBox = CGRect(x: 0, y: 0, width: 612, height: 792) // Default letter size
    var colorSpace = "RGB"
    var textCount = 0
    var creator: String?
    var version: String?
    
    // Parse EPS header information
    let lines = fileContent.components(separatedBy: .newlines)
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Parse bounding box
        if trimmedLine.hasPrefix("%%BoundingBox:") {
            let components = trimmedLine.components(separatedBy: " ")
            if components.count >= 5 {
                if let x = Double(components[1]),
                   let y = Double(components[2]),
                   let width = Double(components[3]),
                   let height = Double(components[4]) {
                    boundingBox = CGRect(x: x, y: y, width: width - x, height: height - y)
                    Log.fileOperation("📋 Found bounding box: \(boundingBox)", level: .info)
                }
            }
        }
        
        // Parse creator
        else if trimmedLine.hasPrefix("%%Creator:") {
            creator = String(trimmedLine.dropFirst("%%Creator:".count)).trimmingCharacters(in: .whitespaces)
        }
        
        // Parse version
        else if trimmedLine.hasPrefix("%%Version:") {
            version = String(trimmedLine.dropFirst("%%Version:".count)).trimmingCharacters(in: .whitespaces)
        }
        
        // Look for color space information
        else if trimmedLine.contains("setcolorspace") || trimmedLine.contains("DeviceRGB") {
            colorSpace = "RGB"
        }
        else if trimmedLine.contains("DeviceCMYK") {
            colorSpace = "CMYK"
        }
        
        // Count text objects (look for text operators)
        else if trimmedLine.contains("show") || trimmedLine.contains("Tj") || trimmedLine.contains("TJ") {
            textCount += 1
        }
    }
    
    // Parse basic PostScript drawing commands to extract shapes
    shapes = try parsePostScriptPaths(fileContent)
    
    Log.info("✅ EPS parsing completed: \(shapes.count) shapes, \(textCount) text objects", category: .fileOperations)
    
    return EPSContent(
        shapes: shapes,
        boundingBox: boundingBox,
        colorSpace: colorSpace,
        textCount: textCount,
        creator: creator,
        version: version
    )
}


func parsePostScriptPaths(_ content: String) throws -> [VectorShape] {
    var shapes: [VectorShape] = []
    var currentPath: [PathElement] = []
    var currentPoint: CGPoint = .zero
    var graphics = PostScriptGraphicsState()
    
    // Split content into tokens for better parsing
    let tokens = tokenizePostScript(content)
    var tokenIndex = 0
    
    while tokenIndex < tokens.count {
        let token = tokens[tokenIndex]
        
        // Parse PostScript commands
        switch token {
        case "moveto", "m":
            if tokenIndex >= 2,
               let x = Double(tokens[tokenIndex - 2]),
               let y = Double(tokens[tokenIndex - 1]),
               x.isFinite && y.isFinite {
                currentPoint = CGPoint(x: x, y: y)
                currentPath.append(.move(to: VectorPoint(currentPoint)))
                Log.fileOperation("📐 moveto: \(x), \(y)", level: .info)
            }
            
        case "lineto", "l":
            if tokenIndex >= 2,
               let x = Double(tokens[tokenIndex - 2]),
               let y = Double(tokens[tokenIndex - 1]),
               x.isFinite && y.isFinite,
               !currentPath.isEmpty { // Only add lineto if we have a current point
                currentPoint = CGPoint(x: x, y: y)
                currentPath.append(.line(to: VectorPoint(currentPoint)))
            }
            
        case "curveto", "c":
            if tokenIndex >= 6,
               let x1 = Double(tokens[tokenIndex - 6]),
               let y1 = Double(tokens[tokenIndex - 5]),
               let x2 = Double(tokens[tokenIndex - 4]),
               let y2 = Double(tokens[tokenIndex - 3]),
               let x3 = Double(tokens[tokenIndex - 2]),
               let y3 = Double(tokens[tokenIndex - 1]),
               x1.isFinite && y1.isFinite && x2.isFinite && y2.isFinite && x3.isFinite && y3.isFinite,
               !currentPath.isEmpty { // Only add curveto if we have a current point
                currentPoint = CGPoint(x: x3, y: y3)
                currentPath.append(.curve(
                    to: VectorPoint(currentPoint),
                    control1: VectorPoint(x1, y1),
                    control2: VectorPoint(x2, y2)
                ))
            }
            
        case "closepath", "z":
            // Only close path if we have path elements and started with moveto
            if !currentPath.isEmpty && currentPath.first != nil {
                currentPath.append(.close)
            }
            
        case "stroke":
            if !currentPath.isEmpty && hasValidPath(currentPath) {
                let vectorPath = VectorPath(elements: currentPath)
                let shape = VectorShape(
                    name: "PostScript Shape \(shapes.count + 1)",
                    path: vectorPath,
                    strokeStyle: StrokeStyle(
                        color: graphics.strokeColor,
                        width: max(0.1, graphics.lineWidth), // Ensure minimum line width
                        placement: .center
                    ),
                    fillStyle: nil
                )
                shapes.append(shape)
                currentPath.removeAll()
            }
            
        case "fill":
            if !currentPath.isEmpty && hasValidPath(currentPath) {
                let vectorPath = VectorPath(elements: currentPath)
                let shape = VectorShape(
                    name: "PostScript Shape \(shapes.count + 1)",
                    path: vectorPath,
                    strokeStyle: nil,
                    fillStyle: FillStyle(color: graphics.fillColor)
                )
                shapes.append(shape)
                currentPath.removeAll()
            }
            
        case "setlinewidth":
            if tokenIndex >= 1,
               let width = Double(tokens[tokenIndex - 1]),
               width.isFinite && width >= 0 {
                graphics.lineWidth = CGFloat(width)
            }
            
        case "setrgbcolor":
            if tokenIndex >= 3,
               let r = Double(tokens[tokenIndex - 3]),
               let g = Double(tokens[tokenIndex - 2]),
               let b = Double(tokens[tokenIndex - 1]),
               r.isFinite && g.isFinite && b.isFinite {
                // Clamp values to 0-1 range
                let clampedR = max(0, min(1, r))
                let clampedG = max(0, min(1, g))
                let clampedB = max(0, min(1, b))
                graphics.fillColor = .rgb(RGBColor(red: clampedR, green: clampedG, blue: clampedB))
                graphics.strokeColor = .rgb(RGBColor(red: clampedR, green: clampedG, blue: clampedB))
            }
            
        case "rect":
            // Rectangle command: x y width height rect
            if tokenIndex >= 4,
               let x = Double(tokens[tokenIndex - 4]),
               let y = Double(tokens[tokenIndex - 3]),
               let width = Double(tokens[tokenIndex - 2]),
               let height = Double(tokens[tokenIndex - 1]),
               x.isFinite && y.isFinite && width.isFinite && height.isFinite,
               width > 0 && height > 0 {
                let rectShape = VectorShape.rectangle(
                    at: CGPoint(x: x, y: y),
                    size: CGSize(width: width, height: height)
                )
                var shape = rectShape
                shape.name = "PostScript Rectangle \(shapes.count + 1)"
                shape.strokeStyle = StrokeStyle(
                    color: graphics.strokeColor,
                    width: max(0.1, graphics.lineWidth),
                    placement: .center
                )
                shape.fillStyle = FillStyle(color: graphics.fillColor)
                shapes.append(shape)
            }
            
        default:
            // Skip unknown commands or continue parsing
            break
        }
        
        tokenIndex += 1
    }
    
    Log.info("📊 PostScript parsing found \(shapes.count) shapes", category: .fileOperations)
    return shapes
}

// MARK: - PostScript Graphics State
struct PostScriptGraphicsState {
    var lineWidth: CGFloat = 1.0
    var strokeColor: VectorColor = .black
    var fillColor: VectorColor = .rgb(RGBColor(red: 0.7, green: 0.7, blue: 0.9))
}

// MARK: - Path Validation
func hasValidPath(_ pathElements: [PathElement]) -> Bool {
    // Check if path has at least a move command
    guard !pathElements.isEmpty else { return false }
    
    // Check if first element is a move
    switch pathElements.first {
    case .move(let point):
        // Ensure the move point has valid coordinates
        return point.x.isFinite && point.y.isFinite
    default:
        return false
    }
}

// MARK: - PostScript Tokenizer
func tokenizePostScript(_ content: String) -> [String] {
    // Split by whitespace and newlines, removing empty tokens
    return content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .filter { !$0.hasPrefix("%") } // Remove comments
}

// MARK: - Binary EPS Handling
func extractPostScriptFromBinaryEPS(data: Data) throws -> String {
    // Binary EPS files start with a 30-byte header
    // Check for EPS binary header (0xC5D0D3C6)
    guard data.count >= 30 else {
        throw VectorImportError.parsingError("File too small to be a valid binary EPS", line: nil)
    }
    
    let headerBytes = data.prefix(4)
    let header = headerBytes.withUnsafeBytes { $0.load(as: UInt32.self) }
    
    // Check for binary EPS signature
    if header == 0xC6D3D0C5 { // Little-endian signature
        // Read PostScript offset and length from header
        let psOffset = data[4..<8].withUnsafeBytes { $0.load(as: UInt32.self) }
        let psLength = data[8..<12].withUnsafeBytes { $0.load(as: UInt32.self) }
        
        Log.fileOperation("📋 Binary EPS detected: PS offset=\(psOffset), length=\(psLength)", level: .info)
        
        guard data.count >= psOffset + psLength else {
            throw VectorImportError.parsingError("Invalid binary EPS: PostScript data extends beyond file", line: nil)
        }
        
        // Extract PostScript portion
        let psData = data[Int(psOffset)..<Int(psOffset + psLength)]
        
        if let psContent = String(data: psData, encoding: .utf8) {
            return psContent
        } else if let psContent = String(data: psData, encoding: .isoLatin1) {
            return psContent
        } else {
            throw VectorImportError.parsingError("Could not decode PostScript portion of binary EPS", line: nil)
        }
    } else {
        // Not a standard binary EPS, try to find PostScript content
        // Look for "%!PS" or "%!PS-Adobe" markers
        if let psContent = findPostScriptContent(in: data) {
            return psContent
        } else {
            throw VectorImportError.parsingError("Could not find PostScript content in file", line: nil)
        }
    }
}

func findPostScriptContent(in data: Data) -> String? {
    // Look for PostScript magic markers
    let markers = ["%!PS-Adobe", "%!PS"]
    
    for marker in markers {
        if let markerData = marker.data(using: .ascii),
           let range = data.range(of: markerData) {
            // Found PostScript content starting at this position
            let psData = data[range.lowerBound...]
            
            // Try different encodings
            if let content = String(data: psData, encoding: .utf8) {
                Log.fileOperation("📋 Found PostScript content with UTF-8 encoding", level: .info)
                return content
            } else if let content = String(data: psData, encoding: .isoLatin1) {
                Log.fileOperation("📋 Found PostScript content with ISO Latin-1 encoding", level: .info)
                return content
            }
        }
    }
    
    // Last resort: try to decode the entire file with different encodings
    if let content = String(data: data, encoding: .ascii) {
        Log.fileOperation("📋 Using ASCII encoding as fallback", level: .info)
        return content
    }
    
    return nil
}

func createPlaceholderEPSContent(fileSize: Int) -> String {
    // Create a simple PostScript content that creates a placeholder rectangle
    return """
    %!PS-Adobe-3.0 EPSF-3.0
    %%Creator: Inkpen EPS Parser
    %%Title: EPS Placeholder
    %%BoundingBox: 0 0 200 100
    %%EndComments
    
    % Placeholder for unsupported EPS format (\(fileSize) bytes)
    newpath
    10 10 moveto
    190 10 lineto
    190 90 lineto
    10 90 lineto
    closepath
    0.8 0.8 0.8 setrgbcolor
    fill
    
    newpath
    10 10 moveto
    190 10 lineto
    190 90 lineto
    10 90 lineto
    closepath
    0 0 0 setrgbcolor
    1 setlinewidth
    stroke
    
    % Add text indicating this is a placeholder
    /Helvetica findfont 12 scalefont setfont
    20 50 moveto
    (EPS Placeholder) show
    """
}

// MARK: - PostScript Content Parsing (regular .ps files)

func parsePostScriptContent(_ url: URL) throws -> EPSContent {
    Log.fileOperation("🔧 Using Core Graphics PostScript converter for robust parsing...", level: .info)
    
    guard let data = try? Data(contentsOf: url) else {
        throw VectorImportError.fileNotFound
    }
    
    // First try Core Graphics PostScript conversion approach
    do {
        return try parsePostScriptWithCoreGraphics(data: data)
    } catch {
        Log.fileOperation("⚠️ Core Graphics conversion failed, falling back to manual parser", level: .info)
        // Fall back to manual parsing if Core Graphics fails
        return try parsePostScriptManually(data: data)
    }
}

// MARK: - Core Graphics PostScript Conversion
func parsePostScriptWithCoreGraphics(data: Data) throws -> EPSContent {
    // Note: CGPSConverter APIs are not publicly available in Swift
    // Fall back to using PDF import approach for PostScript files
    throw VectorImportError.parsingError("Core Graphics PostScript converter not available, using fallback", line: nil)
}

// MARK: - Manual PostScript Parsing (Fallback)
func parsePostScriptManually(data: Data) throws -> EPSContent {
    // Try to handle binary PostScript files
    let fileContent: String
    if let utf8Content = String(data: data, encoding: .utf8) {
        fileContent = utf8Content
    } else if let latinContent = String(data: data, encoding: .isoLatin1) {
        // Try ISO Latin-1 encoding for binary PostScript files
        fileContent = latinContent
        Log.fileOperation("📋 Using ISO Latin-1 encoding for binary PostScript file", level: .info)
    } else {
        // Try to extract PostScript portion from binary file
        fileContent = try extractPostScriptFromBinaryEPS(data: data)
        Log.fileOperation("📋 Extracted PostScript from binary PostScript file", level: .info)
    }
    
    var shapes: [VectorShape] = []
    var boundingBox = CGRect(x: 0, y: 0, width: 612, height: 792) // Default letter size
    var colorSpace = "RGB"
    var textCount = 0
    var creator: String?
    var version: String?
    
    // Parse PostScript header information (similar to EPS but more flexible)
    let lines = fileContent.components(separatedBy: .newlines)
    
    for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespaces)
        
        // Parse bounding box (may be in different formats for PS)
        if trimmedLine.hasPrefix("%%BoundingBox:") || trimmedLine.hasPrefix("%!BoundingBox:") {
            let components = trimmedLine.components(separatedBy: " ")
            if components.count >= 5 {
                if let x = Double(components[1]),
                   let y = Double(components[2]),
                   let width = Double(components[3]),
                   let height = Double(components[4]) {
                    boundingBox = CGRect(x: x, y: y, width: width - x, height: height - y)
                    Log.fileOperation("📋 Found PostScript bounding box: \(boundingBox)", level: .info)
                }
            }
        }
        
        // Parse document setup commands for page size
        else if trimmedLine.contains("PageSize") || trimmedLine.contains("setpagedevice") {
            // Try to extract page dimensions from setpagedevice calls
            if trimmedLine.contains("[") && trimmedLine.contains("]") {
                // This is a basic parser - more sophisticated parsing could be added
                if let range = trimmedLine.range(of: "\\[\\s*(\\d+)\\s+(\\d+)\\s*\\]", options: .regularExpression) {
                    let match = String(trimmedLine[range])
                    let numbers = match.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
                    if numbers.count >= 2 {
                        boundingBox = CGRect(x: 0, y: 0, width: numbers[0], height: numbers[1])
                        Log.fileOperation("📐 Found page size: \(boundingBox.size)", level: .info)
                    }
                }
            }
        }
        
        // Parse creator
        else if trimmedLine.hasPrefix("%%Creator:") || trimmedLine.hasPrefix("%!Creator:") {
            creator = String(trimmedLine.dropFirst("%%Creator:".count)).trimmingCharacters(in: .whitespaces)
        }
        
        // Parse version
        else if trimmedLine.hasPrefix("%%Version:") || trimmedLine.hasPrefix("%!Version:") {
            version = String(trimmedLine.dropFirst("%%Version:".count)).trimmingCharacters(in: .whitespaces)
        }
        
        // Look for color space information
        else if trimmedLine.contains("setcolorspace") || trimmedLine.contains("DeviceRGB") {
            colorSpace = "RGB"
        }
        else if trimmedLine.contains("DeviceCMYK") {
            colorSpace = "CMYK"
        }
        
        // Count text objects (look for text operators)
        else if trimmedLine.contains("show") || trimmedLine.contains("Tj") || trimmedLine.contains("TJ") {
            textCount += 1
        }
    }
    
    // Parse PostScript drawing commands to extract shapes
    shapes = try parsePostScriptPaths(fileContent)
    
    Log.info("✅ Manual PostScript parsing completed: \(shapes.count) shapes, \(textCount) text objects", category: .fileOperations)
    
    return EPSContent(  // Reuse EPSContent struct since PS and EPS have similar structure
        shapes: shapes,
        boundingBox: boundingBox,
        colorSpace: colorSpace,
        textCount: textCount,
        creator: creator,
        version: version
    )
}

// MARK: - Helper Functions
func createRasterShapeFromImage(_ cgImage: CGImage, bounds: CGRect) -> VectorShape {
    // Convert CGImage to NSImage for storage
    let nsImage = NSImage(cgImage: cgImage, size: bounds.size)
    
    // Create a rectangle shape to hold the raster image
    let rectShape = VectorShape.rectangle(at: bounds.origin, size: bounds.size)
    var rasterShape = rectShape
    
    // Store the image in the ImageContentRegistry
    ImageContentRegistry.register(image: nsImage, for: rasterShape.id)
    
    // Set up the shape properties
    rasterShape.name = "PostScript Raster Content"
    rasterShape.fillStyle = nil // No fill since we're using the raster image
    rasterShape.strokeStyle = nil // No stroke
    
    return rasterShape
}

