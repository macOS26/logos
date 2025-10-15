import SwiftUI
import AppKit
import SwiftUI

struct ShapeView: View {
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let viewMode: ViewMode
    let isCanvasLayer: Bool
    let isPasteboardLayer: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    @State private var previewFillOpacity: Double? = nil
    @State private var previewStrokeOpacity: Double? = nil
    @State private var previewStrokeWidth: Double? = nil
    @State private var previewStrokePlacement: StrokePlacement? = nil

    private var effectiveViewMode: ViewMode {
        return (isCanvasLayer || isPasteboardLayer) ? .color : viewMode
    }

    private var effectiveFillOpacity: Double {
        return previewFillOpacity ?? shape.fillStyle?.opacity ?? 1.0
    }

    private var effectiveStrokeOpacity: Double {
        return previewStrokeOpacity ?? shape.strokeStyle?.opacity ?? 1.0
    }

    private var effectiveStrokeWidth: Double {
        return previewStrokeWidth ?? shape.strokeStyle?.width ?? 1.0
    }

    private var effectiveStrokePlacement: StrokePlacement {
        return previewStrokePlacement ?? shape.strokeStyle?.placement ?? .center
    }

    var body: some View {
        ZStack {
            if shape.isGroupContainer {
                if shape.isClippingGroup {
                    // Adobe-style clipping group: first shape is mask, rest are content
                    renderClippingGroup()
                } else {
                    // Regular group
                    ZStack {
                        ForEach(shape.groupedShapes.filter { $0.isVisible }, id: \.id) { groupedShape in
                            if !groupedShape.isTextObject {
                                let cachedPath = Path { path in
                                    addPathElements(groupedShape.path.elements, to: &path)
                                }

                                ZStack {
                                    if effectiveViewMode == .color,
                                       let fillStyle = groupedShape.fillStyle,
                                        fillStyle.color != .clear {
                                        renderFill(fillStyle: fillStyle, path: cachedPath, shape: groupedShape)
                                    }

                                    if effectiveViewMode == .keyline {
                                        cachedPath.stroke(Color.black, lineWidth: 1.0 / zoomLevel)
                                    } else if let strokeStyle = groupedShape.strokeStyle, strokeStyle.color != .clear {
                                        renderStrokeWithPlacement(shape: groupedShape, strokeStyle: strokeStyle, viewMode: effectiveViewMode, path: cachedPath)
                                            .opacity(strokeStyle.placement == .outside ? 1.0 : strokeStyle.opacity)
                                    }
                                }
                                .transformEffect(groupedShape.transform)
                                .opacity(groupedShape.opacity)
                            }
                        }
                    }
                    .transformEffect(shape.transform)
                }
            } else {
                if SVGToInkPenImporter.containsSVGContent(shape),
                   let svgData = SVGToInkPenImporter.getSVGData(for: shape) {
                    SVGShapeRenderer(
                        svgDocument: svgData.document,
                        bounds: shape.bounds,
                        transform: shape.transform,
                        opacity: shape.opacity
                    )
                } else if ImageContentRegistry.containsImage(shape),
                          let image = ImageContentRegistry.image(for: shape.id) {
                    let pathBounds = shape.path.cgPath.boundingBoxOfPath
                    let transformedBounds = pathBounds.applying(shape.transform)

                    ImageNSView(
                        image: image,
                        bounds: transformedBounds,
                        opacity: shape.opacity,
                        fillStyle: shape.fillStyle,
                        viewMode: effectiveViewMode
                    )
                    .offset(x: isSelected ? dragPreviewDelta.x : 0,
                            y: isSelected ? dragPreviewDelta.y : 0)
                } else if shape.linkedImagePath != nil || shape.embeddedImageData != nil {
                    if let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: shape) {
                        let pathBounds = shape.path.cgPath.boundingBoxOfPath
                        let transformedBounds = pathBounds.applying(shape.transform)

                        ImageNSView(
                            image: hydrated,
                            bounds: transformedBounds,
                            opacity: shape.opacity,
                            fillStyle: shape.fillStyle,
                            viewMode: effectiveViewMode
                        )
                        .offset(x: isSelected ? dragPreviewDelta.x : 0,
                                y: isSelected ? dragPreviewDelta.y : 0)
                    } else {
                        let placeholder = Path(CGRect(origin: .zero, size: shape.bounds.size))
                        placeholder
                            .stroke(Color.gray.opacity(0.5), style: SwiftUI.StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .transformEffect(shape.transform)
                    }
                } else {
                    let originalPath = Path { path in
                        addPathElements(shape.path.elements, to: &path)
                    }

                    let finalPath = originalPath.applying(shape.transform)

                    if effectiveViewMode == .color,
                       let fillStyle = shape.fillStyle,
                       fillStyle.color != .clear {
                        renderFill(fillStyle: fillStyle, path: finalPath, shape: shape)
                    }

                    if effectiveViewMode == .keyline {
                        finalPath.stroke(Color.black, lineWidth: 1.0 / zoomLevel)
                    } else if let strokeStyle = shape.strokeStyle, strokeStyle.color != .clear {
                        renderStrokeWithPlacement(shape: shape, strokeStyle: strokeStyle, viewMode: effectiveViewMode, path: finalPath)
                            .opacity(strokeStyle.placement == .outside ? 1.0 : effectiveStrokeOpacity)
                    }
                }
            }

        }
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        .transformEffect(shape.isGroupContainer ? shape.transform : .identity)
        .offset(x: isSelected && !ImageContentRegistry.containsImage(shape) ? dragPreviewDelta.x * zoomLevel : 0,
                y: isSelected && !ImageContentRegistry.containsImage(shape) ? dragPreviewDelta.y * zoomLevel : 0)
        .id(dragPreviewTrigger)
        .opacity(shape.opacity)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShapePreviewUpdate"))) { notification in
            guard let userInfo = notification.userInfo,
                  let shapeID = userInfo["shapeID"] as? UUID,
                  shapeID == shape.id else { return }

            if let fillOpacity = userInfo["fillOpacity"] as? Double {
                previewFillOpacity = fillOpacity
            }
            if let strokeOpacity = userInfo["strokeOpacity"] as? Double {
                previewStrokeOpacity = strokeOpacity
            }
            if let strokeWidth = userInfo["strokeWidth"] as? Double {
                previewStrokeWidth = strokeWidth
            }
            if let placementRaw = userInfo["strokePlacement"] as? String,
               let placement = StrokePlacement(rawValue: placementRaw) {
                previewStrokePlacement = placement
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClearPreviewStates"))) { _ in
            previewFillOpacity = nil
            previewStrokeOpacity = nil
            previewStrokeWidth = nil
            previewStrokePlacement = nil
        }
.id(shape.id)
    }

