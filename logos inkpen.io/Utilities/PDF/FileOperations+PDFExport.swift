//
//  FileOperations+PDFExport.swift
//  logos inkpen.io
//
//  Created by Claude on 1/13/25.
//

import SwiftUI

// MARK: - PDF Export Extensions with Clipping Path and Image Support
extension FileOperations {

    /// Generate PDF data from VectorDocument with proper clipping path and image support
    static func generatePDFDataWithClippingSupport(from document: VectorDocument, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, includeInkpenData: Bool = false, includeBackground: Bool = true) throws -> Data {
        // Get document dimensions - use sizeInPoints which is already in points
        let documentSize = document.settings.sizeInPoints

        // Create PDF context with correct media box size
        let pdfData = NSMutableData()

        // CRITICAL FIX: Set media box in context creation to avoid default 8.5x11
        var mediaBox = CGRect(origin: .zero, size: documentSize)

        // Create auxiliary dictionary for PDF options
        // CRITICAL: Enforce PDF 1.7 to prevent macOS defaulting to PDF 1.3
        let auxiliaryDict: [String: Any] = [
            // Metadata
            kCGPDFContextCreator as String: "Inkpen.io",
            kCGPDFContextAuthor as String: NSFullUserName(),
            kCGPDFContextTitle as String: "Inkpen Document",
            // Additional metadata for better PDF support
            kCGPDFContextSubject as String: "Vector Graphics",
            kCGPDFContextKeywords as String: "vector, graphics, illustration"
        ]

        let auxiliaryInfo = auxiliaryDict as CFDictionary

        // Create PDF context with proper media box and auxiliary info
        guard let pdfConsumer = CGDataConsumer(data: pdfData),
              let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, auxiliaryInfo) else {
            throw VectorImportError.parsingError("Failed to create PDF context", line: nil)
        }

        // Embed inkpen document metadata if requested
        if includeInkpenData {

            // Serialize document to JSON
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601

            if let jsonData = try? encoder.encode(document) {
                // Create XMP metadata with inkpen namespace
                let base64String = jsonData.base64EncodedString()

                // Create XMP metadata format (no BOM character to avoid encoding issues)
                let xmpMetadata = """
                <?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
                <x:xmpmeta xmlns:x="adobe:ns:meta/">
                    <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
                        <rdf:Description rdf:about=""
                            xmlns:inkpen="https://inkpen.io/ns/1.0/">
                            <inkpen:document>\(base64String)</inkpen:document>
                        </rdf:Description>
                    </rdf:RDF>
                </x:xmpmeta>
                <?xpacket end="w"?>
                """

                // Convert to CFData and add to PDF context
                if let xmpData = xmpMetadata.data(using: .utf8) {
                    pdfContext.addDocumentMetadata(xmpData as CFData)
                }
            }
        }

        // Begin PDF page with proper page boxes
        let pageInfo = [
            kCGPDFContextMediaBox as String: mediaBox,
            kCGPDFContextArtBox as String: mediaBox,  // Art box for actual content
            kCGPDFContextTrimBox as String: mediaBox, // Trim box for final trim size
            kCGPDFContextBleedBox as String: mediaBox // Bleed box (no bleed for now)
        ] as [String : Any]
        pdfContext.beginPDFPage(pageInfo as CFDictionary)

        // Set PDF compatibility by using features that require PDF 1.4+
        // Transparency groups require PDF 1.4
        pdfContext.setBlendMode(.normal)
        pdfContext.setShouldAntialias(true)
        pdfContext.setAllowsAntialiasing(true)

        // Enable interpolation for better gradient rendering
        pdfContext.interpolationQuality = .high

        // Flip Y-axis to match standard coordinate system
        pdfContext.translateBy(x: 0, y: documentSize.height)
        pdfContext.scaleBy(x: 1.0, y: -1.0)

