import SwiftUI

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
        guard unifiedObject.layerIndex >= 0 && unifiedObject.layerIndex < document.layers.count else {
            return true
        }
        return document.layers[unifiedObject.layerIndex].isVisible
    }

    var body: some View {
        Group {
            switch unifiedObject.objectType {
            case .text(let shape):
                if shape.textContent != nil, shape.typography != nil {
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
                    if let maskUnifiedObject = document.findObject(by: clipID) {
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
        GeometryReader { geometry in
            Canvas { context, size in
                for object in objects {
                    guard object.isVisible else { continue }

                    switch object.objectType {
                    case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
                        // Skip shapes with typography (handled by SwiftUI)
                        if shape.typography != nil { continue }

                        renderShape(shape, in: context, isSelected: selectedObjectIDs.contains(object.id))

                    case .text:
                        continue  // Text handled by SwiftUI
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
            ctx.stroke(Path(transformedPath), with: .color(.black), lineWidth: 1.0 / zoomLevel)
        } else if let strokeStyle = shape.strokeStyle {
            if let gradient = strokeStyle.gradient {
                renderGradientToContext(gradient: gradient, path: transformedPath, isStroke: true, strokeStyle: strokeStyle, in: &ctx)
            } else if strokeStyle.color != .clear {
                ctx.stroke(
                    Path(transformedPath),
                    with: .color(strokeStyle.color.color.opacity(strokeStyle.opacity)),
                    style: SwiftUI.StrokeStyle(
                        lineWidth: strokeStyle.width,
                        lineCap: strokeStyle.lineCap.cgLineCap,
                        lineJoin: strokeStyle.lineJoin.cgLineJoin,
                        miterLimit: strokeStyle.miterLimit
                    )
                )
            }
        }
    }

    private func renderGradientToContext(gradient: VectorGradient, path: CGPath, isStroke: Bool, strokeStyle: StrokeStyle?, in context: inout GraphicsContext) {
        let pathBounds = path.boundingBoxOfPath
        guard pathBounds.width > 0 && pathBounds.height > 0 else { return }

        // Create an offscreen CGContext to render the gradient
        let width = Int(pathBounds.width.rounded(.up))
        let height = Int(pathBounds.height.rounded(.up))

        guard width > 0 && height > 0 else { return }

        guard let cgContext = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }

        // Flip the coordinate system to match SwiftUI's top-left origin
        cgContext.translateBy(x: 0, y: CGFloat(height))
        cgContext.scaleBy(x: 1.0, y: -1.0)

        // Translate to compensate for path bounds
        cgContext.translateBy(x: -pathBounds.minX, y: -pathBounds.minY)

        // Render gradient using existing logic
        let finalPath = isStroke ? createStrokedPath(path, strokeStyle: strokeStyle, in: cgContext) : path
        renderCGGradientFill(gradient: gradient, path: finalPath, in: cgContext)

        // Convert to CGImage and draw
        if let cgImage = cgContext.makeImage() {
            let image = Image(decorative: cgImage, scale: 1.0)
            context.draw(image, at: CGPoint(x: pathBounds.midX, y: pathBounds.midY), anchor: .center)
        }
    }

    private func createStrokedPath(_ path: CGPath, strokeStyle: StrokeStyle?, in cgContext: CGContext) -> CGPath {
        guard let strokeStyle = strokeStyle else { return path }

        cgContext.setLineWidth(strokeStyle.width)
        cgContext.setLineCap(strokeStyle.lineCap.cgLineCap)
        cgContext.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
        cgContext.setMiterLimit(strokeStyle.miterLimit)
        cgContext.addPath(path)
        cgContext.replacePathWithStrokedPath()

        return cgContext.path ?? path
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
                path.closeSubpath()
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

        // Check if objects were reordered (same count but different order)
        for (index, obj) in lhs.objects.enumerated() {
            if index < rhs.objects.count && obj.id != rhs.objects[index].id {
                return false  // Objects reordered - force update
            }
        }

        // Check if this layer has selection
        let lhsHasSelection = lhs.hasSelection
        let rhsHasSelection = rhs.hasSelection

        // Check if drag state changed (started or stopped)
        let lhsDragging = lhs.dragPreviewDelta != .zero
        let rhsDragging = rhs.dragPreviewDelta != .zero
        let dragStateChanged = lhsDragging != rhsDragging

        // If layer has no selection
        if !lhsHasSelection && !rhsHasSelection {
            // Always update if drag state changed (started/stopped) - needed for caching
            if dragStateChanged {
                return false  // Not equal - force update
            }

            // During drag, don't re-render (use cached image)
            if lhsDragging && rhsDragging {
                return true  // Equal - skip re-render
            }

            // Not dragging - only re-render if zoom, offset, opacity, blend mode, or scale transform changed
            return lhs.zoomLevel == rhs.zoomLevel &&
                   lhs.canvasOffset == rhs.canvasOffset &&
                   lhs.layerOpacity == rhs.layerOpacity &&
                   lhs.layerBlendMode == rhs.layerBlendMode &&
                   lhs.liveScaleTransform == rhs.liveScaleTransform &&
                   lhs.viewMode == rhs.viewMode
        }

        // Layer has selection - check all properties
        return lhs.selectedObjectIDs == rhs.selectedObjectIDs &&
               lhs.dragPreviewDelta == rhs.dragPreviewDelta &&
               lhs.dragPreviewTrigger == rhs.dragPreviewTrigger &&
               lhs.liveScaleTransform == rhs.liveScaleTransform &&
               lhs.zoomLevel == rhs.zoomLevel &&
               lhs.canvasOffset == rhs.canvasOffset &&
               lhs.layerOpacity == rhs.layerOpacity &&
               lhs.layerBlendMode == rhs.layerBlendMode &&
               lhs.viewMode == rhs.viewMode
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

            // Render text and gradients using SwiftUI views
            ForEach(objects, id: \.id) { unifiedObject in
                if unifiedObject.isVisible {
                    let needsSwiftUIRendering = checkNeedsSwiftUIRendering(unifiedObject)
                    if needsSwiftUIRendering {
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
            }
        }
        .opacity(layerOpacity)
        .blendMode(layerBlendMode.swiftUIBlendMode)
    }

    private func checkNeedsSwiftUIRendering(_ object: VectorObject) -> Bool {
        switch object.objectType {
        case .text:
            return true  // Text needs SwiftUI
        case .shape(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape):
            // Only text shapes with typography need SwiftUI, all others rendered by Canvas (including gradients)
            if shape.typography != nil { return true }
            return false
        }
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
