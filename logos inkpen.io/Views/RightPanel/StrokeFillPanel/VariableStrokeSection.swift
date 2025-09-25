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
                .controlSize(.regular)
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
                .controlSize(.regular)
                .help("How much pressure affects thickness (simulated if no pressure input)")
            }
            }

            // REMOVED: Taper is no longer used - natural pressure creates tapering

            // MERGED WITH LIQUID: Smoothness is now controlled by Liquid setting

            // Liquid (Curve Fluidity)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Liquid")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    // Display reversed: internal 0 shows as 100%, internal 100 shows as 0%
                    Text("\(Int(100.0 - document.currentBrushLiquid))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { 100.0 - document.currentBrushLiquid },  // Reverse for display
                    set: { document.currentBrushLiquid = 100.0 - $0 }  // Reverse when setting
                ), in: 0...100)
                .controlSize(.regular)
                .help("Controls curve fluidity and smoothness - 0% = raw input (choppy), 50% = balanced, 100% = maximum liquid smoothing")
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
                .help("Enable advanced curve smoothing algorithms for ultra-smooth strokes")

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
                        ), in: 0...5)
                        .controlSize(.regular)
                        .help("Number of smoothing passes - 0 = off, 5 = maximum smoothing")
                    }

                    // Preserve Sharp Corners Toggle
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
                    .controlSize(.small)
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
                    .controlSize(.small)
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