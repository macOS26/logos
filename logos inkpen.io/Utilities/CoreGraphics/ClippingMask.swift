import SwiftUI

struct ClippingMaskShapeView: View {
    let clippedShape: VectorShape
    let maskShape: VectorShape
    let clippedPath: CGPath
    let maskPath: CGPath
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode
    var body: some View {
        ClippingMaskNSViewRepresentable(
            clippedShape: clippedShape,
            maskShape: maskShape,
            clippedPath: clippedPath,
            maskPath: maskPath,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset,
            isSelected: isSelected,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger,
            viewMode: viewMode
        )
    }
}

struct ClippingMaskNSViewRepresentable: NSViewRepresentable {
    let clippedShape: VectorShape
    let maskShape: VectorShape
    let clippedPath: CGPath
    let maskPath: CGPath
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode

    func makeNSView(context: Context) -> ClippingMaskNSView {
        return ClippingMaskNSView(clippedShape: clippedShape, maskShape: maskShape, clippedPath: clippedPath, maskPath: maskPath, viewMode: viewMode)
    }

    func updateNSView(_ nsView: ClippingMaskNSView, context: Context) {
        nsView.clippedShape = clippedShape
        nsView.clippedPath = clippedPath
        nsView.maskPath = maskPath
        nsView.zoomLevel = zoomLevel
        nsView.canvasOffset = canvasOffset
        nsView.isSelected = isSelected
        nsView.dragPreviewDelta = dragPreviewDelta
        nsView.viewMode = viewMode
        nsView.needsDisplay = true
    }
}

class ClippingMaskNSView: NSView {
    var clippedShape: VectorShape
    var clippedPath: CGPath
    var maskPath: CGPath
    var zoomLevel: Double = 1.0
    var canvasOffset: CGPoint = .zero
    var isSelected: Bool = false
    var dragPreviewDelta: CGPoint = .zero
    var viewMode: ViewMode = .color

    init(clippedShape: VectorShape, maskShape: VectorShape, clippedPath: CGPath, maskPath: CGPath, viewMode: ViewMode = .color) {
        self.clippedShape = clippedShape
        self.clippedPath = clippedPath
        self.maskPath = maskPath
        self.viewMode = viewMode
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()

        context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
        context.scaleBy(x: zoomLevel, y: zoomLevel)

        if isSelected {
            context.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        }

        context.addPath(maskPath)
        context.clip()

        if ImageContentRegistry.containsImage(clippedShape),
           let image = ImageContentRegistry.image(for: clippedShape.id) {
            let pathBounds = clippedShape.path.cgPath.boundingBoxOfPath
            let transformedBounds = pathBounds.applying(clippedShape.transform)
            let effectiveOpacity = viewMode == .keyline ? min(clippedShape.opacity * 0.2, 0.2) : clippedShape.opacity
            context.setAlpha(CGFloat(effectiveOpacity))

            context.translateBy(x: transformedBounds.minX, y: transformedBounds.maxY)
            context.scaleBy(x: 1.0, y: -1.0)

            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: CGRect(origin: .zero, size: transformedBounds.size))
            }
        } else if clippedShape.linkedImagePath != nil || clippedShape.embeddedImageData != nil,
                  let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: clippedShape) {
            let pathBounds = clippedShape.path.cgPath.boundingBoxOfPath
            let transformedBounds = pathBounds.applying(clippedShape.transform)
            let effectiveOpacity = viewMode == .keyline ? min(clippedShape.opacity * 0.2, 0.2) : clippedShape.opacity
            context.setAlpha(CGFloat(effectiveOpacity))

            context.translateBy(x: transformedBounds.minX, y: transformedBounds.maxY)
            context.scaleBy(x: 1.0, y: -1.0)

            if let cgImage = hydrated.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: CGRect(origin: .zero, size: transformedBounds.size))
            }
        } else {
            context.addPath(clippedPath)

            if let fillStyle = clippedShape.fillStyle, fillStyle.color != .clear {
                context.setFillColor(fillStyle.color.cgColor)
                context.fillPath()
            }

            if let strokeStyle = clippedShape.strokeStyle, strokeStyle.color != .clear {
                context.setStrokeColor(strokeStyle.color.cgColor)
                context.setLineWidth(strokeStyle.width)
                context.strokePath()
            }
        }

        context.restoreGState()

        if viewMode == .keyline {
            context.saveGState()

            context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
            context.scaleBy(x: zoomLevel, y: zoomLevel)

            if isSelected {
                context.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
            }

            context.addPath(maskPath)
            context.setStrokeColor(NSColor.systemOrange.cgColor)
            context.setLineWidth(1.0 / zoomLevel)
            context.setLineDash(phase: 0, lengths: [4.0 / zoomLevel, 2.0 / zoomLevel])
            context.strokePath()

            context.restoreGState()
        }
    }
}
