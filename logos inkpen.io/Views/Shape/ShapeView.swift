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

    /// Preview state for live updates during dragging - avoids triggering @Published document changes
    @State private var previewFillOpacity: Double? = nil
    @State private var previewStrokeOpacity: Double? = nil
    @State private var previewStrokeWidth: Double? = nil
    @State private var previewStrokePlacement: StrokePlacement? = nil

    private var effectiveViewMode: ViewMode {
        return (isCanvasLayer || isPasteboardLayer) ? .color : viewMode
    }

    /// Returns the fill opacity to use - preview value during dragging, actual value otherwise
    private var effectiveFillOpacity: Double {
        return previewFillOpacity ?? shape.fillStyle?.opacity ?? 1.0
    }

    /// Returns the stroke opacity to use - preview value during dragging, actual value otherwise
    private var effectiveStrokeOpacity: Double {
        return previewStrokeOpacity ?? shape.strokeStyle?.opacity ?? 1.0
    }

    /// Returns the stroke width to use - preview value during dragging, actual value otherwise
    private var effectiveStrokeWidth: Double {
        return previewStrokeWidth ?? shape.strokeStyle?.width ?? 1.0
    }

    /// Returns the stroke placement to use - preview value during selection, actual value otherwise
    private var effectiveStrokePlacement: StrokePlacement {
        return previewStrokePlacement ?? shape.strokeStyle?.placement ?? .center
    }

    var body: some View {
        ZStack {
            if shape.isGroupContainer {
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
                                        .opacity(strokeStyle.placement == .outside ? 1.0 : effectiveStrokeOpacity)
                                }
                            }
                            .transformEffect(groupedShape.transform)
                            .opacity(groupedShape.opacity)
                        }
                    }
                }
                .transformEffect(shape.transform)
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

            // Update whichever property was sent in the notification
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
    }

    @ViewBuilder
    private func renderStrokeWithPlacement(shape: VectorShape, strokeStyle: StrokeStyle, viewMode: ViewMode, path: Path) -> some View {
        let swiftUIStrokeStyle = SwiftUI.StrokeStyle(
            lineWidth: effectiveStrokeWidth,
            lineCap: strokeStyle.lineCap.cgLineCap.swiftUILineCap,
            lineJoin: strokeStyle.lineJoin.cgLineJoin.swiftUILineJoin,
            miterLimit: strokeStyle.miterLimit,
            dash: strokeStyle.dashPattern.map { CGFloat($0) }
        )

        switch effectiveStrokePlacement {
        case .center:
            renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: swiftUIStrokeStyle, shape: shape)

        case .inside:
            if strokeStyle.isGradient {
                let adjustedStrokeStyle = StrokeStyle(
                    color: strokeStyle.color,
                    width: effectiveStrokeWidth * 2,
                    placement: .center,
                    dashPattern: strokeStyle.dashPattern.map { $0 * 2 },
                    lineCap: strokeStyle.lineCap.cgLineCap,
                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                    miterLimit: strokeStyle.miterLimit,
                    opacity: effectiveStrokeOpacity,
                    blendMode: strokeStyle.blendMode
                )
                let doubleWidthStyle = SwiftUI.StrokeStyle(
                    lineWidth: effectiveStrokeWidth * 2,
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
                    lineWidth: effectiveStrokeWidth * 2,
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
            let expansion = max(effectiveStrokeWidth * 4, 1000)
            let largeRect = boundingBox.insetBy(dx: -expansion, dy: -expansion)

            let outsideMask = Path { maskPath in
                maskPath.addRect(largeRect)
                maskPath.addPath(path)
            }
                .fill(Color.black, style: SwiftUI.FillStyle(eoFill: true))

            if strokeStyle.isGradient {
                let adjustedStrokeStyle = StrokeStyle(
                    color: strokeStyle.color,
                    width: effectiveStrokeWidth * 2,
                    placement: .center,
                    dashPattern: strokeStyle.dashPattern.map { $0 * 2 },
                    lineCap: strokeStyle.lineCap.cgLineCap,
                    lineJoin: strokeStyle.lineJoin.cgLineJoin,
                    miterLimit: strokeStyle.miterLimit,
                    opacity: effectiveStrokeOpacity,
                    blendMode: strokeStyle.blendMode
                )
                let doubleWidthStrokeStyle = SwiftUI.StrokeStyle(
                    lineWidth: effectiveStrokeWidth * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )

                renderStrokeColor(strokeStyle: adjustedStrokeStyle, path: path, swiftUIStyle: doubleWidthStrokeStyle, shape: shape)
                    .mask(outsideMask)
                    .opacity(effectiveStrokeOpacity)
            } else {
                let doubleWidthStrokeStyle = SwiftUI.StrokeStyle(
                    lineWidth: effectiveStrokeWidth * 2,
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 }
                )

                renderStrokeColor(strokeStyle: strokeStyle, path: path, swiftUIStyle: doubleWidthStrokeStyle, shape: shape)
                    .mask(outsideMask)
                    .opacity(effectiveStrokeOpacity)
            }
        }
    }

    @ViewBuilder
    private func renderFill(fillStyle: FillStyle, path: Path, shape: VectorShape) -> some View {
        switch fillStyle.color {
        case .gradient(let vectorGradient):
            GradientFillView(gradient: vectorGradient, path: path.cgPath)
                .opacity(effectiveFillOpacity)

        default:
            path.fill(fillStyle.color.color, style: SwiftUI.FillStyle(eoFill: shape.path.fillRule.cgPathFillRule == .evenOdd))
                .opacity(effectiveFillOpacity)
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
