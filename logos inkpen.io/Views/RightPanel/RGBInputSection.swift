import SwiftUI
import Combine

struct ColorChannelLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.secondary)
            .frame(width: 12)
    }
}

struct ColorValueTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(width: 45)
            .font(.system(size: 11))
    }
}

struct ColorIndicatorStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 12, height: 12)
    }
}

struct HexTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .font(.system(size: 11))
            .frame(width: 70)
    }
}

extension View {
    func colorChannelLabel() -> some View {
        modifier(ColorChannelLabelStyle())
    }
    
    func colorValueTextField() -> some View {
        modifier(ColorValueTextFieldStyle())
    }
    
    func colorIndicator() -> some View {
        modifier(ColorIndicatorStyle())
    }
    
    func hexTextField() -> some View {
        modifier(HexTextFieldStyle())
    }
}

struct ColorChannelSlider: View {
    let color: Color
    let label: String
    @Binding var sliderValue: Double
    @Binding var textValue: String
    let gradient: SwiftUI.LinearGradient
    let onChange: () -> Void
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .colorIndicator()
            
            Text(label)
                .colorChannelLabel()
            
            ZStack {
                Capsule()
                    .fill(Color.white)
                    .frame(height: 6)
                    .overlay(
                        Capsule()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    )
                
                Capsule()
                    .fill(gradient)
                    .frame(height: 6)
                    .allowsHitTesting(false)
                
                Slider(value: $sliderValue, in: 0...255)
                    .controlSize(.regular)
                    .tint(Color.clear)
                    .onChange(of: sliderValue) {
                        textValue = String(Int(sliderValue))
                        onChange()
                    }
            }
            
            TextField("", text: $textValue)
                .colorValueTextField()
                .onChange(of: textValue) {
                    if let intValue = Double(textValue) {
                        sliderValue = min(255, max(0, intValue))
                        onChange()
                    }
                }
        }
    }
}

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
                ColorChannelSlider(
                    color: .red,
                    label: "R",
                    sliderValue: $redSlider,
                    textValue: $redValue,
                    gradient: redGradient,
                    onChange: {
                        guard !isProgrammaticallyUpdating else { return }
                        updateHexFromRGB()
                        updateSharedColor()
                    }
                )
                
                ColorChannelSlider(
                    color: .green,
                    label: "G",
                    sliderValue: $greenSlider,
                    textValue: $greenValue,
                    gradient: greenGradient,
                    onChange: {
                        guard !isProgrammaticallyUpdating else { return }
                        updateHexFromRGB()
                        updateSharedColor()
                    }
                )
                
                ColorChannelSlider(
                    color: .blue,
                    label: "B",
                    sliderValue: $blueSlider,
                    textValue: $blueValue,
                    gradient: blueGradient,
                    onChange: {
                        guard !isProgrammaticallyUpdating else { return }
                        updateHexFromRGB()
                        updateSharedColor()
                    }
                )
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
                    .hexTextField()
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
