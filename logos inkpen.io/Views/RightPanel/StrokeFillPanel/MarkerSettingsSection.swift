import SwiftUI

struct MarkerSettingsSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "pencil.tip")
                    .foregroundColor(.accentColor)
                Text("Marker Settings")
                    .font(.headline)
                    .foregroundColor(Color.ui.primaryText)
                Spacer()
            }

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
                    Text("Tip Size")
                } minimumValueLabel: {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .controlSize(.regular)
                .help("Adjust marker tip thickness (1-50 points)")
            }

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
                    Text("Opacity")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .controlSize(.regular)
                .help("Adjust marker ink opacity (0-100%)")
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
                .help("Enable or disable pressure sensitivity for marker tool")
            }


            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothing")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(document.currentMarkerSmoothingTolerance))%")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerSmoothingTolerance },
                    set: { document.currentMarkerSmoothingTolerance = $0 }
                ), in: 0...100) {
                    Text("Smoothing")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .controlSize(.regular)
                .help("Smoothing amount - 0% = no smoothing (preserves exact shape), 100% = maximum smoothing")
            }

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
                    Text("Feathering")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("100%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .controlSize(.regular)
                .help("Edge softness for felt-tip marker appearance")
            }

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
                    Text("Start Taper")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .controlSize(.regular)
                .help("Thickness tapering at the start of marker strokes")
            }

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
                    Text("End Taper")
                } minimumValueLabel: {
                    Text("0%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("50%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .controlSize(.regular)
                .help("Thickness tapering at the end of marker strokes")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Min Taper Thickness")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.currentMarkerMinTaperThickness))pt")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.currentMarkerMinTaperThickness },
                    set: { document.currentMarkerMinTaperThickness = $0 }
                ), in: 0...60) {
                    Text("Min Taper Thickness")
                } minimumValueLabel: {
                    Text("0")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                } maximumValueLabel: {
                    Text("60")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                .controlSize(.regular)
                .help("Minimum thickness at taper ends (0-60 points)")
            }

            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .padding(.vertical, 4)

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

            HStack {
                Image(systemName: PressureManager.shared.hasRealPressureInput ? "hand.point.up.braille" : "hand.tap")
                    .foregroundColor(PressureManager.shared.hasRealPressureInput ? .green : .orange)
                Text(PressureManager.shared.hasRealPressureInput ? "Pressure input detected" : "Using simulated pressure")
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