    @ViewBuilder
    private func renderStrokeWithPlacement(shape: VectorShape, strokeStyle: StrokeStyle, viewMode: ViewMode, path: Path) -> some View {
        // Use the strokeStyle parameter's width, not the outer shape's (important for groups)
        let actualStrokeWidth = previewStrokeWidth ?? strokeStyle.width
        let actualStrokePlacement = previewStrokePlacement ?? strokeStyle.placement
        let swiftUIStrokeStyle = SwiftUI.StrokeStyle(
            lineWidth: actualStrokeWidth,
            lineCap: strokeStyle.lineCap.cgLineCap.swiftUILineCap,
            lineJoin: strokeStyle.lineJoin.cgLineJoin.swiftUILineJoin,
            miterLimit: strokeStyle.miterLimit,
            dash: strokeStyle.dashPattern.map { CGFloat($0) }
        )

        switch actualStrokePlacement {
        case .center:
            renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: swiftUIStrokeStyle, shape: shape)

        case .inside:
            if strokeStyle.isGradient {
                let adjustedStrokeStyle = StrokeStyle(
                    color: strokeStyle.color,
                    width: actualStrokeWidth * 2,
                    placement: .center,
                    dashPattern: strokeStyle.dashPattern.map { $0 * 2 },
                    lineCap: strokeStyle.lineCap.cgLineCap,
                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                    miterLimit: strokeStyle.miterLimit,
                    opacity: strokeStyle.opacity,
                    blendMode: strokeStyle.blendMode
                )
                let doubleWidthStyle = SwiftUI.StrokeStyle(
                    lineWidth: actualStrokeWidth * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )
                renderStrokeColor(strokeStyle: adjustedStrokeStyle, path: path, swiftUIStyle: doubleWidthStyle, shape: shape)
                    .mask(
                        path.fill(Color.black)
                    )
            } else {
                let doubleWidthStyle = SwiftUI.StrokeStyle(
                    lineWidth: actualStrokeWidth * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )
                renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: doubleWidthStyle, shape: shape)
                    .mask(
                        path.fill(Color.black)
                    )
            }

        case .outside:

            let boundingBox = path.cgPath.boundingBoxOfPath
            let expansion = max(actualStrokeWidth * 4, 1000)
            let largeRect = boundingBox.insetBy(dx: -expansion, dy: -expansion)
            let outsideMask = Path { maskPath in
                maskPath.addRect(largeRect)
                maskPath.addPath(path)
            }
                .fill(Color.black, style: SwiftUI.FillStyle(eoFill: true))

