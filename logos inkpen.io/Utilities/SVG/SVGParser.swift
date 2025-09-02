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
    private var textObjects: [VectorText] = []
    private var currentPath: VectorPath?
    private var currentStroke: StrokeStyle?
    private var currentFill: FillStyle?
    private var currentTransform = CGAffineTransform.identity
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
    private var currentTextContent = ""
    private var currentTextAttributes: [String: String] = [:]
    
    // Multi-line text support
    private var currentTextSpans: [(content: String, attributes: [String: String], x: Double, y: Double)] = []
    private var isInMultiLineText: Bool = false
    
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
    
    
    /// Parse gradient coordinate with enhanced SVG compatibility and proper userSpaceOnUse handling
    /// This version includes extreme value handling for radial gradients that cannot be reproduced
    internal func parseGradientCoordinate(_ value: String, gradientUnits: GradientUnits = .objectBoundingBox, isXCoordinate: Bool = true, useExtremeValueHandling: Bool = false) -> Double {
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
        
        let vectorGradient: VectorGradient
        
        if gradientType == "linearGradient" {
            vectorGradient = finishLinearGradientElement(inheritedGradient: inheritedGradient)
        } else {
            vectorGradient = finishRadialGradientElement(inheritedGradient: inheritedGradient)
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
    
    
}
