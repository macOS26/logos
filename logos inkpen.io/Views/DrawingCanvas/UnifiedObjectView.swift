import SwiftUI
import CoreGraphics
struct UnifiedObjectContentView: View {
    let unifiedObject: VectorObject
    var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let liveScaleTransform: CGAffineTransform
    let liveGradientOriginX: Double?
    let liveGradientOriginY: Double?

    private var layerIsVisible: Bool {
        guard unifiedObject.layerIndex >= 0 && unifiedObject.layerIndex < document.snapshot.layers.count else {
            return true
        }
        return document.snapshot.layers[unifiedObject.layerIndex].isVisible
    }

    var body: some View {
        Group {
            switch unifiedObject.objectType {
            case .text(let shape):
                // Only show NSTextView when editing (blue mode)
                // When selected (green) or unselected (gray), render on Canvas
                if shape.textContent != nil, shape.typography != nil, shape.isEditing == true {
                    StableProfessionalTextCanvas(
                        document: document,
                        textObjectID: shape.id,
                        dragPreviewDelta: dragPreviewDelta,
                        dragPreviewTrigger: dragPreviewTrigger,
                        viewMode: viewMode
                    )
                    .allowsHitTesting(document.viewState.currentTool == .font)
                } else {
                    EmptyView()
                }
            case .clipMask:
                EmptyView()
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape):
                if let _ = shape.clippedByShapeID {
//                    if let maskUnifiedObject = document.snapshot.objects[clipID] {
//                        let maskShape = maskUnifiedObject.shape
//                        let clippedPath = createPreTransformedPath(for: shape)
//                        let maskPath = createPreTransformedPath(for: maskShape)
//                        let isClippedShapeSelected = selectedObjectIDs.contains(unifiedObject.id)
//                        let isMaskShapeSelected = selectedObjectIDs.contains(maskUnifiedObject.id)
//                        let isSelected = isClippedShapeSelected || isMaskShapeSelected
//
//                        ClippingMaskShapeView(
//                            clippedShape: shape,
//                            maskShape: maskShape,
//                            clippedPath: clippedPath,
//                            maskPath: maskPath,
//                            zoomLevel: zoomLevel,
//                            canvasOffset: canvasOffset,
//                            isSelected: isSelected,
//                            dragPreviewDelta: isSelected ? dragPreviewDelta : .zero,
//                            dragPreviewTrigger: dragPreviewTrigger,
//                            viewMode: viewMode
//                        )
//                        .id("\(shape.id)-\(shape.path.isClosed)-\(maskShape.id)-\(maskShape.path.isClosed)-\(shape.clippedByShapeID?.uuidString ?? "none")")
//                    } else {
//                        renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))
//                    }
                } else {
                    ZStack {
                        renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))

                        if shape.isGroupContainer {
                            let _ = print("🟢 RENDER GROUP: isGroupContainer=true, groupedShapes.count=\(shape.groupedShapes.count)")
                            let textShapes = shape.groupedShapes.filter { $0.typography != nil && $0.isVisible }
                            let _ = print("🟢 RENDER GROUP: filtered text shapes count=\(textShapes.count)")
                            ForEach(textShapes, id: \.id) { textShape in
                                let _ = print("🟢 RENDER GROUP: textShape id=\(textShape.id), textContent=\(textShape.textContent != nil), typography=\(textShape.typography != nil)")
                                if textShape.textContent != nil, textShape.typography != nil {
                                    let _ = print("🟢 RENDER GROUP: Creating StableProfessionalTextCanvas for \(textShape.id)")
                                    StableProfessionalTextCanvas(
                                        document: document,
                                        textObjectID: textShape.id,
                                        dragPreviewDelta: dragPreviewDelta,
                                        dragPreviewTrigger: dragPreviewTrigger,
                                        viewMode: viewMode
                                    )
                                    .allowsHitTesting(document.viewState.currentTool == .font)
                                } else {
                                    let _ = print("🔴 RENDER GROUP: SKIPPING textShape \(textShape.id) - textContent or typography is nil")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderRegularShape(shape: VectorShape, isSelected: Bool) -> some View {
        // Refetch latest shape from document (like text does)
        let latestShape = document.findShape(by: shape.id) ?? shape

        ShapeView(
            shape: latestShape,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset,
            isSelected: isSelected,
            viewMode: viewMode,
            isCanvasLayer: unifiedObject.layerIndex == 1,
            isPasteboardLayer: unifiedObject.layerIndex == 0,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger,
            liveScaleTransform: liveScaleTransform,
            liveGradientOriginX: liveGradientOriginX,
            liveGradientOriginY: liveGradientOriginY
        )
        .id("\(shape.id)-\(shape.path.isClosed)-\(latestShape.bounds.hashValue)-\(shape.isClippingPath)-\(shape.clippedByShapeID?.uuidString ?? "none")")
    }

    private func createPreTransformedPath(for shape: VectorShape) -> CGPath {
        let path = CGMutablePath()

        for element in shape.path.elements {
            switch element {
            case .move(let to):
                path.move(to: to.cgPoint)
            case .line(let to):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                path.closeSubpath()
            }
        }

        if !shape.transform.isIdentity {
            let transformedPath = CGMutablePath()
            transformedPath.addPath(path, transform: shape.transform)
            return transformedPath
        }

        return path
    }
}

struct PasteboardBackgroundView: View {
    let pasteboardSize: CGSize
    let pasteboardOrigin: CGPoint
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            let scaledRect = CGRect(
                x: pasteboardOrigin.x * zoomLevel + canvasOffset.x,
                y: pasteboardOrigin.y * zoomLevel + canvasOffset.y,
                width: pasteboardSize.width * zoomLevel,
                height: pasteboardSize.height * zoomLevel
            )

            context.fill(
                Path(roundedRect: scaledRect, cornerRadius: 0),
                with: .color(.black.opacity(0.2))
            )
        }
        .drawingGroup()
    }
}

struct CanvasBackgroundView: View {
    let canvasSize: CGSize
    let backgroundColor: Color
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            let scaledRect = CGRect(
                x: canvasOffset.x,
                y: canvasOffset.y,
                width: canvasSize.width * zoomLevel,
                height: canvasSize.height * zoomLevel
            )

            context.fill(
                Path(roundedRect: scaledRect, cornerRadius: 0),
                with: .color(backgroundColor)
            )
        }
        .drawingGroup()
    }
}

struct LayerCanvasView: View {
    let objects: [VectorObject]
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint

