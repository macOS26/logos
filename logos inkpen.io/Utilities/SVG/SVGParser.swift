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
    private var shapes: [VectorShape] = []
    private var textObjects: [VectorText] = []
    private var currentPath: VectorPath?
    private var currentStroke: StrokeStyle?
    private var currentFill: FillStyle?
    private var currentTransform = CGAffineTransform.identity
    private var transformStack: [CGAffineTransform] = []
    private var documentSize = CGSize(width: 100, height: 100)
    private var viewBoxWidth: Double = 100.0
    private var viewBoxHeight: Double = 100.0
    private var viewBoxX: Double = 0.0
    private var viewBoxY: Double = 0.0
    private var hasViewBox: Bool = false
    private var creator: String?
    private var version: String?
    private var currentElementName = ""
    private var cssStyles: [String: [String: String]] = [:]
    private var currentStyleContent = ""
    private var currentTextContent = ""
    private var currentTextAttributes: [String: String] = [:]
    
    // Multi-line text support
    private var currentTextSpans: [(content: String, attributes: [String: String], x: Double, y: Double)] = []
    private var isInMultiLineText: Bool = false
    
    // MARK: - Gradient Support
    private var gradientDefinitions: [String: VectorGradient] = [:]
    private var currentGradientId: String?
    private var currentGradientType: String? // "linearGradient" or "radialGradient"
    private var currentGradientStops: [GradientStop] = []
    private var currentGradientAttributes: [String: String] = [:]
    private var isParsingGradient = false
    
    // MARK: - Extreme Value Handling for Radial Gradients
    private var useExtremeValueHandling = false
    private var detectedExtremeValues = false
    
    // MARK: - Helper Computed Properties and Functions
    
    /// Computed property for viewBox scale calculations
    private var viewBoxScale: (x: Double, y: Double) {
        return (documentSize.width / viewBoxWidth, documentSize.height / viewBoxHeight)
    }
    
    /// Helper function to parse gradient units from attributes
    private func parseGradientUnits(from attributes: [String: String]) -> GradientUnits {
        return GradientUnits(rawValue: attributes["gradientUnits"] ?? "objectBoundingBox") ?? .objectBoundingBox
    }
    
    /// Helper function to parse spread method from attributes
    private func parseSpreadMethod(from attributes: [String: String]) -> GradientSpreadMethod {
        return GradientSpreadMethod(rawValue: attributes["spreadMethod"] ?? "pad") ?? .pad
    }
    
    /// Helper function to parse radial gradient coordinates from attributes
    private func parseRadialGradientCoordinates(from attributes: [String: String]) -> (cx: String, cy: String, r: String, fx: String?, fy: String?) {
        return (
            cx: attributes["cx"] ?? "50%",
            cy: attributes["cy"] ?? "50%", 
            r: attributes["r"] ?? "50%",
            fx: attributes["fx"],
            fy: attributes["fy"]
        )
    }
    
    /// Helper function to convert degrees to radians
    private func degreesToRadians(_ degrees: Double) -> Double {
        return degrees * .pi / 180.0
    }
    
    /// Helper function to convert radians to degrees
    private func radiansToDegrees(_ radians: Double) -> Double {
        return radians * 180.0 / .pi
    }
    
    /// Helper function to parse gradient transform from attributes
    private func parseGradientTransformFromAttributes(_ attributes: [String: String]) -> (angle: Double, scaleX: Double, scaleY: Double) {
        var gradientAngle: Double = 0.0
        var gradientScaleX: Double = 1.0
        var gradientScaleY: Double = 1.0
        
        if let gradientTransformRaw = attributes["gradientTransform"] {
            Log.fileOperation("🔄 Parsing gradientTransform: \(gradientTransformRaw)", level: .info)
            let transforms = parseGradientTransform(gradientTransformRaw)
            gradientAngle = transforms.angle
            gradientScaleX = transforms.scaleX
            gradientScaleY = transforms.scaleY
            Log.fileOperation("🔄 Extracted: angle=\(gradientAngle)°, scaleX=\(gradientScaleX), scaleY=\(gradientScaleY)", level: .info)
        }
        
        return (angle: gradientAngle, scaleX: gradientScaleX, scaleY: gradientScaleY)
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
        let consolidatedShapes = consolidateSharedGradientsFixed(in: shapes)
        
        return ParseResult(
            shapes: consolidatedShapes,
            textObjects: textObjects,
            documentSize: documentSize,
            creator: creator,
            version: version
        )
    }

    // MARK: - Gradient Consolidation
    private func consolidateSharedGradients(in inputShapes: [VectorShape]) -> [VectorShape] {
        guard !inputShapes.isEmpty else { return inputShapes }
        
        // Group shapes by layer affinity is unknown here; shapes are already appended in order.
        // We’ll conservatively consolidate only shapes that have:
        // - same blend mode and opacity
        // - same fill gradient signature
        // - are not clipping paths and not groups/warp objects
        
        struct GroupKey: Hashable {
            let blendMode: BlendMode
            let opacity: Double
            let gradientSig: String
        }
        
        var buckets: [GroupKey: [VectorShape]] = [:]
        var passthrough: [VectorShape] = []
        
        for shape in inputShapes {
            guard let fill = shape.fillStyle,
                  case .gradient(let g) = fill.color,
                  !shape.isGroup,
                  !shape.isWarpObject,
                  !shape.isClippingPath else {
                passthrough.append(shape)
                continue
            }
            let key = GroupKey(blendMode: shape.blendMode, opacity: fill.opacity, gradientSig: g.signature)
            buckets[key, default: []].append(shape)
        }
        
        var result: [VectorShape] = []
        
        // Add non-gradient or excluded shapes back
        result.append(contentsOf: passthrough)
        
        // For each bucket, if there is more than one shape, build a compound path
        for (key, shapes) in buckets {
            if shapes.count == 1 {
                result.append(shapes[0])
                continue
            }
            
            // Attempt to union paths. If union fails, fall back to multi-subpath compound without boolean union.
            let cgPaths: [CGPath] = shapes.map { $0.path.cgPath }
            
            // Try CoreGraphics union on pairs iteratively (best-effort; falls back on simple merge)
            var combined: CGPath? = cgPaths.first
            for p in cgPaths.dropFirst() {
                if let c = combined, let u = CoreGraphicsPathOperations.union(c, p, using: .winding) {
                    combined = u
                } else {
                    combined = nil
                    break
                }
            }
            
            let compoundPath: VectorPath
            if let unified = combined {
                compoundPath = VectorPath(cgPath: unified, fillRule: .winding)
            } else {
                // Build a compound-like path by concatenating subpaths
                var elements: [PathElement] = []
                for p in cgPaths {
                    let vp = VectorPath(cgPath: p)
                    elements.append(contentsOf: vp.elements)
                }
                compoundPath = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
            }
            
            // Use first shape’s style as canonical
            let base = shapes[0]
            var compound = VectorShape(
                name: "Compound Gradient",
                path: compoundPath,
                geometricType: nil,
                strokeStyle: nil,
                fillStyle: base.fillStyle,
                transform: .identity,
                isVisible: true,
                isLocked: false,
                opacity: base.opacity,
                blendMode: key.blendMode,
                isGroup: false,
                groupedShapes: [],
                groupTransform: .identity,
                isCompoundPath: true,
                isWarpObject: false,
                originalPath: nil,
                warpEnvelope: [],
                originalEnvelope: [],
                isRoundedRectangle: false,
                originalBounds: nil,
                cornerRadii: []
            )
            compound.updateBounds()
            result.append(compound)
        }
        
        return result
    }
    
    // MARK: - Fixed Gradient Consolidation (Order-Preserving)
    /// Fixed version that preserves the original order of shapes while consolidating gradients
    /// The original method put all non-gradient shapes first, then all gradient shapes
    /// This method maintains the original SVG order
    private func consolidateSharedGradientsFixed(in inputShapes: [VectorShape]) -> [VectorShape] {
        guard !inputShapes.isEmpty else { return inputShapes }
        
        struct GroupKey: Hashable {
            let blendMode: BlendMode
            let opacity: Double
            let gradientSig: String
        }
        
        var buckets: [GroupKey: [VectorShape]] = [:]
        var shapeToBucketMap: [VectorShape: GroupKey] = [:]
        
        // First pass: categorize shapes and build buckets
        for shape in inputShapes {
            guard let fill = shape.fillStyle,
                  case .gradient(let g) = fill.color,
                  !shape.isGroup,
                  !shape.isWarpObject,
                  !shape.isClippingPath else {
                continue
            }
            let key = GroupKey(blendMode: shape.blendMode, opacity: fill.opacity, gradientSig: g.signature)
            buckets[key, default: []].append(shape)
            shapeToBucketMap[shape] = key
        }
        
        // Create consolidated shapes for buckets with multiple shapes
        var consolidatedShapes: [GroupKey: VectorShape] = [:]
        for (key, shapes) in buckets {
            if shapes.count == 1 {
                consolidatedShapes[key] = shapes[0]
                continue
            }
            
            // Attempt to union paths. If union fails, fall back to multi-subpath compound without boolean union.
            let cgPaths: [CGPath] = shapes.map { $0.path.cgPath }
            
            // Try CoreGraphics union on pairs iteratively (best-effort; falls back on simple merge)
            var combined: CGPath? = cgPaths.first
            for p in cgPaths.dropFirst() {
                if let c = combined, let u = CoreGraphicsPathOperations.union(c, p, using: .winding) {
                    combined = u
                } else {
                    combined = nil
                    break
                }
            }
            
            let compoundPath: VectorPath
            if let unified = combined {
                compoundPath = VectorPath(cgPath: unified, fillRule: .winding)
            } else {
                // Build a compound-like path by concatenating subpaths
                var elements: [PathElement] = []
                for p in cgPaths {
                    let vp = VectorPath(cgPath: p)
                    elements.append(contentsOf: vp.elements)
                }
                compoundPath = VectorPath(elements: elements, isClosed: true, fillRule: .winding)
            }
            
            // Use first shape's style as canonical
            let base = shapes[0]
            var compound = VectorShape(
                name: "Compound Gradient",
                path: compoundPath,
                geometricType: nil,
                strokeStyle: nil,
                fillStyle: base.fillStyle,
                transform: .identity,
                isVisible: true,
                isLocked: false,
                opacity: base.opacity,
                blendMode: key.blendMode,
                isGroup: false,
                groupedShapes: [],
                groupTransform: .identity,
                isCompoundPath: true,
                isWarpObject: false,
                originalPath: nil,
                warpEnvelope: [],
                originalEnvelope: [],
                isRoundedRectangle: false,
                originalBounds: nil,
                cornerRadii: []
            )
            compound.updateBounds()
            consolidatedShapes[key] = compound
        }
        
        // Second pass: reconstruct the original order while using consolidated shapes
        var result: [VectorShape] = []
        for shape in inputShapes {
            if let key = shapeToBucketMap[shape] {
                // This is a gradient shape - use the consolidated version if it exists
                if let consolidatedShape = consolidatedShapes[key] {
                    // Only add the consolidated shape once (for the first occurrence)
                    if !result.contains(where: { $0.id == consolidatedShape.id }) {
                        result.append(consolidatedShape)
                    }
                } else {
                    // Single shape, add as-is
                    result.append(shape)
                }
            } else {
                // Non-gradient shape, add as-is
                result.append(shape)
            }
        }
        
        return result
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
    private func applyCSSClasses(_ classAttr: String, into attributes: inout [String: String]) {
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
    
    private func parseText(attributes: [String: String]) {
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
    
    private func finishTextElement() {
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
                
                let typography = TypographyProperties(
                    fontFamily: firstFontFamily,
                    fontSize: firstFontSize,
                    lineHeight: firstFontSize * 1.2, // Standard line spacing
                    strokeColor: .black,
                    fillColor: firstFillColor
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
            
            let typography = TypographyProperties(
                fontFamily: fontFamily,
                fontSize: fontSize,
                lineHeight: fontSize,
                strokeColor: .black,
                fillColor: parseColor(fill) ?? .black
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

    // Extract a font-family from either the explicit attribute or inline style
    private func extractFontFamily(from attributes: [String: String]) -> String? {
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
    private func normalizeFontFamily(_ rawFamily: String?) -> String {
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
    
    private func parseRectangle(attributes: [String: String]) {
        let x = parseLength(attributes["x"]) ?? 0
        let y = parseLength(attributes["y"]) ?? 0
        let width = parseLength(attributes["width"]) ?? 0
        let height = parseLength(attributes["height"]) ?? 0
        let rx = parseLength(attributes["rx"]) ?? 0
        let ry = parseLength(attributes["ry"]) ?? 0
        
        let elements: [PathElement]
        
        if rx > 0 || ry > 0 {
            // Rounded rectangle
            let radiusX = rx
            let radiusY = ry == 0 ? rx : ry
            
            elements = [
                .move(to: VectorPoint(x + radiusX, y)),
                .line(to: VectorPoint(x + width - radiusX, y)),
                .curve(to: VectorPoint(x + width, y + radiusY),
                       control1: VectorPoint(x + width, y),
                       control2: VectorPoint(x + width, y + radiusY)),
                .line(to: VectorPoint(x + width, y + height - radiusY)),
                .curve(to: VectorPoint(x + width - radiusX, y + height),
                       control1: VectorPoint(x + width, y + height),
                       control2: VectorPoint(x + width - radiusX, y + height)),
                .line(to: VectorPoint(x + radiusX, y + height)),
                .curve(to: VectorPoint(x, y + height - radiusY),
                       control1: VectorPoint(x, y + height),
                       control2: VectorPoint(x, y + height - radiusY)),
                .line(to: VectorPoint(x, y + radiusY)),
                .curve(to: VectorPoint(x + radiusX, y),
                       control1: VectorPoint(x, y),
                       control2: VectorPoint(x + radiusX, y)),
                .close
            ]
        } else {
            // Regular rectangle
            elements = [
                .move(to: VectorPoint(x, y)),
                .line(to: VectorPoint(x + width, y)),
                .line(to: VectorPoint(x + width, y + height)),
                .line(to: VectorPoint(x, y + height)),
                .close
            ]
        }
        
        let vectorPath = VectorPath(elements: elements, isClosed: true)
        let shape = createShape(
            name: "Rectangle",
            path: vectorPath,
            attributes: attributes,
            geometricType: rx > 0 || ry > 0 ? .roundedRectangle : .rectangle
        )
        
        shapes.append(shape)
    }
    
    private func parseCircle(attributes: [String: String]) {
        let cx = parseLength(attributes["cx"]) ?? 0
        let cy = parseLength(attributes["cy"]) ?? 0
        let r = parseLength(attributes["r"]) ?? 0
        
        let center = CGPoint(x: cx, y: cy)
        let shape = VectorShape.circle(center: center, radius: r)
        
        let finalShape = createShape(
            name: "Circle",
            path: shape.path,
            attributes: attributes,
            geometricType: .circle
        )
        
        shapes.append(finalShape)
    }
    
    private func parseEllipse(attributes: [String: String]) {
        let cx = parseLength(attributes["cx"]) ?? 0
        let cy = parseLength(attributes["cy"]) ?? 0
        let rx = parseLength(attributes["rx"]) ?? 0
        let ry = parseLength(attributes["ry"]) ?? 0
        
        // Create ellipse using bezier curves
        let elements: [PathElement] = [
            .move(to: VectorPoint(cx + rx, cy)),
            .curve(to: VectorPoint(cx, cy + ry),
                   control1: VectorPoint(cx + rx, cy + ry * 0.552),
                   control2: VectorPoint(cx + rx * 0.552, cy + ry)),
            .curve(to: VectorPoint(cx - rx, cy),
                   control1: VectorPoint(cx - rx * 0.552, cy + ry),
                   control2: VectorPoint(cx - rx, cy + ry * 0.552)),
            .curve(to: VectorPoint(cx, cy - ry),
                   control1: VectorPoint(cx - rx, cy - ry * 0.552),
                   control2: VectorPoint(cx - rx * 0.552, cy - ry)),
            .curve(to: VectorPoint(cx + rx, cy),
                   control1: VectorPoint(cx + rx * 0.552, cy - ry),
                   control2: VectorPoint(cx + rx, cy - ry * 0.552)),
            .close
        ]
        
        let vectorPath = VectorPath(elements: elements, isClosed: true)
        let shape = createShape(
            name: "Ellipse",
            path: vectorPath,
            attributes: attributes,
            geometricType: .ellipse
        )
        
        shapes.append(shape)
    }
    
    private func parseLine(attributes: [String: String]) {
        let x1 = parseLength(attributes["x1"]) ?? 0
        let y1 = parseLength(attributes["y1"]) ?? 0
        let x2 = parseLength(attributes["x2"]) ?? 0
        let y2 = parseLength(attributes["y2"]) ?? 0
        
        let elements: [PathElement] = [
            .move(to: VectorPoint(x1, y1)),
            .line(to: VectorPoint(x2, y2))
        ]
        
        let vectorPath = VectorPath(elements: elements, isClosed: false)
        let shape = createShape(
            name: "Line",
            path: vectorPath,
            attributes: attributes,
            geometricType: .line
        )
        
        shapes.append(shape)
    }
    
    private func parsePolyline(attributes: [String: String], closed: Bool) {
        guard let pointsString = attributes["points"] else { return }
        
        let points = parsePoints(pointsString)
        guard !points.isEmpty else { return }
        
        var elements: [PathElement] = [.move(to: VectorPoint(points[0]))]
        
        for i in 1..<points.count {
            elements.append(.line(to: VectorPoint(points[i])))
        }
        
        if closed {
            elements.append(.close)
        }
        
        let vectorPath = VectorPath(elements: elements, isClosed: closed)
        let shape = createShape(
            name: closed ? "Polygon" : "Polyline",
            path: vectorPath,
            attributes: attributes,
            geometricType: closed ? .polygon : nil
        )
        
        shapes.append(shape)
    }
    
    // MARK: - Helper Functions
    
    private func createShape(name: String, path: VectorPath, attributes: [String: String], geometricType: GeometricShapeType? = nil) -> VectorShape {
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
    
    private func parseStrokeStyle(_ attributes: [String: String]) -> StrokeStyle? {
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
            Log.info("🔍 Looking for stroke gradient: \(gradientId)", category: .general)
            Log.info("🔍 Available gradients: \(gradientDefinitions.keys.sorted())", category: .general)
            
                    if let gradient = gradientDefinitions[gradientId] {
            let width = parseLength(attributes["stroke-width"]) ?? 1.0
            let opacity = parseLength(attributes["stroke-opacity"]) ?? 1.0
            Log.info("✅ Applied gradient stroke: \(gradientId)", category: .fileOperations)
            return StrokeStyle(gradient: gradient, width: width, placement: .center, opacity: opacity)
        }
        Log.error("❌ Gradient reference not found for stroke: \(gradientId)", category: .error)
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
    
    private func parseFillStyle(_ attributes: [String: String]) -> FillStyle? {
        let fill = attributes["fill"] ?? "black"
        guard fill != "none" else { return nil }
        
        // Check for gradient reference: url(#gradientId)
        if fill.hasPrefix("url(#") && fill.hasSuffix(")") {
            let gradientId = String(fill.dropFirst(5).dropLast(1)) // Remove "url(#" and ")"
            Log.info("🔍 Looking for fill gradient: \(gradientId)", category: .general)
            Log.info("🔍 Available gradients: \(gradientDefinitions.keys.sorted())", category: .general)
            
            if let gradient = gradientDefinitions[gradientId] {
                let opacity = parseLength(attributes["fill-opacity"]) ?? 1.0
                Log.info("✅ Applied gradient fill: \(gradientId)", category: .fileOperations)
                return FillStyle(gradient: gradient, opacity: opacity)
            }
            Log.error("❌ Gradient reference not found for fill: \(gradientId)", category: .error)
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
    
    private func parseColor(_ colorString: String) -> VectorColor? {
        let color = colorString.trimmingCharacters(in: .whitespaces)
        
        if color.hasPrefix("#") {
            // Hex color
            let hex = String(color.dropFirst())
            if hex.count == 6 {
                let r = Double(Int(hex.prefix(2), radix: 16) ?? 0) / 255.0
                let g = Double(Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255.0
                let b = Double(Int(hex.suffix(2), radix: 16) ?? 0) / 255.0
                return .rgb(RGBColor(red: r, green: g, blue: b))
            } else if hex.count == 3 {
                // Short hex format #RGB -> #RRGGBB
                let r = Double(Int(String(hex.prefix(1)), radix: 16) ?? 0) / 15.0
                let g = Double(Int(String(hex.dropFirst().prefix(1)), radix: 16) ?? 0) / 15.0
                let b = Double(Int(String(hex.suffix(1)), radix: 16) ?? 0) / 15.0
                return .rgb(RGBColor(red: r, green: g, blue: b))
            }
        } else if color.hasPrefix("rgb(") {
            // RGB color
            let content = color.dropFirst(4).dropLast()
            let components = content.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if components.count >= 3 {
                return .rgb(RGBColor(red: components[0]/255.0, green: components[1]/255.0, blue: components[2]/255.0))
            }
        } else {
            // Named colors
            switch color.lowercased() {
            case "black": return .black
            case "white": return .white
            case "red": return .rgb(RGBColor(red: 1, green: 0, blue: 0))
            case "green": return .rgb(RGBColor(red: 0, green: 1, blue: 0))
            case "blue": return .rgb(RGBColor(red: 0, green: 0, blue: 1))
            case "yellow": return .rgb(RGBColor(red: 1, green: 1, blue: 0))
            case "cyan": return .rgb(RGBColor(red: 0, green: 1, blue: 1))
            case "magenta": return .rgb(RGBColor(red: 1, green: 0, blue: 1))
            case "orange": return .rgb(RGBColor(red: 1, green: 0.5, blue: 0))
            case "purple": return .rgb(RGBColor(red: 0.5, green: 0, blue: 1))
            case "lime": return .rgb(RGBColor(red: 0, green: 1, blue: 0))
            case "navy": return .rgb(RGBColor(red: 0, green: 0, blue: 0.5))
            case "teal": return .rgb(RGBColor(red: 0, green: 0.5, blue: 0.5))
            case "silver": return .rgb(RGBColor(red: 0.75, green: 0.75, blue: 0.75))
            case "gray", "grey": return .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5))
            case "maroon": return .rgb(RGBColor(red: 0.5, green: 0, blue: 0))
            case "olive": return .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0))
            case "aqua": return .rgb(RGBColor(red: 0, green: 1, blue: 1))
            case "fuchsia": return .rgb(RGBColor(red: 1, green: 0, blue: 1))
            default: return .black
            }
        }
        
        return nil
    }
    
    private func parseLength(_ value: String?) -> Double? {
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
    
    /// Parse gradient coordinate with enhanced SVG compatibility and proper userSpaceOnUse handling
    /// This version includes extreme value handling for radial gradients that cannot be reproduced
    private func parseGradientCoordinate(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, useExtremeValueHandling: Bool = false) -> Double {
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
                    print("   Mapping: \(normalizedValue < 0.0 || normalizedValue > 1.0 ? (useExtremeValueHandling ? "outside 0-1→proportional mapping" : "outside 0-1→0.5") : "within 0-1 range")")
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
    private func parseRadialGradientCoordinateExtreme(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true) -> Double {
        return parseGradientCoordinate(value, gradientUnits: gradientUnits, isXCoordinate: isXCoordinate, useExtremeValueHandling: true)
    }
    
    private func parseTransform(_ transformString: String) -> CGAffineTransform {
        // Professional SVG transform parsing that handles multiple transforms and proper order
        var transform = CGAffineTransform.identity
        
        // Split the transform string into individual transform functions
        let transformRegex = try! NSRegularExpression(pattern: "(\\w+)\\s*\\(([^)]*)\\)", options: [])
        let matches = transformRegex.matches(in: transformString, options: [], range: NSRange(location: 0, length: transformString.count))
        
        // Process transforms in order (they should be applied left to right)
        for match in matches {
            guard match.numberOfRanges >= 3 else { continue }
            
            let transformType = (transformString as NSString).substring(with: match.range(at: 1))
            let paramsString = (transformString as NSString).substring(with: match.range(at: 2))
            
            // Parse parameters - handle both comma and space separated values
            let params = paramsString
                .replacingOccurrences(of: ",", with: " ")
                .split(separator: " ")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            
            switch transformType.lowercased() {
            case "translate":
                if params.count >= 2 {
                    transform = transform.translatedBy(x: params[0], y: params[1])
                } else if params.count == 1 {
                    transform = transform.translatedBy(x: params[0], y: 0)
                }
                
            case "scale":
                if params.count >= 2 {
                    transform = transform.scaledBy(x: params[0], y: params[1])
                } else if params.count == 1 {
                    transform = transform.scaledBy(x: params[0], y: params[0])
                }
                
            case "rotate":
                // Handle rotate(angle [cx cy])
                if params.count >= 3 {
                    // Rotation around a point: translate(-cx,-cy), rotate, translate(cx,cy)
                    let angle = degreesToRadians(params[0])
                    let cx = params[1]
                    let cy = params[2]
                    transform = transform.translatedBy(x: cx, y: cy)
                    transform = transform.rotated(by: angle)
                    transform = transform.translatedBy(x: -cx, y: -cy)
                } else if params.count >= 1 {
                    // Simple rotation around origin
                    let angle = degreesToRadians(params[0])
                    transform = transform.rotated(by: angle)
                }
                
            case "skewx":
                if params.count >= 1 {
                    let angle = degreesToRadians(params[0])
                    transform = CGAffineTransform(a: transform.a, b: transform.b,
                                                 c: transform.c + transform.a * tan(angle),
                                                 d: transform.d + transform.b * tan(angle),
                                                 tx: transform.tx, ty: transform.ty)
                }
                
            case "skewy":
                if params.count >= 1 {
                    let angle = degreesToRadians(params[0])
                    transform = CGAffineTransform(a: transform.a + transform.c * tan(angle),
                                                 b: transform.b + transform.d * tan(angle),
                                                 c: transform.c, d: transform.d,
                                                 tx: transform.tx, ty: transform.ty)
                }
                
            case "matrix":
                if params.count >= 6 {
                    // matrix(a b c d e f) maps to CGAffineTransform(a, b, c, d, tx, ty)
                    let newTransform = CGAffineTransform(a: params[0], b: params[1],
                                                        c: params[2], d: params[3],
                                                        tx: params[4], ty: params[5])
                    transform = transform.concatenating(newTransform)
                }
                
            default:
                Log.fileOperation("⚠️ Unknown transform type: \(transformType)", level: .info)
            }
        }
        
        return transform
    }
    
    // MARK: - Gradient Parsing Methods
    
    private func parseLinearGradient(attributes: [String: String]) {
        guard let id = attributes["id"] else {
            Log.fileOperation("⚠️ Linear gradient missing id attribute", level: .info)
            return
        }
        
        currentGradientId = id
        currentGradientType = "linearGradient"
        currentGradientAttributes = attributes
        currentGradientStops = []
        isParsingGradient = true
        
        Log.fileOperation("🎨 Parsing linear gradient: \(id)", level: .info)
        print("   - x1: \(attributes["x1"] ?? "0%"), y1: \(attributes["y1"] ?? "0%")")
        print("   - x2: \(attributes["x2"] ?? "100%"), y2: \(attributes["y2"] ?? "0%")")
        print("   - gradientUnits: \(attributes["gradientUnits"] ?? "objectBoundingBox")")
    }
    
    private func parseRadialGradient(attributes: [String: String]) {
        guard let id = attributes["id"] else {
            Log.fileOperation("⚠️ Radial gradient missing id attribute", level: .info)
            return
        }
        
        currentGradientId = id
        currentGradientType = "radialGradient"
        currentGradientAttributes = attributes
        currentGradientStops = []
        isParsingGradient = true
        
        // DETECT EXTREME VALUES: Check if this radial gradient has extreme coordinates
        let (cxRaw, cyRaw, rRaw, fxRaw, fyRaw) = parseRadialGradientCoordinates(from: attributes)
        
        // Check for extreme values in coordinates
        let hasExtremeValues = detectExtremeValuesInRadialGradient(
            cx: cxRaw, cy: cyRaw, r: rRaw, fx: fxRaw, fy: fyRaw
        )
        
        if hasExtremeValues {
            detectedExtremeValues = true
            useExtremeValueHandling = true
            Log.fileOperation("🚨 EXTREME VALUES DETECTED in radial gradient: \(id)", level: .info)
            Log.info("   Enabling extreme value handling for this gradient", category: .general)
        }
        
        Log.fileOperation("🎨 Parsing radial gradient: \(id) (extreme handling: \(useExtremeValueHandling))", level: .info)
    }
    
    /// Detect extreme values in radial gradient coordinates that require special handling
    /// Trigger extreme value handling if normalized coordinates are not between 0-1
    private func detectExtremeValuesInRadialGradient(cx: String, cy: String, r: String, fx: String?, fy: String?) -> Bool {
        let coordinates = [cx, cy, r, fx, fy].compactMap { $0 }
        
        for coord in coordinates {
            // Skip percentage values
            if coord.hasSuffix("%") { continue }
            
            // Check for absolute values that are extremely large or small
            if let value = Double(coord) {
                // Check for values that are way outside normal SVG coordinate ranges
                if value < -10000 || value > 10000 {
                    Log.fileOperation("🚨 EXTREME VALUE DETECTED: \(coord) = \(value)", level: .info)
                    return true
                }
                
                // CRITICAL: Check if normalized value (after division) is outside 0-1 range
                if viewBoxWidth > 0 && viewBoxHeight > 0 {
                    let normalizer = coord == cx || coord == fx ? viewBoxWidth : viewBoxHeight
                    let normalizedValue = value / normalizer
                    
                    // If normalized value is not between 0-1, use extreme value handling
                    if normalizedValue < 0.0 || normalizedValue > 1.0 {
                        Log.fileOperation("🚨 NORMALIZED VALUE OUT OF RANGE: \(coord) = \(value) → \(normalizedValue) (not 0-1)", level: .info)
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private func parseGradientStop(attributes: [String: String]) {
        guard isParsingGradient else { return }
        
        let offset = parseLength(attributes["offset"]) ?? 0.0
        var stopColor = VectorColor.black
        var stopOpacity = 1.0
        
        // Parse stop-color
        if let colorValue = attributes["stop-color"] {
            stopColor = parseColor(colorValue) ?? .black
        }
        
        // Parse stop-opacity
        if let opacityValue = attributes["stop-opacity"] {
            stopOpacity = parseLength(opacityValue) ?? 1.0
        }
        
        // Handle style attribute which might contain stop-color and stop-opacity
        if let style = attributes["style"] {
            let styleDict = parseStyleAttribute(style)
            if let stopColorValue = styleDict["stop-color"] {
                stopColor = parseColor(stopColorValue) ?? stopColor
            }
            if let stopOpacityValue = styleDict["stop-opacity"] {
                stopOpacity = parseLength(stopOpacityValue) ?? stopOpacity
            }
        }
        
        let gradientStop = GradientStop(position: offset, color: stopColor, opacity: stopOpacity)
        currentGradientStops.append(gradientStop)
        
        Log.fileOperation("🎨 Added gradient stop: offset=\(offset), color=\(stopColor)", level: .info)
    }
    
    private func finishGradientElement() {
        guard let gradientId = currentGradientId, let gradientType = currentGradientType, isParsingGradient else { return }
        
        let attributes = currentGradientAttributes
        
        // Handle gradient inheritance (xlink:href / href)
        var inheritedGradient: VectorGradient? = nil
        if let hrefRaw = attributes["xlink:href"] ?? attributes["href"] {
            var refId = hrefRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if refId.hasPrefix("url(#") && refId.hasSuffix(")") {
                refId = String(refId.dropFirst(5).dropLast(1))
            } else if refId.hasPrefix("#") {
                refId = String(refId.dropFirst())
            }
            inheritedGradient = gradientDefinitions[refId]
            if inheritedGradient != nil {
                Log.fileOperation("🧬 Inheriting gradient from \(refId) for \(gradientId)", level: .info)
            } else {
                Log.fileOperation("⚠️ Referenced gradient not found: \(refId)", level: .info)
            }
        }
        
        // Ensure we have at least one gradient stop
        if currentGradientStops.isEmpty {
            if let inherited = inheritedGradient {
                currentGradientStops = inherited.stops
                Log.info("✅ Inherited \(currentGradientStops.count) stops from referenced gradient", category: .fileOperations)
            } else {
                Log.fileOperation("⚠️ Gradient \(gradientId) has no color stops - creating default black to white", level: .info)
                currentGradientStops = [
                    GradientStop(position: 0.0, color: .black),
                    GradientStop(position: 1.0, color: .white)
                ]
            }
        }
        
        // Determine gradient type from stored gradient type
        let vectorGradient: VectorGradient
        
        if gradientType == "linearGradient" {
            // Parse gradient units first to handle coordinates properly
            let gradientUnits = parseGradientUnits(from: attributes)
            
            // Parse linear gradient attributes with enhanced coordinate handling
            let x1Raw = attributes["x1"] ?? "0%"
            let y1Raw = attributes["y1"] ?? "0%"
            let x2Raw = attributes["x2"] ?? "100%"
            let y2Raw = attributes["y2"] ?? "0%"
            
            Log.fileOperation("🔧 Parsing coordinates: x1=\(x1Raw), y1=\(y1Raw), x2=\(x2Raw), y2=\(y2Raw), units=\(gradientUnits)", level: .info)
            
            // Parse coordinates with proper gradient units handling
            let x1 = parseGradientCoordinate(x1Raw, gradientUnits: gradientUnits, isXCoordinate: true)
            let y1 = parseGradientCoordinate(y1Raw, gradientUnits: gradientUnits, isXCoordinate: false)
            let x2 = parseGradientCoordinate(x2Raw, gradientUnits: gradientUnits, isXCoordinate: true)
            let y2 = parseGradientCoordinate(y2Raw, gradientUnits: gradientUnits, isXCoordinate: false)
            
            Log.fileOperation("🔧 Parsed coordinates: x1=\(x1), y1=\(y1), x2=\(x2), y2=\(y2)", level: .info)
            
            // Parse gradientTransform to capture rotation and scale (for Y-flips like scale(1,-1))
            let transformInfo = parseGradientTransformFromAttributes(attributes)
            
            // SIMPLE OBJECT-RELATIVE: ALL gradients paint relative to individual object bounds
            let startPoint: CGPoint
            let endPoint: CGPoint
            
            // Use inherited coordinates if present and not overridden
            if let inherited = inheritedGradient, case .linear(let inh) = inherited,
               attributes["x1"] == nil && attributes["y1"] == nil && attributes["x2"] == nil && attributes["y2"] == nil {
                startPoint = inh.startPoint
                endPoint = inh.endPoint
            } else {
                // Use the original SVG coordinates directly (normalized earlier if needed)
                startPoint = CGPoint(x: x1, y: y1)
                endPoint = CGPoint(x: x2, y: y2)
            }
            
            // Compute the base direction from coordinates
            var deltaX = x2 - x1
            var deltaY = y2 - y1
            
            // Apply scale from gradientTransform to the direction vector only
            // Translation does not affect angle; rotation will be added separately
            if transformInfo.scaleX != 1.0 || transformInfo.scaleY != 1.0 {
                deltaX *= transformInfo.scaleX
                deltaY *= transformInfo.scaleY
            }
            
            // Angle from transformed direction
            var computedAngle = radiansToDegrees(atan2(deltaY, deltaX))
            
            // Add any explicit rotate() from gradientTransform
            if transformInfo.angle != 0.0 {
                computedAngle += transformInfo.angle
            }
            
            let angleDegrees = computedAngle
            
            print("🎯 GRADIENT FROM SVG: angle=\(String(format: "%.2f", angleDegrees))° (transform: \(transformInfo.angle)°)")
            print("   Start: (\(String(format: "%.3f", startPoint.x)), \(String(format: "%.3f", startPoint.y)))")
            print("   End: (\(String(format: "%.3f", endPoint.x)), \(String(format: "%.3f", endPoint.y)))")
            Log.fileOperation("🔥 FINAL GRADIENT: Linear gradient with original coordinates, stops=\(currentGradientStops.count)", level: .info)
            
            // Parse spread method
            let spreadMethod = parseSpreadMethod(from: attributes)
            
            // FORCE OBJECT BOUNDING BOX: Always use shape-relative coordinates
            // Calculate origin point as the midpoint between start and end
            let originX = clamp((startPoint.x + endPoint.x) / 2.0, 0.0, 1.0)
            let originY = clamp((startPoint.y + endPoint.y) / 2.0, 0.0, 1.0)
            
            var linearGradient = LinearGradient(
                startPoint: startPoint,
                endPoint: endPoint,
                stops: currentGradientStops,
                spreadMethod: spreadMethod,
                units: .objectBoundingBox  // Force objectBoundingBox for proper shape fitting
            )
            
            // Inherit units/spread if not specified
            if let inherited = inheritedGradient, case .linear(let inh) = inherited {
                if attributes["gradientUnits"] == nil { linearGradient.units = inh.units }
                if attributes["spreadMethod"] == nil { linearGradient.spreadMethod = inh.spreadMethod }
            }
            
            // Set the origin point to the center of the gradient
            linearGradient.originPoint = CGPoint(x: originX, y: originY)
            
            // Set the angle from the calculated angle (after applying gradientTransform effects)
            linearGradient.angle = angleDegrees
            
            vectorGradient = .linear(linearGradient)
            Log.info("✅ Created linear gradient: \(gradientId) with \(currentGradientStops.count) stops (FORCED objectBoundingBox)", category: .fileOperations)
            print("   - Start: \(startPoint), End: \(endPoint), Angle: \(String(format: "%.1f", angleDegrees))° (shape-relative)")
            
        } else { // radialGradient
            // Parse gradient units first to handle coordinates properly
            let gradientUnits = parseGradientUnits(from: attributes)
            
            // Parse radial gradient attributes with enhanced coordinate handling
            let (cxRaw, cyRaw, rRaw, fxRaw, fyRaw) = parseRadialGradientCoordinates(from: attributes)
            
            Log.fileOperation("🔧 Parsing radial coordinates: cx=\(cxRaw), cy=\(cyRaw), r=\(rRaw), units=\(gradientUnits)", level: .info)
            
            // Use extreme value handling if detected for this gradient
            let useExtremeHandling = useExtremeValueHandling && detectedExtremeValues
            
            let cx = parseGradientCoordinate(cxRaw, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling)
            let cy = parseGradientCoordinate(cyRaw, gradientUnits: gradientUnits, isXCoordinate: false, useExtremeValueHandling: useExtremeHandling)
            let r = parseGradientCoordinate(rRaw, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling) // Use X for radius
            
            // Parse focal point if specified, otherwise use center point
            let fx = fxRaw != nil ? parseGradientCoordinate(fxRaw!, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling) : cx
            let fy = fyRaw != nil ? parseGradientCoordinate(fyRaw!, gradientUnits: gradientUnits, isXCoordinate: false, useExtremeValueHandling: useExtremeHandling) : cy
            
            Log.fileOperation("🔧 Parsed radial coordinates: cx=\(cx), cy=\(cy), r=\(r), fx=\(fx), fy=\(fy)", level: .info)
            print("🔧 Raw values: cxRaw=\(cxRaw), cyRaw=\(cyRaw), rRaw=\(rRaw), fxRaw=\(fxRaw ?? "nil"), fyRaw=\(fyRaw ?? "nil")")
            
            // CORE GRAPHICS COORDINATE CONVERSION: Proper coordinate system mapping
            // parseGradientCoordinate already handles the conversion from userSpaceOnUse to objectBoundingBox
            // So cx, cy, fx, fy are already in the correct 0-1 range
            
            var centerPoint: CGPoint
            var focalPoint: CGPoint
            
            if useExtremeHandling {
                // AUTO-CENTER MODE: Use your radial gradient code that auto-centers fills
                centerPoint = CGPoint(x: 0.5, y: 0.5)  // Center of object
                focalPoint = CGPoint(x: 0.5, y: 0.5)   // Focal at center
                Log.fileOperation("🎯 AUTO-CENTERED RADIAL: center=(0.5,0.5), focal=(0.5,0.5) (extreme value mode)", level: .info)
            } else {
                // STANDARD MODE: Use parsed coordinates
                centerPoint = CGPoint(x: cx, y: cy)
                focalPoint = CGPoint(x: fx, y: fy)
                Log.fileOperation("🎯 STANDARD RADIAL: center=(\(cx),\(cy)), focal=(\(fx),\(fy))", level: .info)
            }
            
            // Handle radius for extreme value mode
            let finalRadius: Double
            if useExtremeHandling {
                // AUTO-CENTER MODE: Use fixed radius that spans from center to object edge
                finalRadius = 0.5
                Log.fileOperation("🎯 AUTO-CENTERED RADIAL: radius=0.5 (spans center to object edge)", level: .info)
            } else {
                // STANDARD MODE: Use parsed radius
                finalRadius = r
                Log.fileOperation("🎯 STANDARD RADIAL: radius=\(r)", level: .info)
            }
            
            Log.fileOperation("🎯 GRADIENT COORDINATES: center=(\(centerPoint.x),\(centerPoint.y)), focal=(\(focalPoint.x),\(focalPoint.y)), radius=\(finalRadius)", level: .info)
            print("   Original: cx=\(cxRaw), cy=\(cyRaw), r=\(rRaw), fx=\(fxRaw ?? "nil"), fy=\(fyRaw ?? "nil")")
            Log.info("   Converted: cx=\(cx), cy=\(cy), r=\(r), fx=\(fx), fy=\(fy)", category: .general)
            Log.info("   Final: center=(\(centerPoint.x),\(centerPoint.y)), radius=\(finalRadius)", category: .general)
            Log.info("   Units: \(gradientUnits) - parseGradientCoordinate handled conversion", category: .general)
            
            // Parse spread method
            let spreadMethod = parseSpreadMethod(from: attributes)
            
            // NEW: Parse gradientTransform for angle and independent scaling
            let (gradientAngle, gradientScaleX, gradientScaleY) = parseGradientTransformFromAttributes(attributes)
            
            // CORE GRAPHICS RADIAL GRADIENT: Use proper coordinate system conversion
            var radialGradient = RadialGradient(
                centerPoint: centerPoint,
                radius: max(0.001, finalRadius), // Use final radius (auto-centered or parsed)
                stops: currentGradientStops,
                focalPoint: focalPoint, // Use the properly converted focal point
                spreadMethod: spreadMethod,
                units: .objectBoundingBox  // Force objectBoundingBox for proper shape fitting
            )
            
            // Inherit center/radius/units/spread if not specified
            if let inherited = inheritedGradient, case .radial(let inh) = inherited {
                if attributes["cx"] == nil && attributes["cy"] == nil { radialGradient.centerPoint = inh.centerPoint }
                if attributes["r"] == nil { radialGradient.radius = inh.radius }
                if attributes["gradientUnits"] == nil { radialGradient.units = inh.units }
                if attributes["spreadMethod"] == nil { radialGradient.spreadMethod = inh.spreadMethod }
            }
            
            // Set the origin point to the center point
            radialGradient.originPoint = centerPoint
            
            // Apply gradient transform for angle and scaling
            radialGradient.angle = gradientAngle
            radialGradient.scaleX = abs(gradientScaleX) // Apply transform scale
            radialGradient.scaleY = abs(gradientScaleY) // Apply transform scale
            
            vectorGradient = .radial(radialGradient)
            Log.info("✅ Created radial gradient: \(gradientId) with \(currentGradientStops.count) stops (FORCED objectBoundingBox)", category: .fileOperations)
            print("   - Center: \(centerPoint), Radius: \(String(format: "%.3f", finalRadius)) (shape-relative)")
            Log.info("   - Origin Point: \(radialGradient.originPoint)", category: .general)
            Log.info("   - Scale: X=\(gradientScaleX), Y=\(gradientScaleY)", category: .general)
            if useExtremeHandling {
                Log.info("   - Mode: AUTO-CENTERED (extreme value handling)", category: .general)
            } else {
                Log.info("   - Mode: STANDARD (parsed coordinates)", category: .general)
            }
            if fxRaw != nil || fyRaw != nil {
                Log.info("   - Focal point: \(focalPoint)", category: .general)
            }
        }
        
        // Store the gradient definition
        gradientDefinitions[gradientId] = vectorGradient
        
        // Reset parsing state
        currentGradientId = nil
        currentGradientType = nil
        currentGradientAttributes = [:]
        currentGradientStops = []
        isParsingGradient = false
        
        // Reset extreme value handling for next gradient
        if detectedExtremeValues {
            Log.fileOperation("🔄 Resetting extreme value handling for next gradient", level: .info)
            detectedExtremeValues = false
            useExtremeValueHandling = false
        }
        
        Log.info("📚 Stored gradient definition: \(gradientId) with \(vectorGradient.stops.count) stops", category: .general)
    }
    
    /// Parse SVG gradientTransform attribute to extract angle and aspect ratio
    private func parseGradientTransform(_ transform: String) -> (angle: Double, scaleX: Double, scaleY: Double) {
        var angle: Double = 0.0
        var scaleX: Double = 1.0
        var scaleY: Double = 1.0
        
        // Parse transform functions: translate(x,y) rotate(angle) scale(sx,sy)
        // Example: "translate(771.04 670.64) rotate(83.98) scale(1 .65)"
        
        // Extract rotate value
        if let rotateMatch = transform.range(of: #"rotate\(([^)]+)\)"#, options: .regularExpression) {
            let rotateSubstring = String(transform[rotateMatch])
            let numbers = extractNumbers(from: rotateSubstring)
            if let rotateAngle = numbers.first {
                // negate the SVG rotation
                angle = -rotateAngle
                Log.fileOperation("🔄 Extracted rotation: \(rotateAngle)° -> angle: \(angle)°", level: .info)
            }
        }
        
        // Extract scale values for independent X/Y scaling
        if let scaleMatch = transform.range(of: #"scale\(([^)]+)\)"#, options: .regularExpression) {
            let scaleSubstring = String(transform[scaleMatch])
            let numbers = extractNumbers(from: scaleSubstring)
            if numbers.count >= 2 {
                scaleX = numbers[0]
                scaleY = numbers[1]
                Log.fileOperation("🔄 Extracted scale: x=\(scaleX), y=\(scaleY)", level: .info)
            } else if numbers.count == 1 {
                // Uniform scale
                scaleX = numbers[0]
                scaleY = numbers[0]
                Log.fileOperation("🔄 Extracted uniform scale: \(numbers[0])", level: .info)
            }
        }
        
        return (angle: angle, scaleX: scaleX, scaleY: scaleY)
    }
    
    /// Extract numbers from a string (helper for parseGradientTransform)
    private func extractNumbers(from string: String) -> [Double] {
        // Regular expression to match numbers (including decimals and negative)
        let pattern = #"-?\d*\.?\d+"#
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        let matches = regex.matches(in: string, range: range)
        
        return matches.compactMap { match in
            if let range = Range(match.range, in: string) {
                return Double(String(string[range]))
            }
            return nil
        }
    }
    
    /// Clamp a value between min and max
    private func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        return max(minValue, min(maxValue, value))
    }
    
    private func parseStyleAttribute(_ style: String) -> [String: String] {
        var styleDict: [String: String] = [:]
        
        let declarations = style.components(separatedBy: ";")
        for declaration in declarations {
            let keyValue = declaration.components(separatedBy: ":")
            if keyValue.count >= 2 {
                let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                styleDict[key] = value
            }
        }
        
        return styleDict
    }
    
    // MARK: - Professional SVG Path Tokenization
    private func tokenizeSVGPath(_ pathData: String) -> [String] {
        var tokens: [String] = []
        let chars = Array(pathData)
        var i = 0
        
        while i < chars.count {
            let char = chars[i]
            
            // Skip whitespace and commas
            if char.isWhitespace || char == "," {
                i += 1
                continue
            }
            
            // Handle commands (letters)
            if char.isLetter {
                tokens.append(String(char))
                i += 1
                continue
            }
            
            // Handle numbers (including negative and decimal)
            if char.isNumber || char == "." || (char == "-" || char == "+") {
                var numberStr = ""
                var hasDecimal = false
                let _ = i  // Track starting index for potential debugging
                
                // Handle sign only if it's at the start of a number
                if char == "-" || char == "+" {
                    // Look ahead to see if this is actually a number
                    if i + 1 < chars.count && (chars[i + 1].isNumber || chars[i + 1] == ".") {
                        numberStr.append(char)
                        i += 1
                    } else {
                        // Not a number, skip this character
                        i += 1
                        continue
                    }
                }
                
                // Collect digits and decimal point
                while i < chars.count {
                    let currentChar = chars[i]
                    
                    if currentChar.isNumber {
                        numberStr.append(currentChar)
                        i += 1
                    } else if currentChar == "." && !hasDecimal {
                        // Only accept decimal point if followed by digit or if we haven't started collecting digits yet
                        if i + 1 < chars.count && chars[i + 1].isNumber || numberStr.isEmpty || numberStr == "-" || numberStr == "+" {
                            numberStr.append(currentChar)
                            hasDecimal = true
                            i += 1
                        } else {
                            break
                        }
                    } else {
                        break
                    }
                }
                
                // Handle scientific notation (e/E)
                if i < chars.count && (chars[i] == "e" || chars[i] == "E") {
                    numberStr.append(chars[i])
                    i += 1
                    
                    // Handle sign after e/E
                    if i < chars.count && (chars[i] == "+" || chars[i] == "-") {
                        numberStr.append(chars[i])
                        i += 1
                    }
                    
                    // Collect exponent digits
                    while i < chars.count && chars[i].isNumber {
                        numberStr.append(chars[i])
                        i += 1
                    }
                }
                
                // Only add if we actually collected a valid number
                if !numberStr.isEmpty && numberStr != "-" && numberStr != "+" {
                    tokens.append(numberStr)
                }
                continue
            }
            
            // Unknown character, skip it
            i += 1
        }
        
        return tokens
    }
    
    private func parsePathData(_ pathData: String) -> [PathElement] {
        var elements: [PathElement] = []
        var currentPoint = CGPoint.zero
        var subpathStart = CGPoint.zero
        var lastControlPoint: CGPoint?
        
        Log.info("🔍 RAW PATH DATA: \(pathData.prefix(100))...", category: .general)
        
        // Professional SVG tokenization using proper regex patterns
        let tokens = tokenizeSVGPath(pathData)
        Log.fileOperation("🎯 FIRST 15 TOKENS: \(tokens.prefix(15))", level: .info)
        
        // Check for basic parsing issues
        var coordinateCount = 0
        var commandCount = 0
        for token in tokens {
            if token.rangeOfCharacter(from: .letters) != nil {
                commandCount += 1
            } else if Double(token) != nil {
                coordinateCount += 1
            }
        }
        Log.fileOperation("📊 PARSED: \(commandCount) commands, \(coordinateCount) coordinates", level: .info)
        
        var i = 0
        var currentCommand: String = ""
        
        while i < tokens.count {
            let token = tokens[i]
            
            // Check if this is a command or a parameter
            if token.rangeOfCharacter(from: .letters) != nil {
                // It's a command
                currentCommand = token
                Log.fileOperation("🔧 COMMAND: \(currentCommand)", level: .info)
                i += 1
                continue
            }
            
            // It's a parameter - process based on current command
            switch currentCommand {
            case "M": // Move to (absolute)
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    Log.info("   Move to: (\(x), \(y))", category: .general)
                    currentPoint = CGPoint(x: x, y: y)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    // After first moveto, subsequent coordinate pairs are treated as lineto
                    currentCommand = "L"
                } else {
                    Log.info("   ⚠️ Not enough tokens for M command", category: .general)
                    i += 1
                }
                
            case "m": // Move to (relative)
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    subpathStart = currentPoint
                    elements.append(.move(to: VectorPoint(currentPoint)))
                    i += 2
                    currentCommand = "l"
                } else {
                    i += 1
                }
                
            case "L": // Line to (absolute)
                if i + 1 < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    let y = Double(tokens[i + 1]) ?? 0
                    Log.info("   Line to: (\(x), \(y))", category: .general)
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    Log.info("   ⚠️ Not enough tokens for L command", category: .general)
                    i += 1
                }
                
            case "l": // Line to (relative)
                if i + 1 < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    let dy = Double(tokens[i + 1]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 2
                } else {
                    i += 1
                }
                
            case "H": // Horizontal line to (absolute)
                if i < tokens.count {
                    let x = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: x, y: currentPoint.y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "h": // Horizontal line to (relative)
                if i < tokens.count {
                    let dx = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "V": // Vertical line to (absolute)
                if i < tokens.count {
                    let y = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: y)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "v": // Vertical line to (relative)
                if i < tokens.count {
                    let dy = Double(tokens[i]) ?? 0
                    currentPoint = CGPoint(x: currentPoint.x, y: currentPoint.y + dy)
                    lastControlPoint = nil // Reset control point after line command
                    elements.append(.line(to: VectorPoint(currentPoint)))
                    i += 1
                } else {
                    i += 1
                }
                
            case "C": // Cubic bezier curve (absolute)
                if i + 5 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x2 = Double(tokens[i + 2]) ?? 0
                    let y2 = Double(tokens[i + 3]) ?? 0
                    let x = Double(tokens[i + 4]) ?? 0
                    let y = Double(tokens[i + 5]) ?? 0
                    
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    i += 1
                }
                
            case "c": // Cubic bezier curve (relative)
                if i + 5 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx2 = Double(tokens[i + 2]) ?? 0
                    let dy2 = Double(tokens[i + 3]) ?? 0
                    let dx = Double(tokens[i + 4]) ?? 0
                    let dy = Double(tokens[i + 5]) ?? 0
                    
                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    let x2 = currentPoint.x + dx2
                    let y2 = currentPoint.y + dy2
                    let newPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    
                    Log.info("   Curve from (\(currentPoint.x), \(currentPoint.y)) to (\(newPoint.x), \(newPoint.y))", category: .general)
                    Log.info("   Controls: (\(x1), \(y1)), (\(x2), \(y2))", category: .general)
                    
                    currentPoint = newPoint
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 6
                } else {
                    Log.info("   ⚠️ Not enough tokens for c command", category: .general)
                    i += 1
                }
                
            case "S": // Smooth cubic bezier curve (absolute)
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let x2 = Double(tokens[i]) ?? 0
                    let y2 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0
                    
                    // Calculate reflected control point - if no previous control point, use current point
                    let x1: Double
                    let y1: Double
                    
                    if let lastCP = lastControlPoint {
                        // Reflect the previous control point across the current point
                        x1 = 2 * currentPoint.x - lastCP.x
                        y1 = 2 * currentPoint.y - lastCP.y
                    } else {
                        // No previous control point, use current point (creates a straight line start)
                        x1 = currentPoint.x
                        y1 = currentPoint.y
                    }
                    
                    Log.info("   Smooth curve from (\(currentPoint.x), \(currentPoint.y)) to (\(x), \(y))", category: .general)
                    Log.info("   Controls: (\(x1), \(y1)), (\(x2), \(y2))", category: .general)
                    
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x2, y: y2)
                    
                    elements.append(.curve(
                        to: VectorPoint(currentPoint),
                        control1: VectorPoint(x1, y1),
                        control2: VectorPoint(x2, y2)
                    ))
                    i += 4
                }
                
            case "s": // Smooth cubic bezier curve (relative)
                while i + 3 < tokens.count && tokens[i].rangeOfCharacter(from: .letters) == nil {
                    let dx2 = Double(tokens[i]) ?? 0
                    let dy2 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0
                    
                    // Calculate reflected control point - if no previous control point, use current point
                    let reflectedX: Double
                    let reflectedY: Double
                    
                    if let lastCP = lastControlPoint {
                        // CRITICAL FIX: Reflect the previous control point across the current point
                        reflectedX = 2.0 * currentPoint.x - lastCP.x
                        reflectedY = 2.0 * currentPoint.y - lastCP.y
                    } else {
                        // No previous control point, use current point (creates a straight line start)
                        reflectedX = currentPoint.x
                        reflectedY = currentPoint.y
                    }
                    
                    // Calculate second control point (relative to current point)
                    let secondControlX = currentPoint.x + dx2
                    let secondControlY = currentPoint.y + dy2
                    
                    // Calculate end point (relative to current point)
                    let endX = currentPoint.x + dx
                    let endY = currentPoint.y + dy
                    
                    // Create explicit VectorPoint objects to avoid any variable mixup
                    let firstControl = VectorPoint(reflectedX, reflectedY)
                    let secondControl = VectorPoint(secondControlX, secondControlY)
                    let endPointVector = VectorPoint(endX, endY)
                    
                    // Update state
                    currentPoint = CGPoint(x: endX, y: endY)
                    lastControlPoint = CGPoint(x: secondControlX, y: secondControlY)
                    
                    // Create curve element with explicit control point order
                    // SVG 's' command: control1 = reflected, control2 = second control
                    let smoothCurveElement = PathElement.curve(
                        to: endPointVector,
                        control1: firstControl,
                        control2: secondControl
                    )
                    
                    elements.append(smoothCurveElement)
                    i += 4
                }
                
            case "Q": // Quadratic bezier curve (absolute)
                if i + 3 < tokens.count {
                    let x1 = Double(tokens[i]) ?? 0
                    let y1 = Double(tokens[i + 1]) ?? 0
                    let x = Double(tokens[i + 2]) ?? 0
                    let y = Double(tokens[i + 3]) ?? 0
                    
                    currentPoint = CGPoint(x: x, y: y)
                    lastControlPoint = CGPoint(x: x1, y: y1)
                    
                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }
                
            case "q": // Quadratic bezier curve (relative)
                if i + 3 < tokens.count {
                    let dx1 = Double(tokens[i]) ?? 0
                    let dy1 = Double(tokens[i + 1]) ?? 0
                    let dx = Double(tokens[i + 2]) ?? 0
                    let dy = Double(tokens[i + 3]) ?? 0
                    
                    let x1 = currentPoint.x + dx1
                    let y1 = currentPoint.y + dy1
                    currentPoint = CGPoint(x: currentPoint.x + dx, y: currentPoint.y + dy)
                    lastControlPoint = CGPoint(x: x1, y: y1)
                    
                    elements.append(.quadCurve(
                        to: VectorPoint(currentPoint),
                        control: VectorPoint(x1, y1)
                    ))
                    i += 4
                } else {
                    i += 1
                }
                
            case "Z", "z": // Close path
                Log.info("   Close path", category: .general)
                elements.append(.close)
                currentPoint = subpathStart
                lastControlPoint = nil
                i += 1
                
            default:
                // Skip unknown commands
                i += 1
            }
        }
        
        Log.info("🏁 FINAL ELEMENTS: \(elements.count) total", category: .general)
        for (index, element) in elements.enumerated() {
            Log.info("  [\(index)] \(element)", category: .general)
        }
        return elements
    }
    
    private func parsePoints(_ pointsString: String) -> [CGPoint] {
        let coordinates = pointsString
            .replacingOccurrences(of: ",", with: " ")
            .split(separator: " ")
            .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        
        var points: [CGPoint] = []
        for i in stride(from: 0, to: coordinates.count - 1, by: 2) {
            points.append(CGPoint(x: coordinates[i], y: coordinates[i + 1]))
        }
        
        return points
    }
}
