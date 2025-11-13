import SwiftUI

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
    @Binding var value: Double
    let gradient: SwiftUI.LinearGradient
    let onEditingChanged: (Bool) -> Void

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

                Slider(value: $value, in: 0...255, onEditingChanged: onEditingChanged)
                    .controlSize(.regular)
                    .tint(Color.clear)
            }

            Text("\(Int(value))")
                .colorValueTextField()
        }
    }
}

struct RGBInputSection: View {
    @Binding var snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    let activeColorTarget: ColorTarget
    @Binding var defaultFillColor: VectorColor
    @Binding var defaultStrokeColor: VectorColor
    let defaultFillOpacity: Double
    let defaultStrokeOpacity: Double
    let onTriggerLayerUpdates: (Set<Int>) -> Void
    let onAddColorSwatch: (VectorColor) -> Void
    let onSetActiveColor: (VectorColor) -> Void
    @Binding var colorDeltaColor: VectorColor?
    @Binding var colorDeltaOpacity: Double?

    @Binding var sharedColor: VectorColor
    @Environment(AppState.self) private var appState

    let disableSetActiveColor: Bool
    let onColorSelected: ((VectorColor) -> Void)?
    let onDismiss: (() -> Void)?

    init(
        snapshot: Binding<DocumentSnapshot>,
        selectedObjectIDs: Set<UUID>,
        activeColorTarget: ColorTarget,
        defaultFillColor: Binding<VectorColor>,
        defaultStrokeColor: Binding<VectorColor>,
        defaultFillOpacity: Double,
        defaultStrokeOpacity: Double,
        onTriggerLayerUpdates: @escaping (Set<Int>) -> Void,
        onAddColorSwatch: @escaping (VectorColor) -> Void,
        onSetActiveColor: @escaping (VectorColor) -> Void,
        colorDeltaColor: Binding<VectorColor?>,
        colorDeltaOpacity: Binding<Double?>,
        sharedColor: Binding<VectorColor>,
        disableSetActiveColor: Bool = false,
        onColorSelected: ((VectorColor) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self._snapshot = snapshot
        self.selectedObjectIDs = selectedObjectIDs
        self.activeColorTarget = activeColorTarget
        self._defaultFillColor = defaultFillColor
        self._defaultStrokeColor = defaultStrokeColor
        self.defaultFillOpacity = defaultFillOpacity
        self.defaultStrokeOpacity = defaultStrokeOpacity
        self.onTriggerLayerUpdates = onTriggerLayerUpdates
        self.onAddColorSwatch = onAddColorSwatch
        self.onSetActiveColor = onSetActiveColor
        self._colorDeltaColor = colorDeltaColor
        self._colorDeltaOpacity = colorDeltaOpacity
        self._sharedColor = sharedColor
        self.disableSetActiveColor = disableSetActiveColor
        self.onColorSelected = onColorSelected
        self.onDismiss = onDismiss
    }

    @State private var redValue: Double = 133
    @State private var greenValue: Double = 78
    @State private var blueValue: Double = 68

    private var currentColor: RGBColor {
        return RGBColor(
            red: redValue / 255.0,
            green: greenValue / 255.0,
            blue: blueValue / 255.0,
            alpha: 1.0
        )
    }

    private func swiftUIColor(r: Double, g: Double, b: Double) -> Color {
        return Color(.displayP3, red: r/255.0, green: g/255.0, blue: b/255.0)
    }

    private var redGradient: SwiftUI.LinearGradient {
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: 0, g: greenValue, b: blueValue),
                swiftUIColor(r: 255, g: greenValue, b: blueValue)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var greenGradient: SwiftUI.LinearGradient {
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: redValue, g: 0, b: blueValue),
                swiftUIColor(r: redValue, g: 255, b: blueValue)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var blueGradient: SwiftUI.LinearGradient {
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(r: redValue, g: greenValue, b: 0),
                swiftUIColor(r: redValue, g: greenValue, b: 255)
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
                    value: Binding(
                        get: { redValue },
                        set: { onUpdateRed($0) }
                    ),
                    gradient: redGradient,
                    onEditingChanged: onRedEditingChanged
                )

                ColorChannelSlider(
                    color: .green,
                    label: "G",
                    value: Binding(
                        get: { greenValue },
                        set: { onUpdateGreen($0) }
                    ),
                    gradient: greenGradient,
                    onEditingChanged: onGreenEditingChanged
                )

                ColorChannelSlider(
                    color: .blue,
                    label: "B",
                    value: Binding(
                        get: { blueValue },
                        set: { onUpdateBlue($0) }
                    ),
                    gradient: blueGradient,
                    onEditingChanged: onBlueEditingChanged
                )
            }

