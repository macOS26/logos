//
//  HSBInputSection.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Professional HSB Input Section

struct HSBInputSection: View {
    @ObservedObject var document: VectorDocument
    @Binding var sharedColor: VectorColor // Shared color state
    
    @State private var hueValue: String = "0"
    @State private var saturationValue: String = "100"
    @State private var brightnessValue: String = "100"
    @State private var hexValue: String = "ff0000"
    
    // Slider values
    @State private var hueSlider: Double = 0        // 0-360 degrees
    @State private var saturationSlider: Double = 100 // 0-100%
    @State private var brightnessSlider: Double = 100 // 0-100%
    
    // Find closest Pantone color match
    @ObservedObject private var pantoneLibrary = PantoneLibrary()
    
    // Computed color from HSB values
    private var currentColor: HSBColorModel {
        let h = Double(hueValue) ?? 0
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        
        return HSBColorModel(hue: h, saturation: s, brightness: b)
    }
    
    private var closestPantoneColor: PantoneLibraryColor? {
        pantoneLibrary.findClosestMatch(to: currentColor)
    }
    
    // Helper function to get SwiftUI Color from HSB values
    private func swiftUIColor(h: Double, s: Double, b: Double) -> Color {
        return Color(hue: h/360.0, saturation: s/100.0, brightness: b/100.0)
    }
    