    // Pre-render cache: stores rendered GraphicsContext for each object by UUID
    @State private var preRenderCache: [UUID: CachedRender] = [:]

    // Cache entry: stores both the hash and rendered image
    private struct CachedRender {
        let objectHash: Int
        let renderedImage: GraphicsContext.ResolvedImage
    }

    // Pre-filter visible objects OUTSIDE Canvas body (O(n) once per objects change)
    private var visibleObjects: [VectorObject] {
        objects.filter { object in
            guard object.isVisible else { return false }
            return true
        }
    }

    var body: some View {

        Canvas { context, size in
            // Apply canvas transform ONCE to entire context (O(1))
            var transformedContext = context
            transformedContext.transform = CGAffineTransform.identity
                .translatedBy(x: canvasOffset.x, y: canvasOffset.y)
                .scaledBy(x: zoomLevel, y: zoomLevel)

            for object in visibleObjects {
                let isSelected = selectedObjectIDs.contains(object.id)
                let currentHash = object.hashValue

                // Check cache: if hash matches, use cached render
                if let cached = preRenderCache[object.id], cached.objectHash == currentHash {
                    // Draw cached image (O(1))
                    var ctx = transformedContext
                    if isSelected && dragPreviewDelta != .zero {
                        ctx.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                    }
                    ctx.draw(cached.renderedImage, at: .zero)
                } else {
                    // Render to temporary Image, resolve it, cache it, then draw
                    switch object.objectType {
                    case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                        renderAndCacheShape(shape, objectID: object.id, objectHash: currentHash, in: transformedContext, isSelected: isSelected, context: context)
                    case .text(let shape):
                        renderAndCacheText(shape, objectID: object.id, objectHash: currentHash, in: transformedContext, isSelected: isSelected, context: context)
                    }
                }
            }
        }
    }

    // MARK: - Viewport Culling (O(1) operations)

