//
//  SVGParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// MARK: - PROFESSIONAL SVG PARSER
class SVGParser: NSObject, XMLParserDelegate {
    var shapes: [VectorShape] = []
    internal var textObjects: [VectorText] = []
    private var currentPath: VectorPath?
    private var currentStroke: StrokeStyle?
    private var currentFill: FillStyle?
    internal var currentTransform = CGAffineTransform.identity
    private var transformStack: [CGAffineTransform] = []
    private var documentSize = CGSize(width: 100, height: 100)
    internal var viewBoxWidth: Double = 100.0
    internal var viewBoxHeight: Double = 100.0
    private var viewBoxX: Double = 0.0
    private var viewBoxY: Double = 0.0
    private var hasViewBox: Bool = false
    private var creator: String?
    private var version: String?
    private var currentElementName = ""
    private var cssStyles: [String: [String: String]] = [:]
    private var currentStyleContent = ""
    internal var currentTextContent = ""
    internal var currentTextAttributes: [String: String] = [:]
    
    // Multi-line text support
    internal var currentTextSpans: [(content: String, attributes: [String: String], x: Double, y: Double)] = []
    internal var isInMultiLineText: Bool = false
    
    // MARK: - Gradient Support
    internal var gradientDefinitions: [String: VectorGradient] = [:]
    internal var currentGradientId: String?
    internal var currentGradientType: String? // "linearGradient" or "radialGradient"
    internal var currentGradientStops: [GradientStop] = []
    internal var currentGradientAttributes: [String: String] = [:]
    internal var isParsingGradient = false
    
    // MARK: - Extreme Value Handling for Radial Gradients
    internal var useExtremeValueHandling = false
    internal var detectedExtremeValues = false
    
    // MARK: - Helper Computed Properties and Functions
    
    /// Computed property for viewBox scale calculations
    private var viewBoxScale: (x: Double, y: Double) {
        return (documentSize.width / viewBoxWidth, documentSize.height / viewBoxHeight)
    }
    
    
    /// Helper function to parse gradient transform angle from attributes
    private func parseGradientTransformAngle(from attributes: [String: String]) -> Double {
        var finalAngle = 0.0
        if let gradientTransform = attributes["gradientTransform"] {
            Log.fileOperation("🔧 Parsing gradientTransform: \(gradientTransform)", level: .info)
            
            // Parse rotate transform
            let rotatePattern = #"rotate\s*\(\s*([+-]?[0-9]*\.?[0-9]+)\s*\)"#
            if let regex = try? NSRegularExpression(pattern: rotatePattern, options: []),
               let match = regex.firstMatch(in: gradientTransform, options: [], range: NSRange(gradientTransform.startIndex..., in: gradientTransform)) {
                
                if let angleRange = Range(match.range(at: 1), in: gradientTransform) {
                    let angleStr = String(gradientTransform[angleRange])
                    if let transformAngle = Double(angleStr) {
                        finalAngle = transformAngle
                        Log.fileOperation("🔄 Found rotate transform: \(transformAngle)°", level: .info)
                    }
                }
            }
            
            // Parse scale transform to check for Y-flip
            let scalePattern = #"scale\s*\(\s*([+-]?[0-9]*\.?[0-9]+)\s*[,\s]+\s*([+-]?[0-9]*\.?[0-9]+)\s*\)"#
            if let regex = try? NSRegularExpression(pattern: scalePattern, options: []),
               let match = regex.firstMatch(in: gradientTransform, options: [], range: NSRange(gradientTransform.startIndex..., in: gradientTransform)) {
                
                if let scaleYRange = Range(match.range(at: 2), in: gradientTransform) {
                    let scaleYStr = String(gradientTransform[scaleYRange])
                    if let scaleY = Double(scaleYStr), scaleY < 0 {
                        Log.fileOperation("🔄 Found Y-flip scale: \(scaleY)", level: .info)
                    }
                }
            }
        }
        return finalAngle
    }
    
    struct ParseResult {
        let shapes: [VectorShape]
        let textObjects: [VectorText]
        let documentSize: CGSize
        let creator: String?
        let version: String?
    }
    
