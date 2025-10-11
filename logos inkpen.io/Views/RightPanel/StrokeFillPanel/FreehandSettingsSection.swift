
import SwiftUI

struct FreehandSettingsSection: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "scribble")
                    .foregroundColor(.accentColor)
                Text("Freehand Tool")
                    .font(.headline)
                    .foregroundColor(Color.ui.primaryText)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Fill Mode")
                    .font(.subheadline)
                    .foregroundColor(Color.ui.secondaryText)

                Picker("", selection: Binding(
                    get: { document.freehandFillMode },
                    set: { document.freehandFillMode = $0 }
                )) {
                    ForEach(VectorDocument.FreehandFillMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .help("Choose whether freehand paths have fill or just stroke")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Smoothing")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(formatNumberForDisplay(document.freehandSmoothingTolerance))")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                        .monospacedDigit()
                }

                Slider(value: Binding(
                    get: { document.freehandSmoothingTolerance },
                    set: { document.freehandSmoothingTolerance = $0 }
                ), in: 0.1...10)
                .controlSize(.small)
                .help("Curve fitting tolerance - lower values preserve more detail, higher values create smoother curves")
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Close Path")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                    Text("Connect end back to start")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { document.freehandClosePath },
                    set: { document.freehandClosePath = $0 }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .controlSize(.small)
                .help("When enabled, closes the path by connecting the end to the start")
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Expand Stroke")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                    Text("Convert stroke to filled outline")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { document.freehandExpandStroke },
                    set: { document.freehandExpandStroke = $0 }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .controlSize(.small)
                .help("When enabled, converts the stroke to a filled path outline")
            }

            Divider()
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Real-time Smoothing")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { document.realTimeSmoothingEnabled },
                        set: { document.realTimeSmoothingEnabled = $0 }
                    ))
                    .toggleStyle(SwitchToggleStyle())
                    .controlSize(.small)
                }
                .help("Enable real-time smoothing during drawing")

                if document.realTimeSmoothingEnabled {
                    HStack {
                        Text("Strength")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.secondaryText)
                        Spacer()
                        Text("\(Int(document.realTimeSmoothingStrength * 100))%")
                            .font(.subheadline)
                            .foregroundColor(Color.ui.primaryText)
                            .monospacedDigit()
                    }

                    Slider(value: Binding(
                        get: { document.realTimeSmoothingStrength },
                        set: { document.realTimeSmoothingStrength = $0 }
                    ), in: 0...1)
                    .controlSize(.small)
                    .help("Strength of real-time smoothing (0-100%)")
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Preserve Sharp Corners")
                        .font(.subheadline)
                        .foregroundColor(Color.ui.primaryText)
                    Text("Keep sharp angles during simplification")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { document.preserveSharpCorners },
                    set: { document.preserveSharpCorners = $0 }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                .controlSize(.small)
                .help("Preserve sharp corners when simplifying paths")
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
                .help("Enable advanced curve smoothing algorithms")

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
                        ), in: 1...3)
                        .controlSize(.small)
                        .help("More iterations create smoother curves but may lose detail (1-3)")
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

            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Color.ui.primaryBlue)
                Text("Draw smooth curves with automatic path fitting")
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