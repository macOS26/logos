import SwiftUI

struct PreferencesView: View {
    @Environment(AppState.self) private var appState
    @Environment(\._openURL) private var openURL
    @State private var pressureCurve: [CGPoint] = PreferencesView.defaultPressureCurve()
    @Binding var imageQuality: Double
    @Binding var tileSize: Int

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

            GroupBox(label: Label("Image Settings", systemImage: "photo").font(.headline)) {
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Preview Quality: \(Int(imageQuality * 100))%")
                                .font(.subheadline)
                            Spacer()
                        }

                        Slider(value: $imageQuality, in: 0.1...1.0, step: 0.05)
                            .onChange(of: imageQuality) { _, newValue in
                                ApplicationSettings.shared.imagePreviewQuality = newValue
                                ImageTileCache.shared.clearCache()
                            }

                        Text("Controls image resolution in canvas. Lower values use less memory.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("Low (20%)") {
                            imageQuality = 0.2
                        }
                        .buttonStyle(.bordered)

                        Button("Medium (50%)") {
                            imageQuality = 0.5
                        }
                        .buttonStyle(.bordered)

                        Button("High (100%)") {
                            imageQuality = 1.0
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }

                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Tile Size: \(Int(tileSize))px")
                                .font(.subheadline)
                            Spacer()
                        }

                        Slider(value: Binding(
                            get: { Double(tileSize) },
                            set: { tileSize = Int($0) }
                        ), in: 32...1024, step: 32)
                            .onChange(of: tileSize) { _, newValue in
                                ApplicationSettings.shared.imageTileSize = newValue
                                ImageTileCache.shared.clearCache()
                            }

                        Text("Size of image tiles. Smaller tiles use less memory but may be slower.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 8) {
                        Button("Small (128px)") {
                            tileSize = 128
                        }
                        .buttonStyle(.bordered)

                        Button("Medium (512px)") {
                            tileSize = 512
                        }
                        .buttonStyle(.bordered)

                        Button("Large (1024px)") {
                            tileSize = 1024
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
        .frame(minWidth: 400, minHeight: 750)
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

func defaultPressureCurveData() -> Data {
    let defaultCurve = [
        CGPoint(x: 0.0, y: 0.0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1.0, y: 1.0)
    ]
    return (try? JSONEncoder().encode(defaultCurve)) ?? Data()
}
