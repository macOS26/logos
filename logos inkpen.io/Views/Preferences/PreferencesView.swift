import SwiftUI

struct PreferencesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\._openURL) private var openURL
    @State private var pressureCurve: [CGPoint] = PreferencesView.defaultPressureCurve()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Label("Pressure Sensitivity", systemImage: "hand.draw").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {

                    PressureCurveEditor(curve: $pressureCurve, size: 300)
                        .padding(.vertical, 8)

                    HStack(spacing: 8) {
                        Button("Linear") {
                            pressureCurve = PreferencesView.defaultPressureCurve()
                        }
                        .buttonStyle(.bordered)

                        Button("Soft") {
                            pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.4),
                                CGPoint(x: 0.5, y: 0.65),
                                CGPoint(x: 0.75, y: 0.85),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Button("Hard") {
                            pressureCurve = [
                                CGPoint(x: 0.0, y: 0.0),
                                CGPoint(x: 0.25, y: 0.1),
                                CGPoint(x: 0.5, y: 0.35),
                                CGPoint(x: 0.75, y: 0.6),
                                CGPoint(x: 1.0, y: 1.0)
                            ]
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()
        }
        .padding(24)
        .frame(minWidth: 400, minHeight: 550)
        .onAppear {
            loadPressureCurve()
        }
        .onChange(of: pressureCurve) { oldValue, newValue in
            savePressureCurve()
        }
    }

    private func loadPressureCurve() {
        if let data = UserDefaults.standard.array(forKey: "pressureCurve") as? [[String: Double]] {
            let loadedCurve = data.compactMap { dict -> CGPoint? in
                guard let x = dict["x"], let y = dict["y"] else { return nil }
                return CGPoint(x: x, y: y)
            }
            if loadedCurve.count >= 2 {
                pressureCurve = loadedCurve
            }
        }
    }

    private func savePressureCurve() {
        let data = pressureCurve.map { ["x": $0.x, "y": $0.y] }
        UserDefaults.standard.set(data, forKey: "pressureCurve")
        UserDefaults.standard.synchronize()

        appState.pressureCurve = pressureCurve

    }

    static func defaultPressureCurve() -> [CGPoint] {
        return [
            CGPoint(x: 0.0, y: 0.0),
            CGPoint(x: 0.25, y: 0.25),
            CGPoint(x: 0.5, y: 0.5),
            CGPoint(x: 0.75, y: 0.75),
            CGPoint(x: 1.0, y: 1.0)
        ]
    }

    static func defaultPressureCurveData() -> Data {
        let defaultCurve = defaultPressureCurve()
        return (try? JSONEncoder().encode(defaultCurve)) ?? Data()
    }
}