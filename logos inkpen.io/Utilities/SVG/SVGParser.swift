import SwiftUI

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

    internal lazy var sharedTextStorage = NSTextStorage()
    internal lazy var sharedLayoutManager = NSLayoutManager()
    internal lazy var sharedTextContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))

    internal var fontCache: [String: PlatformFont] = [:]

    internal var currentTextSpans: [(content: String, attributes: [String: String], x: Double, y: Double)] = []
    internal var isInMultiLineText: Bool = false

    internal var maxTextWidth: CGFloat = 0

    internal var currentGroupId: String? = nil
    internal var textBoxBounds: [String: CGRect] = [:]
    internal var pendingTextBoxRect: CGRect? = nil

    internal var gradientDefinitions: [String: VectorGradient] = [:]
    internal var currentGradientId: String?
    internal var currentGradientType: String?
    internal var currentGradientStops: [GradientStop] = []
    internal var currentGradientAttributes: [String: String] = [:]
    internal var isParsingGradient = false

    internal var useExtremeValueHandling = false
    internal var detectedExtremeValues = false

    internal var clipPathDefinitions: [String: VectorPath] = [:]
    internal var currentClipPathId: String?
    internal var currentClipPath: VectorPath?
    internal var isParsingClipPath = false
    internal var pendingClipPathId: String?
    internal var clipPathStack: [String?] = []

    var inkpenMetadata: String? = nil
    private var isInMetadata = false
    private var isInInkpenDocument = false
    private var currentMetadataContent = ""

    private var viewBoxScale: (x: Double, y: Double) {
        return (documentSize.width / viewBoxWidth, documentSize.height / viewBoxHeight)
    }

    struct ParseResult {
        let shapes: [VectorShape]
        let textObjects: [VectorText]
        let documentSize: CGSize
        let viewBoxSize: CGSize?
        let creator: String?
        let version: String?
    }

    func parse(_ xmlString: String) throws -> ParseResult {
        guard let data = xmlString.data(using: .utf8) else {
            throw VectorImportError.parsingError("Invalid SVG string", line: nil)
        }

        sharedTextStorage = NSTextStorage()
        sharedLayoutManager = NSLayoutManager()
        sharedTextContainer = NSTextContainer(size: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        sharedTextContainer.lineFragmentPadding = 0
        sharedTextContainer.lineBreakMode = .byWordWrapping
        sharedTextStorage.addLayoutManager(sharedLayoutManager)
        sharedLayoutManager.addTextContainer(sharedTextContainer)

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

        var finalShapes = shapes

        if !clipPathDefinitions.isEmpty {
            let unclippedImages = finalShapes.filter { shape in
                shape.name == "Image" && shape.clippedByShapeID == nil && shape.embeddedImageData != nil
            }

            if !unclippedImages.isEmpty, let firstClipPathEntry = clipPathDefinitions.first {
                let clipPath = firstClipPathEntry.value
                var updatedShapes: [VectorShape] = []

                for shape in finalShapes {
                    if shape.id == unclippedImages[0].id {
                        var maskedImage = shape
                        let clipShapeId = UUID()
                        maskedImage.clippedByShapeID = clipShapeId
                        maskedImage.name = "Masked Image"
                        updatedShapes.append(maskedImage)

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
                        updatedShapes.append(shape)
                    }
                }

                finalShapes = updatedShapes
            }
        }

        let consolidatedShapes = SVGConsolidationHelpers.consolidateSharedGradientsFixed(in: finalShapes)

        return ParseResult(
            shapes: consolidatedShapes,
            textObjects: textObjects,
            documentSize: documentSize,
            viewBoxSize: hasViewBox ? CGSize(width: viewBoxWidth, height: viewBoxHeight) : nil,
            creator: creator,
            version: version
        )
    }

    func enableExtremeValueHandling() {
        useExtremeValueHandling = true
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElementName = elementName

        if isParsingClipPath {
            switch elementName {
            case "path", "rect", "circle", "ellipse", "polygon":
                parseShapeForClipPath(elementName: elementName, attributes: attributeDict)
                return
            default:
                break
            }
        }

        switch elementName {
        case "svg":
            parseSVGRoot(attributes: attributeDict)

        case "defs":
            break

        case "style":
            currentStyleContent = ""

        case "metadata":
            isInMetadata = true
            currentMetadataContent = ""

        case "inkpen:document":
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
            isInMultiLineText = true

            var overlay = attributeDict
            if let classAttr = attributeDict["class"], !classAttr.isEmpty {
                applyCSSClasses(classAttr, into: &overlay)
            }
            if let style = attributeDict["style"], !style.isEmpty {
                let styleDict = parseStyleAttribute(style)
                for (k, v) in styleDict { overlay[k] = v }
            }

            let tspanX = parseLength(overlay["x"]) ?? 0
            let tspanY = parseLength(overlay["y"]) ?? 0
            var tspanAttributes = currentTextAttributes
            if let fam = overlay["font-family"], !fam.isEmpty { tspanAttributes["font-family"] = fam }
            if let size = overlay["font-size"], !size.isEmpty { tspanAttributes["font-size"] = size }
            if let fill = overlay["fill"], !fill.isEmpty { tspanAttributes["fill"] = fill }

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
            isInMetadata = false

        case "inkpen:document":
            if isInInkpenDocument {
                inkpenMetadata = currentMetadataContent.trimmingCharacters(in: .whitespacesAndNewlines)
                isInInkpenDocument = false
                currentMetadataContent = ""
            }

        case "svg":
            if hasViewBox {
                currentTransform = CGAffineTransform.identity
                    .translatedBy(x: -viewBoxX, y: -viewBoxY)
                    .scaledBy(x: viewBoxScale.x, y: viewBoxScale.y)
                } else {
                currentTransform = .identity
            }

        case "g":
            if !transformStack.isEmpty {
                transformStack.removeLast()
                currentTransform = transformStack.last ?? (hasViewBox ?
                    CGAffineTransform.identity
                        .translatedBy(x: -viewBoxX, y: -viewBoxY)
                        .scaledBy(x: viewBoxScale.x, y: viewBoxScale.y) :
                    .identity)
            }
            if !clipPathStack.isEmpty {
                let previousClipPath = clipPathStack.removeLast()
                pendingClipPathId = previousClipPath
            } else if pendingClipPathId != nil {
                pendingClipPathId = nil
            }

        case "style":
            parseCSSStyles(currentStyleContent)
            currentStyleContent = ""

        case "text":
            finishTextElement()

        case "linearGradient", "radialGradient":
            finishGradientElement()

        case "clipPath":
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
            currentMetadataContent += string
        } else if currentElementName == "text" {
            currentTextContent += string
        } else if currentElementName == "tspan" {
            if !currentTextSpans.isEmpty {
                let lastIndex = currentTextSpans.count - 1
                currentTextSpans[lastIndex].content += string
            } else {
                currentTextContent += string
            }
        }
    }

    private func parseCSSStyles(_ cssContent: String) {

        let rules = cssContent.components(separatedBy: "}")

        for rule in rules {
            let parts = rule.components(separatedBy: "{")
            if parts.count == 2 {
                let selector = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let declarations = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                var styles: [String: String] = [:]

                let declParts = declarations.components(separatedBy: ";")
                for decl in declParts {
                    let keyValue = decl.components(separatedBy: ":")
                    if keyValue.count >= 2 {
                        let key = keyValue[0].trimmingCharacters(in: .whitespacesAndNewlines)
                        let value = keyValue[1...].joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
                        styles[key] = value
                    }
                }

                cssStyles[selector] = styles
            }
        }

    }

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

    private func parseSVGRoot(attributes: [String: String]) {
        if let width = attributes["width"], let height = attributes["height"] {
            let w = parseLength(width) ?? 100
            let h = parseLength(height) ?? 100
            documentSize = CGSize(width: w, height: h)
        }

        if let viewBox = attributes["viewBox"] {
            let parts = viewBox.split(separator: " ").compactMap { Double($0) }
            if parts.count >= 4 {
                viewBoxX = parts[0]
                viewBoxY = parts[1]
                viewBoxWidth = parts[2]
                viewBoxHeight = parts[3]
                hasViewBox = true

                if attributes["width"] == nil && attributes["height"] == nil {
                    documentSize = CGSize(width: viewBoxWidth, height: viewBoxHeight)
                }

                let scaleX = viewBoxScale.x
                let scaleY = viewBoxScale.y

                // Always apply the viewBox scale transform to map viewBox coordinates
                // to document coordinates. For 96 DPI SVGs (scale ≈ 4/3), this scales
                // the artwork up to match the document size, ensuring the imported
                // SVG appears at 100% when reopened.
                currentTransform = CGAffineTransform.identity
                    .translatedBy(x: -viewBoxX, y: -viewBoxY)
                    .scaledBy(x: scaleX, y: scaleY)

            }
        } else {
            viewBoxWidth = documentSize.width
            viewBoxHeight = documentSize.height
        }

        creator = attributes["data-name"] ?? attributes["generator"]
        version = attributes["version"]
    }

    private func parseGroup(attributes: [String: String]) {
        transformStack.append(currentTransform)

        currentGroupId = attributes["id"]

        clipPathStack.append(pendingClipPathId)

        if let transform = attributes["transform"] {
            let groupTransform = parseTransform(transform)
            currentTransform = currentTransform.concatenating(groupTransform)
        }

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

        if pendingClipPathId == nil, let clipPathAttr = mergedAttributes["clip-path"] {
            if let range = clipPathAttr.range(of: "#") {
                let idPart = clipPathAttr[range.upperBound...]
                if let endRange = idPart.range(of: ")") {
                    let clipId = String(idPart[..<endRange.lowerBound])
                    if clipPathDefinitions[clipId] != nil {
                        pendingClipPathId = clipId
                    } else {
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
        let (shouldClip, clipPathId) = checkForClipPath(attributes)

        let shape = createShape(
            name: "Path",
            path: vectorPath,
            attributes: attributes
        )

        if shouldClip, let clipId = clipPathId {
            applyClipPathToShape(shape, clipPathId: clipId)
        } else {
            shapes.append(shape)
        }

    }

    private func parseImage(attributes: [String: String]) {

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

        let x = parseLength(mergedAttributes["x"]) ?? 0
        let y = parseLength(mergedAttributes["y"]) ?? 0
        let width = parseLength(mergedAttributes["width"]) ?? 100
        let height = parseLength(mergedAttributes["height"]) ?? 100
        let imageHref = mergedAttributes["href"] ?? mergedAttributes["xlink:href"] ?? ""

        var clipPathId: String? = nil

        if let clipPathAttr = mergedAttributes["clip-path"], !clipPathAttr.isEmpty {
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

        if clipPathId == nil, let pendingId = pendingClipPathId {
            clipPathId = pendingId
        }

        let imageRect = CGRect(x: x, y: y, width: width, height: height)
        let imagePath = VectorPath(elements: [
            .move(to: VectorPoint(imageRect.minX, imageRect.minY)),
            .line(to: VectorPoint(imageRect.maxX, imageRect.minY)),
            .line(to: VectorPoint(imageRect.maxX, imageRect.maxY)),
            .line(to: VectorPoint(imageRect.minX, imageRect.maxY)),
            .close
        ], isClosed: true)

        var imageAttributes = mergedAttributes
        imageAttributes["fill"] = "none"
        imageAttributes["fill-opacity"] = "0"

        var imageShape = createShape(
            name: "Image",
            path: imagePath,
            attributes: imageAttributes,
            geometricType: .rectangle
        )

        imageShape.fillStyle = nil

        if imageHref.hasPrefix("data:") {
            if let dataRange = imageHref.range(of: "base64,") {
                let base64String = String(imageHref[dataRange.upperBound...])
                imageShape.embeddedImageData = Data(base64Encoded: base64String)
            }
        } else if !imageHref.isEmpty {
            imageShape.linkedImagePath = imageHref
        }

        if let clipId = clipPathId {

            if let clipPath = clipPathDefinitions[clipId] {
                var closedClipPath = clipPath
                if !closedClipPath.isClosed {
                    var elements = closedClipPath.elements
                    if !elements.isEmpty && !elements.contains(where: { if case .close = $0 { return true }; return false }) {
                        elements.append(.close)
                    }
                    closedClipPath = VectorPath(elements: elements, isClosed: true)
                }

                var maskedImageShape = imageShape
                let clipShapeId = UUID()
                maskedImageShape.clippedByShapeID = clipShapeId
                maskedImageShape.name = "Masked Image"

                shapes.append(maskedImageShape)

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

                return
            } else {
                Log.warning("⚠️ Clip path '\(clipId)' referenced but not found in definitions. Available: \(clipPathDefinitions.keys.joined(separator: ", "))", category: .fileOperations)
                Log.warning("⚠️ Falling back to no clipping for this image", category: .fileOperations)
            }
        }

        shapes.append(imageShape)
    }

    private func parseClipPath(attributes: [String: String]) {
        isParsingClipPath = true
        currentClipPathId = attributes["id"]
        currentClipPath = nil
    }

    private func parseShapeForClipPath(elementName: String, attributes: [String: String]) {
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

        if let path = clipPath {
            if currentClipPath == nil {
                currentClipPath = path
            } else {
            }
        }
    }

    func createShape(name: String, path: VectorPath, attributes: [String: String], geometricType: GeometricShapeType? = nil) -> VectorShape {
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
                } else {
                    Log.error("❌ No styles found for \(selector)", category: .error)
                }
            }
        }

        for (selector, styles) in cssStyles {
            if selector.contains(",") {
                let selectors = selector.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if let className = attributes["class"] {
                    let classNames = className.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    for cls in classNames {
                        if selectors.contains("." + cls) {
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
        let transform: CGAffineTransform
        if mergedAttributes["transform"] != nil {
            let shapeTransform = parseTransform(mergedAttributes["transform"] ?? "")
            transform = currentTransform.concatenating(shapeTransform)
        } else {
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

    internal func checkForClipPath(_ attributes: [String: String]) -> (shouldClip: Bool, clipPathId: String?) {
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

        if let clipPathAttr = mergedAttributes["clip-path"] {
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

    internal func applyClipPathToShape(_ shape: VectorShape, clipPathId: String) {
        guard let clipPath = clipPathDefinitions[clipPathId] else {
            Log.error("❌ Clip path not found: \(clipPathId)", category: .error)
            shapes.append(shape)
            return
        }

        var closedClipPath = clipPath
        if !closedClipPath.isClosed {
            var elements = closedClipPath.elements
            if !elements.isEmpty && !elements.contains(where: { if case .close = $0 { return true }; return false }) {
                elements.append(.close)
            }
            closedClipPath = VectorPath(elements: elements, isClosed: true)
        }

        var maskedShape = shape
        let clipShapeId = UUID()
        maskedShape.clippedByShapeID = clipShapeId
        maskedShape.name = "Masked \(shape.name)"

        shapes.append(maskedShape)

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
