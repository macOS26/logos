import SwiftUI

struct CheckerboardPattern: View {
    let size: CGFloat
    var body: some View {
        GeometryReader { geometry in
            let tileSize = self.size
            let rows = Int(geometry.size.height / tileSize) + 1
            let cols = Int(geometry.size.width / tileSize) + 1

            ZStack {
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        let isEven = (row + col) % 2 == 0
                                Rectangle()
                            .fill(isEven ? Color.white : Color(white: 0.8333))
                            .frame(width: tileSize, height: tileSize)
                            .position(
                                x: CGFloat(col) * tileSize + tileSize / 2,
                                y: CGFloat(row) * tileSize + tileSize / 2
                            )
                    }
                }
            }
        }
    }
}

@ViewBuilder
func renderColorSwatchRightPanel(_ color: VectorColor, width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 0, borderWidth: CGFloat = 0.5, opacity: Double = 1.0) -> some View {
    ZStack {
        CheckerboardPattern(size: min(4, width / 4))
            .frame(width: width, height: height)
            .clipped()

        if case .clear = color {
            if cornerRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.clear)
                    .frame(width: width, height: height)
                    .border(Color.gray, width: borderWidth)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: width, height: height)
                    .border(Color.gray, width: borderWidth)
            }

            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: width, y: height))
            }
            .stroke(Color.red, lineWidth: 3)
            .frame(width: width, height: height)
        } else if case .gradient(let gradient) = color {
            GradientSwatchNSView(gradient: gradient, size: width)
                .frame(width: width, height: height)
                .overlay(
                    Group {
                        if cornerRadius > 0 {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(Color.gray, lineWidth: borderWidth)
                        } else {
                            Rectangle()
                                .stroke(Color.gray, lineWidth: borderWidth)
                        }
                    }
                )
        } else {
            if cornerRadius > 0 {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color.color.opacity(opacity))
                    .frame(width: width, height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.gray, lineWidth: borderWidth)
                    )
            } else {
                Rectangle()
                    .fill(color.color.opacity(opacity))
                    .frame(width: width, height: height)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: borderWidth)
                    )
            }
        }
    }
    .allowsHitTesting(true)
}

struct GradientSwatchNSView: NSViewRepresentable {
    let gradient: VectorGradient
    let size: CGFloat

    func makeNSView(context: Context) -> GradientSwatchNSViewClass {
        return GradientSwatchNSViewClass(gradient: gradient, size: size)
    }

    func updateNSView(_ nsView: GradientSwatchNSViewClass, context: Context) {
        nsView.gradient = gradient
        nsView.size = size
        nsView.needsDisplay = true
    }
}

class GradientSwatchNSViewClass: NSView {
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
        case .linear(_):
            let startPoint = CGPoint(x: 0, y: size / 2)
            let endPoint = CGPoint(x: size, y: size / 2)
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [])

        case .radial(_):
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            context.drawRadialGradient(cgGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }

        context.restoreGState()
    }
}