            if strokeStyle.isGradient {
                let adjustedStrokeStyle = StrokeStyle(
                    color: strokeStyle.color,
                    width: actualStrokeWidth * 2,
                    placement: .center,
                    dashPattern: strokeStyle.dashPattern.map { $0 * 2 },
                    lineCap: strokeStyle.lineCap.cgLineCap,
                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                    miterLimit: strokeStyle.miterLimit,
                    opacity: strokeStyle.opacity,
                    blendMode: strokeStyle.blendMode
                )
                let doubleWidthStrokeStyle = SwiftUI.StrokeStyle(
                    lineWidth: actualStrokeWidth * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )

                renderStrokeColor(strokeStyle: adjustedStrokeStyle, path: path, swiftUIStyle: doubleWidthStrokeStyle, shape: shape)
                    .mask(outsideMask)
                    .opacity(strokeStyle.opacity)
            } else {
                let doubleWidthStrokeStyle = SwiftUI.StrokeStyle(
                    lineWidth: actualStrokeWidth * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )

                renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: doubleWidthStrokeStyle, shape: shape)
                    .mask(outsideMask)
                    .opacity(strokeStyle.opacity)
            }
        }
    }

    @ViewBuilder
    private func renderFill(fillStyle: FillStyle, path: Path, shape: VectorShape) -> some View {
        // Use the fillStyle parameter's opacity, not the outer shape's (important for groups)
        let actualFillOpacity = previewFillOpacity ?? fillStyle.opacity

        switch fillStyle.color {
        case .gradient(let vectorGradient):
            GradientFillView(gradient: vectorGradient, path: path.cgPath)
                .opacity(actualFillOpacity)

        default:
            path.fill(fillStyle.color.color, style: SwiftUI.FillStyle(eoFill: shape.path.fillRule.cgPathFillRule == .evenOdd))
                .opacity(actualFillOpacity)
        }
    }

    @ViewBuilder
    private func renderStrokeColor(strokeStyle: StrokeStyle, path: Path, swiftUIStyle: SwiftUI.StrokeStyle, shape: VectorShape) -> some View {
        switch strokeStyle.color {
        case .gradient(let vectorGradient):
            GradientStrokeView(gradient: vectorGradient, path: path.cgPath, strokeStyle: strokeStyle)

        default:
            path.stroke(strokeStyle.color.color, style: swiftUIStyle)
        }
    }

    @ViewBuilder
    private func renderClippingGroup() -> some View {
        let visibleShapes = shape.groupedShapes.filter { $0.isVisible }

        if visibleShapes.isEmpty {
            EmptyView()
        } else {
            // First shape is the clipping mask
            let maskShape = visibleShapes.first!
            let contentShapes = Array(visibleShapes.dropFirst())

            if effectiveViewMode == .keyline {
                // In keyline mode, show all shapes as outlines (no clipping)
                ZStack {
                    // Render mask shape outline
                    let maskPath = Path { path in
                        addPathElements(maskShape.path.elements, to: &path)
                    }
                    maskPath
                        .stroke(Color.black, lineWidth: 1.0 / zoomLevel)
                        .transformEffect(maskShape.transform)

                    // Render content shapes outlines
                    ForEach(contentShapes, id: \.id) { contentShape in
                        if !contentShape.isTextObject {
                            let contentPath = Path { path in
                                addPathElements(contentShape.path.elements, to: &path)
                            }
                            contentPath
                                .stroke(Color.black, lineWidth: 1.0 / zoomLevel)
                                .transformEffect(contentShape.transform)
                        }
                    }
                }
                .transformEffect(shape.transform)
            } else {
                // In color mode, apply the clipping mask
                let maskPath = Path { path in
                    addPathElements(maskShape.path.elements, to: &path)
                }
                .applying(maskShape.transform)

                // Render all content shapes
                ZStack {
                    ForEach(contentShapes, id: \.id) { contentShape in
                        if !contentShape.isTextObject {
                            // Check if this is an image
                            if ImageContentRegistry.containsImage(contentShape),
                               let image = ImageContentRegistry.image(for: contentShape.id) {
                                let pathBounds = contentShape.path.cgPath.boundingBoxOfPath
                                let transformedBounds = pathBounds.applying(contentShape.transform)

                                ImageNSView(
                                    image: image,
                                    bounds: transformedBounds,
                                    opacity: contentShape.opacity,
                                    fillStyle: contentShape.fillStyle,
                                    viewMode: effectiveViewMode
                                )
                            } else if contentShape.linkedImagePath != nil || contentShape.embeddedImageData != nil,
                                      let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: contentShape) {
                                let pathBounds = contentShape.path.cgPath.boundingBoxOfPath
                                let transformedBounds = pathBounds.applying(contentShape.transform)

                                ImageNSView(
                                    image: hydrated,
                                    bounds: transformedBounds,
                                    opacity: contentShape.opacity,
                                    fillStyle: contentShape.fillStyle,
                                    viewMode: effectiveViewMode
                                )
                            } else {
                                // Regular vector shape
                                let contentPath = Path { path in
                                    addPathElements(contentShape.path.elements, to: &path)
                                }

                                ZStack {
                                    if let fillStyle = contentShape.fillStyle,
                                       fillStyle.color != .clear {
                                        renderFill(fillStyle: fillStyle, path: contentPath, shape: contentShape)
                                    }

                                    if let strokeStyle = contentShape.strokeStyle, strokeStyle.color != .clear {
                                        renderStrokeWithPlacement(shape: contentShape, strokeStyle: strokeStyle, viewMode: effectiveViewMode, path: contentPath)
                                            .opacity(strokeStyle.placement == .outside ? 1.0 : strokeStyle.opacity)
                                    }
                                }
                                .transformEffect(contentShape.transform)
                                .opacity(contentShape.opacity)
                            }
                        }
                    }
                }
                .mask(maskPath.fill())  // Apply the clipping mask
                .transformEffect(shape.transform)
            }
        }
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
