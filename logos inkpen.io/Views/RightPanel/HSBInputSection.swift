//
//  HSBInputSection.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Professional HSB Input Section with SPOT Color Matching

struct HSBInputSection: View {
    @ObservedObject var document: VectorDocument
    @Binding var sharedColor: VectorColor // Shared color state
    
    @State private var hueValue: String = "0"
    @State private var saturationValue: String = "100"
    @State private var brightnessValue: String = "100"
    
    // Slider values
    @State private var hueSlider: Double = 0        // 0-360 degrees
    @State private var saturationSlider: Double = 100 // 0-100%
    @State private var brightnessSlider: Double = 100 // 0-100%
    
    // Computed color from HSB values
    private var currentColor: HSBColorModel {
        let h = Double(hueValue) ?? 0
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        
        return HSBColorModel(hue: h, saturation: s, brightness: b)
    }
    
    // Find closest SPOT color match
    private var closestSPOTColor: SPOTColor {
        SPOTColor.findClosestMatch(to: currentColor)
    }
    
    // Hue gradient (full spectrum)
    private var hueGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(hue: 0.0, saturation: 1.0, brightness: 1.0),     // Red
                Color(hue: 0.17, saturation: 1.0, brightness: 1.0),    // Yellow
                Color(hue: 0.33, saturation: 1.0, brightness: 1.0),    // Green
                Color(hue: 0.5, saturation: 1.0, brightness: 1.0),     // Cyan
                Color(hue: 0.67, saturation: 1.0, brightness: 1.0),    // Blue
                Color(hue: 0.83, saturation: 1.0, brightness: 1.0),    // Magenta
                Color(hue: 1.0, saturation: 1.0, brightness: 1.0)      // Red again
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Saturation gradient (gray to current hue at full saturation)
    private var saturationGradient: LinearGradient {
        let currentHue = (Double(hueValue) ?? 0) / 360.0
        let currentBrightness = (Double(brightnessValue) ?? 0) / 100.0
        
        return LinearGradient(
            colors: [
                Color(hue: currentHue, saturation: 0.0, brightness: currentBrightness), // Gray
                Color(hue: currentHue, saturation: 1.0, brightness: currentBrightness)  // Full saturation
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Brightness gradient (black to current hue/saturation at full brightness)
    private var brightnessGradient: LinearGradient {
        let currentHue = (Double(hueValue) ?? 0) / 360.0
        let currentSaturation = (Double(saturationValue) ?? 0) / 100.0
        
        return LinearGradient(
            colors: [
                Color(hue: currentHue, saturation: currentSaturation, brightness: 0.0), // Black
                Color(hue: currentHue, saturation: currentSaturation, brightness: 1.0)  // Full brightness
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Current Color Preview with SPOT Match
            VStack(alignment: .leading, spacing: 8) {
                Text("HSB Color")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    // Current HSB Color
                    VStack(spacing: 4) {
                        Circle()
                            .fill(currentColor.color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                        
                        Text("HSB")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Arrow
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    // Closest SPOT Color Match
                    VStack(spacing: 4) {
                        Button {
                            // Apply closest SPOT color
                            let spotColor = VectorColor.spot(closestSPOTColor)
                            sharedColor = spotColor
                            document.addColorToCurrentMode(spotColor)
                            updateHSBFromColor(spotColor)
                        } label: {
                            Circle()
                                .fill(closestSPOTColor.color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Click to use closest SPOT color: \(closestSPOTColor.number)")
                        
                        Text("SPOT \(closestSPOTColor.number)")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                    }
                }
                
                // Color values display
                VStack(alignment: .leading, spacing: 2) {
                    Text("H: \(Int(hueSlider))° S: \(Int(saturationSlider))% B: \(Int(brightnessSlider))%")
                        .font(.caption2)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    
                    Text("Closest: SPOT \(closestSPOTColor.number) - \(closestSPOTColor.name)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
            
            // Hue Slider (0-360°)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color(hue: hueSlider / 360.0, saturation: 1.0, brightness: 1.0))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                    
                    Text("Hue")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    TextField("H", text: $hueValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .font(.caption)
                        .onChange(of: hueValue) { _ in
                            syncHueSlider()
                            updateSharedColor()
                        }
                    
                    Text("°")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 0) {
                    Slider(value: $hueSlider, in: 0...360, step: 1)
                        .onChange(of: hueSlider) { _ in
                            syncHueValue()
                            updateSharedColor()
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hueGradient)
                                .frame(height: 8)
                        )
                }
            }
            
            // Saturation Slider (0-100%)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color(hue: hueSlider / 360.0, saturation: saturationSlider / 100.0, brightness: brightnessSlider / 100.0))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                    
                    Text("Saturation")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    TextField("S", text: $saturationValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .font(.caption)
                        .onChange(of: saturationValue) { _ in
                            syncSaturationSlider()
                            updateSharedColor()
                        }
                    
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 0) {
                    Slider(value: $saturationSlider, in: 0...100, step: 1)
                        .onChange(of: saturationSlider) { _ in
                            syncSaturationValue()
                            updateSharedColor()
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(saturationGradient)
                                .frame(height: 8)
                        )
                }
            }
            
            // Brightness Slider (0-100%)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(Color(hue: hueSlider / 360.0, saturation: saturationSlider / 100.0, brightness: brightnessSlider / 100.0))
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(Color.gray, lineWidth: 0.5))
                    
                    Text("Brightness")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    TextField("B", text: $brightnessValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 50)
                        .font(.caption)
                        .onChange(of: brightnessValue) { _ in
                            syncBrightnessSlider()
                            updateSharedColor()
                        }
                    
                    Text("%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 0) {
                    Slider(value: $brightnessSlider, in: 0...100, step: 1)
                        .onChange(of: brightnessSlider) { _ in
                            syncBrightnessValue()
                            updateSharedColor()
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(brightnessGradient)
                                .frame(height: 8)
                        )
                }
            }
            
            // SPOT Color Presets (Popular colors for quick access)
            VStack(alignment: .leading, spacing: 8) {
                Text("Popular SPOT Colors")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), spacing: 4) {
                    let popularColors = [
                        SPOTColor.allSPOTColors.first { $0.number == "032" }!, // Reflex Blue
                        SPOTColor.allSPOTColors.first { $0.number == "185" }!, // Red
                        SPOTColor.allSPOTColors.first { $0.number == "355" }!, // Green
                        SPOTColor.allSPOTColors.first { $0.number == "Yellow" }!, // Yellow
                        SPOTColor.allSPOTColors.first { $0.number == "286" }!, // Blue
                        SPOTColor.allSPOTColors.first { $0.number == "2587" }!, // Purple
                        SPOTColor.allSPOTColors.first { $0.number == "021" }!, // Orange
                        SPOTColor.allSPOTColors.first { $0.number == "Cool Gray 9" }! // Gray
                    ]
                    
                    ForEach(popularColors, id: \.number) { spotColor in
                        Button {
                            let vectorColor = VectorColor.spot(spotColor)
                            sharedColor = vectorColor
                            document.addColorToCurrentMode(vectorColor)
                            updateHSBFromColor(vectorColor)
                        } label: {
                            Rectangle()
                                .fill(spotColor.color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray, lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("SPOT \(spotColor.number): \(spotColor.name)")
                    }
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            .cornerRadius(8)
        }
        .onAppear {
            updateHSBFromSharedColor()
        }
        .onChange(of: sharedColor) { _ in
            updateHSBFromSharedColor()
        }
    }
    
    // MARK: - Helper Methods
    
    private func syncHueValue() {
        hueValue = String(Int(hueSlider))
    }
    
    private func syncHueSlider() {
        if let value = Double(hueValue) {
            hueSlider = max(0, min(360, value))
        }
    }
    
    private func syncSaturationValue() {
        saturationValue = String(Int(saturationSlider))
    }
    
    private func syncSaturationSlider() {
        if let value = Double(saturationValue) {
            saturationSlider = max(0, min(100, value))
        }
    }
    
    private func syncBrightnessValue() {
        brightnessValue = String(Int(brightnessSlider))
    }
    
    private func syncBrightnessSlider() {
        if let value = Double(brightnessValue) {
            brightnessSlider = max(0, min(100, value))
        }
    }
    
    private func updateSharedColor() {
        sharedColor = .hsb(currentColor)
    }
    
    private func updateHSBFromSharedColor() {
        updateHSBFromColor(sharedColor)
    }
    
    private func updateHSBFromColor(_ color: VectorColor) {
        var hsbColor: HSBColorModel
        
        switch color {
        case .hsb(let hsb):
            hsbColor = hsb
        case .rgb(let rgb):
            hsbColor = HSBColorModel.fromRGB(rgb)
        case .cmyk(let cmyk):
            hsbColor = HSBColorModel.fromRGB(cmyk.rgbColor)
        case .spot(let spot):
            hsbColor = spot.hsbEquivalent
        case .pantone(let pantone):
            hsbColor = HSBColorModel.fromRGB(pantone.rgbEquivalent)
        case .appleSystem(let system):
            hsbColor = HSBColorModel.fromRGB(system.rgbEquivalent)
        case .black:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 0)
        case .white:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 1)
        case .clear:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 1)
        }
        
        // Update sliders and text fields
        hueSlider = hsbColor.hue
        saturationSlider = hsbColor.saturation * 100
        brightnessSlider = hsbColor.brightness * 100
        
        hueValue = String(Int(hueSlider))
        saturationValue = String(Int(saturationSlider))
        brightnessValue = String(Int(brightnessSlider))
    }
} 