//
//  SVGParser.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - PROFESSIONAL SVG PARSER
class SVGParser: NSObject, XMLParserDelegate {
    var shapes: [VectorShape] = []
    internal var textObjects: [VectorText] = []
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

    // PERFORMANCE: Reusable layout components to avoid recreation for each text box
    internal lazy var sharedTextStorage = NSTextStorage()
    internal lazy var sharedLayoutManager = NSLayoutManager()
    internal lazy var sharedTextContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))

    // PERFORMANCE: Font cache to avoid repeated NSFont lookups
    internal var fontCache: [String: NSFont] = [:]
    
    // Multi-line text support
    internal var currentTextSpans: [(content: String, attributes: [String: String], x: Double, y: Double)] = []
    internal var isInMultiLineText: Bool = false

    // Track maximum text width for consistent sizing
    internal var maxTextWidth: CGFloat = 0

    // Track text box bounds from invisible rect elements
    internal var currentGroupId: String? = nil
    internal var textBoxBounds: [String: CGRect] = [:]  // Group ID -> rect bounds
    internal var pendingTextBoxRect: CGRect? = nil
    
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
    
    // MARK: - Image and ClipPath Support
    internal var clipPathDefinitions: [String: VectorPath] = [:]
    internal var currentClipPathId: String?
    internal var currentClipPath: VectorPath?
    internal var isParsingClipPath = false
    internal var pendingClipPathId: String? // For elements with clip-path attribute
    internal var clipPathStack: [String?] = [] // Stack to handle nested groups with clip paths

    // MARK: - Inkpen Metadata Support
    var inkpenMetadata: String? = nil // Base64 encoded inkpen document
    private var isInMetadata = false
    private var isInInkpenDocument = false
    private var currentMetadataContent = ""

    // MARK: - Helper Computed Properties and Functions
    
    /// Computed property for viewBox scale calculations
    private var viewBoxScale: (x: Double, y: Double) {
        return (documentSize.width / viewBoxWidth, documentSize.height / viewBoxHeight)
    }
    
    
    
    struct ParseResult {
        let shapes: [VectorShape]
        let textObjects: [VectorText]
        let documentSize: CGSize
        let viewBoxSize: CGSize?  // Added to track viewBox dimensions separately
        let creator: String?
        let version: String?
    }
    
    func parse(_ xmlString: String) throws -> ParseResult {
        guard let data = xmlString.data(using: .utf8) else {
            throw VectorImportError.parsingError("Invalid SVG string", line: nil)
        }

        // PERFORMANCE: Initialize shared layout manager once per parse
        sharedTextStorage = NSTextStorage()
        sharedLayoutManager = NSLayoutManager()
        sharedTextContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        sharedTextContainer.lineFragmentPadding = 0
        sharedTextContainer.lineBreakMode = .byWordWrapping
        sharedTextStorage.addLayoutManager(sharedLayoutManager)
        sharedLayoutManager.addTextContainer(sharedTextContainer)

        // Clear font cache for new parse
        fontCache.removeAll()

        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = self

        if !xmlParser.parse() {
            if let error = xmlParser.parserError {
                throw VectorImportError.parsingError("XML parsing failed: \(error.localizedDescription)", line: xmlParser.lineNumber)
            } else {
                throw VectorImportError.parsingError("Unknown XML parsing error", line: nil)
            }
        }
        
        // Apply any orphaned clipPaths to images that don't have clipping
        var finalShapes = shapes
        
        // If we have clipPath definitions and images without clipping, connect them
        if !clipPathDefinitions.isEmpty {
            // Find images without clipping
            let unclippedImages = finalShapes.filter { shape in
                shape.name == "Image" && shape.clippedByShapeID == nil && shape.embeddedImageData != nil
            }
            
            // Apply first available clipPath to first unclipped image (common SVG pattern)
            if !unclippedImages.isEmpty, let firstClipPathEntry = clipPathDefinitions.first {
                let clipPath = firstClipPathEntry.value
                var updatedShapes: [VectorShape] = []
                
                for shape in finalShapes {
                    if shape.id == unclippedImages[0].id {
                        // This is the image to clip
                        var maskedImage = shape
                        let clipShapeId = UUID()
                        maskedImage.clippedByShapeID = clipShapeId
                        maskedImage.name = "Masked Image"
                        updatedShapes.append(maskedImage)
                        
                        // Add the clip shape
                        var clipShape = VectorShape(
                            name: "Clip Path",
                            path: clipPath,
                            strokeStyle: nil,
                            fillStyle: FillStyle(color: .clear, opacity: 0),
                            transform: .identity
                        )
                        clipShape.id = clipShapeId
                        clipShape.isClippingPath = true
                        clipShape.isCompoundPath = true
                        updatedShapes.append(clipShape)
                        
                    } else if !unclippedImages.contains(where: { $0.id == shape.id }) {
                        // Keep other shapes as-is
                        updatedShapes.append(shape)
                    }
                }
                
                finalShapes = updatedShapes
            }
        }
        
        // Consolidate shapes that share identical gradients into compound paths
        // FIXED: Use the order-preserving consolidation method
        let consolidatedShapes = SVGConsolidationHelpers.consolidateSharedGradientsFixed(in: finalShapes)

        // Note: Text objects already have correct widths from NSLayoutManager
        // No need to trim - SVG spacing is already correct
        return ParseResult(
            shapes: consolidatedShapes,
            textObjects: textObjects,
            documentSize: documentSize,
            viewBoxSize: hasViewBox ? CGSize(width: viewBoxWidth, height: viewBoxHeight) : nil,
            creator: creator,
            version: version
        )
    }

    /// Enable extreme value handling for radial gradients that cannot be reproduced
    /// Use this for SVGs with extreme coordinate values that cause rendering issues
    func enableExtremeValueHandling() {
        useExtremeValueHandling = true
    }
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElementName = elementName
        
        // If we're inside a clipPath, handle shape elements differently
        if isParsingClipPath {
            switch elementName {
            case "path", "rect", "circle", "ellipse", "polygon":
                // Parse these shapes for the clip path definition
                parseShapeForClipPath(elementName: elementName, attributes: attributeDict)
                return // Don't process as regular shapes
            default:
                break
            }
        }
        
        switch elementName {
        case "svg":
            parseSVGRoot(attributes: attributeDict)
            
        case "defs":
            // Start of definitions section
            break
            
        case "style":
            // Start of CSS style section
            currentStyleContent = ""

        case "metadata":
            // Start of metadata section
            isInMetadata = true
            currentMetadataContent = ""

        case "inkpen:document":
            // Start of inkpen document section
            if isInMetadata {
                isInInkpenDocument = true
                currentMetadataContent = ""
            }

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
            
        case "clipPath":
            parseClipPath(attributes: attributeDict)
            
        case "image":
            parseImage(attributes: attributeDict)
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "metadata":
            // End of metadata section
            isInMetadata = false

        case "inkpen:document":
            // End of inkpen document section
            if isInInkpenDocument {
                // Trim and store the base64 content
                inkpenMetadata = currentMetadataContent.trimmingCharacters(in: .whitespacesAndNewlines)
                if !inkpenMetadata!.isEmpty {
                }
                isInInkpenDocument = false
                currentMetadataContent = ""
            }

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
            // Pop clip path stack when exiting group
            if !clipPathStack.isEmpty {
                let previousClipPath = clipPathStack.removeLast()
                if pendingClipPathId != previousClipPath {
                }
                pendingClipPathId = previousClipPath
            } else if pendingClipPathId != nil {
                pendingClipPathId = nil
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
            
        case "clipPath":
            // Finish parsing clipPath element
            isParsingClipPath = false
            if let clipId = currentClipPathId, let clipPath = currentClipPath {
                clipPathDefinitions[clipId] = clipPath
            }
            currentClipPathId = nil
            currentClipPath = nil
            
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if currentElementName == "style" {
            currentStyleContent += string
        } else if isInInkpenDocument {
            // Accumulate inkpen metadata content
            currentMetadataContent += string
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
            }
        }
        
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
                
                
                // If no explicit width/height, use viewBox dimensions
                if attributes["width"] == nil && attributes["height"] == nil {
                    documentSize = CGSize(width: viewBoxWidth, height: viewBoxHeight)
                }
                
                // Calculate the viewBox transform
                let scaleX = viewBoxScale.x
                let scaleY = viewBoxScale.y

                // Check if this is a 96 DPI SVG (scale is approximately 4/3)
                // If so, DON'T apply the scale transform since coordinates are already in viewBox space
                let is96DPI = abs(scaleX - (4.0/3.0)) < 0.1 && abs(scaleY - (4.0/3.0)) < 0.1

                if is96DPI {
                    // For 96 DPI SVGs, only apply translation, no scaling
                    currentTransform = CGAffineTransform.identity
                        .translatedBy(x: -viewBoxX, y: -viewBoxY)
                } else {
                    // Apply full viewBox transform for normal SVGs
                    currentTransform = CGAffineTransform.identity
                        .translatedBy(x: -viewBoxX, y: -viewBoxY)
                        .scaledBy(x: scaleX, y: scaleY)
                }

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

        // Capture group ID for text box bounds tracking
        currentGroupId = attributes["id"]

        // Push current clip path to stack for nested groups
        clipPathStack.append(pendingClipPathId)
        
        if let transform = attributes["transform"] {
            let groupTransform = parseTransform(transform)
            currentTransform = currentTransform.concatenating(groupTransform)
        }
        
        // First check if group has a class that might define clip-path
        var mergedAttributes = attributes
        if let className = attributes["class"] {
            // Handle multiple classes separated by spaces
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    // CSS class styles have lower priority than inline styles
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                        }
                    }
                }
            }
        }
        
        // Check for clip-path on the group (now checking merged attributes which includes CSS class styles)
        // CRITICAL FIX: Only apply clip path if we don't already have one from parent group
        if pendingClipPathId == nil, let clipPathAttr = mergedAttributes["clip-path"] {
            // Extract ID from "url(#id)" format
            if let range = clipPathAttr.range(of: "#") {
                let idPart = clipPathAttr[range.upperBound...]
                if let endRange = idPart.range(of: ")") {
                    let clipId = String(idPart[..<endRange.lowerBound])
                    // CRITICAL: Validate the clip path exists before setting pendingClipPathId
                    // This prevents race conditions where groups reference non-existent clip paths
                    if clipPathDefinitions[clipId] != nil {
                        // Store this for elements within the group
                        pendingClipPathId = clipId
                    } else {
                        // Clip path not yet defined, store for later resolution
                        // This can happen if clipPath is defined after the group in the SVG
                        pendingClipPathId = clipId
                        Log.warning("⚠️ Group references clip path '\(clipId)' which is not yet defined. Will attempt to resolve later.", category: .fileOperations)
                    }
                }
            }
        } else if pendingClipPathId != nil {
        }
    }
    
    private func parsePath(attributes: [String: String]) {
        guard let d = attributes["d"] else { return }
        

        let pathData = parsePathData(d)
        let hasCloseElement = pathData.contains { if case .close = $0 { return true }; return false }
        let vectorPath = VectorPath(elements: pathData, isClosed: hasCloseElement)

        
        // Check if this path should be clipped
        let (shouldClip, clipPathId) = checkForClipPath(attributes)
        
        let shape = createShape(
            name: "Path",
            path: vectorPath,
            attributes: attributes
        )

        if shape.fillStyle != nil {
        } else {
        }
        if shape.strokeStyle != nil {
        } else {
        }

        // Apply clipping if needed
        if shouldClip, let clipId = clipPathId {
            applyClipPathToShape(shape, clipPathId: clipId)
        } else {
            shapes.append(shape)
        }
        
    }
    
    
    // MARK: - Image Parsing
    
    private func parseImage(attributes: [String: String]) {
        // Debug log to see what attributes we're getting
        
        // First, merge CSS class styles with inline styles to get the full attribute set
        var mergedAttributes = attributes
        
        if let className = attributes["class"] {
            // Handle multiple classes separated by spaces
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    // CSS class styles have lower priority than inline styles
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                        }
                    }
                }
            }
        }
        
        // Get image position and dimensions
        let x = parseLength(mergedAttributes["x"]) ?? 0
        let y = parseLength(mergedAttributes["y"]) ?? 0
        let width = parseLength(mergedAttributes["width"]) ?? 100
        let height = parseLength(mergedAttributes["height"]) ?? 100
        
        // Get image data (can be href, xlink:href, or embedded data)
        let imageHref = mergedAttributes["href"] ?? mergedAttributes["xlink:href"] ?? ""
        
        // Check for clip-path attribute (now checking merged attributes which includes CSS class styles)
        // Also check if there's a pending clip path from the parent group
        var clipPathId: String? = nil
        
        if let clipPathAttr = mergedAttributes["clip-path"], !clipPathAttr.isEmpty {
            // Extract ID from "url(#id)" format
            if let range = clipPathAttr.range(of: "#") {
                let idPart = clipPathAttr[range.upperBound...]
                if let endRange = idPart.range(of: ")") {
                    let extractedId = String(idPart[..<endRange.lowerBound])
                    if !extractedId.isEmpty {
                        clipPathId = extractedId
                    }
                }
            }
        }
        
        // If no clip path was extracted from attributes, use pending clip path from parent group
        if clipPathId == nil, let pendingId = pendingClipPathId {
            clipPathId = pendingId
        }
        
        // Create a rectangle path for the image bounds
        let imageRect = CGRect(x: x, y: y, width: width, height: height)
        let imagePath = VectorPath(elements: [
            .move(to: VectorPoint(imageRect.minX, imageRect.minY)),
            .line(to: VectorPoint(imageRect.maxX, imageRect.minY)),
            .line(to: VectorPoint(imageRect.maxX, imageRect.maxY)),
            .line(to: VectorPoint(imageRect.minX, imageRect.maxY)),
            .close
        ], isClosed: true)
        
        // Create the shape for the image with transparent background
        // Don't apply fill style from attributes for images - they should be transparent
        var imageAttributes = mergedAttributes
        imageAttributes["fill"] = "none" // Ensure no fill color for images
        imageAttributes["fill-opacity"] = "0" // Fully transparent
        
        var imageShape = createShape(
            name: "Image",
            path: imagePath,
            attributes: imageAttributes,
            geometricType: .rectangle
        )
        
        // Override fill to ensure transparency
        imageShape.fillStyle = nil // No fill for images - let the image data show through
        
        // Store image data
        if imageHref.hasPrefix("data:") {
            // Embedded base64 image data
            if let dataRange = imageHref.range(of: "base64,") {
                let base64String = String(imageHref[dataRange.upperBound...])
                imageShape.embeddedImageData = Data(base64Encoded: base64String)
            }
        } else if !imageHref.isEmpty {
            // External image reference
            imageShape.linkedImagePath = imageHref
        }
        
        // Apply clip path if specified

        // CRITICAL FIX: Validate the clip path exists before applying
        // This prevents race conditions where wrong clip paths are applied
        if let clipId = clipPathId {

            if let clipPath = clipPathDefinitions[clipId] {
                // Ensure the clip path is closed
                var closedClipPath = clipPath
                if !closedClipPath.isClosed {
                    var elements = closedClipPath.elements
                    if !elements.isEmpty && !elements.contains(where: { if case .close = $0 { return true }; return false }) {
                        elements.append(.close)
                    }
                    closedClipPath = VectorPath(elements: elements, isClosed: true)
                }

                // CRITICAL FIX: For InkPen's clipping mask system to work correctly:
                // 1. The clipped shape (image) must be added FIRST
                // 2. The clipping mask must be added LAST (on top)
                // This is the OPPOSITE of how Adobe Illustrator does it in the layers panel

                // First, add the image shape with the clippedByShapeID set
                var maskedImageShape = imageShape
                // Generate a unique ID for the clip shape that will be created
                let clipShapeId = UUID()
                maskedImageShape.clippedByShapeID = clipShapeId
                maskedImageShape.name = "Masked Image"

                // Add the masked image FIRST
                shapes.append(maskedImageShape)

                // Then create and add the clip shape LAST (on top)
                // IMPORTANT: Don't apply currentTransform to clip shapes - clipPath coordinates
                // are already in the correct coordinate space (usually userSpaceOnUse)
                var clipShape = VectorShape(
                    name: "Clip Path",
                    path: closedClipPath,
                    strokeStyle: nil,
                    fillStyle: FillStyle(color: .clear, opacity: 0), // Transparent fill
                    transform: .identity  // Clip paths use their own coordinate system
                )
                // Use the same ID we referenced above
                clipShape.id = clipShapeId
                clipShape.isClippingPath = true
                clipShape.isCompoundPath = true // Mark as compound for proper handling

                // Add the clip shape LAST (on top)
                shapes.append(clipShape)

                return // Don't add the original unmasked image
            } else {
                Log.warning("⚠️ Clip path '\(clipId)' referenced but not found in definitions. Available: \(clipPathDefinitions.keys.joined(separator: ", "))", category: .fileOperations)
                Log.warning("⚠️ Falling back to no clipping for this image", category: .fileOperations)
            }
        }
        
        shapes.append(imageShape)
    }
    
    // MARK: - ClipPath Parsing
    
    private func parseClipPath(attributes: [String: String]) {
        isParsingClipPath = true
        currentClipPathId = attributes["id"]
        currentClipPath = nil
    }
    
    private func parseShapeForClipPath(elementName: String, attributes: [String: String]) {
        // Parse the shape and extract its path for use as a clipping path
        var clipPath: VectorPath?
        
        switch elementName {
        case "path":
            if let d = attributes["d"] {
                let pathData = parsePathData(d)
                clipPath = VectorPath(elements: pathData, isClosed: true)
            }
            
        case "rect":
            let x = parseLength(attributes["x"]) ?? 0
            let y = parseLength(attributes["y"]) ?? 0
            let width = parseLength(attributes["width"]) ?? 0
            let height = parseLength(attributes["height"]) ?? 0
            let rect = CGRect(x: x, y: y, width: width, height: height)
            clipPath = VectorPath(elements: [
                .move(to: VectorPoint(rect.minX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.minY)),
                .line(to: VectorPoint(rect.maxX, rect.maxY)),
                .line(to: VectorPoint(rect.minX, rect.maxY)),
                .close
            ], isClosed: true)
            
        case "circle":
            let cx = parseLength(attributes["cx"]) ?? 0
            let cy = parseLength(attributes["cy"]) ?? 0
            let r = parseLength(attributes["r"]) ?? 0
            // Create circle path using bezier curves
            let center = CGPoint(x: cx, y: cy)
            clipPath = VectorPath(elements: [
                .move(to: VectorPoint(center.x + r, center.y)),
                .curve(to: VectorPoint(center.x, center.y + r),
                       control1: VectorPoint(center.x + r, center.y + r * 0.552),
                       control2: VectorPoint(center.x + r * 0.552, center.y + r)),
                .curve(to: VectorPoint(center.x - r, center.y),
                       control1: VectorPoint(center.x - r * 0.552, center.y + r),
                       control2: VectorPoint(center.x - r, center.y + r * 0.552)),
                .curve(to: VectorPoint(center.x, center.y - r),
                       control1: VectorPoint(center.x - r, center.y - r * 0.552),
                       control2: VectorPoint(center.x - r * 0.552, center.y - r)),
                .curve(to: VectorPoint(center.x + r, center.y),
                       control1: VectorPoint(center.x + r * 0.552, center.y - r),
                       control2: VectorPoint(center.x + r, center.y - r * 0.552)),
                .close
            ], isClosed: true)
            
        case "ellipse":
            let cx = parseLength(attributes["cx"]) ?? 0
            let cy = parseLength(attributes["cy"]) ?? 0
            let rx = parseLength(attributes["rx"]) ?? 0
            let ry = parseLength(attributes["ry"]) ?? 0
            let center = CGPoint(x: cx, y: cy)
            // Create ellipse path using bezier curves
            clipPath = VectorPath(elements: [
                .move(to: VectorPoint(center.x + rx, center.y)),
                .curve(to: VectorPoint(center.x, center.y + ry),
                       control1: VectorPoint(center.x + rx, center.y + ry * 0.552),
                       control2: VectorPoint(center.x + rx * 0.552, center.y + ry)),
                .curve(to: VectorPoint(center.x - rx, center.y),
                       control1: VectorPoint(center.x - rx * 0.552, center.y + ry),
                       control2: VectorPoint(center.x - rx, center.y + ry * 0.552)),
                .curve(to: VectorPoint(center.x, center.y - ry),
                       control1: VectorPoint(center.x - rx, center.y - ry * 0.552),
                       control2: VectorPoint(center.x - rx * 0.552, center.y - ry)),
                .curve(to: VectorPoint(center.x + rx, center.y),
                       control1: VectorPoint(center.x + rx * 0.552, center.y - ry),
                       control2: VectorPoint(center.x + rx, center.y - ry * 0.552)),
                .close
            ], isClosed: true)
            
        case "polygon":
            if let points = attributes["points"] {
                let parsedPoints = parsePoints(points)
                var elements: [PathElement] = []
                for (index, point) in parsedPoints.enumerated() {
                    if index == 0 {
                        elements.append(.move(to: VectorPoint(point.x, point.y)))
                    } else {
                        elements.append(.line(to: VectorPoint(point.x, point.y)))
                    }
                }
                elements.append(.close)
                clipPath = VectorPath(elements: elements, isClosed: true)
            }
            
        default:
            break
        }
        
        // Store the clip path (if this is the first shape in the clipPath, use it; otherwise combine)
        if let path = clipPath {
            if currentClipPath == nil {
                currentClipPath = path
            } else {
                // Combine multiple paths in a clipPath element
                // For now, just use the first one (could be enhanced to support compound clip paths)
            }
        }
    }
    
    
    
    
    
    
    
    func createShape(name: String, path: VectorPath, attributes: [String: String], geometricType: GeometricShapeType? = nil) -> VectorShape {
        // Merge CSS class styles with inline styles
        var mergedAttributes = attributes
        
        if let className = attributes["class"] {
            // Handle multiple classes separated by spaces
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    // CSS class styles have lower priority than inline styles
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
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
        } else {
            // Our own exported SVG (no transform attribute) - coordinates are already correct
            transform = currentTransform.isIdentity ? .identity : currentTransform
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
    
    // MARK: - Clip Path Helpers
    
    /// Check if attributes contain a clip-path reference (either inline or via CSS)
    internal func checkForClipPath(_ attributes: [String: String]) -> (shouldClip: Bool, clipPathId: String?) {
        // First merge CSS classes to get full attributes
        var mergedAttributes = attributes
        
        if let className = attributes["class"] {
            let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for cls in classNames {
                let selector = "." + cls
                if let classStyles = cssStyles[selector] {
                    for (key, value) in classStyles {
                        if mergedAttributes[key] == nil {
                            mergedAttributes[key] = value
                        }
                    }
                }
            }
        }
        
        // Check for clip-path attribute
        if let clipPathAttr = mergedAttributes["clip-path"] {
            // Extract ID from "url(#id)" format
            if let range = clipPathAttr.range(of: "#") {
                let idPart = clipPathAttr[range.upperBound...]
                if let endRange = idPart.range(of: ")") {
                    let clipPathId = String(idPart[..<endRange.lowerBound])
                    return (true, clipPathId)
                }
            }
        }
        
        return (false, nil)
    }
    
    /// Apply a clip path to a shape by creating the appropriate mask relationship
    internal func applyClipPathToShape(_ shape: VectorShape, clipPathId: String) {
        guard let clipPath = clipPathDefinitions[clipPathId] else {
            Log.error("❌ Clip path not found: \(clipPathId)", category: .error)
            shapes.append(shape)
            return
        }
        
        // Ensure the clip path is closed
        var closedClipPath = clipPath
        if !closedClipPath.isClosed {
            var elements = closedClipPath.elements
            if !elements.isEmpty && !elements.contains(where: { if case .close = $0 { return true }; return false }) {
                elements.append(.close)
            }
            closedClipPath = VectorPath(elements: elements, isClosed: true)
        }
        
        // Create clipped shape with reference to mask
        var maskedShape = shape
        let clipShapeId = UUID()
        maskedShape.clippedByShapeID = clipShapeId
        maskedShape.name = "Masked \(shape.name)"
        
        // Add the masked shape FIRST (InkPen ordering)
        shapes.append(maskedShape)
        
        // Create and add the clip shape LAST (on top)
        var clipShape = VectorShape(
            name: "Clip Path",
            path: closedClipPath,
            strokeStyle: nil,
            fillStyle: FillStyle(color: .clear, opacity: 0),
            transform: .identity
        )
        clipShape.id = clipShapeId
        clipShape.isClippingPath = true
        clipShape.isCompoundPath = true
        
        shapes.append(clipShape)
        
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
