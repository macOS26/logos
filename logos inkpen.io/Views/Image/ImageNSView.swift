
import SwiftUI
import AppKit
import SwiftUI


struct ImageNSView: NSViewRepresentable {
    let image: NSImage
    let bounds: CGRect
    let opacity: Double
    let fillStyle: FillStyle?
    let viewMode: ViewMode

    func makeNSView(context: Context) -> ImageNSViewClass {
        return ImageNSViewClass(image: image, bounds: bounds, opacity: opacity, fillStyle: fillStyle, viewMode: viewMode)
    }

    func updateNSView(_ nsView: ImageNSViewClass, context: Context) {
        nsView.image = image
        nsView.imageBounds = bounds
        nsView.opacity = opacity
        nsView.fillStyle = fillStyle
        nsView.viewMode = viewMode
        nsView.needsDisplay = true
    }
}

class ImageNSViewClass: NSView {
    var image: NSImage
    var imageBounds: CGRect
    var opacity: Double
    var fillStyle: FillStyle?
    var viewMode: ViewMode

    init(image: NSImage, bounds: CGRect, opacity: Double, fillStyle: FillStyle? = nil, viewMode: ViewMode = .color) {
        self.image = image
        self.imageBounds = bounds
        self.opacity = opacity
        self.fillStyle = fillStyle
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

        let effectiveOpacity = viewMode == .keyline ? min(opacity * 0.2, 0.2) : opacity
        context.setAlpha(CGFloat(effectiveOpacity))

        context.translateBy(x: imageBounds.minX, y: imageBounds.maxY)
        context.scaleBy(x: 1.0, y: -1.0)

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.interpolationQuality = .high

            context.draw(cgImage, in: CGRect(origin: .zero, size: imageBounds.size))
        }

        if let fillStyle = fillStyle, fillStyle.color != .clear {
            context.setBlendMode(.lighten)
            context.setFillColor(fillStyle.color.cgColor)
            context.setAlpha(CGFloat(fillStyle.opacity))

            context.fill(CGRect(origin: .zero, size: imageBounds.size))
        }

        context.restoreGState()
    }
}
