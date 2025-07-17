//
//  CMYKInputSection.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Professional CMYK Input Section

struct CMYKInputSection: View {
    @ObservedObject var document: VectorDocument
    @Binding var sharedColor: VectorColor // Shared color state
    
    @State private var cyanValue: String = "0"
    @State private var magentaValue: String = "0"
    @State private var yellowValue: String = "0"
    @State private var blackValue: String = "0"
    
    // Slider values (0-100)
    @State private var cyanSlider: Double = 0
    @State private var magentaSlider: Double = 0
    @State private var yellowSlider: Double = 0
    @State private var blackSlider: Double = 0
    
    // Computed color from CMYK values
    private var currentColor: CMYKColor {
        let c = (Double(cyanValue) ?? 0) / 100.0
        let m = (Double(magentaValue) ?? 0) / 100.0
        let y = (Double(yellowValue) ?? 0) / 100.0
        let k = (Double(blackValue) ?? 0) / 100.0
        
        return CMYKColor(
            cyan: max(0, min(1, c)),
            magenta: max(0, min(1, m)),
            yellow: max(0, min(1, y)),
            black: max(0, min(1, k))
        )
    }
    
    // Helper function to get SwiftUI Color from CMYK values
    private func swiftUIColorFromCMYK(c: Double, m: Double, y: Double, k: Double) -> Color {
        let cmykColor = CMYKColor(cyan: c/100.0, magenta: m/100.0, yellow: y/100.0, black: k/100.0)
        return cmykColor.color
    }
    
