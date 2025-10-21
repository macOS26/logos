import SwiftUI
import CoreGraphics
struct UnifiedObjectContentView: View {
    let unifiedObject: VectorObject
    @ObservedObject var document: VectorDocument
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
                if let clipID = shape.clippedByShapeID {
                    if let maskUnifiedObject = document.snapshot.objects[clipID] {
                        let maskShape = maskUnifiedObject.shape
                        let clippedPath = createPreTransformedPath(for: shape)
                        let maskPath = createPreTransformedPath(for: maskShape)
                        let isClippedShapeSelected = selectedObjectIDs.contains(unifiedObject.id)
                        let isMaskShapeSelected = selectedObjectIDs.contains(maskUnifiedObject.id)
                        let isSelected = isClippedShapeSelected || isMaskShapeSelected

                        ClippingMaskShapeView(
                            clippedShape: shape,
                            maskShape: maskShape,
                            clippedPath: clippedPath,
                            maskPath: maskPath,
                            zoomLevel: zoomLevel,
                            canvasOffset: canvasOffset,
                            isSelected: isSelected,
                            dragPreviewDelta: isSelected ? dragPreviewDelta : .zero,
                            dragPreviewTrigger: dragPreviewTrigger,
                            viewMode: viewMode
                        )
                        .id("\(shape.id)-\(shape.path.isClosed)-\(maskShape.id)-\(maskShape.path.isClosed)-\(shape.clippedByShapeID?.uuidString ?? "none")")
                    } else {
                        renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))
                    }
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
    }
}

struct LayerCanvasView: View {
    let objects: [VectorObject]
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint

    var body: some View {
        Canvas { context, size in
            for object in objects {
                guard object.isVisible else { continue }

                switch object.objectType {
                case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                    // Skip shapes with typography (handled by SwiftUI)
                    if shape.typography != nil { continue }

                    renderShape(shape, in: context, isSelected: selectedObjectIDs.contains(object.id))

                case .text(let shape):
                    // Filter out text objects that are in editing mode (blue mode)
                    if shape.isEditing == true { continue }

                    // Render text on Canvas when NOT editing (green/gray mode)
                    let isSelected = selectedObjectIDs.contains(object.id)
                    renderText(shape, in: context, isSelected: isSelected)
                }
            }
        }
    }

