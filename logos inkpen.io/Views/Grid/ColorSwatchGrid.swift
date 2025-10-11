import SwiftUI

struct ColorSwatchGrid: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState
    @State private var selectedFillColor: VectorColor = .white
    @State private var selectedStrokeColor: VectorColor = .black
    @State private var showingColorPicker = false

    let columns = [
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1),
        GridItem(.fixed(10), spacing: 1)
    ]

    private var currentFillColor: VectorColor {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.color
                }
            }
        }

        return document.defaultFillColor
    }

    private var currentStrokeColor: VectorColor {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let strokeStyle = shape.strokeStyle {
                    return strokeStyle.color
                } else {
                    return .clear
                }
            }
        }

        return document.defaultStrokeColor
    }

    private var currentFillOpacity: Double {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let fillStyle = shape.fillStyle {
                    return fillStyle.opacity
                }
            }
        }

        return document.defaultFillOpacity
    }

    private var currentStrokeOpacity: Double {
        if let firstSelectedObjectID = document.selectedObjectIDs.first,
           let unifiedObject = document.findObject(by: firstSelectedObjectID) {
            switch unifiedObject.objectType {
            case .shape(let shape):
                if let strokeStyle = shape.strokeStyle {
                    return strokeStyle.opacity
                }
            }
        }

        return document.defaultStrokeOpacity
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Button {
                    document.activeColorTarget = .stroke
                } label: {
                    if case .clear = currentStrokeColor {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()

	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)

                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentStrokeColor {
                        ZStack {
                            GradientSwatchNSView(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)

                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(currentStrokeColor.color.opacity(currentStrokeOpacity))
                                .frame(width: 22, height: 22)

                            if document.activeColorTarget == .stroke {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .focusable(false)
                .help("Current Stroke Color (Opacity: \(Int(currentStrokeOpacity * 100))%) - Click to make active")
                .offset(x: 6, y: 6)
                Button {
                    document.activeColorTarget = .fill
                } label: {
                    if case .clear = currentFillColor {
                        ZStack {
                            CheckerboardPattern(size: 4)
                                .frame(width: 22, height: 22)
                                .clipped()

	                            Rectangle()
	                                .fill(Color.clear)
	                                .frame(width: 22, height: 22)

                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }

                            Path { path in
                                path.move(to: CGPoint(x: 0, y: 0))
                                path.addLine(to: CGPoint(x: 22, y: 22))
                            }
                            .stroke(Color.red, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                        }
                    } else if case .gradient(let gradient) = currentFillColor {
                        ZStack {
                            GradientSwatchNSView(gradient: gradient, size: 22)
                                .frame(width: 22, height: 22)

                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    } else {
                        ZStack {
                            Rectangle()
                                .fill(currentFillColor.color.opacity(currentFillOpacity))
                                .frame(width: 22, height: 22)

                            if document.activeColorTarget == .fill {
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 2)
	                                Rectangle().inset(by: 1)
	                                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                            }
                        }
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .focusable(false)
                .help("Current Fill Color (Opacity: \(Int(currentFillOpacity * 100))%) - Click to make active")
                .offset(x: -6, y: -6)
            }
			.frame(width: 28, height: 28)
            .padding(.bottom, 6)
            .padding(.top, 8)

            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(Array(document.currentSwatches.enumerated()), id: \.offset) { index, color in
                    Button {
                        if document.activeColorTarget == .stroke {
                            selectedStrokeColor = color
                            document.setActiveColor(color)
                        } else {
                            selectedFillColor = color
                            document.setActiveColor(color)
                        }
                    } label: {
                        ZStack {
                            if case .clear = color {
                                ZStack {
                                    CheckerboardPattern(size: 2)
                                        .frame(width: 10, height: 10)
                                        .clipped()

                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: 10, height: 10)
                                        .border(Color.gray, width: 0.5)

                                    Path { path in
                                        path.move(to: CGPoint(x: 0, y: 0))
                                        path.addLine(to: CGPoint(x: 10, y: 10))
                                    }
                                    .stroke(Color.red, lineWidth: 1)
                                    .frame(width: 10, height: 10)
                                }
                            } else if case .gradient(let gradient) = color {
                                GradientSwatchNSView(gradient: gradient, size: 10)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            } else {
                                Rectangle()
                                    .fill(color.color)
                                    .frame(width: 10, height: 10)
                                    .border(Color.gray, width: 0.5)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help("\(colorDescription(for: color)) (Click to apply to \(document.activeColorTarget == .fill ? "fill" : "stroke"))")
                }
            }
            .padding(.horizontal, 2)

            Button {
                appState.persistentInkHUD.show(document: document)
            } label: {
                Image(systemName: "plus.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(BorderlessButtonStyle())
            .help("Add Custom Color")
        }
    }

    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb): return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk): return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .hsb(let hsb): return "HSB(\(Int(hsb.hue))°, \(Int(hsb.saturation * 100))%, \(Int(hsb.brightness * 100))%)"
        case .pantone(let pantone): return "Pantone \(pantone.pantone)"
        case .spot(let spot): return "SPOT \(spot.number)"
        case .appleSystem(let systemColor): return "Apple \(systemColor.name.capitalized)"
        case .gradient(let gradient):
            switch gradient {
            case .linear(_): return "Linear Gradient"
            case .radial(_): return "Radial Gradient"
            }
        }
    }
}