    private func calculateViewportBounds(size: CGSize) -> CGRect {
        // Convert viewport to document space with padding for smooth scrolling
        let padding: CGFloat = 200.0 // Extra padding to preload nearby objects
        let minX = (-canvasOffset.x - padding) / zoomLevel
        let minY = (-canvasOffset.y - padding) / zoomLevel
        let maxX = (size.width - canvasOffset.x + padding) / zoomLevel
        let maxY = (size.height - canvasOffset.y + padding) / zoomLevel

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func isObjectInViewport(_ bounds: CGRect, viewport: CGRect) -> Bool {
        // Fast AABB intersection test (O(1))
        return bounds.intersects(viewport)
    }

    private func isObjectInViewportSIMD(_ bounds: CGRect, viewport: CGRect) -> Bool {
        // SIMD-accelerated AABB intersection test (O(1), vectorized)
        // Pack bounds into SIMD vectors for parallel comparison
        let objMin = SIMD2<Double>(bounds.minX, bounds.minY)
        let objMax = SIMD2<Double>(bounds.maxX, bounds.maxY)
        let vpMin = SIMD2<Double>(viewport.minX, viewport.minY)
        let vpMax = SIMD2<Double>(viewport.maxX, viewport.maxY)

        // Vectorized intersection test (2 comparisons in parallel)
        // Check overlap: objMax >= vpMin AND objMin <= vpMax
        let overlapMin = objMax .>= vpMin
        let overlapMax = objMin .<= vpMax

        // Combine results: all components must overlap (reduce with AND)
        return all(overlapMin) && all(overlapMax)
    }

    // MARK: - Pre-Render Cache Functions

    private func renderAndCacheShape(_ shape: VectorShape, objectID: UUID, objectHash: Int, in transformedContext: GraphicsContext, isSelected: Bool, context: GraphicsContext) {
        // Get shape bounds for sizing the cached image
        let bounds = shape.bounds
        let cacheSize = CGSize(width: max(1, bounds.width + 100), height: max(1, bounds.height + 100))

        // Render shape to Image
        let image = Image(size: cacheSize) { tempContext in
            // Adjust context to render at origin
            var shapeContext = tempContext
            shapeContext.translateBy(x: -bounds.minX + 50, y: -bounds.minY + 50)
            renderShape(shape, in: shapeContext, isSelected: false) // Render without selection for cache
        }

        // Resolve to cached image
        let resolvedImage = context.resolve(image)

        // Store in cache
        DispatchQueue.main.async {
            preRenderCache[objectID] = CachedRender(objectHash: objectHash, renderedImage: resolvedImage)
        }

        // Draw immediately (without cache transform since we just rendered)
        var ctx = transformedContext
        if isSelected && dragPreviewDelta != .zero {
            ctx.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        }
        ctx.translateBy(x: bounds.minX - 50, y: bounds.minY - 50)
        ctx.draw(resolvedImage, at: .zero)
    }

    private func renderAndCacheText(_ shape: VectorShape, objectID: UUID, objectHash: Int, in transformedContext: GraphicsContext, isSelected: Bool, context: GraphicsContext) {
        // Get text bounds for sizing the cached image
        let bounds = shape.bounds
        let cacheSize = CGSize(width: max(1, bounds.width + 100), height: max(1, bounds.height + 100))

        // Render text to Image
        let image = Image(size: cacheSize) { tempContext in
            // Adjust context to render at origin
            var textContext = tempContext
            textContext.translateBy(x: -bounds.minX + 50, y: -bounds.minY + 50)
            renderText(shape, in: textContext, isSelected: false) // Render without selection for cache
        }

        // Resolve to cached image
        let resolvedImage = context.resolve(image)

        // Store in cache
        DispatchQueue.main.async {
            preRenderCache[objectID] = CachedRender(objectHash: objectHash, renderedImage: resolvedImage)
        }

        // Draw immediately (without cache transform since we just rendered)
        var ctx = transformedContext
        if isSelected && dragPreviewDelta != .zero {
            ctx.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        }
        ctx.translateBy(x: bounds.minX - 50, y: bounds.minY - 50)
        ctx.draw(resolvedImage, at: .zero)
    }

    // MARK: - Optimized Shape Rendering

    private func renderShape(_ shape: VectorShape, in context: GraphicsContext, isSelected: Bool) {
        // Fast path: skip invisible shapes (O(1))
        let hasVisibleFill = viewMode == .color && shape.fillStyle != nil && shape.fillStyle!.color != .clear
        let hasVisibleStroke = (viewMode == .keyline || shape.strokeStyle != nil) && (shape.strokeStyle == nil || shape.strokeStyle!.color != .clear)
        guard hasVisibleFill || hasVisibleStroke else { return }

        // Use cached CGPath (O(1) on cache hit)
        let cgPath = shape.cachedCGPath

        // Apply drag delta if selected (O(1))
        var ctx = context
        if isSelected && dragPreviewDelta != .zero {
            ctx.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        }

        // Render fill (O(1) for solid, O(n) for gradient where n = stops)
        if viewMode == .color, let fillStyle = shape.fillStyle {
            if let gradient = fillStyle.gradient {
                renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: fillStyle, in: &ctx)
            } else if fillStyle.color != .clear {
                ctx.fill(Path(cgPath), with: .color(fillStyle.color.color.opacity(fillStyle.opacity)))
            }
        }

        // Render stroke (O(1) for solid, O(n) for gradient or placement strokes)
        if viewMode == .keyline {
            ctx.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0)
        } else if let strokeStyle = shape.strokeStyle {
            if strokeStyle.placement == .center {
                if let gradient = strokeStyle.gradient {
                    renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: strokeStyle, in: &ctx)
                } else if strokeStyle.color != .clear {
                    ctx.stroke(
                        Path(cgPath),
                        with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity)),
                        style: SwiftUI.StrokeStyle(
                            lineWidth: strokeStyle.width,
                            lineCap: strokeStyle.lineCap.cgLineCap,
                            lineJoin: strokeStyle.lineJoin.cgLineJoin,
                            miterLimit: strokeStyle.miterLimit
                        )
                    )
                }
            } else {
                renderStrokeWithPlacement(strokeStyle: strokeStyle, path: cgPath, in: &ctx)
            }
        }
    }

    private func renderStrokeWithPlacement(strokeStyle: StrokeStyle, path: CGPath, in context: inout GraphicsContext) {
        // Use PathOperations.outlineStroke for inside/outside strokes
        // No need to scale - canvas context is already scaled

        // Get the outlined stroke path
        guard let outlinedPath = PathOperations.outlineStroke(path: path, strokeStyle: strokeStyle) else {
            return
        }

        // Render the outlined path as a filled shape
        if let gradient = strokeStyle.gradient {
            // For outlined strokes, we treat it as a fill but still need stroke opacity
            // Pass isStroke: false since path is already outlined, but pass strokeStyle for opacity
            renderGradientToContext(gradient: gradient, path: outlinedPath, isStroke: false, strokeStyle: strokeStyle, fillStyle: nil, in: &context)
        } else if strokeStyle.color != .clear {
            // Simple fill using SwiftUI's Path
            context.fill(
                Path(outlinedPath),
                with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity))
            )
        }
    }

    private func renderGradientToContext(gradient: VectorGradient, path: CGPath, isStroke: Bool, strokeStyle: StrokeStyle?, fillStyle: FillStyle? = nil, in context: inout GraphicsContext) {
        // Paint gradient directly to CGContext (like we do for CoreText)
        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Apply opacity based on whether we have fillStyle or strokeStyle
            // Note: For outlined strokes, isStroke is false but we still use strokeStyle
            if let fillStyle = fillStyle {
                cgContext.setAlpha(CGFloat(fillStyle.opacity))
            } else if let strokeStyle = strokeStyle {
                cgContext.setAlpha(CGFloat(strokeStyle.opacity))
            }

            // Create stroked path if needed
            let finalPath: CGPath
            if isStroke, let strokeStyle = strokeStyle {
                cgContext.setLineWidth(strokeStyle.width)
                cgContext.setLineCap(strokeStyle.lineCap.cgLineCap)
                cgContext.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
                cgContext.setMiterLimit(strokeStyle.miterLimit)
                cgContext.addPath(path)
                cgContext.replacePathWithStrokedPath()
                finalPath = cgContext.path ?? path
            } else {
                finalPath = path
            }

            // Render gradient directly
            renderCGGradientFill(gradient: gradient, path: finalPath, in: cgContext)

            cgContext.restoreGState()
        }
    }

    // MARK: - Optimized Gradient Rendering

    private func renderCGGradientFill(gradient: VectorGradient, path: CGPath, in cgContext: CGContext) {
        cgContext.saveGState()

        // Fast path bounds calculation (O(1))
        let pathBounds = path.boundingBoxOfPath

        // Optimize color conversion - avoid creating new color objects (O(n) where n = stops)
        let colors: [CGColor] = gradient.stops.map { stop in
            if case .clear = stop.color {
                return stop.color.cgColor
            }
            // Direct CGColor creation is faster than SwiftUI Color wrapper
            return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }

        // Create gradient once (O(n) where n = stops)
        guard let cgGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        ) else {
            cgContext.restoreGState()
            return
        }

        // Clip once (O(1))
        cgContext.addPath(path)
        cgContext.clip()

        // Render gradient based on type
        switch gradient {
        case .linear(let linear):
            // Pre-calculate common values (O(1))
            let scale = CGFloat(linear.scaleX)
            let originX = linear.originPoint.x * scale
            let originY = linear.originPoint.y * scale
            let centerX = pathBounds.minX + pathBounds.width * originX
            let centerY = pathBounds.minY + pathBounds.height * originY
            let angle = CGFloat(linear.storedAngle * .pi / 180.0)

            let dx = linear.endPoint.x - linear.startPoint.x
            let dy = linear.endPoint.y - linear.startPoint.y
            let length = sqrt(dx * dx + dy * dy) * scale * max(pathBounds.width, pathBounds.height)

            let halfLength = length / 2
            let cosAngle = cos(angle)
            let sinAngle = sin(angle)

            let start = CGPoint(
                x: centerX - cosAngle * halfLength,
                y: centerY - sinAngle * halfLength
            )
            let end = CGPoint(
                x: centerX + cosAngle * halfLength,
                y: centerY + sinAngle * halfLength
            )

            cgContext.drawLinearGradient(
                cgGradient,
                start: start,
                end: end,
                options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
            )

        case .radial(let radial):
            let center = CGPoint(
                x: pathBounds.minX + pathBounds.width * radial.originPoint.x,
                y: pathBounds.minY + pathBounds.height * radial.originPoint.y
            )

            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)
            cgContext.rotate(by: CGFloat(radial.angle * .pi / 180.0))
            cgContext.scaleBy(x: CGFloat(radial.scaleX), y: CGFloat(radial.scaleY))

            let focalPoint = radial.focalPoint.map { CGPoint(x: $0.x, y: $0.y) } ?? .zero
            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)

            cgContext.drawRadialGradient(
                cgGradient,
                startCenter: focalPoint,
                startRadius: 0,
                endCenter: .zero,
                endRadius: radius,
                options: [.drawsAfterEndLocation]
            )

            cgContext.restoreGState()
        }

        cgContext.restoreGState()
    }

    // MARK: - Optimized Text Rendering

    private func renderText(_ shape: VectorShape, in context: GraphicsContext, isSelected: Bool) {
        // Fast validation (O(1))
        guard let vectorText = VectorText.from(shape) else { return }
        guard !vectorText.content.isEmpty else { return }

        // Apply drag delta if selected (O(1))
        var ctx = context
        if isSelected && dragPreviewDelta != .zero {
            ctx.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        }

        ctx.withCGContext { cgContext in
            cgContext.saveGState()

            cgContext.setAlpha(CGFloat(vectorText.typography.fillOpacity))

            // Build paragraph style once (O(1))
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
            paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
            paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
            paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight

            let nsFont = vectorText.typography.nsFont
            let textColor = NSColor(cgColor: vectorText.typography.fillColor.cgColor) ?? .black

            // Shared attributes to avoid duplicate dictionary creation
            let commonAttributes: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .paragraphStyle: paragraphStyle,
                .kern: vectorText.typography.letterSpacing
            ]

            // Create layout system once (O(n) where n = text length)
            let attributedString = NSAttributedString(string: vectorText.content, attributes: commonAttributes)
            let textStorage = NSTextStorage(attributedString: attributedString)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)

            let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
            let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: .greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping
            layoutManager.addTextContainer(textContainer)

            // Layout glyphs once (O(n))
            let textRange = NSRange(location: 0, length: vectorText.content.count)
            layoutManager.ensureGlyphs(forGlyphRange: textRange)
            layoutManager.ensureLayout(for: textContainer)

            // Rendering attributes with color (reuse common attributes)
            var renderAttributes = commonAttributes
            renderAttributes[.foregroundColor] = textColor

            let glyphRange = layoutManager.glyphRange(for: textContainer)
            let textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

            // Enumerate and draw lines (O(k) where k = number of lines)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { lineRect, lineUsedRect, _, lineRange, _ in
                let lineString = (vectorText.content as NSString).substring(with: lineRange)
                let lineAttribString = NSAttributedString(string: lineString, attributes: renderAttributes)
                var line = CTLineCreateWithAttributedString(lineAttribString)

                // Apply justification if needed
                if vectorText.typography.alignment.nsTextAlignment == .justified,
                   let justifiedLine = CTLineCreateJustifiedLine(line, 1.0, lineUsedRect.width) {
                    line = justifiedLine
                }

                // Calculate line position
                let glyphLocation = layoutManager.location(forGlyphAt: lineRange.location)
                let lineX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left, .justified:
                    lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    lineX = vectorText.position.x + lineRect.origin.x + glyphLocation.x
                default:
                    lineX = vectorText.position.x + lineUsedRect.origin.x + glyphLocation.x
                }
                let lineY = vectorText.position.y + lineRect.origin.y + glyphLocation.y

                // Draw line
                cgContext.saveGState()
                cgContext.textMatrix = textMatrix
                cgContext.textPosition = CGPoint(x: lineX, y: lineY)
                CTLineDraw(line, cgContext)
                cgContext.restoreGState()
            }

            cgContext.restoreGState()
        }
    }

}

