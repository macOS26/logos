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

    private func calculateDotPosition(geometry: GeometryProxy, squareSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        guard let gradient = currentGradient else { return CGPoint(x: centerX, y: centerY) }

        switch gradient {
        case .linear:
            let originX = getOriginX(gradient)
            let originY = getOriginY(gradient)

            let clampedX = max(0.0, min(1.0, originX))
            let clampedY = max(0.0, min(1.0, originY))

            return CGPoint(
                x: clampedX * squareSize,
                y: clampedY * squareSize
            )

        case .radial:
            let originX = getOriginX(gradient)
            let originY = getOriginY(gradient)

            let clampedX = max(0.0, min(1.0, originX))
            let clampedY = max(0.0, min(1.0, originY))

            return CGPoint(
                x: clampedX * squareSize,
                y: clampedY * squareSize
            )
        }
    }

    private func createGradientPreview(geometry: GeometryProxy, squareSize: CGFloat) -> some View {
        return Group {
            if let gradient = currentGradient {
                GradientPreviewNSView(gradient: gradient, size: squareSize)
                    .frame(width: squareSize, height: squareSize)
                    .overlay(Rectangle().stroke(Color.ui.lightGrayBorder, lineWidth: 1))
                    .overlay(CartesianGrid(width: squareSize, height: squareSize) { x, y in
                        let clampedX = max(0.0, min(1.0, x))
                        let clampedY = max(0.0, min(1.0, y))
                        updateOriginX(clampedX, true)
                        updateOriginY(clampedY, true)
                    })
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: squareSize, height: squareSize)
                    .overlay(Rectangle().stroke(Color.ui.lightGrayBorder, lineWidth: 1))
            }
        }
    }

    private func createDraggableDot(geometry: GeometryProxy, squareSize: CGFloat, centerX: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 8, height: 8)
            .overlay(Circle().stroke(Color.black, lineWidth: 1))
            .position(calculateDotPosition(geometry: geometry, squareSize: squareSize, centerX: centerX, centerY: centerY))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let normalizedX = max(0.0, min(1.0, value.location.x / squareSize))
                        let normalizedY = max(0.0, min(1.0, value.location.y / squareSize))
                        updateOriginXOptimized(normalizedX, true, true)
                        updateOriginYOptimized(normalizedY, true, true)
                    }
                    .onEnded { _ in
                        applyGradientToSelectedShapesOptimized(false)
                    }
            )
    }

    private func createPreviewContent(geometry: GeometryProxy) -> some View {
        let fullWidth = geometry.size.width
        let squareSize = fullWidth
        let centerX: CGFloat = fullWidth / 2
        let centerY: CGFloat = fullWidth / 2

        return createGradientPreview(geometry: geometry, squareSize: squareSize)
            .onTapGesture { location in
                let normalizedX = max(0.0, min(1.0, location.x / fullWidth))
                let normalizedY = max(0.0, min(1.0, location.y / fullWidth))
                updateOriginX(normalizedX, true)
                updateOriginY(normalizedY, true)
            }
            .overlay(createDraggableDot(geometry: geometry, squareSize: squareSize, centerX: centerX, centerY: centerY))
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
                                .foregroundColor(Color.ui.primaryBlue)
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
