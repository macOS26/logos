import SwiftUI

struct VariableStrokeSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scribble.variable")
                    .foregroundColor(.accentColor)
                Text("Brush Tool")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Thickness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentBrushThickness))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentBrushThickness },
                    set: { document.currentBrushThickness = $0 }
                ), in: 0...100)
                .controlSize(.regular)
                .help("Adjust brush stroke thickness (0-100 points)")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pressure Sensitivity")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { appState.pressureSensitivityEnabled },
                        set: { appState.pressureSensitivityEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .controlSize(.small)
                }
                .help("Enable or disable pressure sensitivity for variable stroke")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentBrushSmoothingTolerance))px")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentBrushSmoothingTolerance },
                    set: { document.currentBrushSmoothingTolerance = $0 }
                ), in: 0...10)
                .controlSize(.regular)
                .help("Point reduction threshold - higher values remove more duplicate points for smoother strokes (0-10 pixels)")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Liquid")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(100.0 - document.currentBrushLiquid))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { 100.0 - document.currentBrushLiquid },
                    set: { document.currentBrushLiquid = 100.0 - $0 }
                ), in: 0...100)
                .controlSize(.regular)
                .help("Controls curve fluidity - 0% = no smoothing (all points), 50% = moderate smoothing, 100% = maximum liquid smoothing")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Min Taper Thickness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentBrushMinTaperThickness))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentBrushMinTaperThickness },
                    set: { document.currentBrushMinTaperThickness = $0 }
                ), in: 0...15)
                .controlSize(.regular)
                .help("Minimum thickness at taper ends (0-15 points)")
            }

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "waveform.path")
                        .foregroundColor(.purple)
                    Text("Advanced Smoothing")
                        .font(.headline)
                        .foregroundColor(Color.ui.primaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.advancedSmoothingEnabled },
                        set: { document.advancedSmoothingEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .controlSize(.small)
                }
                .help("Enable advanced curve smoothing algorithms for ultra-smooth strokes")

                if document.advancedSmoothingEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Chaikin Iterations")
                                .font(.subheadline)
                                .foregroundColor(Color.ui.secondaryText)
                            Spacer()
                            Text("\(document.chaikinSmoothingIterations)")
                                .font(.subheadline)
                                .foregroundColor(Color.ui.primaryText)
                                .monospacedDigit()
                        }

                        Slider(value: Binding<Double>(
                            get: { Double(document.chaikinSmoothingIterations) },
                            set: { document.chaikinSmoothingIterations = Int(round($0)) }
                        ), in: 0...6)
                        .controlSize(.regular)
                        .help("Number of smoothing passes - 0 = off, 6 = maximum smoothing")
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Preserve Sharp Corners")
                                .font(.subheadline)
                                .foregroundColor(Color.ui.primaryText)
                            Text("Keep intentional sharp angles in strokes")
                                .font(.caption)
                                .foregroundColor(Color.ui.secondaryText)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { document.preserveSharpCorners },
                            set: { document.preserveSharpCorners = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .controlSize(.small)
                        .help("Keep intentional sharp angles during simplification")
                    }
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview Style")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)

                    Picker("", selection: Binding(
                        get: { appState.brushPreviewStyle },
                        set: { appState.brushPreviewStyle = $0 }
                    )) {
                        Text("Blue Outline").tag(AppState.BrushPreviewStyle.outline)
                        Text("Fill Color").tag(AppState.BrushPreviewStyle.fill)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: .infinity)
                    .help("Choose how the brush preview appears while drawing")
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply No Stroke")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Remove stroke from brush shapes")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.brushApplyNoStroke },
                        set: { document.brushApplyNoStroke = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, brush shapes will have no stroke regardless of current stroke settings")
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remove Overlap")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Union overlapping parts of same shape")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.brushRemoveOverlap },
                        set: { document.brushRemoveOverlap = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, overlapping parts of brush strokes will be merged using union operation")
                }
            }

            HStack {
                Image(systemName: document.hasPressureInput ? "hand.point.up.braille" : "hand.tap")
                    .foregroundColor(document.hasPressureInput ? .green : .orange)
                Text(document.hasPressureInput ? "Pressure input detected" : "Using simulated pressure")
                    .font(.caption)
                    .foregroundColor(Color.ui.secondaryText)
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