    // Hue slider gradient (full rainbow)
    private var hueGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hue: 0.0, saturation: 1.0, brightness: 1.0),    // Red
                Color(hue: 0.167, saturation: 1.0, brightness: 1.0),  // Orange
                Color(hue: 0.333, saturation: 1.0, brightness: 1.0),  // Yellow
                Color(hue: 0.5, saturation: 1.0, brightness: 1.0),    // Green
                Color(hue: 0.667, saturation: 1.0, brightness: 1.0),  // Cyan
                Color(hue: 0.833, saturation: 1.0, brightness: 1.0),  // Blue
                Color(hue: 1.0, saturation: 1.0, brightness: 1.0)     // Magenta
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Saturation slider gradient (from gray to current hue at full saturation)
    private var saturationGradient: LinearGradient {
        let h = Double(hueValue) ?? 0
        let b = Double(brightnessValue) ?? 100
        return LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(h: h, s: 0, b: b),
                swiftUIColor(h: h, s: 100, b: b)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Brightness slider gradient (from black to current hue/saturation at full brightness)
    private var brightnessGradient: LinearGradient {
        let h = Double(hueValue) ?? 0
        let s = Double(saturationValue) ?? 100
        return LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(h: h, s: s, b: 0),
                swiftUIColor(h: h, s: s, b: 100)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // HSB Sliders with Native Apple Sliders and Gradients (matching RGB style)
            VStack(spacing: 8) {
                // Hue Slider
                HStack(spacing: 8) {
                    Circle()
                        .fill(
                            AngularGradient(
                                gradient: Gradient(colors: [
                                    .red, .yellow, .green, .cyan, .blue, Color(red: 1, green: 0, blue: 1), .red
                                ]),
                                center: .center
                            )
                        )
                        .frame(width: 12, height: 12)
                    
                    Text("H")
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
                        Slider(value: $hueSlider, in: 0...360)
                            .tint(Color.clear)
                            .onChange(of: hueSlider) { _, _ in
                                hueValue = String(Int(hueSlider))
                                // ONLY update H - do not touch S or B
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(hueGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $hueValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: hueValue) { _, _ in
                            if let intValue = Double(hueValue) {
                                hueSlider = min(360, max(0, intValue))
                                // ONLY update H - do not touch S or B
                            }
                        }
                        
                    Text("°")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Saturation Slider
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        swiftUIColor(h: Double(hueValue) ?? 0, s: 100, b: Double(brightnessValue) ?? 100),
                                        swiftUIColor(h: Double(hueValue) ?? 0, s: 0, b: Double(brightnessValue) ?? 100)
                                    ]),
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 6
                                )
                            )
                            .frame(width: 12, height: 12)
                        
                        // Current color preview overlay - same size with darken blend
                        Circle()
                            .fill(currentColor.color)
                            .frame(width: 12, height: 12)
                            .blendMode(.multiply)
                    }
                    
                    Text("S")
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
                        Slider(value: $saturationSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: saturationSlider) { _, _ in
                                saturationValue = String(Int(saturationSlider))
                                // ONLY update S - do not touch H or B
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(saturationGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $saturationValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: saturationValue) { _, _ in
                            if let intValue = Double(saturationValue) {
                                saturationSlider = min(100, max(0, intValue))
                                // ONLY update S - do not touch H or B
                            }
                        }
                        
                    Text("%")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                
                // Brightness Slider
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        swiftUIColor(h: Double(hueValue) ?? 0, s: Double(saturationValue) ?? 100, b: 100),
                                        swiftUIColor(h: Double(hueValue) ?? 0, s: Double(saturationValue) ?? 100, b: 0)
                                    ]),
                                    center: .center,
                                    startRadius: 2,
                                    endRadius: 6
                                )
                            )
                            .frame(width: 12, height: 12)
                        
                        // Current color preview overlay - same size with darken blend
                        Circle()
                            .fill(currentColor.color)
                            .frame(width: 12, height: 12)
                            .blendMode(.multiply)
                    }
                    
                    Text("B")
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
                        Slider(value: $brightnessSlider, in: 0...100)
                            .tint(Color.clear)
                            .onChange(of: brightnessSlider) { _, _ in
                                brightnessValue = String(Int(brightnessSlider))
                                // ONLY update B - do not touch H or S
                            }
                        
                        // Gradient overlay
                        Capsule()
                            .fill(brightnessGradient)
                            .frame(height: 6)
                            .allowsHitTesting(false)
                    }
                    
                    TextField("", text: $brightnessValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 45)
                        .font(.system(size: 11))
                        .onChange(of: brightnessValue) { _, _ in
                            if let intValue = Double(brightnessValue) {
                                brightnessSlider = min(100, max(0, intValue))
                                // ONLY update B - do not touch H or S
                            }
                        }
                        
                    Text("%")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            // Two Swatch Previews: HSB and PMS
            HStack(spacing: 6) {
                // HSB Color Swatch Preview
                Button(action: {
                    addColorToSwatches()
                }) {
                    VStack(spacing: 2) {
                        Rectangle()
                            .fill(currentColor.color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        Text("HSB")
                            .font(.system(size: 6))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to add HSB color to swatches")
                
                // PMS Color Swatch Preview
                Button(action: {
                    addPMSColorToSwatches()
                }) {
                    VStack(spacing: 2) {
                        ZStack {
                            Rectangle()
                                .fill(closestPantoneColor?.color ?? currentColor.color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            // Show Pantone number if match found
                            if let pantoneColor = closestPantoneColor {
                                Text(pantoneColor.pantone.replacingOccurrences(of: "-c", with: "").replacingOccurrences(of: " C", with: ""))
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                        Text("PMS")
                            .font(.system(size: 6))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .help("Click to add PMS color to swatches")
                
                Button("Add") {
                    addPMSColorToSwatches()
                }
                .font(.system(size: 10))
                .foregroundColor(.primary)
                
                Spacer()
                
                Text("#")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                
                TextField("ff0000", text: $hexValue)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(size: 11))
                    .frame(width: 55)
                    .onChange(of: hexValue) { _, _ in
                        updateHSBFromHex()
                    }
            }
            
            // HSB colors with preset hues at full saturation and brightness
            Text("HSB colors with preset hues")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .padding(.top, 8)
            
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30)), count: 8), spacing: 4) {
                ForEach(defaultHSBColors.indices, id: \.self) { index in
                    Button(action: {
                        let hsbColor = defaultHSBColors[index]
                        addSpecificPMSColorToSwatches(hsbColor)
                    }) {
                        ZStack {
                            Rectangle()
                                .fill(defaultHSBColors[index].color)
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            // Show Pantone number if match found for this specific color
                            if let pantoneMatch = pantoneLibrary.findClosestMatch(to: defaultHSBColors[index]) {
                                Text(pantoneMatch.pantone.replacingOccurrences(of: "-c", with: "").replacingOccurrences(of: " C", with: ""))
                                    .font(.system(size: 6, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Click to add color to swatches")
                }
            }
        }
        .padding(.vertical, 8)
        .onAppear {
            loadFromSharedColor()
            // Ensure initial color displays with proper PMS matching
            updateSharedColor()
        }
        .onChange(of: sharedColor) { _, newColor in
            loadFromSharedColor()
        }
    }
    
    // MARK: - Default HSB Colors
    
    private var defaultHSBColors: [HSBColorModel] {
        [
            // First row - Pure hues at full saturation and brightness
            HSBColorModel(hue: 0, saturation: 0, brightness: 0),      // Black
            HSBColorModel(hue: 0, saturation: 0, brightness: 1),      // White
            HSBColorModel(hue: 0, saturation: 0, brightness: 0.8),    // Light Gray
            HSBColorModel(hue: 0, saturation: 1, brightness: 1),      // Red
            HSBColorModel(hue: 30, saturation: 1, brightness: 1),     // Orange
            HSBColorModel(hue: 60, saturation: 1, brightness: 1),     // Yellow
            HSBColorModel(hue: 120, saturation: 1, brightness: 1),    // Green
            HSBColorModel(hue: 180, saturation: 1, brightness: 1),    // Cyan
            
            // Second row - More hues
            HSBColorModel(hue: 240, saturation: 1, brightness: 1),    // Blue
            HSBColorModel(hue: 270, saturation: 1, brightness: 1),    // Purple
            HSBColorModel(hue: 300, saturation: 1, brightness: 1),    // Magenta
            HSBColorModel(hue: 15, saturation: 1, brightness: 1),     // Red-Orange
            HSBColorModel(hue: 45, saturation: 1, brightness: 1),     // Yellow-Orange
            HSBColorModel(hue: 90, saturation: 1, brightness: 1),     // Yellow-Green
            HSBColorModel(hue: 150, saturation: 1, brightness: 1),    // Green-Cyan
            HSBColorModel(hue: 210, saturation: 1, brightness: 1),    // Blue-Cyan
            
            // Third row - Darker variations
            HSBColorModel(hue: 0, saturation: 1, brightness: 0.7),    // Dark Red
            HSBColorModel(hue: 60, saturation: 1, brightness: 0.7),   // Dark Yellow
            HSBColorModel(hue: 120, saturation: 1, brightness: 0.7),  // Dark Green
            HSBColorModel(hue: 180, saturation: 1, brightness: 0.7),  // Dark Cyan
            HSBColorModel(hue: 240, saturation: 1, brightness: 0.7),  // Dark Blue
            HSBColorModel(hue: 300, saturation: 1, brightness: 0.7),  // Dark Magenta
            HSBColorModel(hue: 30, saturation: 1, brightness: 0.7),   // Dark Orange
            HSBColorModel(hue: 270, saturation: 1, brightness: 0.7),  // Dark Purple
            
            // Fourth row - Pastel colors (lower saturation)
            HSBColorModel(hue: 0, saturation: 0.5, brightness: 1),    // Pastel Red
            HSBColorModel(hue: 60, saturation: 0.5, brightness: 1),   // Pastel Yellow
            HSBColorModel(hue: 120, saturation: 0.5, brightness: 1),  // Pastel Green
            HSBColorModel(hue: 180, saturation: 0.5, brightness: 1),  // Pastel Cyan
            HSBColorModel(hue: 240, saturation: 0.5, brightness: 1),  // Pastel Blue
            HSBColorModel(hue: 300, saturation: 0.5, brightness: 1),  // Pastel Magenta
            HSBColorModel(hue: 30, saturation: 0.5, brightness: 1),   // Pastel Orange
            HSBColorModel(hue: 270, saturation: 0.5, brightness: 1),  // Pastel Purple
        ]
    }
    
    // MARK: - Helper Methods
    
    private func updateHexFromHSB() {
        let rgbColor = currentColor.rgbColor
        let r = Int(rgbColor.red * 255)
        let g = Int(rgbColor.green * 255)
        let b = Int(rgbColor.blue * 255)
        hexValue = String(format: "%02x%02x%02x", r, g, b)
    }
    
    private func updateHSBFromHex() {
        let cleanHex = hexValue.replacingOccurrences(of: "#", with: "")
        if cleanHex.count == 6 {
            let scanner = Scanner(string: cleanHex)
            var hexNumber: UInt64 = 0
            
            if scanner.scanHexInt64(&hexNumber) {
                let r = Double((hexNumber & 0xff0000) >> 16) / 255.0
                let g = Double((hexNumber & 0x00ff00) >> 8) / 255.0
                let b = Double(hexNumber & 0x0000ff) / 255.0
                
                let rgbColor = RGBColor(red: r, green: g, blue: b, alpha: 1.0)
                let hsbColor = HSBColorModel.fromRGB(rgbColor)
                
                setHSBValues(
                    hue: hsbColor.hue,
                    saturation: hsbColor.saturation * 100,
                    brightness: hsbColor.brightness * 100
                )
            }
        }
    }
    
    private func updateSharedColor() {
        // Always try to match to PMS first, fallback to HSB
        if let pantoneMatch = pantoneLibrary.findClosestMatch(to: currentColor) {
            sharedColor = .pantone(pantoneMatch)
        } else {
            sharedColor = .hsb(currentColor)
        }
    }
    
    private func loadFromSharedColor() {
        var hsbColor: HSBColorModel
        
        switch sharedColor {
        case .hsb(let hsb):
            hsbColor = hsb
        case .rgb(let rgb):
            hsbColor = HSBColorModel.fromRGB(rgb)
        case .cmyk(let cmyk):
            hsbColor = HSBColorModel.fromRGB(cmyk.rgbColor)
        case .pantone(let pantone):
            hsbColor = HSBColorModel.fromRGB(pantone.rgbEquivalent)
        case .spot(let spot):
            hsbColor = spot.hsbEquivalent
        case .appleSystem(let system):
            hsbColor = HSBColorModel.fromRGB(system.rgbEquivalent)
        case .clear:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 1)
        case .black:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 0)
        case .white:
            hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 1)
        }
        
        setHSBValues(
            hue: hsbColor.hue,
            saturation: hsbColor.saturation * 100,
            brightness: hsbColor.brightness * 100
        )
    }
    
    private func setHSBValues(hue: Double, saturation: Double, brightness: Double) {
        hueValue = String(Int(hue))
        saturationValue = String(Int(saturation))
        brightnessValue = String(Int(brightness))
        hueSlider = hue
        saturationSlider = saturation
        brightnessSlider = brightness
        updateHexFromHSB()
    }
    
    private func applyColorToActiveSelection() {
        let vectorColor = VectorColor.hsb(currentColor)
        document.setActiveColor(vectorColor)
    }
    
    private func addColorToSwatches() {
        let vectorColor = VectorColor.hsb(currentColor)
        document.addColorToSwatches(vectorColor)
    }
    
    private func addPMSColorToSwatches() {
        // Add current HSB color as a PMS color using the closest Pantone match name
        if let pantoneColor = closestPantoneColor {
            // Create a PMS color based on current HSB values but with Pantone naming
            let pmsColor = VectorColor.pantone(pantoneColor)
            document.addColorSwatch(pmsColor)
        } else {
            // Fallback: Add as HSB color if no PMS match found
            let hsbColor = VectorColor.hsb(currentColor)
            document.addColorSwatch(hsbColor)
        }
    }
    
    private func addSpecificHSBColorToSwatches(_ hsbColor: HSBColorModel) {
        let vectorColor = VectorColor.hsb(hsbColor)
        document.addColorToSwatches(vectorColor)
    }
    
    private func addSpecificPMSColorToSwatches(_ hsbColor: HSBColorModel) {
        // Find closest PMS match for this specific HSB color
        if let pantoneMatch = pantoneLibrary.findClosestMatch(to: hsbColor) {
            let pmsColor = VectorColor.pantone(pantoneMatch)
            document.addColorSwatch(pmsColor)
        } else {
            // Fallback to HSB if no PMS match
            let vectorColor = VectorColor.hsb(hsbColor)
            document.addColorSwatch(vectorColor)
        }
    }
} 