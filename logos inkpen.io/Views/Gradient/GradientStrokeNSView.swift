import SwiftUI
import SwiftUI

class GradientStrokeNSView: NSView {
    var gradient: VectorGradient
    var path: CGPath
    var strokeStyle: StrokeStyle

    init(gradient: VectorGradient, path: CGPath, strokeStyle: StrokeStyle) {
        self.gradient = gradient
        self.path = path
        self.strokeStyle = strokeStyle
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

        context.setLineWidth(strokeStyle.width)
        context.setLineCap(strokeStyle.lineCap.cgLineCap)
        context.setLineJoin(strokeStyle.lineJoin.cgLineJoin)
        context.setMiterLimit(strokeStyle.miterLimit)

        context.setStrokeColorSpace(CGColorSpaceCreateDeviceRGB())

        switch gradient {
        case .linear(let linear):
            context.addPath(path)
            context.replacePathWithStrokedPath()

            let strokeBounds = context.boundingBoxOfPath

            let startPoint = CGPoint(x: strokeBounds.minX, y: strokeBounds.minY + strokeBounds.height * CGFloat(linear.originPoint.y))
            let endPoint = CGPoint(x: strokeBounds.maxX, y: strokeBounds.minY + strokeBounds.height * CGFloat(linear.originPoint.y))

            context.clip()
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [])

        case .radial(let radial):
            context.addPath(path)
            context.replacePathWithStrokedPath()

            let strokeBounds = context.boundingBoxOfPath

            let center = CGPoint(x: strokeBounds.minX + strokeBounds.width * CGFloat(radial.originPoint.x),
                                y: strokeBounds.minY + strokeBounds.height * CGFloat(radial.originPoint.y))
            let radius = max(strokeBounds.width, strokeBounds.height) * CGFloat(radial.radius)

            context.clip()
            context.drawRadialGradient(cgGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }

        context.restoreGState()
    }
}


    func calculateOrientedBoundingBox(for shape: VectorShape) -> [CGPoint] {


        if shape.isGroup || shape.isGroupContainer {
            let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds

            let objectSpaceCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]

            let worldSpaceCorners = objectSpaceCorners.map { corner in
                corner.applying(shape.transform)
            }


            return worldSpaceCorners
        }

        let pathElements = shape.path.elements
        var actualCorners: [CGPoint] = []


        for element in pathElements {
            switch element {
            case .move(let to):
                actualCorners.append(to.cgPoint)
            case .line(let to):
                actualCorners.append(to.cgPoint)
            case .curve(let to, _, _):
                actualCorners.append(to.cgPoint)
            case .quadCurve(let to, _):
                actualCorners.append(to.cgPoint)
            case .close:
                break
            }

            if actualCorners.count >= 4 && (shape.geometricType == .rectangle || pathElements.count <= 6) {
                break
            }
        }

        if actualCorners.count >= 4 && (shape.geometricType == .rectangle || shape.geometricType == .star || pathElements.count <= 8) {
            let detectedCorners = Array(actualCorners.prefix(4))
            return detectedCorners
        }

        let objectSpaceBounds = shape.path.cgPath.boundingBoxOfPath

        let objectSpaceCorners = [
            CGPoint(x: objectSpaceBounds.minX, y: objectSpaceBounds.minY),
            CGPoint(x: objectSpaceBounds.maxX, y: objectSpaceBounds.minY),
            CGPoint(x: objectSpaceBounds.maxX, y: objectSpaceBounds.maxY),
            CGPoint(x: objectSpaceBounds.minX, y: objectSpaceBounds.maxY)
        ]

        let worldSpaceCorners = objectSpaceCorners.map { corner in
            corner.applying(shape.transform)
        }

        return worldSpaceCorners
    }