struct IsolatedLayerView: View {
    let objects: [VectorObject]
    let layerID: UUID
    let document: VectorDocument  // NOT @ObservedObject!
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let objectUpdateTrigger: UInt
    let liveScaleTransform: CGAffineTransform
    let layerOpacity: Double
    let layerBlendMode: BlendMode
    let liveGradientOriginX: Double?
    let liveGradientOriginY: Double?
    let selectedObjectData: [UUID: VectorObject]  // Full data of selected objects

    @State private var cachedImage: NSImage?

    // Track if this layer has selection
    private var hasSelection: Bool {
        objects.contains(where: { selectedObjectIDs.contains($0.id) })
    }

   
    var body: some View {
        ZStack {
            // Render paths using Canvas (gradients and text still use SwiftUI)
            LayerCanvasView(
                objects: objects,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedObjectIDs: selectedObjectIDs,
                viewMode: viewMode,
                dragPreviewDelta: dragPreviewDelta
            )

            // For text editor only - filter .text objects first
            ForEach(objects.filter { object in
                guard object.isVisible else { return false }
                if case .text = object.objectType { return true }
                return false
            }, id: \.id) { unifiedObject in
                UnifiedObjectContentView(
                    unifiedObject: unifiedObject,
                    document: document,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    selectedObjectIDs: selectedObjectIDs,
                    viewMode: viewMode,
                    dragPreviewDelta: dragPreviewDelta,
                    dragPreviewTrigger: dragPreviewTrigger,
                    liveScaleTransform: liveScaleTransform,
                    liveGradientOriginX: liveGradientOriginX,
                    liveGradientOriginY: liveGradientOriginY
                )
            }
        }
        .opacity(layerOpacity)
        .blendMode(layerBlendMode.swiftUIBlendMode)
    }

