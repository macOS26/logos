//
//  VariableStrokeSection.swift
//  logos inkpen.io
//
//  Variable stroke section for brush tool settings
//

import SwiftUI

struct VariableStrokeSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scribble.variable")
                    .foregroundColor(.accentColor)
                Text("Variable Stroke")
                    .font(.headline)
                Spacer()
            }

            // Brush Thickness
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
                ), in: 1...100)
                .help("Adjust brush stroke thickness (1-100 points)")
            }

            // Pressure Sensitivity Toggle
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

            // Pressure Sensitivity Slider (only show when enabled)
            if appState.pressureSensitivityEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sensitivity")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Text("\(Int(document.currentBrushPressureSensitivity * 100))%")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                            .monospacedDigit()
                    }

                Slider(value: Binding(
                    get: { document.currentBrushPressureSensitivity },
                    set: { document.currentBrushPressureSensitivity = $0 }
                ), in: 0...1)
                .help("How much pressure affects thickness (simulated if no pressure input)")
            }
            }

            // Brush Taper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Taper")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentBrushTaper * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentBrushTaper },
                    set: { document.currentBrushTaper = $0 }
                ), in: 0...1)
                .help("Amount of tapering at start and end of stroke")
            }

            // Brush Smoothness
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentBrushSmoothingTolerance))")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentBrushSmoothingTolerance },
                    set: { document.currentBrushSmoothingTolerance = $0 }
                ), in: 0.5...10)
                .help("Curve fitting tolerance - lower values preserve more detail, higher values create smoother curves")
            }

            // Advanced Smoothing Section
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
                .help("Enable advanced curve smoothing algorithms")

                if document.advancedSmoothingEnabled {
                    // Chaikin Smoothing Iterations
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
                        ), in: 1...3)
                        .help("More iterations create smoother curves but may lose detail (1-3)")
                    }

                    // Adaptive Tension Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Adaptive Tension")
                                .font(.subheadline)
                                .foregroundColor(Color.ui.primaryText)
                            Text("Adjust curve tension based on curvature")
                                .font(.caption)
                                .foregroundColor(Color.ui.secondaryText)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { document.adaptiveTensionEnabled },
                            set: { document.adaptiveTensionEnabled = $0 }
                        ))
                        .toggleStyle(SwitchToggleStyle(tint: .purple))
                        .controlSize(.small)
                        .help("Enable adaptive curve tension based on curvature")
                    }
                }
            }

            // Brush Tool Options
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)

                // Brush Preview Style
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
                    .help("Choose how the brush preview appears while drawing")
                }

                // Apply No Stroke Toggle
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
                    .help("When enabled, brush shapes will have no stroke regardless of current stroke settings")
                }

                // Remove Overlap Toggle
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
                    .help("When enabled, overlapping parts of brush strokes will be merged using union operation")
                }
            }

            // Pressure Input Status
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