            HStack(spacing: 8) {
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

                Button("Add Swatch") {
                    onAddColorSwatch(.rgb(currentColor))
                }
                .font(.system(size: 10))

                Spacer()

                Text(String(format: "#%02x%02x%02x", Int(redValue), Int(greenValue), Int(blueValue)))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadInitialColor()
        }
        .onChange(of: sharedColor) { _, newColor in
            loadInitialColor()
        }
    }

    private func loadInitialColor() {
        let rgb: RGBColor
        switch sharedColor {
        case .rgb(let color):
            rgb = color
        case .cmyk(let color):
            rgb = color.rgbColor
        case .hsb(let color):
            rgb = color.rgbColor
        case .pantone(let color):
            rgb = color.rgbEquivalent
        case .spot(let color):
            rgb = color.rgbEquivalent
        case .appleSystem(let color):
            rgb = color.rgbEquivalent
        case .gradient(let gradient):
            if let firstStop = gradient.stops.first {
                switch firstStop.color {
                case .rgb(let color):
                    rgb = color
                default:
                    let components = firstStop.color.color.components
                    rgb = RGBColor(red: components.red, green: components.green, blue: components.blue)
                }
            } else {
                rgb = RGBColor(red: 0, green: 0, blue: 0)
            }
        case .clear:
            rgb = RGBColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .black:
            rgb = RGBColor(red: 0, green: 0, blue: 0)
        case .white:
            rgb = RGBColor(red: 1, green: 1, blue: 1)
        }
        redValue = rgb.red * 255
        greenValue = rgb.green * 255
        blueValue = rgb.blue * 255
    }

    private func onUpdateRed(_ value: Double) {
        redValue = value

        // ONLY update colorDelta for live preview - NO other updates during drag!
        if !disableSetActiveColor {
            let previewColor = VectorColor.rgb(currentColor)
            colorDeltaColor = previewColor  // Direct binding update for live canvas preview

            // Update defaultFillColor/defaultStrokeColor for live toolbar preview
            if activeColorTarget == .fill {
                defaultFillColor = previewColor
            } else {
                defaultStrokeColor = previewColor
            }
        }
        // All other updates happen on drag end
    }

    private func onUpdateGreen(_ value: Double) {
        greenValue = value

        // ONLY update colorDelta for live preview - NO other updates during drag!
        if !disableSetActiveColor {
            let previewColor = VectorColor.rgb(currentColor)
            colorDeltaColor = previewColor  // Direct binding update for live canvas preview

            // Update defaultFillColor/defaultStrokeColor for live toolbar preview
            if activeColorTarget == .fill {
                defaultFillColor = previewColor
            } else {
                defaultStrokeColor = previewColor
            }
        }
        // All other updates happen on drag end
    }

    private func onUpdateBlue(_ value: Double) {
        blueValue = value

        // ONLY update colorDelta for live preview - NO other updates during drag!
        if !disableSetActiveColor {
            let previewColor = VectorColor.rgb(currentColor)
            colorDeltaColor = previewColor  // Direct binding update for live canvas preview

            // Update defaultFillColor/defaultStrokeColor for live toolbar preview
            if activeColorTarget == .fill {
                defaultFillColor = previewColor
            } else {
                defaultStrokeColor = previewColor
            }
        }
        // All other updates happen on drag end
    }

    private func onRedEditingChanged(_ isEditing: Bool) {
        if isEditing {
            // Start of drag - set opacity for preview
            let currentOpacity = activeColorTarget == .fill ? defaultFillOpacity : defaultStrokeOpacity
            colorDeltaOpacity = currentOpacity
        } else {
            // print("HELLO")
            // Clear colorDelta and actually update objects
            colorDeltaColor = nil
            colorDeltaOpacity = nil

            // Update defaults
            // TODO: Re-enable when RGB methods are available
            // PaintSelectionOperations.updateDefaultColorRed(
            //     normalizedValue,
            //     target: activeColorTarget,
            //     defaultFillColor: &defaultFillColor,
            //     defaultStrokeColor: &defaultStrokeColor
            // )

            // Update active color (toolbar display)
            let finalColor = VectorColor.rgb(currentColor)
            onSetActiveColor(finalColor)

            // Update selected objects
            // TODO: Re-enable when RGB methods are available
            // let affectedLayers = PaintSelectionOperations.updateRGBRedLive(
            //     normalizedValue,
            //     target: activeColorTarget,
            //     snapshot: &snapshot,
            //     selectedObjectIDs: selectedObjectIDs,
            //     defaultFillOpacity: defaultFillOpacity,
            //     defaultStrokeOpacity: defaultStrokeOpacity
            // )
            // onTriggerLayerUpdates(affectedLayers)

            // Update sharedColor to sync with other color sections (HSB, etc.)
            sharedColor = VectorColor.rgb(currentColor)
        }
    }

    private func onGreenEditingChanged(_ isEditing: Bool) {
        if isEditing {
            // Start of drag - set opacity for preview
            let currentOpacity = activeColorTarget == .fill ? defaultFillOpacity : defaultStrokeOpacity
            colorDeltaOpacity = currentOpacity
        } else {
            // Clear colorDelta and actually update objects
            colorDeltaColor = nil
            colorDeltaOpacity = nil

            // Update defaults
            // TODO: Re-enable when RGB methods are available
            // PaintSelectionOperations.updateDefaultColorGreen(
            //     normalizedValue,
            //     target: activeColorTarget,
            //     defaultFillColor: &defaultFillColor,
            //     defaultStrokeColor: &defaultStrokeColor
            // )

            // Update active color (toolbar display)
            let finalColor = VectorColor.rgb(currentColor)
            onSetActiveColor(finalColor)

            // Update selected objects
            // TODO: Re-enable when RGB methods are available
            // let affectedLayers = PaintSelectionOperations.updateRGBGreenLive(
            //     normalizedValue,
            //     target: activeColorTarget,
            //     snapshot: &snapshot,
            //     selectedObjectIDs: selectedObjectIDs,
            //     defaultFillOpacity: defaultFillOpacity,
            //     defaultStrokeOpacity: defaultStrokeOpacity
            // )
            // onTriggerLayerUpdates(affectedLayers)

            // Update sharedColor to sync with other color sections (HSB, etc.)
            sharedColor = VectorColor.rgb(currentColor)
        }
    }

    private func onBlueEditingChanged(_ isEditing: Bool) {
        if isEditing {
            // Start of drag - set opacity for preview
            let currentOpacity = activeColorTarget == .fill ? defaultFillOpacity : defaultStrokeOpacity
            colorDeltaOpacity = currentOpacity
        } else {
            // Clear colorDelta and actually update objects
            colorDeltaColor = nil
            colorDeltaOpacity = nil

            // Update defaults
            // TODO: Re-enable when RGB methods are available
            // PaintSelectionOperations.updateDefaultColorBlue(
            //     normalizedValue,
            //     target: activeColorTarget,
            //     defaultFillColor: &defaultFillColor,
            //     defaultStrokeColor: &defaultStrokeColor
            // )

            // Update active color (toolbar display)
            let finalColor = VectorColor.rgb(currentColor)
            onSetActiveColor(finalColor)

            // Update selected objects
            // TODO: Re-enable when RGB methods are available
            // let affectedLayers = PaintSelectionOperations.updateRGBBlueLive(
            //     normalizedValue,
            //     target: activeColorTarget,
            //     snapshot: &snapshot,
            //     selectedObjectIDs: selectedObjectIDs,
            //     defaultFillOpacity: defaultFillOpacity,
            //     defaultStrokeOpacity: defaultStrokeOpacity
            // )
            // onTriggerLayerUpdates(affectedLayers)

            // Update sharedColor to sync with other color sections (HSB, etc.)
            sharedColor = VectorColor.rgb(currentColor)
        }
    }
}
