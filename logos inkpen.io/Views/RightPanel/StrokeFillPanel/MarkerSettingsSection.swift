//
//  MarkerSettingsSection.swift
//  logos inkpen.io
//
//  Marker tool settings section for StrokeFillPanel
//

import SwiftUI

struct MarkerSettingsSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pen")
                    .foregroundColor(.accentColor)
                Text("Marker Settings")
                    .font(.headline)
                    .foregroundColor(Color.ui.primaryText)
                Spacer()
            }

            // Marker Tip Size
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tip Size")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerTipSize))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerTipSize },
                    set: { document.currentMarkerTipSize = $0 }
                ), in: 1...50) {
                    Text("Marker Tip Size")
                } minimumValueLabel: {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Adjust marker tip thickness (1-50 points)")
            }

            // Marker Opacity
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerOpacity * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerOpacity },
                    set: { document.currentMarkerOpacity = $0 }
                ), in: 0...1) {
                    Text("Marker Opacity")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Adjust marker ink opacity (0-100%)")
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
                .help("Enable or disable pressure sensitivity for marker tool")
            }

            // Pressure Sensitivity Slider (only show when enabled)
            if appState.pressureSensitivityEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Sensitivity")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Text("\(Int(document.currentMarkerPressureSensitivity * 100))%")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                            .monospacedDigit()
                    }

                Slider(value: Binding(
                    get: { document.currentMarkerPressureSensitivity },
                    set: { document.currentMarkerPressureSensitivity = $0 }
                ), in: 0...1) {
                    Text("Marker Pressure Sensitivity")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("How much pressure affects marker thickness (simulated if no pressure input)")
            }
            }

            // Smoothing Tolerance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothing")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentMarkerSmoothingTolerance))")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerSmoothingTolerance },
                    set: { document.currentMarkerSmoothingTolerance = $0 }
                ), in: 0.5...10) {
                    Text("Marker Smoothing")
                } minimumValueLabel: {
                    Text("0.5")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("10")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Curve fitting tolerance - lower values preserve more detail, higher values create smoother curves")
            }

            // Feathering
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Feathering")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerFeathering * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerFeathering },
                    set: { document.currentMarkerFeathering = $0 }
                ), in: 0...1) {
                    Text("Marker Feathering")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Edge softness for felt-tip marker appearance")
            }

            // Start Taper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Start Taper")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerTaperStart * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerTaperStart },
                    set: { document.currentMarkerTaperStart = $0 }
                ), in: 0...0.5) {
                    Text("Marker Start Taper")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Thickness tapering at the start of marker strokes")
            }

            // End Taper
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("End Taper")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerTaperEnd * 100))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerTaperEnd },
                    set: { document.currentMarkerTaperEnd = $0 }
                ), in: 0...0.5) {
                    Text("Marker End Taper")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .help("Thickness tapering at the end of marker strokes")
            }

            // Marker Tool Options
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)

                // Use Fill Color for Stroke Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Use Fill Color for Stroke")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Use fill color for both fill and stroke")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.markerUseFillAsStroke },
                        set: { document.markerUseFillAsStroke = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, marker uses fill color for both fill and stroke. When disabled, uses stroke color for both.")
                }

                // Apply No Stroke Toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apply No Stroke")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                        Text("Remove stroke from marker shapes")
                            .font(.caption)
                            .foregroundColor(Color.ui.secondaryText)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.markerApplyNoStroke },
                        set: { document.markerApplyNoStroke = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, marker shapes will have no stroke regardless of current stroke settings")
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
                        get: { document.markerRemoveOverlap },
                        set: { document.markerRemoveOverlap = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .controlSize(.small)
                    .help("When enabled, overlapping parts of marker strokes will be merged using union operation")
                }
            }

            // Marker Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.ui.primaryBlue)
                Text("Felt-tip marker with variable width based on drawing speed")
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