    private func renderShape(_ shape: VectorShape, in context: GraphicsContext, isSelected: Bool) {
        // Create CGPath from VectorPath
        let cgPath = createCGPath(from: shape.path, transform: shape.transform)

        // Apply zoom and offset transform, plus drag preview for selected shapes
        var transformedPath = cgPath
        var canvasTransform = CGAffineTransform.identity
            .translatedBy(x: canvasOffset.x, y: canvasOffset.y)
            .scaledBy(x: zoomLevel, y: zoomLevel)

        // Apply drag preview delta for selected shapes
        if isSelected && dragPreviewDelta != .zero {
            canvasTransform = canvasTransform.translatedBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        }

        if let scaledPath = transformedPath.copy(using: &canvasTransform) {
            transformedPath = scaledPath
        }

        var ctx = context

        // Render fill
        if viewMode == .color, let fillStyle = shape.fillStyle {
            if let gradient = fillStyle.gradient {
                // Use CGImage for gradient rendering
                renderGradientToContext(gradient: gradient, path: transformedPath, isStroke: false, strokeStyle: nil, in: &ctx)
            } else if fillStyle.color != .clear {
                ctx.fill(Path(transformedPath), with: .color(fillStyle.color.color.opacity(fillStyle.opacity)))
            }
        }

        // Render stroke
        if viewMode == .keyline {
            // Use actual stroke width if available, otherwise use a default
            let strokeWidth = shape.strokeStyle?.width ?? 1.0
            ctx.stroke(Path(transformedPath), with: .color(.black), lineWidth: strokeWidth * zoomLevel)
        } else if let strokeStyle = shape.strokeStyle {
            if strokeStyle.placement == .center {
                // Standard center stroke
                if let gradient = strokeStyle.gradient {
                    renderGradientToContext(gradient: gradient, path: transformedPath, isStroke: true, strokeStyle: strokeStyle, in: &ctx)
                } else if strokeStyle.color != .clear {
                    ctx.stroke(
                        Path(transformedPath),
                        with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity)),
                        style: SwiftUI.StrokeStyle(
                            lineWidth: strokeStyle.width * zoomLevel,
                            lineCap: strokeStyle.lineCap.cgLineCap,
                            lineJoin: strokeStyle.lineJoin.cgLineJoin,
                            miterLimit: strokeStyle.miterLimit
                        )
                    )
                }
            } else {
                // Inside or outside stroke - use path operations
                renderStrokeWithPlacement(strokeStyle: strokeStyle, path: transformedPath, in: &ctx)
            }
        }
    }

    private func renderStrokeWithPlacement(strokeStyle: StrokeStyle, path: CGPath, in context: inout GraphicsContext) {
        // Use PathOperations.outlineStroke for inside/outside strokes
        // Need to scale the stroke style for zoom level
        let scaledStrokeStyle = StrokeStyle(
            color: strokeStyle.color,
            width: strokeStyle.width * zoomLevel,
            placement: strokeStyle.placement,
            dashPattern: strokeStyle.dashPattern,
            lineCap: strokeStyle.lineCap.cgLineCap,
            lineJoin: strokeStyle.lineJoin.cgLineJoin,
            miterLimit: strokeStyle.miterLimit,
            opacity: strokeStyle.opacity,
            blendMode: strokeStyle.blendMode
        )

        // Get the outlined stroke path
        guard let outlinedPath = PathOperations.outlineStroke(path: path, strokeStyle: scaledStrokeStyle) else {
            return
        }

        // Render the outlined path with fill
        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Render with gradient or solid color
            if let gradient = strokeStyle.gradient {
                renderCGGradientFill(gradient: gradient, path: outlinedPath, in: cgContext)
            } else {
                cgContext.setFillColor(strokeStyle.color.cgColor)
                cgContext.setAlpha(strokeStyle.opacity)
                cgContext.addPath(outlinedPath)
                cgContext.fillPath()
            }

            cgContext.restoreGState()
        }
    }

    private func renderGradientToContext(gradient: VectorGradient, path: CGPath, isStroke: Bool, strokeStyle: StrokeStyle?, in context: inout GraphicsContext) {
        // Paint gradient directly to CGContext (like we do for CoreText)
        context.withCGContext { cgContext in
            cgContext.saveGState()

            // Create stroked path if needed
            let finalPath: CGPath
            if isStroke, let strokeStyle = strokeStyle {
                cgContext.setLineWidth(strokeStyle.width * zoomLevel)
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

    private func renderCGGradientFill(gradient: VectorGradient, path: CGPath, in cgContext: CGContext) {
        cgContext.saveGState()

        let pathBounds = path.boundingBoxOfPath
        let colors = gradient.stops.map { stop -> CGColor in
            if case .clear = stop.color {
                return stop.color.cgColor
            } else {
                return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
            }
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }

        guard let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            cgContext.restoreGState()
            return
        }

        cgContext.addPath(path)
        cgContext.clip()

        switch gradient {
        case .linear(let linear):
            let originX = linear.originPoint.x
            let originY = linear.originPoint.y
            let scale = CGFloat(linear.scaleX)
            let scaledOriginX = originX * scale
            let scaledOriginY = originY * scale
            let centerX = pathBounds.minX + pathBounds.width * scaledOriginX
            let centerY = pathBounds.minY + pathBounds.height * scaledOriginY
            let gradientAngle = CGFloat(linear.storedAngle * .pi / 180.0)
            let gradientVector = CGPoint(x: linear.endPoint.x - linear.startPoint.x, y: linear.endPoint.y - linear.startPoint.y)
            let gradientLength = sqrt(gradientVector.x * gradientVector.x + gradientVector.y * gradientVector.y)
            let scaledLength = gradientLength * CGFloat(scale) * max(pathBounds.width, pathBounds.height)

            let startX = centerX - cos(gradientAngle) * scaledLength / 2
            let startY = centerY - sin(gradientAngle) * scaledLength / 2
            let endX = centerX + cos(gradientAngle) * scaledLength / 2
            let endY = centerY + sin(gradientAngle) * scaledLength / 2
            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)

            cgContext.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        case .radial(let radial):
            let originX = radial.originPoint.x
            let originY = radial.originPoint.y
            let center = CGPoint(x: pathBounds.minX + pathBounds.width * originX,
                                 y: pathBounds.minY + pathBounds.height * originY)

            cgContext.saveGState()
            cgContext.translateBy(x: center.x, y: center.y)

            let angleRadians = CGFloat(radial.angle * .pi / 180.0)
            cgContext.rotate(by: angleRadians)

            let scaleX = CGFloat(radial.scaleX)
            let scaleY = CGFloat(radial.scaleY)
            cgContext.scaleBy(x: scaleX, y: scaleY)

            let focalPoint: CGPoint
            if let focal = radial.focalPoint {
                focalPoint = CGPoint(x: focal.x, y: focal.y)
            } else {
                focalPoint = CGPoint.zero
            }

            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)
            cgContext.drawRadialGradient(cgGradient, startCenter: focalPoint, startRadius: 0, endCenter: CGPoint.zero, endRadius: radius, options: [.drawsAfterEndLocation])

            cgContext.restoreGState()
        }

        cgContext.restoreGState()
    }

    private func renderText(_ shape: VectorShape, in context: GraphicsContext, isSelected: Bool) {
        // Convert VectorShape to VectorText (same as PDF export)
        guard let vectorText = VectorText.from(shape) else { return }
        guard !vectorText.content.isEmpty else { return }

        // Use CoreGraphics to render CTLine directly on Canvas (same as PDF export)
        context.withCGContext { cgContext in
            // Apply zoom and canvas offset transform
            cgContext.translateBy(x: canvasOffset.x, y: canvasOffset.y)
            cgContext.scaleBy(x: zoomLevel, y: zoomLevel)

            // Apply drag preview delta for selected text (like shapes do)
            if isSelected && dragPreviewDelta != .zero {
                cgContext.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
            }

            // EXACT SAME CODE AS PDF EXPORT (renderTextToPDF_Lines)
            let nsFont = vectorText.typography.nsFont
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = vectorText.typography.alignment.nsTextAlignment
            paragraphStyle.lineSpacing = max(0, vectorText.typography.lineSpacing)
            paragraphStyle.minimumLineHeight = vectorText.typography.lineHeight
            paragraphStyle.maximumLineHeight = vectorText.typography.lineHeight

            let layoutAttributes: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .paragraphStyle: paragraphStyle,
                .kern: vectorText.typography.letterSpacing
            ]

            let attributedString = NSAttributedString(string: vectorText.content, attributes: layoutAttributes)
            let textStorage = NSTextStorage(attributedString: attributedString)
            let layoutManager = NSLayoutManager()
            textStorage.addLayoutManager(layoutManager)

            let textBoxWidth = vectorText.areaSize?.width ?? vectorText.bounds.width
            let textContainer = NSTextContainer(size: CGSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))
            textContainer.lineFragmentPadding = 0
            textContainer.lineBreakMode = .byWordWrapping
            layoutManager.addTextContainer(textContainer)

            layoutManager.ensureGlyphs(forGlyphRange: NSRange(location: 0, length: vectorText.content.count))
            layoutManager.ensureLayout(for: textContainer)

            cgContext.saveGState()

            cgContext.setAlpha(CGFloat(vectorText.typography.fillOpacity))

            let renderingAttributes: [NSAttributedString.Key: Any] = [
                .font: nsFont,
                .paragraphStyle: paragraphStyle,
                .kern: vectorText.typography.letterSpacing,
                .foregroundColor: NSColor(cgColor: vectorText.typography.fillColor.cgColor) ?? NSColor.black
            ]

            let glyphRange = layoutManager.glyphRange(for: textContainer)

            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (lineRect, lineUsedRect, container, lineRange, stop) in
                let lineRange = NSRange(location: lineRange.location, length: lineRange.length)
                let lineString = (vectorText.content as NSString).substring(with: lineRange)
                let lineAttribString = NSAttributedString(string: lineString, attributes: renderingAttributes)
                var line = CTLineCreateWithAttributedString(lineAttribString)

                if vectorText.typography.alignment.nsTextAlignment == .justified {
                    if let justifiedLine = CTLineCreateJustifiedLine(line, 1.0, lineUsedRect.width) {
                        line = justifiedLine
                    }
                }

                let firstGlyphIndex = lineRange.location
                let glyphLocation = layoutManager.location(forGlyphAt: firstGlyphIndex)
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

                cgContext.saveGState()

                cgContext.textMatrix = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 0)

                cgContext.textPosition = CGPoint(x: lineX, y: lineY)
                CTLineDraw(line, cgContext)

                cgContext.restoreGState()
            }

            cgContext.restoreGState()
        }
    }

    private func createCGPath(from vectorPath: VectorPath, transform: CGAffineTransform) -> CGPath {
        let path = CGMutablePath()

        for element in vectorPath.elements {
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
                if !path.isEmpty {
                    path.closeSubpath()
                }
            }
        }

        if !transform.isIdentity {
            var mutableTransform = transform
            return path.copy(using: &mutableTransform) ?? path
        }

        return path
    }
}