    // Cyan slider gradient (morphs from current color with C=0 to current color with C=100)
    private var cyanGradient: LinearGradient {
        let m = Double(magentaValue) ?? 0
        let y = Double(yellowValue) ?? 0
        let k = Double(blackValue) ?? 0
        return LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: 0, m: m, y: y, k: k),
                swiftUIColorFromCMYK(c: 100, m: m, y: y, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Magenta slider gradient
    private var magentaGradient: LinearGradient {
        let c = Double(cyanValue) ?? 0
        let y = Double(yellowValue) ?? 0
        let k = Double(blackValue) ?? 0
        return LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: 0, y: y, k: k),
                swiftUIColorFromCMYK(c: c, m: 100, y: y, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Yellow slider gradient
    private var yellowGradient: LinearGradient {
        let c = Double(cyanValue) ?? 0
        let m = Double(magentaValue) ?? 0
        let k = Double(blackValue) ?? 0
        return LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: m, y: 0, k: k),
                swiftUIColorFromCMYK(c: c, m: m, y: 100, k: k)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Black slider gradient
    private var blackGradient: LinearGradient {
        let c = Double(cyanValue) ?? 0
        let m = Double(magentaValue) ?? 0
        let y = Double(yellowValue) ?? 0
        return LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColorFromCMYK(c: c, m: m, y: y, k: 0),
                swiftUIColorFromCMYK(c: c, m: m, y: y, k: 100)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CMYK Process Colors")
                    .font(.caption)
                .fontWeight(.medium)
                    .foregroundColor(.secondary)
            
            Text("Enter process color values (0-100%)")
                .font(.caption2)
                    .foregroundColor(.secondary)
            
            // CMYK Sliders with Native Apple Sliders and Gradients
            VStack(spacing: 8) {
                // Cyan Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 12, height: 12)
                    
                    Text("C")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    ZStack {
                        // White background for slider track
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        // Native Apple Slider
                        Slider(value: $cyanSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: cyanSlider) {
                                cyanValue = String(Int(cyanSlider))
                                updateSharedColor()
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(cyanGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $cyanValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: cyanValue) {
                            if let intValue = Double(cyanValue) {
                                cyanSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
                
                // Magenta Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.pink)
                        .frame(width: 12, height: 12)
                    
                    Text("M")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    ZStack {
                        // White background for slider track
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        // Native Apple Slider
                        Slider(value: $magentaSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: magentaSlider) {
                                magentaValue = String(Int(magentaSlider))
                                updateSharedColor()
                }
                
                        // Gradient overlay
                        Capsule()
                            .fill(magentaGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $magentaValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: magentaValue) {
                            if let intValue = Double(magentaValue) {
                                magentaSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
                
                // Yellow Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 12, height: 12)
                    
                    Text("Y")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    ZStack {
                        // White background for slider track
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        // Native Apple Slider
                        Slider(value: $yellowSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: yellowSlider) {
                                yellowValue = String(Int(yellowSlider))
                                updateSharedColor()
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(yellowGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $yellowValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: yellowValue) {
                            if let intValue = Double(yellowValue) {
                                yellowSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
                
                // Black Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 12, height: 12)
                    
                    Text("K")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 12)
                    
                    ZStack {
                        // White background for slider track
                        Capsule()
                            .fill(Color.white)
                            .frame(height: 6)
                            .overlay(
                                Capsule()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                        
                        // Native Apple Slider
                        Slider(value: $blackSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: blackSlider) {
                                blackValue = String(Int(blackSlider))
                                updateSharedColor()
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(blackGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $blackValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: blackValue) {
                            if let intValue = Double(blackValue) {
                                blackSlider = min(100, max(0, intValue))
                                updateSharedColor()
                            }
                        }
                }
            }
            
            // Compact Color Preview and Add Button (similar to RGB)
            HStack(spacing: 8) {
                // Square Color Swatch Preview (30x30 like RGB section)
                Button(action: {
                    applyColorToActiveSelection()
                }) {
                Rectangle()
                        .fill(currentColor.color)
                        .frame(width: 30, height: 30)
                    .overlay(
                        Rectangle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to apply color to active fill or stroke")
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("CMYK(\(Int(currentColor.cyan * 100)), \(Int(currentColor.magenta * 100)), \(Int(currentColor.yellow * 100)), \(Int(currentColor.black * 100)))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Button("Add to Swatches") {
                        addCMYKColorToSwatches()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                }
                
                Spacer()
            }
            
            // Quick CMYK Presets
        VStack(alignment: .leading, spacing: 4) {
                Text("Common Process Colors")
                    .font(.caption2)
                .foregroundColor(.secondary)
            
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    CMYKPresetButton(name: "Cyan", cmyk: (100, 0, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Magenta", cmyk: (0, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Yellow", cmyk: (0, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Black", cmyk: (0, 0, 0, 100), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Red", cmyk: (0, 100, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Green", cmyk: (100, 0, 100, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Blue", cmyk: (100, 100, 0, 0), action: applyCMYKPreset)
                    CMYKPresetButton(name: "Rich Black", cmyk: (30, 30, 30, 100), action: applyCMYKPreset)
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadFromSharedColor()
        }
        .onChange(of: sharedColor) { _, newColor in
            loadFromSharedColor()
        }
    }
    
    private func updateSharedColor() {
        sharedColor = .cmyk(currentColor)
    }
    
    private func loadFromSharedColor() {
        switch sharedColor {
        case .rgb(let rgb):
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .cmyk(let cmyk):
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .hsb(let hsb):
            let rgb = hsb.rgbColor
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .pantone(let pantone):
            let cmyk = pantone.cmykEquivalent
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .spot(let spot):
            let cmyk = spot.cmykEquivalent
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .appleSystem(let system):
            let rgb = system.rgbEquivalent
            let cmyk = ColorManagement.rgbToCMYK(rgb)
            setCMYKValues(
                cyan: Int(cmyk.cyan * 100),
                magenta: Int(cmyk.magenta * 100),
                yellow: Int(cmyk.yellow * 100),
                black: Int(cmyk.black * 100)
            )
        case .clear:
            setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 0)
        case .black:
            setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 100)
        case .white:
            setCMYKValues(cyan: 0, magenta: 0, yellow: 0, black: 0)
        }
    }
    
    private func setCMYKValues(cyan: Int, magenta: Int, yellow: Int, black: Int) {
        cyanValue = String(cyan)
        magentaValue = String(magenta)
        yellowValue = String(yellow)
        blackValue = String(black)
        cyanSlider = Double(cyan)
        magentaSlider = Double(magenta)
        yellowSlider = Double(yellow)
        blackSlider = Double(black)
    }
    
    private func applyColorToActiveSelection() {
        let vectorColor = VectorColor.cmyk(currentColor)
        document.setActiveColor(vectorColor)
    }
    
    private func addCMYKColorToSwatches() {
        let vectorColor = VectorColor.cmyk(currentColor)
        document.addColorSwatch(vectorColor)
    }
    
    private func applyCMYKPreset(_ cmyk: (Int, Int, Int, Int)) {
        cyanValue = String(cmyk.0)
        magentaValue = String(cmyk.1)
        yellowValue = String(cmyk.2)
        blackValue = String(cmyk.3)
        cyanSlider = Double(cmyk.0)
        magentaSlider = Double(cmyk.1)
        yellowSlider = Double(cmyk.2)
        blackSlider = Double(cmyk.3)
        updateSharedColor()
    }
}

struct CMYKPresetButton: View {
    let name: String
    let cmyk: (Int, Int, Int, Int)
    let action: ((Int, Int, Int, Int)) -> Void
    
    var body: some View {
        Button {
            action(cmyk)
        } label: {
            VStack(spacing: 2) {
                let cmykColor = CMYKColor(
                    cyan: Double(cmyk.0) / 100.0,
                    magenta: Double(cmyk.1) / 100.0,
                    yellow: Double(cmyk.2) / 100.0,
                    black: Double(cmyk.3) / 100.0
                )
                
                        Rectangle()
                    .fill(cmykColor.color)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Rectangle()
                            .stroke(Color.gray, lineWidth: 0.5)
                    )
                
                Text(name)
                    .font(.system(size: 8))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .help("CMYK(\(cmyk.0), \(cmyk.1), \(cmyk.2), \(cmyk.3))")
    }
} 