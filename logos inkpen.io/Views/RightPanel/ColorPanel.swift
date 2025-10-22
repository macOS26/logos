import SwiftUI

struct ColorPanel: View {
    let snapshot: DocumentSnapshot
    let selectedObjectIDs: Set<UUID>
    @ObservedObject var document: VectorDocument  // Keep temporarily for methods
    @Environment(AppState.self) private var appState
    @State private var searchText = ""
    @State private var showingPantoneSearch = false
    @State private var currentPreviewColor: VectorColor = .rgb(RGBColor(red: 0.0, green: 0.478, blue: 1.0, colorSpace: .displayP3))
    let onColorSelected: ((VectorColor) -> Void)?
    let showGradientEditing: Bool

    init(snapshot: DocumentSnapshot, selectedObjectIDs: Set<UUID>, document: VectorDocument, onColorSelected: ((VectorColor) -> Void)? = nil, showGradientEditing: Bool = false) {
        self.snapshot = snapshot
        self.selectedObjectIDs = selectedObjectIDs
        self.document = document
        self.onColorSelected = onColorSelected
        self.showGradientEditing = showGradientEditing
        let initialColor = document.getSelectedObjectColor() ?? document.defaultFillColor
        self._currentPreviewColor = State(initialValue: initialColor)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
                .frame(height: 8)
            if showGradientEditing, let gradientState = appState.gradientEditingState {
                HStack {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.blue)
                    Text("Editing Gradient Stop \(gradientState.stopIndex + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("ID: \(gradientState.gradientId.uuidString.prefix(8))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .fontDesign(.monospaced)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .padding(.horizontal, 12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Picker("Color Mode", selection: Binding(
                    get: { document.settings.colorMode },
                    set: { newMode in
                        let oldMode = document.settings.colorMode
                        document.settings.colorMode = newMode

                        currentPreviewColor = convertColorToMode(currentPreviewColor, from: oldMode, to: newMode)

                        document.updateColorSwatchesForMode()
                    }
                )) {
                    ForEach(ColorMode.allCases, id: \.self) { mode in
                        HStack {
                            Image(systemName: mode.iconName)
                            Text(mode.rawValue)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .font(.caption)
            }
            .padding(.horizontal, 12)

            if document.settings.colorMode == .pms {
                HSBInputSection(document: document, sharedColor: $currentPreviewColor, showGradientEditing: showGradientEditing)
                    .padding(.horizontal, 12)
            } else if document.settings.colorMode == .cmyk {
                CMYKInputSection(document: document, sharedColor: $currentPreviewColor, onColorSelected: onColorSelected, showGradientEditing: showGradientEditing)
                        .padding(.horizontal, 12)
            } else if document.settings.colorMode == .rgb {
                RGBInputSection(document: document, sharedColor: $currentPreviewColor, showGradientEditing: showGradientEditing)
                        .padding(.horizontal, 12)
            }

            HStack {
                Text(colorModeDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)

            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28), spacing: 4), count: 8), spacing: 4) {
                                    ForEach(Array(filteredColors.enumerated()), id: \.offset) { index, color in
                    Button {
                        selectColor(color)
                        currentPreviewColor = color
                    } label: {
                        ZStack {
                            renderColorSwatchRightPanel(color, width: 30, height: 30, cornerRadius: 0, borderWidth: 1)

                            if case .pantone = color {
                                overlayText(for: color)
                            }
                        }
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(colorDescription(for: color))
                    .contextMenu {
                        Button("Delete Swatch") {
                            document.removeColorSwatch(color)
                        }
                    }
                    }
                }
                .padding(.horizontal, 12)
            }

            Spacer()
        }
        .sheet(isPresented: $showingPantoneSearch) {
            PantoneColorPickerSheet(document: document)
        }
        .onAppear {
            currentPreviewColor = (document.viewState.activeColorTarget == .stroke) ? document.defaultStrokeColor : document.defaultFillColor
        }
        .onChange(of: document.viewState.activeColorTarget) { _, newTarget in
            currentPreviewColor = (newTarget == .stroke) ? document.defaultStrokeColor : document.defaultFillColor
        }
        .onChange(of: document.defaultFillColor) { _, newFill in
            if document.viewState.activeColorTarget == .fill {
                currentPreviewColor = newFill
            }
        }
        .onChange(of: document.defaultStrokeColor) { _, newStroke in
            if document.viewState.activeColorTarget == .stroke {
                currentPreviewColor = newStroke
            }
        }
    }

    private var colorModeDescription: String {
        switch document.settings.colorMode {
        case .rgb:
            return "RGB colors for screen display"
        case .cmyk:
            return "CMYK colors for print production"
        case .pms:
            return "PMS colors with Pantone matching"
        }
    }

    private var filteredColors: [VectorColor] {
        if searchText.isEmpty {
            return document.currentSwatches
        } else {
            return document.currentSwatches.filter { color in
                colorDescription(for: color).localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func selectColor(_ color: VectorColor) {

        if let onColorSelected = onColorSelected {
            onColorSelected(color)
        } else {

            currentPreviewColor = color

            if document.viewState.activeColorTarget == .stroke {
                document.setActiveColor(color)
            } else {
                document.setActiveColor(color)
            }
        }
    }

    private func colorDescription(for color: VectorColor) -> String {
        switch color {
        case .black: return "Black"
        case .white: return "White"
        case .clear: return "Clear"
        case .rgb(let rgb):
            return "RGB(\(Int(rgb.red * 255)), \(Int(rgb.green * 255)), \(Int(rgb.blue * 255)))"
        case .cmyk(let cmyk):
            return "CMYK(\(Int((cmyk.cyan * 100).isFinite ? cmyk.cyan * 100 : 0))%, \(Int((cmyk.magenta * 100).isFinite ? cmyk.magenta * 100 : 0))%, \(Int((cmyk.yellow * 100).isFinite ? cmyk.yellow * 100 : 0))%, \(Int((cmyk.black * 100).isFinite ? cmyk.black * 100 : 0))%)"
        case .hsb(let hsb):
            return "HSB(\(Int(hsb.hue))°, \(Int(hsb.saturation * 100))%, \(Int(hsb.brightness * 100))%)"
        case .pantone(let pantone):
            return "PANTONE \(pantone.pantone) - \(pantone.name)"
        case .spot(let spot):
            return "SPOT \(spot.number) - \(spot.name)"
        case .appleSystem(let systemColor):
            return "Apple \(systemColor.name.capitalized)"
        case .gradient(let gradient):
            switch gradient {
            case .linear(_): return "Linear Gradient"
            case .radial(_): return "Radial Gradient"
            }
        }
    }

    @ViewBuilder
    private func overlayText(for color: VectorColor) -> some View {
        if case .pantone(let pantone) = color {
            Text(pantone.pantone)
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 0)
                .lineLimit(3)
                .minimumScaleFactor(0.5)
                .multilineTextAlignment(.center)
                .frame(width: 30, height: 30)
                .allowsTightening(true)
        }
    }

    private func convertColorToMode(_ color: VectorColor, from oldMode: ColorMode, to newMode: ColorMode) -> VectorColor {
        if oldMode == newMode {
            return color
        }

        if oldMode == .rgb && newMode == .cmyk {
            switch color {
            case .rgb(let rgbColor):
                let cmykColor = ColorManagement.rgbToCMYK(rgbColor)
                return .cmyk(cmykColor)
            case .cmyk:
                return color
            case .hsb(let hsb):
                let cmykColor = ColorManagement.rgbToCMYK(hsb.rgbColor)
                return .cmyk(cmykColor)
            case .pantone(let pantone):
                return .cmyk(pantone.cmykEquivalent)
            case .spot(let spot):
                return .cmyk(spot.cmykEquivalent)
            case .appleSystem(let system):
                let cmykColor = ColorManagement.rgbToCMYK(system.rgbEquivalent)
                return .cmyk(cmykColor)
            case .gradient:
                return color
            case .clear:
                return .clear
            case .black:
                return .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1))
            case .white:
                return .cmyk(CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 0))
            }
        }

        if oldMode == .cmyk && newMode == .rgb {
            switch color {
            case .cmyk(let cmykColor):
                let rgbColor = cmykColor.rgbColor
                return .rgb(rgbColor)
            case .rgb:
                return color
            case .hsb(let hsb):
                return .rgb(hsb.rgbColor)
            case .pantone(let pantone):
                return .rgb(pantone.rgbEquivalent)
            case .spot(let spot):
                return .rgb(spot.rgbEquivalent)
            case .appleSystem:
                return color
            case .gradient:
                return color
            case .clear:
                return .clear
            case .black:
                return .rgb(RGBColor(red: 0, green: 0, blue: 0))
            case .white:
                return .rgb(RGBColor(red: 1, green: 1, blue: 1))
            }
        }

        if newMode == .pms {
            switch color {
            case .hsb:
                return color
            case .rgb(let rgb):
                return .hsb(HSBColorModel.fromRGB(rgb))
            case .cmyk(let cmyk):
                return .hsb(HSBColorModel.fromRGB(cmyk.rgbColor))
            case .pantone(let pantone):
                return .hsb(HSBColorModel.fromRGB(pantone.rgbEquivalent))
            case .spot(let spot):
                return .hsb(spot.hsbEquivalent)
            case .appleSystem(let system):
                return .hsb(HSBColorModel.fromRGB(system.rgbEquivalent))
            case .gradient:
                return color
            case .clear:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 1, alpha: 0))
            case .black:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 0))
            case .white:
                return .hsb(HSBColorModel(hue: 0, saturation: 0, brightness: 1))
            }
        }

        return color
    }

    private func updateSelectedTextStrokeColor(color: VectorColor, document: VectorDocument) {
        guard !document.viewState.selectedObjectIDs.isEmpty else { return }

        var oldColors: [UUID: VectorColor] = [:]
        var newColors: [UUID: VectorColor] = [:]
        var oldOpacities: [UUID: Double] = [:]
        var newOpacities: [UUID: Double] = [:]

        for textID in document.viewState.selectedObjectIDs {
            if let obj = document.findObject(by: textID) {
                switch obj.objectType {
                case .text(let shape):
                    oldColors[textID] = shape.typography?.strokeColor ?? .clear
                    newColors[textID] = color
                    oldOpacities[textID] = shape.typography?.strokeOpacity ?? document.defaultStrokeOpacity
                    newOpacities[textID] = document.defaultStrokeOpacity
                case .shape, .warp, .group, .clipGroup, .clipMask:
                    continue
                }
            }
        }

        if !oldColors.isEmpty {
            let command = ChangeColorCommand(
                objectIDs: Array(document.viewState.selectedObjectIDs),
                target: .stroke,
                oldColors: oldColors,
                newColors: newColors,
                oldOpacities: oldOpacities,
                newOpacities: newOpacities
            )
            document.executeCommand(command)
        }

        for textID in document.viewState.selectedObjectIDs {
            document.updateTextStrokeColorInUnified(id: textID, color: color)
        }
    }
}