    func parse(_ xmlString: String) throws -> ParseResult {
        guard let data = xmlString.data(using: .utf8) else {
            throw VectorImportError.parsingError("Invalid SVG string", line: nil)
        }
        
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self
        
        if !xmlParser.parse() {
            if let error = xmlParser.parserError {
                throw VectorImportError.parsingError("XML parsing failed: \(error.localizedDescription)", line: xmlParser.lineNumber)
            } else {
                throw VectorImportError.parsingError("Unknown XML parsing error", line: nil)
            }
        }
        
        // Consolidate shapes that share identical gradients into compound paths
        // FIXED: Use the order-preserving consolidation method
        let consolidatedShapes = SVGConsolidationHelpers.consolidateSharedGradientsFixed(in: shapes)
        
        return ParseResult(
            shapes: consolidatedShapes,
            textObjects: textObjects,
            documentSize: documentSize,
            creator: creator,
            version: version
        )
    }

    
    /// Enable extreme value handling for radial gradients that cannot be reproduced
    /// Use this for SVGs with extreme coordinate values that cause rendering issues
    func enableExtremeValueHandling() {
        useExtremeValueHandling = true
        Log.fileOperation("🔧 Enabled extreme value handling for radial gradients", level: .info)
    }
    
    /// Disable extreme value handling (default behavior)
    func disableExtremeValueHandling() {
        useExtremeValueHandling = false
        detectedExtremeValues = false
        Log.fileOperation("🔧 Disabled extreme value handling for radial gradients", level: .info)
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElementName = elementName
        
        switch elementName {
        case "svg":
            parseSVGRoot(attributes: attributeDict)
            
        case "defs":
            // Start of definitions section
            break
            
        case "style":
            // Start of CSS style section
            currentStyleContent = ""
            
        case "g":
            parseGroup(attributes: attributeDict)
            
        case "path":
            parsePath(attributes: attributeDict)
            
        case "rect":
            parseRectangle(attributes: attributeDict)
            
        case "circle":
            parseCircle(attributes: attributeDict)
            
        case "ellipse":
            parseEllipse(attributes: attributeDict)
            
        case "line":
            parseLine(attributes: attributeDict)
            
        case "polyline", "polygon":
            parsePolyline(attributes: attributeDict, closed: elementName == "polygon")
            
        case "text":
            parseText(attributes: attributeDict)
            
        case "tspan":
            // Mark that we're in multi-line text
            isInMultiLineText = true
            
            // Merge tspan class/style for typography overrides
            var overlay = attributeDict
            if let classAttr = attributeDict["class"], !classAttr.isEmpty {
                applyCSSClasses(classAttr, into: &overlay)
            }
            if let style = attributeDict["style"], !style.isEmpty {
                let styleDict = parseStyleAttribute(style)
                for (k, v) in styleDict { overlay[k] = v }
            }
            
            // Store tspan attributes for later processing
            let tspanX = parseLength(overlay["x"]) ?? 0
            let tspanY = parseLength(overlay["y"]) ?? 0
            
            // Create a copy of current text attributes and merge with tspan overrides
            var tspanAttributes = currentTextAttributes
            if let fam = overlay["font-family"], !fam.isEmpty { tspanAttributes["font-family"] = fam }
            if let size = overlay["font-size"], !size.isEmpty { tspanAttributes["font-size"] = size }
            if let fill = overlay["fill"], !fill.isEmpty { tspanAttributes["fill"] = fill }
            
            // Store this tspan for later processing
            currentTextSpans.append((content: "", attributes: tspanAttributes, x: tspanX, y: tspanY))
            break
            
        case "linearGradient":
            parseLinearGradient(attributes: attributeDict)
            
        case "radialGradient":
            parseRadialGradient(attributes: attributeDict)
            
        case "stop":
            parseGradientStop(attributes: attributeDict)
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "svg":
            // Reset transform when exiting SVG root
            if hasViewBox {
                // Keep viewBox transform as the base
                currentTransform = CGAffineTransform.identity
                    .translatedBy(x: -viewBoxX, y: -viewBoxY)
                    .scaledBy(x: viewBoxScale.x, y: viewBoxScale.y)
                } else {
                currentTransform = .identity
            }
            
        case "g":
            // Pop transform stack
            if !transformStack.isEmpty {
                transformStack.removeLast()
                currentTransform = transformStack.last ?? (hasViewBox ? 
                    CGAffineTransform.identity
                        .translatedBy(x: -viewBoxX, y: -viewBoxY)
                        .scaledBy(x: viewBoxScale.x, y: viewBoxScale.y) : 
                    .identity)
            }
            
        case "style":
            // Parse CSS styles
            parseCSSStyles(currentStyleContent)
            currentStyleContent = ""
            
        case "text":
            // Finish parsing text element
            finishTextElement()
            
        case "linearGradient", "radialGradient":
            // Finish parsing gradient element
            finishGradientElement()
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElementName == "style" {
            currentStyleContent += string
        } else if currentElementName == "text" {
            currentTextContent += string
        } else if currentElementName == "tspan" {
            // Add content to the current tspan
            if !currentTextSpans.isEmpty {
                let lastIndex = currentTextSpans.count - 1
                currentTextSpans[lastIndex].content += string
            } else {
                // Fallback: add to main text content
                currentTextContent += string
            }
        }
    }
    
    // MARK: - CSS Style Parsing
    
    private func parseCSSStyles(_ cssContent: String) {
        Log.fileOperation("🎨 Parsing CSS styles", level: .info)
        
        // Parse CSS rules from style content
        let rules = cssContent.components(separatedBy: "}")
        
        for rule in rules {
            let parts = rule.components(separatedBy: "{")
            if parts.count == 2 {
                let selector = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let declarations = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                
                var styles: [String: String] = [:]
                
                // Parse individual declarations
                let declParts = declarations.components(separatedBy: ";")
                for decl in declParts {
                    let keyValue = decl.components(separatedBy: ":")
                    if keyValue.count >= 2 {
                        let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        // Join back in case the value contains colons (like in URLs)
                        let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                        styles[key] = value
                    }
                }
                
                cssStyles[selector] = styles
                Log.fileOperation("📋 Added CSS rule: \(selector) -> \(styles)", level: .info)
            }
        }
        
        Log.info("✅ CSS parsing complete - \(cssStyles.count) rules parsed", category: .fileOperations)
    }

    // Apply space-separated CSS classes from a class attribute into an attribute dictionary
    internal func applyCSSClasses(_ classAttr: String, into attributes: inout [String: String]) {
        let classNames = classAttr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for cls in classNames {
            let selector = "." + cls
            if let classStyles = cssStyles[selector] {
                for (key, value) in classStyles {
                    if attributes[key] == nil { attributes[key] = value }
                }
            }
        }
        // Handle comma-joined selectors like ".st3, .st4"
        for (selector, styles) in cssStyles where selector.contains(",") {
            let selectors = selector.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for cls in classNames {
                if selectors.contains("." + cls) {
                    for (key, value) in styles {
                        if attributes[key] == nil { attributes[key] = value }
                    }
                }
            }
        }
    }
    
    // MARK: - SVG Element Parsers
    

    
    private func parseSVGRoot(attributes: [String: String]) {
        // Parse width and height first
        if let width = attributes["width"], let height = attributes["height"] {
            let w = parseLength(width) ?? 100
            let h = parseLength(height) ?? 100
            documentSize = CGSize(width: w, height: h)
        }
        
        // Parse viewBox
        if let viewBox = attributes["viewBox"] {
            let parts = viewBox.split(separator: " ").compactMap { Double($0) }
            if parts.count >= 4 {
                // viewBox format: "x y width height"
                viewBoxX = parts[0]
                viewBoxY = parts[1]
                viewBoxWidth = parts[2] 
                viewBoxHeight = parts[3]
                hasViewBox = true
                
                Log.fileOperation("🔧 ViewBox parsed: x=\(viewBoxX), y=\(viewBoxY), width=\(viewBoxWidth), height=\(viewBoxHeight)", level: .info)
                
                // If no explicit width/height, use viewBox dimensions
                if attributes["width"] == nil && attributes["height"] == nil {
                    documentSize = CGSize(width: viewBoxWidth, height: viewBoxHeight)
                }
                
                // Calculate the viewBox transform
                let scaleX = viewBoxScale.x
                let scaleY = viewBoxScale.y
                
                // Apply viewBox transform as the base transform
                currentTransform = CGAffineTransform.identity
                    .translatedBy(x: -viewBoxX, y: -viewBoxY)
                    .scaledBy(x: scaleX, y: scaleY)
                
                Log.fileOperation("🔄 ViewBox transform: scale=(\(scaleX), \(scaleY)), translate=(\(-viewBoxX), \(-viewBoxY))", level: .info)
            }
        } else {
            // No viewBox, use document size
            viewBoxWidth = documentSize.width
            viewBoxHeight = documentSize.height
        }
        
        creator = attributes["data-name"] ?? attributes["generator"]
        version = attributes["version"]
    }
    
    private func parseGroup(attributes: [String: String]) {
        // Save current transform and apply group transform
        transformStack.append(currentTransform)
        
        if let transform = attributes["transform"] {
            let groupTransform = parseTransform(transform)
            currentTransform = currentTransform.concatenating(groupTransform)
            Log.fileOperation("🔄 Group transform applied: \(transform)", level: .info)
        }
    }
    
    private func parsePath(attributes: [String: String]) {
        guard let d = attributes["d"] else { return }
        
        Log.info("🔍 Parsing SVG path: \(d)", category: .general)
        
        let pathData = parsePathData(d)
        let vectorPath = VectorPath(elements: pathData)
        
        Log.fileOperation("📐 Created path with \(pathData.count) elements", level: .info)
        
        let shape = createShape(
            name: "Path",
            path: vectorPath,
            attributes: attributes
        )
        
        if let fill = shape.fillStyle {
            Log.fileOperation("🎨 Shape has fill style: \(fill)", level: .info)
        } else {
            Log.fileOperation("⚪ Shape has no fill", level: .info)
        }
        if let stroke = shape.strokeStyle {
            Log.fileOperation("🖊️ Shape has stroke style: \(stroke)", level: .info)
        } else {
            Log.fileOperation("📝 Shape has no stroke", level: .info)
        }
        
        shapes.append(shape)
        Log.info("✅ Added shape to collection - total: \(shapes.count)", category: .fileOperations)
    }
    
    
    
    
    
    
    // MARK: - Helper Functions
    
    func createShape(name: String, path: VectorPath, attributes: [String: String], geometricType: GeometricShapeType? = nil) -> VectorShape {
        // Merge CSS class styles with inline styles
        var mergedAttributes = attributes
        
        if let className = attributes["class"] {
            Log.fileOperation("🏷️ Processing classes: \(className)", level: .info)
            // Handle multiple classes separated by spaces
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    Log.info("✅ Found styles for \(selector): \(classStyles)", category: .fileOperations)
                    // CSS class styles have lower priority than inline styles
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                            Log.info("   Applied \(key): \(value)", category: .general)
                        }
                    }
                } else {
                    Log.error("❌ No styles found for \(selector)", category: .error)
                }
            }
        }
        
        // Also check for combined class selectors (e.g., ".cls-1, .cls-2, .cls-3")
        for (selector, styles) in cssStyles {
            if selector.contains(",") {
                // Split comma-separated selectors
                let selectors = selector.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if let className = attributes["class"] {
                    let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    for cls in classNames {
                        if selectors.contains("." + cls) {
                            // Apply these styles
                            for (key, value) in styles {
                                if mergedAttributes[key] == nil {
                                    mergedAttributes[key] = value
                                }
                            }
                            break
                        }
                    }
                }
            }
        }
        
        let stroke = parseStrokeStyle(mergedAttributes)
        let fill = parseFillStyle(mergedAttributes)
        
        // CRITICAL FIX: Don't apply SVG transforms to our own exported shapes since coordinates are already transformed
        // Only apply transforms for external SVGs that use transform attributes
        let transform: CGAffineTransform
        if mergedAttributes["transform"] != nil {
            // External SVG with transform attribute - apply it
            // CRITICAL: Apply viewBox transform AFTER shape transform to ensure objects stay within bounds
            let shapeTransform = parseTransform(mergedAttributes["transform"] ?? "")
            transform = currentTransform.concatenating(shapeTransform)
            Log.fileOperation("🔄 Applied external SVG transform (viewBox → shape transform)", level: .info)
        } else {
            // Our own exported SVG (no transform attribute) - coordinates are already correct
            transform = currentTransform.isIdentity ? .identity : currentTransform
            Log.info("✅ Using identity transform for logos-exported shape", category: .fileOperations)
        }
        
        return VectorShape(
            name: name,
            path: path,
            geometricType: geometricType,
            strokeStyle: stroke,
            fillStyle: fill,
            transform: transform
        )
    }
    
    
    /// Parse gradient coordinate using GradientCoordinateConverter
    internal func parseGradientCoordinate(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, useExtremeValueHandling: Bool = false) -> Double {
        return GradientCoordinateConverter.parseGradientCoordinate(
            value, 
            gradientUnits: gradientUnits, 
            isXCoordinate: isXCoordinate, 
            useExtremeValueHandling: useExtremeValueHandling,
            viewBoxWidth: viewBoxWidth,
            viewBoxHeight: viewBoxHeight
        )
    }
    
    /// ENHANCED RADIAL GRADIENT COORDINATE PARSING FOR EXTREME VALUES
    private func parseRadialGradientCoordinateExtreme(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true) -> Double {
        return GradientCoordinateConverter.parseRadialGradientCoordinateExtreme(
            value,
            gradientUnits: gradientUnits,
            isXCoordinate: isXCoordinate,
            viewBoxWidth: viewBoxWidth,
            viewBoxHeight: viewBoxHeight
        )
    }
    
    
    
    
}
