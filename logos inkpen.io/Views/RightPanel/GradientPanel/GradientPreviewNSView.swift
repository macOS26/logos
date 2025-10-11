
import SwiftUI
import AppKit


struct GradientPreviewNSView: NSViewRepresentable {
    let gradient: VectorGradient
    let size: CGFloat

    func makeNSView(context: Context) -> GradientPreviewNSViewClass {
        return GradientPreviewNSViewClass(gradient: gradient, size: size)
    }

    func updateNSView(_ nsView: GradientPreviewNSViewClass, context: Context) {
        nsView.gradient = gradient
        nsView.size = size
        nsView.needsDisplay = true
    }
}

class GradientPreviewNSViewClass: NSView {
    var gradient: VectorGradient
    var size: CGFloat

    init(gradient: VectorGradient, size: CGFloat) {
        self.gradient = gradient
        self.size = size
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
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

        let pathBounds = CGRect(x: 0, y: 0, width: size, height: size)
        let path = CGPath(rect: pathBounds, transform: nil)

        let colors = gradient.stops.map { stop -> CGColor in
            if case .clear = stop.color {
                return stop.color.cgColor
            } else {
                return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
            }
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }
        guard let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }

        context.addPath(path)
        context.clip()

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

            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        case .radial(let radial):

            let originX = radial.originPoint.x
            let originY = radial.originPoint.y

            let center = CGPoint(x: pathBounds.minX + pathBounds.width * originX,
                                 y: pathBounds.minY + pathBounds.height * originY)

            context.saveGState()

            context.translateBy(x: center.x, y: center.y)

            let angleRadians = CGFloat(radial.angle * .pi / 180.0)
            context.rotate(by: angleRadians)

            let scaleX = CGFloat(radial.scaleX)
            let scaleY = CGFloat(radial.scaleY)
            context.scaleBy(x: scaleX, y: scaleY)

            let focalPoint: CGPoint
            if let focal = radial.focalPoint {
                focalPoint = CGPoint(x: focal.x, y: focal.y)
            } else {
                focalPoint = CGPoint.zero
            }

            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)

            context.drawRadialGradient(cgGradient, startCenter: focalPoint, startRadius: 0, endCenter: CGPoint.zero, endRadius: radius, options: [.drawsAfterEndLocation])

            context.restoreGState()
        }

        context.restoreGState()
    }
}