        // Set background color from document settings only if includeBackground is true
        if includeBackground && document.settings.backgroundColor != .clear {
            pdfContext.setFillColor(document.settings.backgroundColor.cgColor)
            pdfContext.fill(mediaBox)
        }

        // Render document content with clipping path support
        try renderDocumentToPDFWithClipping(document: document, context: pdfContext, isExport: isExport, useCMYK: useCMYK, textRenderingMode: textRenderingMode, includeBackground: includeBackground)

        // End PDF document
        pdfContext.endPDFPage()
        pdfContext.closePDF()

        return pdfData as Data
    }

    /// Render VectorDocument to PDF context with clipping path support
    static func renderDocumentToPDFWithClipping(document: VectorDocument, context: CGContext, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs, includeBackground: Bool = true) throws {

        // Save graphics state
        context.saveGState()

        // Build a map of clipping relationships
        var clippingMasks: [UUID: VectorShape] = [:]
        var clippedShapes: [UUID: [VectorShape]] = [:]

        // First pass: organize shapes by clipping relationships
        for (index, layer) in document.layers.enumerated() {
            autoreleasepool {
                // Skip pasteboard (index 0) and canvas (index 1) for PDF export
                guard index >= 2, !layer.isLocked, layer.isVisible else { return }

                let shapesInLayer = document.getShapesForLayer(index)
                for shape in shapesInLayer where shape.isVisible {
                    if shape.isClippingPath {
                        clippingMasks[shape.id] = shape
                        if clippedShapes[shape.id] == nil {
                            clippedShapes[shape.id] = []
                        }
                    } else if let clipId = shape.clippedByShapeID {
                        if clippedShapes[clipId] == nil {
                            clippedShapes[clipId] = []
                        }
                        clippedShapes[clipId]?.append(shape)
                    }
                }
            }
        }

        // Set to track already rendered shapes
        var renderedShapeIds = Set<UUID>()

        // Render layers (skip pasteboard and canvas background)
        for (index, layer) in document.layers.enumerated() {
            // Skip pasteboard (index 0) and canvas (index 1) for PDF export
            guard index >= 2, !layer.isLocked, layer.isVisible else { continue }

            try autoreleasepool {

                // Save graphics state for layer opacity and blend mode
                context.saveGState()

                // CRITICAL: Set blend mode and opacity BEFORE beginTransparencyLayer
                // This applies them to the entire layer group, not to individual shapes inside

                // Apply layer blend mode if not normal
                if layer.blendMode != .normal {
                    context.setBlendMode(layer.blendMode.cgBlendMode)
                }

                // Apply layer opacity
                if layer.opacity < 1.0 {
                    context.setAlpha(CGFloat(layer.opacity))
                }

                // CRITICAL FIX: ALWAYS use transparency groups for ALL layers
                // This ensures consistent rendering at all zoom levels in PDF viewers
                // Even layers with normal blend mode and 100% opacity need this for proper isolation
                context.beginTransparencyLayer(auxiliaryInfo: nil)

                // Render shapes in layer using unified objects - SAME AS SVG
                // Skip text objects here - they will be rendered on top in a second pass
                let shapesInLayer = document.getShapesForLayer(index)
                for shape in shapesInLayer where shape.isVisible {
                    // Skip Canvas Background if not including background
                    if !includeBackground && shape.name == "Canvas Background" {
                        continue
                    }

                    // CRITICAL: Skip text objects - render them on top later (matches SVG)
                    if shape.isTextObject {
                        continue
                    }

                    // Skip if already rendered as part of a clipping group
                    guard !renderedShapeIds.contains(shape.id) else { continue }

                    // If this shape is clipped by another shape, skip it here
                    // It will be rendered with its clipping mask
                    if shape.clippedByShapeID != nil {
                        continue
                    }

                    // If this is a clipping mask, render it with its clipped shapes
                    if shape.isClippingPath, let clipped = clippedShapes[shape.id], !clipped.isEmpty {
                        try renderClippingGroup(
                            clippingMask: shape,
                            clippedShapes: clipped,
                            context: context,
                            isExport: isExport,
                            useCMYK: useCMYK,
                            textRenderingMode: textRenderingMode
                        )
                        renderedShapeIds.insert(shape.id)
                        clipped.forEach { renderedShapeIds.insert($0.id) }
                    } else if !shape.isClippingPath {
                        // Regular shape without clipping
                        try renderShapeToPDFWithImageSupport(shape: shape, context: context, isExport: isExport, useCMYK: useCMYK, textRenderingMode: textRenderingMode)
                        renderedShapeIds.insert(shape.id)
                    }
                }

                // End transparency layer (always opened above)
                context.endTransparencyLayer()

                // Restore graphics state for layer
                context.restoreGState()
            }
        }

        // SECOND PASS: Render all text objects on top (matches SVG behavior)
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType,
               shape.isTextObject && shape.isVisible {
                // Skip text objects on Pasteboard (always) or Canvas (if not including background)
                let layer = document.layers[safe: unifiedObject.layerIndex]
                if layer?.name == "Pasteboard" {
                    continue // ALWAYS skip Pasteboard
                }
                if !includeBackground && layer?.name == "Canvas" {
                    continue // Skip Canvas only if not including background
                }

                // Render the text object
                if let vectorText = VectorText.from(shape) {
                    try renderTextToPDF(vectorText: vectorText, context: context, renderingMode: textRenderingMode)
                }
            }
        }

        // Restore graphics state
        context.restoreGState()

    }

    /// Render a clipping group (mask and clipped shapes)
    static func renderClippingGroup(clippingMask: VectorShape, clippedShapes: [VectorShape], context: CGContext, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs) throws {

        // Save graphics state for clipping
        context.saveGState()

        // Apply the clipping mask's transform
        context.concatenate(clippingMask.transform)

        // Set up the clipping path
        let clipPath = convertVectorPathToCGPath(clippingMask.path)
        context.addPath(clipPath)
        context.clip()

        // Reset transform for clipped content
        context.concatenate(clippingMask.transform.inverted())

        // Render all clipped shapes
        for shape in clippedShapes {
            try renderShapeToPDFWithImageSupport(shape: shape, context: context, isExport: isExport, useCMYK: useCMYK, textRenderingMode: textRenderingMode)
        }

        // Restore graphics state to remove clipping
        context.restoreGState()
    }

    /// Render individual shape to PDF context with image support and proper group handling
    static func renderShapeToPDFWithImageSupport(shape: VectorShape, context: CGContext, isExport: Bool = false, useCMYK: Bool = false, textRenderingMode: AppState.PDFTextRenderingMode = .glyphs) throws {
        // Check if this is a text object - render as PDF text instead of paths
        if shape.isTextObject, let vectorText = VectorText.from(shape) {
            try renderTextToPDF(vectorText: vectorText, context: context, renderingMode: textRenderingMode)
            return
        }

        // Check if this is a group - create proper PDF transparency group
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // IMPORTANT: Create a PDF transparency group (Form XObject)
            // This will be recognized as a group in Illustrator and other PDF editors
            
            
            // Save graphics state for group
            context.saveGState()
            
            // Apply group transform if any
            context.concatenate(shape.transform)
            
            // Begin PDF transparency group
            // This creates a Form XObject that will be recognized as a group
            context.beginTransparencyLayer(auxiliaryInfo: nil)
            
            // Apply group opacity if it's less than 1.0
            if shape.opacity < 1.0 {
                context.setAlpha(CGFloat(shape.opacity))
            }
            
            // Apply group blend mode if not normal
            if shape.blendMode != .normal {
                context.setBlendMode(shape.blendMode.cgBlendMode)
            }
            
            // Render each shape in the group recursively
            for groupedShape in shape.groupedShapes {
                try renderShapeToPDFWithImageSupport(
                    shape: groupedShape, 
                    context: context, 
                    isExport: isExport, 
                    useCMYK: useCMYK,
                    textRenderingMode: textRenderingMode
                )
            }
            
            // End the transparency group
            context.endTransparencyLayer()
            
            // Restore graphics state
            context.restoreGState()
            
            return
        }

        // Check if this is an image shape
        // First check for embedded data
        if let imageData = shape.embeddedImageData {
            try renderImageToPDF(shape: shape, imageData: imageData, context: context)
            return
        }

        // Try to hydrate linked images if available
        if let image = ImageContentRegistry.hydrateImageIfAvailable(for: shape) {
            // Convert to data for rendering
            if let tiffRep = image.tiffRepresentation {
                try renderImageToPDF(shape: shape, imageData: tiffRep, context: context)
                return
            }
        }

        // Regular vector shape rendering
        let cgPath = convertVectorPathToCGPath(shape.path)

        // Save graphics state for this shape
        context.saveGState()

        // Apply shape transform
        context.concatenate(shape.transform)

        // Handle fill
        if let fillStyle = shape.fillStyle {
            // Check if fill is a gradient
            if case .gradient(let gradient) = fillStyle.color {
                // For gradients, we need to clip first then draw
                context.addPath(cgPath)
                context.saveGState()
                context.clip()

                // Draw the gradient - use export version if this is an export
                if isExport {
                    drawPDFGradientForExport(gradient, in: context, bounds: cgPath.boundingBox, opacity: fillStyle.opacity, useCMYK: useCMYK)
                } else {
                    drawPDFGradient(gradient, in: context, bounds: cgPath.boundingBox, opacity: fillStyle.opacity)
                }

                context.restoreGState()
            } else {
                // Regular color fill
                context.addPath(cgPath)
                setFillStyle(fillStyle, context: context)
                context.fillPath()
            }
        }

        // Handle stroke - NEVER export stroke if color is .clear (checkerboard/none)
        if let strokeStyle = shape.strokeStyle {
            // DO NOT EXPORT STROKE IF COLOR IS CLEAR!
            if case .clear = strokeStyle.color {
                // Skip stroke completely - this is the "none" stroke (checkerboard)
            } else if strokeStyle.width > 0 && strokeStyle.opacity > 0 {
                // Only export stroke if it has a real color, width, and opacity
                context.addPath(cgPath)
                setStrokeStyle(strokeStyle, context: context)
                context.strokePath()
            }
        }

        // Restore graphics state
        context.restoreGState()
    }

    /// Render image to PDF context
    static func renderImageToPDF(shape: VectorShape, imageData: Data, context: CGContext) throws {

        // Create NSImage from data
        guard let nsImage = NSImage(data: imageData) else {
            Log.error("Failed to create NSImage from embedded data", category: .error)
            return
        }

        // Get CGImage from NSImage
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Log.error("Failed to get CGImage from NSImage", category: .error)
            return
        }

        // Save graphics state
        context.saveGState()

        // Apply shape transform
        context.concatenate(shape.transform)

        // Apply shape opacity if needed
        if shape.opacity < 1.0 {
            context.setAlpha(CGFloat(shape.opacity))
        }

        // Draw the image within the shape bounds
        let bounds = shape.bounds

        // Translate to the image position
        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.minY)

        // Flip the image vertically since we already flipped the context
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw the image at origin with correct size
        context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))

        context.restoreGState()

        // Restore graphics state
        context.restoreGState()

    }

    /// Render text to PDF context using actual PDF text (searchable/selectable)
    /// Uses the SAME NSLayoutManager logic as text-to-outlines for precise positioning
    static func renderTextToPDF(vectorText: VectorText, context: CGContext, renderingMode: AppState.PDFTextRenderingMode = .glyphs) throws {

        guard !vectorText.content.isEmpty else { return }

        // Dispatch to appropriate rendering method based on mode
        switch renderingMode {
        case .glyphs:
            try renderTextToPDF_Glyphs(vectorText: vectorText, context: context)
        case .lines:
            try renderTextToPDF_Lines(vectorText: vectorText, context: context)
        }
    }

    /// Render text by individual glyphs (most accurate)
    /// Uses the SAME NSLayoutManager logic as text-to-outlines for precise positioning
    private static func renderTextToPDF_Glyphs(vectorText: VectorText, context: CGContext) throws {

        guard !vectorText.content.isEmpty else { return }

        // Create the EXACT same NSLayoutManager setup as text-to-outlines (ProfessionalTextViewModel:387-418)
        let nsFont = vectorText.typography.nsFont
        let ctFont = nsFont as CTFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
        paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight

        let attributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,
            .kern: vectorText.typography.letterSpacing
        ]

        let attributedString = NSAttributedString(string: vectorText.content, attributes: attributes)

        // Create text storage and layout manager (SAME AS TEXT-TO-OUTLINES)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // SAME container setup as convertUsingNSLayoutManager:411
        let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
        let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        // Force complete layout
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: vectorText.content.count))
        layoutManager.ensureLayout(for: textContainer)

        // Save graphics state
        context.saveGState()

        // Apply opacity and set fill color (SAME AS OTHER PDF RENDERING)
        context.setAlpha(CGFloat(vectorText.typography.fillOpacity))

        // Use setFillColor with cgColor (same pattern as setFillStyle in FileOperations+PDF.swift:99-125)
        let cgColor = vectorText.typography.fillColor.cgColor
        if let components = cgColor.components, components.count >= 3 {
            context.setFillColor(red: components[0], green: components[1], blue: components[2], alpha: vectorText.typography.fillOpacity)
        } else if let components = cgColor.components, components.count == 2 {
            context.setFillColor(gray: components[0], alpha: vectorText.typography.fillOpacity)
        } else {
            context.setFillColor(cgColor)
        }

        // Set text drawing mode (fill only, no stroke for now)
        context.setTextDrawingMode(.fill)

        // Create CGFont for glyph drawing (SAME AS TEXT-TO-OUTLINES:429-434)
        let cgFont = CTFontCopyGraphicsFont(ctFont, nil)

        // Set font on context for glyph drawing
        context.setFont(cgFont)
        context.setFontSize(nsFont.pointSize)

        // Track skipped glyphs for logging
        var skippedGlyphCount = 0

        // Enumerate line fragments (SAME AS TEXT-TO-OUTLINES:442)
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in

            // Draw each glyph individually with precise positioning (SAME AS TEXT-TO-OUTLINES but draw instead of path)
            for glyphIndex in lineRange.location..<NSMaxRange(lineRange) {
                let glyph = layoutManager.cgGlyph(at: glyphIndex)
                let glyphLocation = layoutManager.location(forGlyphAt: glyphIndex)

                // CRITICAL FIX: Check if this is a rectangular placeholder glyph (missing character)
                // Same detection as ProfessionalTextViewModel:514-524
                if let glyphPath = CTFontCreatePathForGlyph(ctFont, CGGlyph(glyph), nil) {
                    if isRectangleGlyph(glyphPath) {
                        // Skip this glyph - it's a missing character placeholder
                        skippedGlyphCount += 1

                        continue
                    }
                }

                // Get line fragment rects for this glyph (SAME AS TEXT-TO-OUTLINES:451-455)
                var actualLineRect = CGRect.zero
                var actualUsedRect = CGRect.zero
                var effectiveRange = NSRange()
                actualLineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)
                actualUsedRect = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &effectiveRange, withoutAdditionalLayout: true)

                // Calculate glyph X position (MATCH TEXT-TO-OUTLINES:469-483)
                let glyphX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left, .justified:
                    // For left and justified: use actualUsedRect for precise start position
                    glyphX = vectorText.position.x + actualUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    // For center and right: use lineRect since glyphLocation.x already includes the alignment offset
                    glyphX = vectorText.position.x + lineRect.origin.x + glyphLocation.x
                default:
                    // Fallback to left alignment behavior
                    glyphX = vectorText.position.x + actualUsedRect.origin.x + glyphLocation.x
                }

                // Calculate glyph Y position (SAME AS TEXT-TO-OUTLINES:483)
                let glyphY = vectorText.position.y + actualLineRect.origin.y + glyphLocation.y

                // Draw glyph at position using CoreGraphics (creates actual PDF text)
                context.saveGState()

                // CRITICAL FIX: Apply text matrix to flip Y-axis for correct PDF orientation
                // PDF coordinate system has Y=0 at bottom, increasing upward
                // We need to flip the text to render correctly
                context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

                // Set text position and draw glyph
                context.textPosition = CGPoint(x: glyphX, y: glyphY)
                context.showGlyphs([glyph], at: [CGPoint.zero])

                context.restoreGState()
            }
        }

        context.restoreGState()

        // Report skipped glyphs if any

    }

    /// Helper method to detect if a glyph path is a rectangle (missing character placeholder)
    /// Same logic as ProfessionalTextViewModel:270-345
    private static func isRectangleGlyph(_ path: CGPath) -> Bool {
        // Analyze the path structure
        var subpaths: [[CGPoint]] = []
        var currentPath: [CGPoint] = []
        var hasCurves = false

        path.applyWithBlock { elementPointer in
            let element = elementPointer.pointee
            switch element.type {
            case .moveToPoint:
                // Start a new subpath
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                }
                currentPath = [element.points[0]]

            case .addLineToPoint:
                // Add line point
                currentPath.append(element.points[0])

            case .addQuadCurveToPoint, .addCurveToPoint:
                // If we have curves, it's not a rectangle
                hasCurves = true

            case .closeSubpath:
                // Close current subpath
                if !currentPath.isEmpty {
                    subpaths.append(currentPath)
                    currentPath = []
                }

            @unknown default:
                break
            }
        }

        // Add any remaining path
        if !currentPath.isEmpty {
            subpaths.append(currentPath)
        }

        // Rectangles have no curves
        if hasCurves {
            return false
        }

        // Missing glyph rectangles typically have exactly 2 subpaths (outer and inner)
        if subpaths.count != 2 {
            return false
        }

        // Check if both subpaths are rectangles (4 or 5 points including close)
        for subpath in subpaths {
            if subpath.count < 4 || subpath.count > 5 {
                return false
            }

            // Check if points form a rectangle (all angles are 90 degrees)
            if !isRectangularPath(subpath) {
                return false
            }
        }

        // Check if one rectangle is inside the other (counter pattern)
        let bounds1 = boundingBox(of: subpaths[0])
        let bounds2 = boundingBox(of: subpaths[1])

        let isNested = (bounds1.contains(bounds2) || bounds2.contains(bounds1))

        if isNested {
            return true
        }

        return false
    }

    /// Helper to check if points form a rectangle
    private static func isRectangularPath(_ points: [CGPoint]) -> Bool {
        guard points.count >= 4 else { return false }

        // Check that we have mostly horizontal and vertical lines
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]

            let dx = abs(p2.x - p1.x)
            let dy = abs(p2.y - p1.y)

            // Line should be mostly horizontal or vertical
            let isHorizontal = dy < 0.1 && dx > 0.1
            let isVertical = dx < 0.1 && dy > 0.1

            if !isHorizontal && !isVertical {
                return false
            }
        }

        return true
    }

    /// Helper to calculate bounding box of points
    private static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }

        var minX = points[0].x
        var minY = points[0].y
        var maxX = points[0].x
        var maxY = points[0].y

        for point in points {
            minX = min(minX, point.x)
            minY = min(minY, point.y)
            maxX = max(maxX, point.x)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Render text by lines using CTLine (better performance, maintains placement accuracy)
    private static func renderTextToPDF_Lines(vectorText: VectorText, context: CGContext) throws {

        guard !vectorText.content.isEmpty else { return }

        // Create the EXACT same NSLayoutManager setup
        let nsFont = vectorText.typography.nsFont
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
        paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
        paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
        paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight

        // Attributes for layout manager (no foregroundColor for layout)
        let layoutAttributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,
            .kern: vectorText.typography.letterSpacing
        ]

        let attributedString = NSAttributedString(string: vectorText.content, attributes: layoutAttributes)

        // Create text storage and layout manager (SAME AS TEXT-TO-OUTLINES)
        let textStorage = NSTextStorage(attributedString: attributedString)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        // SAME container setup as convertUsingNSLayoutManager:411
        let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
        let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))
        textContainer.lineFragmentPadding = 0
        textContainer.lineBreakMode = .byWordWrapping
        layoutManager.addTextContainer(textContainer)

        // Force complete layout
        layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: vectorText.content.count))
        layoutManager.ensureLayout(for: textContainer)

        // Save graphics state
        context.saveGState()

        // Apply opacity
        context.setAlpha(CGFloat(vectorText.typography.fillOpacity))

        // Attributes for CTLine rendering (WITH paragraphStyle for justification spacing)
        // NOTE: CTLine ignores alignment from paragraphStyle (we handle via glyphLocation.x),
        // but it DOES use justification to add word spacing
        let renderingAttributes: [NSAttributedString.Key: Any] = [
            .font: nsFont,
            .paragraphStyle: paragraphStyle,  // Required for justification spacing
            .kern: vectorText.typography.letterSpacing,
            .foregroundColor: NSColor(cgColor: vectorText.typography.fillColor.cgColor) ?? NSColor.black
        ]

        // Enumerate line fragments
        let glyphRange = layoutManager.glyphRange(for: textContainer)

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
            // Create CTLine from the range of text in this line with proper color
            let lineRange = NSRange(location: lineRange.location, length: lineRange.length)
            let lineString = (vectorText.content as NSString).substring(with: lineRange)
            let lineAttribString = NSAttributedString(string: lineString, attributes: renderingAttributes)
            var line = CTLineCreateWithAttributedString(lineAttribString)

            // CRITICAL FIX: Create justified line if needed
            if vectorText.typography.alignment.nsTextAlignment == .justified {
                // CTLine needs explicit justification using CTLineCreateJustifiedLine
                // Use lineUsedRect.width as the target width for justification
                if let justifiedLine = CTLineCreateJustifiedLine(line, 1.0, lineUsedRect.width) {
                    line = justifiedLine
                }
            }

            // Get baseline offset from first glyph in line (needed for Y position AND X offset)
            let firstGlyphIndex = lineRange.location
            let glyphLocation = layoutManager.location(forGlyphAt: firstGlyphIndex)

            // CRITICAL FIX: NSLayoutManager stores alignment offset in glyphLocation.x, NOT lineRect.origin.x
            // This is the EXACT same logic as the glyph method (lines 530-540)
            let lineX: CGFloat
            switch vectorText.typography.alignment.nsTextAlignment {
            case .left, .justified:
                // For left and justified: use lineUsedRect for precise start position
                lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
            case .center, .right:
                // CRITICAL FIX: Use lineRect + glyphLocation (same as glyph method!)
                // glyphLocation.x contains the alignment offset for center/right
                lineX = vectorText.position.x + lineRect.origin.x + glyphLocation.x
            default:
                // Fallback to left alignment behavior
                lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
            }
            let lineY = vectorText.position.y + lineRect.origin.y + glyphLocation.y

            // Draw the line
            context.saveGState()

            // CRITICAL FIX: Apply text matrix to flip Y-axis for correct PDF orientation
            context.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

            // Set text position and draw line
            context.textPosition = CGPoint(x: lineX, y: lineY)
            CTLineDraw(line, context)

            context.restoreGState()
        }

        context.restoreGState()

    }
}