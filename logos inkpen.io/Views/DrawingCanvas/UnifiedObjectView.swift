import SwiftUI
import CoreGraphics
struct VectorObjectView: View {
    let object: VectorObject
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
        guard object.layerIndex >= 0 && object.layerIndex < document.snapshot.layers.count else {
            return true
        }
        return document.snapshot.layers[object.layerIndex].isVisible
    }

    var body: some View {
        Group {
            switch object.objectType {
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
                // Clipping masks are now rendered in Canvas (LayerCanvasView)
                EmptyView()
            case .shape, .image, .warp, .group, .clipGroup:
                // All shapes (including clipped ones) are now rendered in Canvas (LayerCanvasView)
                // This view is only for overlays like text editors
                EmptyView()
            }
        }
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
    let objectsDict: [UUID: VectorObject]  // For looking up mask shapes
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let liveScaleTransform: CGAffineTransform
    let objectUpdateTrigger: UInt
    let dragPreviewTrigger: Bool

    // Pre-filter visible objects OUTSIDE Canvas body (O(n) once per objects change)
    private var visibleObjects: [VectorObject] {
        objects.filter { object in
            guard object.isVisible else { return false }
            return true
        }
    }

    var body: some View {
        Canvas { context, size in
            _ = objectUpdateTrigger
            // Apply base canvas transform (no drag delta)
            let baseTransform = CGAffineTransform.identity
                .translatedBy(x: canvasOffset.x, y: canvasOffset.y)
                .scaledBy(x: zoomLevel, y: zoomLevel)

            // Render objects in original stacking order
            // Selected objects share the same drag delta transform
            for object in visibleObjects {
                let isSelected = selectedObjectIDs.contains(object.id)

                // Apply selection transform (with drag delta) for selected objects
                // For liveScaleTransform, we apply it to the path geometry directly (not context)
                // to keep stroke width constant while scaling the shape
                let isTextObject = if case .text = object.objectType { true } else { false }

                if isSelected && dragPreviewDelta != .zero {
                    context.transform = baseTransform
                        .translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
                } else {
                    context.transform = baseTransform
                }

                // Pass liveScaleTransform to renderShape so it can apply it to the path geometry
                // This keeps stroke width constant during scaling
                let shapeTransform = (isSelected && !isTextObject) ? liveScaleTransform : .identity

                // Get mask shape if this object is clipped
                let maskShape: VectorShape? = {
                    guard let shape = object.shape as VectorShape?,
                          let maskID = shape.clippedByShapeID,
                          let maskObject = objectsDict[maskID] else {
                        return nil
                    }
                    return maskObject.shape
                }()

                switch object.objectType {
                case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    renderShape(shape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape)
                case .image(let shape):
                    renderImage(shape, context: &context, isSelected: isSelected, scaleTransform: shapeTransform, maskShape: maskShape)
                case .text(let shape):
                    // For text, pass liveScaleTransform so it can reflow (don't transform)
                    renderText(shape, context: &context, isSelected: isSelected, liveScaleTransform: isSelected ? liveScaleTransform : .identity, maskShape: maskShape)
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

    // MARK: - Optimized Shape Rendering

    private func renderShape(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil) {
        // Fast path: skip invisible shapes (O(1))
        let hasVisibleFill = viewMode == .color && shape.fillStyle != nil && shape.fillStyle!.color != .clear
        let hasVisibleStroke = (viewMode == .keyline || shape.strokeStyle != nil) && (shape.strokeStyle == nil || shape.strokeStyle!.color != .clear)
        guard hasVisibleFill || hasVisibleStroke else { return }

        // Use cached CGPath (O(1) on cache hit)
        // If scaleTransform is active, apply it to the path geometry to scale the shape
        // while keeping stroke width constant
        let cgPath: CGPath
        if scaleTransform != .identity {
            let mutablePath = CGMutablePath()
            mutablePath.addPath(shape.cachedCGPath, transform: scaleTransform)
            cgPath = mutablePath
        } else {
            cgPath = shape.cachedCGPath
        }

        // Drag delta is now applied at canvas level, not per-object

        // If we have a mask, use drawLayer to isolate clipping
        if let maskShape = maskShape {
            context.drawLayer { layerContext in
                let maskPath = maskShape.cachedCGPath
                layerContext.clip(to: Path(maskPath))

                // Render fill (O(1) for solid, O(n) for gradient where n = stops)
                if viewMode == .color, let fillStyle = shape.fillStyle {
                    if let gradient = fillStyle.gradient {
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: fillStyle, in: &layerContext)
                    } else if fillStyle.color != .clear {
                        layerContext.fill(Path(cgPath), with: .color(fillStyle.color.color.opacity(fillStyle.opacity)))
                    }
                }

                // Render stroke (O(1) for solid, O(n) for gradient or placement strokes)
                if viewMode == .keyline {
                    layerContext.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0)
                } else if let strokeStyle = shape.strokeStyle {
                    if strokeStyle.placement == .center {
                        if let gradient = strokeStyle.gradient {
                            renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: strokeStyle, in: &layerContext)
                        } else if strokeStyle.color != .clear {
                            layerContext.stroke(
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
                        renderStrokeWithPlacement(strokeStyle: strokeStyle, path: cgPath, in: &layerContext)
                    }
                }
            }
        } else {
            // No mask, render directly
            // Render fill (O(1) for solid, O(n) for gradient where n = stops)
            if viewMode == .color, let fillStyle = shape.fillStyle {
                if let gradient = fillStyle.gradient {
                    renderGradientToContext(gradient: gradient, path: cgPath, isStroke: false, strokeStyle: nil, fillStyle: fillStyle, in: &context)
                } else if fillStyle.color != .clear {
                    context.fill(Path(cgPath), with: .color(fillStyle.color.color.opacity(fillStyle.opacity)))
                }
            }

            // Render stroke (O(1) for solid, O(n) for gradient or placement strokes)
            // Stroke width stays constant regardless of scale transform
            if viewMode == .keyline {
                context.stroke(Path(cgPath), with: .color(.black), lineWidth: 1.0)
            } else if let strokeStyle = shape.strokeStyle {
                if strokeStyle.placement == .center {
                    if let gradient = strokeStyle.gradient {
                        renderGradientToContext(gradient: gradient, path: cgPath, isStroke: true, strokeStyle: strokeStyle, in: &context)
                    } else if strokeStyle.color != .clear {
                        context.stroke(
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
                    renderStrokeWithPlacement(strokeStyle: strokeStyle, path: cgPath, in: &context)
                }
            }
        }
    }

    private func renderStrokeWithPlacement(strokeStyle: StrokeStyle, path: CGPath, in context: inout GraphicsContext) {
        // Use PathOperations.outlineStroke for inside/outside strokes
        // Stroke width stays constant (no scaling compensation needed)

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
                // Stroke width stays constant (no scaling compensation)
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

    private func renderText(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, liveScaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil) {
        // Fast validation (O(1))
        guard let vectorText = VectorText.from(shape) else { return }
        guard !vectorText.content.isEmpty else { return }

        // Drag delta is now applied at canvas level, not per-object

        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Apply clipping mask if provided
            if let maskShape = maskShape {
                let maskPath = maskShape.cachedCGPath
                cgContext.addPath(maskPath)
                cgContext.clip()
            }

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

            // Calculate text box width - use scaled width during live preview for reflow
            var textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
            var textPosition = vectorText.position

            if liveScaleTransform != .identity {
                // Apply live scale transform to get new dimensions and position
                let originalBounds = CGRect(
                    x: vectorText.position.x,
                    y: vectorText.position.y,
                    width: textBoxWidth,
                    height: vectorText.areaSize?.height ?? vectorText.bounds.height
                )
                let scaledBounds = originalBounds.applying(liveScaleTransform)
                textBoxWidth = scaledBounds.width
                textPosition = CGPoint(x: scaledBounds.minX, y: scaledBounds.minY)
            }

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

                // Calculate line position using scaled position during live preview
                let glyphLocation = layoutManager.location(forGlyphAt: lineRange.location)
                let lineX: CGFloat
                switch vectorText.typography.alignment.nsTextAlignment {
                case .left, .justified:
                    lineX = textPosition.x + lineUsedRect.origin.x + glyphLocation.x
                case .center, .right:
                    lineX = textPosition.x + lineRect.origin.x + glyphLocation.x
                default:
                    lineX = textPosition.x + lineUsedRect.origin.x + glyphLocation.x
                }
                let lineY = textPosition.y + lineRect.origin.y + glyphLocation.y

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

    // MARK: - Optimized Image Rendering

    private func renderImage(_ shape: VectorShape, context: inout GraphicsContext, isSelected: Bool, scaleTransform: CGAffineTransform = .identity, maskShape: VectorShape? = nil) {
        // Fast validation (O(1))
        guard let imageData = shape.embeddedImageData else { return }
        guard let nsImage = NSImage(data: imageData) else { return }
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }

        // Drag delta is now applied at canvas level, not per-object

        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Apply clipping mask if provided
            if let maskShape = maskShape {
                let maskPath = maskShape.cachedCGPath
                cgContext.addPath(maskPath)
                cgContext.clip()
            }

            // Apply opacity
            cgContext.setAlpha(CGFloat(shape.opacity))

            // Get image bounds from path
            let pathBounds = shape.path.cgPath.boundingBoxOfPath

            // Apply scale transform if active
            var renderBounds = pathBounds
            if scaleTransform != .identity {
                renderBounds = pathBounds.applying(scaleTransform)
            }

            // Apply the shape's transform
            if !shape.transform.isIdentity {
                cgContext.concatenate(shape.transform)
            }

            // Flip coordinate system for image rendering
            cgContext.translateBy(x: renderBounds.minX, y: renderBounds.maxY)
            cgContext.scaleBy(x: 1.0, y: -1.0)

            // Set high-quality rendering
            cgContext.setAllowsAntialiasing(true)
            cgContext.setShouldAntialias(true)
            cgContext.interpolationQuality = .high

            // Draw the image
            cgContext.draw(cgImage, in: CGRect(origin: .zero, size: renderBounds.size))

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
                objectsDict: document.snapshot.objects,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset,
                selectedObjectIDs: selectedObjectIDs,
                viewMode: viewMode,
                dragPreviewDelta: dragPreviewDelta,
                liveScaleTransform: liveScaleTransform,
                objectUpdateTrigger: objectUpdateTrigger,
                dragPreviewTrigger: dragPreviewTrigger
            )

            // For text editor only - filter .text objects first
            ForEach(objects.filter { object in
                guard object.isVisible else { return false }
                if case .text = object.objectType { return true }
                return false
            }, id: \.id) { object in
                VectorObjectView(
                    object: object,
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
        //.id(objectUpdateTrigger)  // Force re-render when layer trigger updates
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
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
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
