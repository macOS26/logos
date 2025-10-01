//
//  PreferencesView.swift
//  logos inkpen.io
//
//  Application preferences window
//

import SwiftUI

struct AppPreferencesView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(AppState.self) private var appState
    @State private var selectedTab: PreferenceTab = .pressure

    enum PreferenceTab: String, CaseIterable {
        case pressure = "Pressure"
//        case general = "General"

        var icon: String {
            switch self {
            case .pressure: return "hand.draw"
//            case .general: return "gear"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Done") {
                    // Curve changes auto-save via AppState
                    presentationMode.wrappedValue.dismiss()
                }
                .buttonStyle(ProfessionalPrimaryButtonStyle())
            }
            .padding()

            Divider()

            // Tab bar
            HStack(spacing: 0) {
                ForEach(PreferenceTab.allCases, id: \.self) { tab in
                    Button(action: {
                        selectedTab = tab
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.icon)
                            Text(tab.rawValue)
                        }
                        .font(.subheadline)
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedTab == tab ? Color.accentColor : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            ScrollView {
                pressurePreferencesView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 450, height: 560)
    }

    // MARK: - Pressure Preferences

    private var pressurePreferencesView: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Pressure Sensitivity")
                        .font(.headline)

                    Text("Configure how pressure from your stylus or tablet is mapped to stroke thickness.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Pressure curve editor
                PressureCurveEditor(
                    curve: Binding(
                        get: { appState.pressureCurve },
                        set: { appState.pressureCurve = $0 }
                    ),
                    size: 400
                )
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Preset buttons
                VStack(alignment: .leading, spacing: 8) {
                    Text("Presets")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 12) {
                        Button("Linear") {
                            Log.info("🔘 LINEAR BUTTON PRESSED", category: .pressure)
                            AppState.shared.pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.25),
                                CGPoint(x: 0.5, y: 0.5),
                                CGPoint(x: 0.75, y: 0.75),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Button("Soft") {
                            appState.pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.4),
                                CGPoint(x: 0.5, y: 0.65),
                                CGPoint(x: 0.75, y: 0.85),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Button("Hard") {
                            appState.pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.1),
                                CGPoint(x: 0.5, y: 0.35),
                                CGPoint(x: 0.75, y: 0.6),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Button("Reset") {
                            appState.pressureCurve = AppPreferencesView.defaultPressureCurve()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()
            }
            .padding()

            Spacer()
        }
    }

    // MARK: - General Preferences

    private var generalPreferencesView: some View {
        VStack(spacing: 20) {
            Text("General preferences coming soon...")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding()
    }

    // MARK: - Defaults

    static func defaultPressureCurve() -> [CGPoint] {
        return [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 0.25, y: 0.25),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 1.0, y: 1.0)
        ]
    }
}

// Helper function to create default curve data
func defaultPressureCurveData() -> Data {
    let defaultCurve = AppPreferencesView.defaultPressureCurve()
    return (try? JSONEncoder().encode(defaultCurve)) ?? Data()
}

#Preview {
    AppPreferencesView()
}