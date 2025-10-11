
import SwiftUI
import Combine

struct RGBInputSection: View {
    @ObservedObject var document: VectorDocument
    @Binding var sharedColor: VectorColor
    @Environment(AppState.self) private var appState

    let showGradientEditing: Bool

    @State private var redValue: String = "133"
    @State private var greenValue: String = "78"
    @State private var blueValue: String = "68"
    @State private var hexValue: String = "854e44"

    @State private var redSlider: Double = 133
    @State private var greenSlider: Double = 78
    @State private var blueSlider: Double = 68

    @State private var isProgrammaticallyUpdating: Bool = false
    @State private var isDisplayingGradient: Bool = false

    private var currentColor: RGBColor {
        let r = Double(redValue) ?? 0
        let g = Double(greenValue) ?? 0
        let b = Double(blueValue) ?? 0

        return RGBColor(
            red: min(255, max(0, r)) / 255.0,
            green: min(255, max(0, g)) / 255.0,
            blue: min(255, max(0, b)) / 255.0,
            alpha: 1.0
        )
    }

    private func swiftUIColor(r: Double, g: Double, b: Double) -> Color {
        return Color(.displayP3, red: r/255.0, green: g/255.0, blue: b/255.0)
    }

    private var redGradient: SwiftUI.LinearGradient {
        let g = Double(greenValue) ?? 0
        let b = Double(blueValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: 0, g: g, b: b),
                swiftUIColor(r: 255, g: g, b: b)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var greenGradient: SwiftUI.LinearGradient {
        let r = Double(redValue) ?? 0
        let b = Double(blueValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: r, g: 0, b: b),
                swiftUIColor(r: r, g: 255, b: b)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var blueGradient: SwiftUI.LinearGradient {
        let r = Double(redValue) ?? 0
        let g = Double(greenValue) ?? 0
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: r, g: g, b: 0),
                swiftUIColor(r: r, g: g, b: 255)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)

                    Text("R")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )

                        Slider(value: $redSlider, in: 0...255)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: redSlider) {
                                guard !isProgrammaticallyUpdating else {
                                    return
                                }
                                redValue = String(Int(redSlider))
                                updateHexFromRGB()
                                updateSharedColor()
                            }

                        Capsule()
                            .fill(redGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $redValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: redValue) {
                            guard !isProgrammaticallyUpdating else {
                                return
                            }
                            if let intValue = Double(redValue) {
                                redSlider = min(255, max(0, intValue))
                                updateHexFromRGB()
                                updateSharedColor()
                            }
                        }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)

                    Text("G")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )

                        Slider(value: $greenSlider, in: 0...255)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: greenSlider) {
                                guard !isProgrammaticallyUpdating else { return }
                                greenValue = String(Int(greenSlider))
                                updateHexFromRGB()
                                updateSharedColor()
                            }

                        Capsule()
                            .fill(greenGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $greenValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: greenValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(greenValue) {
                                greenSlider = min(255, max(0, intValue))
                                updateHexFromRGB()
                                updateSharedColor()
                            }
                        }
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)

                    Text("B")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    ZStack {
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )

                        Slider(value: $blueSlider, in: 0...255)
                            .controlSize(.regular)
                            .tint(Color.clear)
                            .onChange(of: blueSlider) {
                                guard !isProgrammaticallyUpdating else { return }
                                blueValue = String(Int(blueSlider))
                                updateHexFromRGB()
                                updateSharedColor()
                            }

                        Capsule()
                            .fill(blueGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $blueValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: blueValue) {
                            guard !isProgrammaticallyUpdating else { return }
                            if let intValue = Double(blueValue) {
                                blueSlider = min(255, max(0, intValue))
                                updateHexFromRGB()
                                updateSharedColor()
                            }
                        }
                }
            }

            HStack(spacing: 8) {
                Button(action: {
                    applyColorToActiveSelection()
                }) {
                    Rectangle()
                        .fill(Color(.displayP3,
                            red: currentColor.red,
                            green: currentColor.green,
                            blue: currentColor.blue))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(BorderlessButtonStyle())
                .help("Click to apply color to active fill or stroke")

                VStack(alignment: .leading, spacing: 2) {
                    Button("Add Swatch") {
                        addColorToSwatches()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                }

                Spacer()

                Text("#")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("854e44", text: $hexValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
                    .frame(width: 70)
                    .onChange(of: hexValue) {
                        updateRGBFromHex()
                        updateSharedColor()
                    }

            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadFromSharedColor()
        }
        .onChange(of: sharedColor) { _, newColor in
            loadFromSharedColor()
        }
    }

    private func updateHexFromRGB() {
        let r = Int(Double(redValue) ?? 0)
        let g = Int(Double(greenValue) ?? 0)
        let b = Int(Double(blueValue) ?? 0)
        hexValue = String(format: "%02x%02x%02x", r, g, b)
    }

    private func updateRGBFromHex() {
        let cleanHex = hexValue.replacingOccurrences(of: "#", with: "")
        if cleanHex.count == 6 {
            let scanner = Scanner(string: cleanHex)
            var hexNumber: UInt64 = 0

            if scanner.scanHexInt64(&hexNumber) {
                let r = Int((hexNumber & 0xff0000) >> 16)
                let g = Int((hexNumber & 0x00ff00) >> 8)
                let b = Int(hexNumber & 0x0000ff)

                redValue = String(r)
                greenValue = String(g)
                blueValue = String(b)
                redSlider = Double(r)
                greenSlider = Double(g)
                blueSlider = Double(b)
            }
        }
    }

    private func updateSharedColor() {
        if isDisplayingGradient {
            return
        }

        sharedColor = .rgb(currentColor)

        if isProgrammaticallyUpdating {
            return
        }


        return

    }

    private func loadFromSharedColor() {

        isDisplayingGradient = false

        switch sharedColor {
        case .rgb(let rgb):
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .cmyk(let cmyk):
            let rgb = cmyk.rgbColor
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .hsb(let hsb):
            let rgb = hsb.rgbColor
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .pantone(let pantone):
            let rgb = pantone.rgbEquivalent
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .spot(let spot):
            let rgb = spot.rgbEquivalent
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .appleSystem(let system):
            let rgb = system.rgbEquivalent
            setRGBValues(
                red: Int(rgb.red * 255),
                green: Int(rgb.green * 255),
                blue: Int(rgb.blue * 255)
            )
        case .gradient(let gradient):
            isDisplayingGradient = true
            if let firstStop = gradient.stops.first {
                switch firstStop.color {
                case .rgb(let rgb):
                    setRGBValues(
                        red: Int(rgb.red * 255),
                        green: Int(rgb.green * 255),
                        blue: Int(rgb.blue * 255)
                    )
                default:
                    let swiftUIColor = firstStop.color.color
                    let components = swiftUIColor.components
                    setRGBValues(
                        red: Int(components.red * 255),
                        green: Int(components.green * 255),
                        blue: Int(components.blue * 255)
                    )
                }
            } else {
                setRGBValues(red: 0, green: 0, blue: 0)
            }
        case .clear:
            return
        case .black:
            setRGBValues(red: 0, green: 0, blue: 0)
        case .white:
            setRGBValues(red: 255, green: 255, blue: 255)
        }
    }

    private func setRGBValues(red: Int, green: Int, blue: Int) {

        isProgrammaticallyUpdating = true
        redValue = String(red)
        greenValue = String(green)
        blueValue = String(blue)
        redSlider = Double(red)
        greenSlider = Double(green)
        blueSlider = Double(blue)
        updateHexFromRGB()
        isProgrammaticallyUpdating = false

    }

    private func applyColorToActiveSelection() {
        let vectorColor = VectorColor.rgb(currentColor)


        if showGradientEditing, let gradientCallback = appState.gradientEditingState?.onColorSelected {
            gradientCallback(vectorColor)
            document.addColorSwatch(vectorColor)
            return
        }

        document.setActiveColor(vectorColor)
        document.addColorSwatch(vectorColor)
    }

    private func addColorToSwatches() {
        let vectorColor = VectorColor.rgb(currentColor)
        document.addColorToSwatches(vectorColor)
    }
}

#Preview {
    RGBInputSection(document: VectorDocument(), sharedColor: .constant(.black), showGradientEditing: false)
        .padding()
        .environment(AppState.shared)
}
