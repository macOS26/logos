import SwiftUI

struct GradientPreviewAndStopsView: View {
    let currentGradient: VectorGradient?
    let document: VectorDocument
    @Binding var editingGradientStopId: UUID?
    @Binding var editingGradientStopColor: VectorColor
    @Binding var showingGradientColorPicker: Bool
    let getGradientStops: (VectorGradient) -> [GradientStop]
    let getOriginX: (VectorGradient) -> Double
    let getOriginY: (VectorGradient) -> Double
    let getScale: (VectorGradient) -> Double
    let getAspectRatio: (VectorGradient) -> Double
    let updateOriginX: (Double, Bool) -> Void
    let updateOriginY: (Double, Bool) -> Void
    let updateOriginXOptimized: (Double, Bool, Bool) -> Void
    let updateOriginYOptimized: (Double, Bool, Bool) -> Void
    let addColorStop: () -> Void
    let updateStopPosition: (UUID, Double) -> Void
    let updateStopOpacity: (UUID, Double) -> Void
    let removeColorStop: (UUID) -> Void
    let applyGradientToSelectedShapes: () -> Void
    let applyGradientToSelectedShapesOptimized: (Bool) -> Void
    let activateGradientStop: (UUID, VectorColor) -> Void

    private func createGradientPreview(geometry: GeometryProxy, squareSize: CGFloat) -> some View {
        return Canvas { context, size in
            guard let gradient = currentGradient else {
                // Draw gray background if no gradient
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray.opacity(0.3)))
                context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(Color.ui.lightGrayBorder), lineWidth: 1)
                return
            }

            // Draw gradient background using CGContext
            context.withCGContext { cgContext in
                renderGradientToCGContext(gradient: gradient, context: cgContext, size: size)
            }

            // Draw border
            context.stroke(Path(CGRect(origin: .zero, size: size)), with: .color(Color.ui.lightGrayBorder), lineWidth: 1)

            // Draw grid lines
            for i in 0..<5 {
                let position = CGFloat(i) / 4.0
                let xPos = position * size.width
                let yPos = position * size.height
                let isCenter = position == 0.5
                let opacity = isCenter ? 0.9 : 0.3
                let width: CGFloat = isCenter ? 1.0 : 0.5

                // Vertical line
                var vLine = Path()
                vLine.move(to: CGPoint(x: xPos, y: 0))
                vLine.addLine(to: CGPoint(x: xPos, y: size.height))
                context.stroke(vLine, with: .color(.white.opacity(opacity)), lineWidth: width)

                // Horizontal line
                var hLine = Path()
                hLine.move(to: CGPoint(x: 0, y: yPos))
                hLine.addLine(to: CGPoint(x: size.width, y: yPos))
                context.stroke(hLine, with: .color(.white.opacity(opacity)), lineWidth: width)
            }

            // Draw grid intersection dots
            let gridPoints: [(x: CGFloat, y: CGFloat, isCenter: Bool)] = [
                (0, 0, false), (0.5, 0, false), (1, 0, false),
                (0, 0.5, false), (0.5, 0.5, true), (1, 0.5, false),
                (0, 1, false), (0.5, 1, false), (1, 1, false),
                (0.25, 0.25, false), (0.75, 0.25, false),
                (0.25, 0.75, false), (0.75, 0.75, false),
                (0.25, 0.5, false), (0.75, 0.5, false),
                (0.5, 0.25, false), (0.5, 0.75, false)
            ]

            for point in gridPoints {
                let pos = CGPoint(x: point.x * size.width, y: point.y * size.height)
                let circle = Path(ellipseIn: CGRect(x: pos.x - 6, y: pos.y - 6, width: 12, height: 12))
                let color = point.isCenter ? Color.green.opacity(0.6) : Color.ui.mediumBlueBackground
                context.fill(circle, with: .color(color))
            }

            // Draw labels
            let labels: [(text: String, x: CGFloat, y: CGFloat, alignX: CGFloat, alignY: CGFloat)] = [
                ("(0,0)", 6, 10, 0, 0),
                ("(0.5,0)", size.width/2, 10, 0.5, 0),
                ("(1,0)", size.width - 6, 10, 1, 0),
                ("(0,1)", 6, size.height - 2, 0, 1),
                ("(0.5,1)", size.width/2, size.height - 2, 0.5, 1),
                ("(1,1)", size.width - 6, size.height - 2, 1, 1)
            ]

            for label in labels {
                let text = Text(label.text)
                    .font(.caption2)
                    .foregroundColor(Color.ui.white)

                context.draw(text, at: CGPoint(x: label.x, y: label.y), anchor: UnitPoint(x: label.alignX, y: label.alignY))
            }

            // Draw centerpoint dot
            let originX = document.viewState.liveGradientOriginX ?? getOriginX(gradient)
            let originY = document.viewState.liveGradientOriginY ?? getOriginY(gradient)
            let clampedX = max(0.0, min(1.0, originX))
            let clampedY = max(0.0, min(1.0, originY))
            let dotPos = CGPoint(x: clampedX * size.width, y: clampedY * size.height)

            let dotCircle = Path(ellipseIn: CGRect(x: dotPos.x - 4, y: dotPos.y - 4, width: 8, height: 8))
            context.fill(dotCircle, with: .color(.white))
            context.stroke(dotCircle, with: .color(.black), lineWidth: 1)
        }
        .frame(width: squareSize, height: squareSize)
    }

    private func renderGradientToCGContext(gradient: VectorGradient, context: CGContext, size: CGSize) {
        context.saveGState()

        let pathBounds = CGRect(origin: .zero, size: size)
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

    @State private var dragStartGradient: VectorGradient? = nil
    @State private var dragStartOpacities: [UUID: Double] = [:]

    private func createPreviewContent(geometry: GeometryProxy) -> some View {
        let fullWidth = geometry.size.width
        let squareSize = fullWidth

        return createGradientPreview(geometry: geometry, squareSize: squareSize)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if dragStartGradient == nil {
                            dragStartGradient = currentGradient
                            // Capture old opacities
                            for objectID in document.viewState.selectedObjectIDs {
                                if let shape = document.findShape(by: objectID) {
                                    dragStartOpacities[objectID] = shape.fillStyle?.opacity ?? 1.0
                                }
                            }
                        }
                        let normalizedX = max(0.0, min(1.0, value.location.x / fullWidth))
                        let normalizedY = max(0.0, min(1.0, value.location.y / fullWidth))
                        updateOriginXOptimized(normalizedX, true, true)
                        updateOriginYOptimized(normalizedY, true, true)
                    }
                    .onEnded { _ in
                        applyGradientToSelectedShapesOptimized(false)

                        // Create undo command
                        if let startGradient = dragStartGradient, let endGradient = currentGradient {
                            var oldGradients: [UUID: VectorGradient?] = [:]
                            var newGradients: [UUID: VectorGradient?] = [:]
                            var newOpacities: [UUID: Double] = [:]

                            for objectID in document.viewState.selectedObjectIDs {
                                oldGradients[objectID] = startGradient
                                newGradients[objectID] = endGradient
                                if let shape = document.findShape(by: objectID) {
                                    newOpacities[objectID] = shape.fillStyle?.opacity ?? 1.0
                                }
                            }

                            let command = GradientCommand(
                                objectIDs: Array(document.viewState.selectedObjectIDs),
                                target: .fill,
                                oldGradients: oldGradients,
                                newGradients: newGradients,
                                oldOpacities: dragStartOpacities,
                                newOpacities: newOpacities
                            )
                            document.commandManager.execute(command)
                        }

                        dragStartGradient = nil
                        dragStartOpacities.removeAll()
                    }
            )
    }

    var body: some View {
        if currentGradient != nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)

                GeometryReader { geometry in
                    createPreviewContent(geometry: geometry)
                }
                .aspectRatio(1, contentMode: .fit)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Color Stops")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Button(action: addColorStop) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }

                    let stops = currentGradient.map { getGradientStops($0).sorted { $0.position < $1.position } } ?? []
                    ForEach(stops, id: \.id) { stop in
                        HStack(spacing: 8) {
                            Button(action: {
                                activateGradientStop(stop.id, stop.color)
                            }) {
                                renderColorSwatchRightPanel(stop.color, width: 20, height: 20, cornerRadius: 0, borderWidth: 1, opacity: stop.opacity)
                            }
                            .buttonStyle(BorderlessButtonStyle())

                            VStack(alignment: .leading, spacing: 2) {

                                HStack(spacing: 8) {
                                    Slider(value: Binding(
                                        get: { stop.position },
                                        set: { updateStopPosition(stop.id, $0) }
                                    ), in: 0...1)
                                    .controlSize(.regular)

                                    TextField("", text: Binding(
                                        get: {
                                            let percentage = stop.position * 100
                                            return percentage.truncatingRemainder(dividingBy: 1) == 0 ?
                                                String(format: "%.0f", percentage) :
                                                String(format: "%.1f", percentage)
                                        },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                let clamped = max(0, min(100, doubleValue))
                                                updateStopPosition(stop.id, clamped / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))

                                    TextField("", text: Binding(
                                        get: {
                                            let percentage = stop.opacity * 100
                                            return percentage.truncatingRemainder(dividingBy: 1) == 0 ?
                                                String(format: "%.0f", percentage) :
                                                String(format: "%.1f", percentage)
                                        },
                                        set: { newValue in
                                            if let doubleValue = Double(newValue) {
                                                let clamped = max(0, min(100, doubleValue))
                                                updateStopOpacity(stop.id, clamped / 100.0)
                                            }
                                        }
                                    ))
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 40)
                                    .font(.system(size: 11))
                                }
                            }

                            if stops.count > 2 {
                                Button(action: { removeColorStop(stop.id) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(Color.ui.errorColor)
                                }
                                .buttonStyle(BorderlessButtonStyle())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }
}
