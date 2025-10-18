import SwiftUI

struct UnifiedObjectContentView: View {
    let unifiedObject: VectorObject
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

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
                    .allowsHitTesting(document.currentTool == .font)
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
                                    .allowsHitTesting(document.currentTool == .font)
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
        ShapeView(
            shape: shape,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset,
            isSelected: isSelected,
            viewMode: viewMode,
            isCanvasLayer: unifiedObject.layerIndex == 1,
            isPasteboardLayer: unifiedObject.layerIndex == 0,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger
        )
        .id("\(shape.id)-\(shape.path.isClosed)-\(shape.bounds.hashValue)-\(shape.isClippingPath)-\(shape.clippedByShapeID?.uuidString ?? "none")")
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
                    dragPreviewTrigger: dragPreviewTrigger
                )
            }
        }
        .compositingGroup()
        .opacity(pasteboardBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].opacity : 1.0 } ?? 1.0)
        .blendMode(pasteboardBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].blendMode.swiftUIBlendMode : .normal } ?? .normal)
//        .onAppear {
//            layerOpacities = document.layers.map { $0.opacity }
//            layerBlendModes = document.layers.map { $0.blendMode }
//        }
//        .onChange(of: document.layers.map { $0.opacity }) {
//            layerOpacities = document.layers.map { $0.opacity }
//        }
//        .onChange(of: document.layers.map { $0.blendMode }) {
//            layerBlendModes = document.layers.map { $0.blendMode }
//        }
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
                    dragPreviewTrigger: dragPreviewTrigger
                )
            }
        }
        .compositingGroup()
        .opacity(canvasBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].opacity : 1.0 } ?? 1.0)
        .blendMode(canvasBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].blendMode.swiftUIBlendMode : .normal } ?? .normal)
//        .onAppear {
//            layerOpacities = document.layers.map { $0.opacity }
//            layerBlendModes = document.layers.map { $0.blendMode }
//        }
//        .onChange(of: document.layers.map { $0.opacity }) {
//            layerOpacities = document.layers.map { $0.opacity }
//        }
//        .onChange(of: document.layers.map { $0.blendMode }) {
//            layerBlendModes = document.layers.map { $0.blendMode }
//        }
    }
}

struct NonBackgroundObjectsView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let isShiftPressed: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    @Binding var layerPreviewOpacities: [UUID: Double]

    private var nonBackgroundObjects: [VectorObject] {
        document.getObjectsInStackingOrder().filter { obj in
            // Cull objects from invisible layers
            guard obj.layerIndex < document.layers.count else { return false }
            guard document.layers[obj.layerIndex].isVisible else { return false }

            switch obj.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                return shape.name != "Canvas Background" && shape.name != "Pasteboard Background"
            case .text:
                return true
            }
        }
    }

    private var objectsByLayer: [Int: [VectorObject]] {
        Dictionary(grouping: nonBackgroundObjects, by: { $0.layerIndex })
    }

    var body: some View {
        ZStack {
            ForEach(objectsByLayer.keys.sorted(), id: \.self) { layerIndex in
                if layerIndex < document.layers.count,
                   document.layers[layerIndex].isVisible,
                   let objects = objectsByLayer[layerIndex] {
                    IsolatedLayerView(
                        objects: objects,
                        layerID: document.layers[layerIndex].id,
                        document: document,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        selectedObjectIDs: selectedObjectIDs,
                        viewMode: viewMode,
                        dragPreviewDelta: dragPreviewDelta,
                        dragPreviewTrigger: dragPreviewTrigger,
                        layerOpacity: layerPreviewOpacities[document.layers[layerIndex].id] ?? document.layers[layerIndex].opacity,
                        layerBlendMode: document.layers[layerIndex].blendMode
                    )
                    .equatable()
                }
            }
        }
        .compositingGroup()
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
    let layerOpacity: Double
    let layerBlendMode: BlendMode

    @State private var cachedImage: NSImage?
    @State private var isDragging: Bool = false

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

        // Check if this layer has selection
        let lhsHasSelection = lhs.hasSelection
        let rhsHasSelection = rhs.hasSelection

        // If layer has no selection, don't re-render during drag
        if !lhsHasSelection && !rhsHasSelection {
            // Only re-render if zoom, offset, opacity, or blend mode changed
            return lhs.zoomLevel == rhs.zoomLevel &&
                   lhs.canvasOffset == rhs.canvasOffset &&
                   lhs.layerOpacity == rhs.layerOpacity &&
                   lhs.layerBlendMode == rhs.layerBlendMode &&
                   lhs.viewMode == rhs.viewMode
        }

        // Layer has selection - check all properties
        return lhs.selectedObjectIDs == rhs.selectedObjectIDs &&
               lhs.dragPreviewDelta == rhs.dragPreviewDelta &&
               lhs.dragPreviewTrigger == rhs.dragPreviewTrigger &&
               lhs.zoomLevel == rhs.zoomLevel &&
               lhs.canvasOffset == rhs.canvasOffset &&
               lhs.layerOpacity == rhs.layerOpacity &&
               lhs.layerBlendMode == rhs.layerBlendMode &&
               lhs.viewMode == rhs.viewMode
    }

    var body: some View {
        ZStack {
            let shouldShowCache = isDragging && !hasSelection && cachedImage != nil

            if shouldShowCache {
                // Show cached image - SwiftUI views are HIDDEN
                if let cached = cachedImage {
                    Image(nsImage: cached)
                        .resizable()
                        .frame(width: cached.size.width / zoomLevel, height: cached.size.height / zoomLevel)
                        .offset(x: canvasOffset.x / zoomLevel, y: canvasOffset.y / zoomLevel)
                        .allowsHitTesting(false)
                }
            } else {
                // Render live SwiftUI views
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
                            dragPreviewTrigger: dragPreviewTrigger
                        )
                    }
                }
            }
        }
        .opacity(layerOpacity)
        .blendMode(layerBlendMode.swiftUIBlendMode)
        .onChange(of: dragPreviewDelta) { oldValue, newValue in
            let wasDragging = oldValue != .zero
            let isNowDragging = newValue != .zero

            // Drag started
            if !wasDragging && isNowDragging && !hasSelection {
                print("🔵 CACHE: Rendering layer \(layerID) to cache")
                renderLayerToCache()
                isDragging = true
            }

            // Drag ended
            if wasDragging && !isNowDragging {
                print("🔵 CACHE: Clearing cache for layer \(layerID)")
                isDragging = false
                cachedImage = nil
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