struct IsolatedLayerView: View, Equatable {
    let objects: [VectorObject]
    let layerID: UUID
    let document: VectorDocument  // NOT @ObservedObject!
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
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

    // Equatable: Only re-render if layer has selection and drag changed, or if objects changed
    static func == (lhs: IsolatedLayerView, rhs: IsolatedLayerView) -> Bool {

        // If layer ID changed, definitely need to re-render
        guard lhs.layerID == rhs.layerID else { return false }

        // If objects array changed, need to re-render
        guard lhs.objects.count == rhs.objects.count else { return false }

        guard lhs.selectedObjectIDs == rhs.selectedObjectIDs else { return false}

        // Check if objects themselves changed (not just count/order)
        guard lhs.objects == rhs.objects else { return false }

        // Layer has selection - check all properties INCLUDING selected object data
        
        if lhs.selectedObjectIDs == rhs.selectedObjectIDs {
            return lhs.selectedObjectData == rhs.selectedObjectData &&
                   lhs.dragPreviewDelta == rhs.dragPreviewDelta &&
                   lhs.dragPreviewTrigger == rhs.dragPreviewTrigger &&
                   lhs.liveScaleTransform == rhs.liveScaleTransform &&
                   lhs.zoomLevel == rhs.zoomLevel &&
                   lhs.canvasOffset == rhs.canvasOffset &&
                   lhs.layerOpacity == rhs.layerOpacity &&
                   lhs.layerBlendMode == rhs.layerBlendMode &&
                   lhs.viewMode == rhs.viewMode
        } else {
            // Not dragging - only re-render if zoom, offset, opacity, blend mode, or scale transform changed
            return lhs.zoomLevel == rhs.zoomLevel &&
                   lhs.canvasOffset == rhs.canvasOffset &&
                   lhs.layerOpacity == rhs.layerOpacity &&
                   lhs.layerBlendMode == rhs.layerBlendMode &&
                   lhs.liveScaleTransform == rhs.liveScaleTransform &&
                   lhs.viewMode == rhs.viewMode
                   
        }
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
