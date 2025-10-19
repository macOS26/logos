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
            liveScaleTransform: liveScaleTransform
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
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    private var pasteboardBackground: VectorObject? {
        document.getObjectsInStackingOrder().first { obj in
            switch obj.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.name == "Pasteboard Background"
            case .text:
                return false
            }
        }
    }

    @State private var layerOpacities: [Double] = []
    @State private var layerBlendModes: [BlendMode] = []

    var body: some View {
        ZStack {
            if let pasteboardBackground = pasteboardBackground {
                UnifiedObjectContentView(
                    unifiedObject: pasteboardBackground,
                    document: document,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    selectedObjectIDs: selectedObjectIDs,
                    viewMode: viewMode,
                    dragPreviewDelta: dragPreviewDelta,
                    dragPreviewTrigger: dragPreviewTrigger,
                    liveScaleTransform: .identity
                )
            }
        }
        .compositingGroup()
        .opacity(pasteboardBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].opacity : 1.0 } ?? 1.0)
        .blendMode(pasteboardBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].blendMode.swiftUIBlendMode : .normal } ?? .normal)
    }
}

struct CanvasBackgroundView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    private var canvasBackground: VectorObject? {
        document.getObjectsInStackingOrder().first { obj in
            switch obj.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.name == "Canvas Background"
            case .text:
                return false
            }
        }
    }
//
//    @State private var layerOpacities: [Double] = []
//    @State private var layerBlendModes: [BlendMode] = []

    var body: some View {
        ZStack {
            if let canvasBackground = canvasBackground {
                UnifiedObjectContentView(
                    unifiedObject: canvasBackground,
                    document: document,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    selectedObjectIDs: selectedObjectIDs,
                    viewMode: viewMode,
                    dragPreviewDelta: dragPreviewDelta,
                    dragPreviewTrigger: dragPreviewTrigger,
                    liveScaleTransform: .identity
                )
            }
        }
        .compositingGroup()
        .opacity(canvasBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].opacity : 1.0 } ?? 1.0)
        .blendMode(canvasBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].blendMode.swiftUIBlendMode : .normal } ?? .normal)
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
            // Show cache for inactive layers (no selection)
            let shouldShowCache = !hasSelection && cachedImage != nil

            if shouldShowCache {
                // Show cached image - SwiftUI views are HIDDEN
                if let cached = cachedImage {
                    Image(nsImage: cached)
                        .resizable()
                        .frame(width: cached.size.width * zoomLevel, height: cached.size.height * zoomLevel)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .allowsHitTesting(false)
                }
            } else {
                // Render live SwiftUI views (active layer with selection)
                ForEach(objects, id: \.id) { unifiedObject in
                    if unifiedObject.isVisible {
                        UnifiedObjectContentView(
                            unifiedObject: unifiedObject,
                            document: document,
                            zoomLevel: zoomLevel,
                            canvasOffset: canvasOffset,
                            selectedObjectIDs: selectedObjectIDs,
                            viewMode: viewMode,
                            dragPreviewDelta: dragPreviewDelta,
                            dragPreviewTrigger: dragPreviewTrigger,
                            liveScaleTransform: liveScaleTransform
                        )
                    }
                }
            }
        }
        .opacity(layerOpacity)

        .blendMode(layerBlendMode.swiftUIBlendMode)
        .onAppear {
            // Cache inactive layer on appear
            if !hasSelection {
                renderLayerToCache()
            }
        }
        .onChange(of: hasSelection) { oldValue, newValue in
            if newValue {
                // Layer became active - clear cache to show live views
                cachedImage = nil
            } else {
                // Layer became inactive - create cache
                renderLayerToCache()
            }
        }
        .onChange(of: objects.count) { oldValue, newValue in
            // Objects changed - invalidate cache if inactive
            if !hasSelection {
                renderLayerToCache()
            }
        }
    }

    private func renderLayerToCache() {
        guard !objects.isEmpty else { return }

        let pageSize = document.settings.sizeInPoints
        let scale = zoomLevel

        guard let context = CGContext(
            data: nil,
            width: Int(pageSize.width * scale),
            height: Int(pageSize.height * scale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return }

        context.clear(CGRect(x: 0, y: 0, width: pageSize.width * scale, height: pageSize.height * scale))
        context.translateBy(x: 0, y: pageSize.height * scale)
        context.scaleBy(x: scale, y: -scale)

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