    private func renderLayerToCache() {
        guard !objects.isEmpty else { return }

        let pageSize = document.settings.sizeInPoints
        let retinaScale: CGFloat = 2.0 // Retina resolution
        let renderScale = retinaScale

        // Use Display P3 color space for better color accuracy
        guard let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) else { return }

        guard let context = CGContext(
            data: nil,
            width: Int(pageSize.width * renderScale),
            height: Int(pageSize.height * renderScale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        context.clear(CGRect(x: 0, y: 0, width: pageSize.width * renderScale, height: pageSize.height * renderScale))
        context.translateBy(x: 0, y: pageSize.height * renderScale)
        context.scaleBy(x: renderScale, y: -renderScale)

        // Render all shapes in this layer using Core Graphics
        for object in objects where object.isVisible {
            switch object.objectType {
            case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                FileOperations.drawShapeInPDF(shape, context: context)
            case .text(let shape):
                if let text = VectorText.from(shape) {
                    FileOperations.drawTextInPDF(text, context: context)
                }
            }
        }

        if let cgImage = context.makeImage() {
            cachedImage = NSImage(cgImage: cgImage, size: NSSize(width: pageSize.width, height: pageSize.height))
        }
    }
}

struct CGOpacityModifier: ViewModifier {
    let opacity: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { _ in
                Color.clear.preference(key: OpacityPreferenceKey.self, value: opacity)
            }
        )
        .transformEffect(.identity)
        .opacity(Double(opacity))
    }
}

struct OpacityPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 1.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
