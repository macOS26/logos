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
    @State private var isUpdatingHexFromHSB: Bool = false // Flag to prevent feedback loops
    
    // Slider values
    @State private var hueSlider: Double = 0        // 0-360 degrees
    @State private var saturationSlider: Double = 100 // 0-100%
    @State private var brightnessSlider: Double = 100 // 0-100%
    
    // State for PMS entry
    @State private var pmsEntryText: String = ""
    
    // Live PMS preview state
    @State private var livePMSPreview: PantoneLibraryColor? = nil
    
    // Find closest Pantone color match
    @ObservedObject private var pantoneLibrary = PantoneLibrary()
    
    // Computed color from HSB values - preserves exact user input
    private var currentColor: HSBColorModel {
        let h = Double(hueValue) ?? 0
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        
        // Create HSBColorModel that preserves exact hue value (no normalization)
        return HSBColorModel(hue: h, saturation: s, brightness: b)
    }
    
    private var closestPantoneColor: PantoneLibraryColor? {
        // Use preserved user input for PMS matching, but normalize H=360 to 0 for calculation
        let userHue = Double(hueValue) ?? 0
        let normalizedHue = userHue >= 360 ? 0 : userHue
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        
        let matchingColor = HSBColorModel(hue: normalizedHue, saturation: s, brightness: b)
        return pantoneLibrary.findClosestMatch(to: matchingColor)
    }
    
    // Live preview color - either from live PMS search or current HSB (preserves exact user input)
    private var livePreviewColor: (pms: PantoneLibraryColor?, hsb: HSBColorModel) {
        if let livePMS = livePMSPreview {
            // Show live PMS match and its HSB approximation
            let hsbApproximation = HSBColorModel.fromRGB(livePMS.rgbEquivalent)
            return (pms: livePMS, hsb: hsbApproximation)
        } else {
            // PRESERVE USER INPUT: Show HSB color with exact user values (H=360 stays 360)
            let userHue = Double(hueValue) ?? 0  // Keep exact user input
            let s = (Double(saturationValue) ?? 0) / 100.0
            let b = (Double(brightnessValue) ?? 0) / 100.0
            let preservedHSB = HSBColorModel(hue: userHue, saturation: s, brightness: b)
            
            return (pms: closestPantoneColor, hsb: preservedHSB)
        }
    }
    
    // Current hue as solid color for H circle
    private var currentHueColor: Color {
        Color(hue: (Double(hueValue) ?? 0) / 360.0, saturation: 1.0, brightness: 1.0)
    }
    
    // Current saturation color for S circle
    private var currentSaturationColor: Color {
        let h = Double(hueValue) ?? 0
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = Double(brightnessValue) ?? 100
        return Color(hue: h/360.0, saturation: s, brightness: b/100.0)
    }
    
    // Current brightness color for B circle
    private var currentBrightnessColor: Color {
        let h = Double(hueValue) ?? 0
        let s = Double(saturationValue) ?? 100
        let b = (Double(brightnessValue) ?? 0) / 100.0
        return Color(hue: h/360.0, saturation: s/100.0, brightness: b)
    }
    
    // Helper function to get SwiftUI Color from HSB values
    private func swiftUIColor(h: Double, s: Double, b: Double) -> Color {
        return Color(hue: h/360.0, saturation: s/100.0, brightness: b/100.0)
    }
    
    // Hue slider gradient (full rainbow)
    private var hueGradient: SwiftUI.LinearGradient {
        SwiftUI.LinearGradient(
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
    private var saturationGradient: SwiftUI.LinearGradient {
        let h = Double(hueValue) ?? 0
        let b = Double(brightnessValue) ?? 100
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(h: h, s: 0, b: b),
                swiftUIColor(h: h, s: 100, b: b)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Brightness slider gradient (from black to current hue/saturation at full brightness)
    private var brightnessGradient: SwiftUI.LinearGradient {
        let h = Double(hueValue) ?? 0
        let s = Double(saturationValue) ?? 100
        return SwiftUI.LinearGradient(
            gradient: Gradient(colors: [
                swiftUIColor(h: h, s: s, b: 0),
                swiftUIColor(h: h, s: s, b: 100)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // HSB Sliders with Native Apple Sliders and Gradients (matching RGB style)
            VStack(spacing: 6) {
                // Hue Slider
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentHueColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    
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
                                updateHexFromHSB()
                                // Clear live PMS preview when manually adjusting HSB
                                livePMSPreview = nil
                                // DO NOT call updateSharedColor() here - keep sliders isolated
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
                                    updateHexFromHSB()
                                    // Clear live PMS preview when manually adjusting HSB
                                    livePMSPreview = nil
                                    // NO updateSharedColor() - HSB sliders are isolated
                                }
                            }
                }
                
                // Saturation Slider
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentSaturationColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    
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
                                updateHexFromHSB()
                                // Clear live PMS preview when manually adjusting HSB
                                livePMSPreview = nil
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
                                    updateHexFromHSB()
                                    // Clear live PMS preview when manually adjusting HSB
                                    livePMSPreview = nil
                                }
                            }
                }
                
                // Brightness Slider
                HStack(spacing: 6) {
                    Circle()
                        .fill(currentBrightnessColor)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                        )
                    
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
                                updateHexFromHSB()
                                // Clear live PMS preview when manually adjusting HSB
                                livePMSPreview = nil
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
                                    updateHexFromHSB()
                                    // Clear live PMS preview when manually adjusting HSB
                                    livePMSPreview = nil
                                }
                            }
                }
            }
            
            // HSB and PMS Swatch Previews with PMS Entry
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    // HSB Color Swatch Preview (shows live preview approximation)
                    Button(action: {
                        addColorToSwatches()
                    }) {
                        VStack(spacing: 2) {
                            Rectangle()
                                .fill(livePreviewColor.hsb.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            Text("HSB")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Click to add HSB color to swatches (preserves exact HSB values)")
                    
                    // PMS Color Swatch Preview (shows live PMS preview)
                    Button(action: {
                        addPMSColorToSwatches()
                    }) {
                        VStack(spacing: 2) {
                            ZStack {
                                Rectangle()
                                    .fill(livePreviewColor.pms?.color ?? livePreviewColor.hsb.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Rectangle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                
                                // Show Pantone number if match found (live or closest) - proper multi-line formatting
                                if let pantoneColor = livePreviewColor.pms {
                                    Text(pantoneColor.pantone.replacingOccurrences(of: "-c", with: "").replacingOccurrences(of: " C", with: ""))
                                        .font(.system(size: 7, weight: .bold))
                                        .foregroundColor(.white)
                                        .shadow(color: .black, radius: 1, x: 0, y: 0)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.5)
                                        .multilineTextAlignment(.center)
                                        .frame(width: 30, height: 30)
                                        .allowsTightening(true)
                                }
                            }
                            Text("PMS")
                                .font(.system(size: 7))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Click to add PMS/Pantone color to swatches (converts to closest Pantone match)")
                    
                    Spacer()
                }
                
                // PMS Entry and Hex Row
                HStack(spacing: 6) {
                    TextField("PMS # or Name", text: $pmsEntryText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 10))
                        .onSubmit {
                            searchAndApplyPMSColor()
                        }
                        .onChange(of: pmsEntryText) { _, newValue in
                            performLivePMSSearch(newValue)
                        }
                    
                    Button("Add") {
                        searchAndApplyPMSColor()
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.primary)
                    
                    Text("#")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    TextField("ff0000", text: $hexValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 10))
                        .frame(width: 60)
                        .onChange(of: hexValue) { _, _ in
                            // NEVER update HSB from hex - user explicitly forbids this
                            // Only clear live PMS preview when manually adjusting hex
                            if !isUpdatingHexFromHSB {
                                livePMSPreview = nil
                            }
                        }
                }
            }
            
            // Bottom color swatches with PMS names
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(32)), count: 4), spacing: 4) {
                ForEach(Array(defaultHSBColors.enumerated()), id: \.offset) { index, hsbColor in
                    Button(action: {
                        addSpecificPMSColorToSwatches(hsbColor)
                    }) {
                        ZStack {
                            Rectangle()
                                .fill(hsbColor.color)
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                            
                            // Show PMS color names on swatches - proper multi-line formatting
                            if hsbColor.saturation == 0 && hsbColor.brightness == 0 {
                                Text("black")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.5)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 30, height: 30)
                                    .allowsTightening(true)
                            } else if hsbColor.saturation == 0 && hsbColor.brightness == 1 && hsbColor.alpha == 1 {
                                Text("white")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.black)
                                    .shadow(color: .white, radius: 1, x: 0, y: 0)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.5)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 30, height: 30)
                                    .allowsTightening(true)
                            } else if hsbColor.alpha < 1.0 {
                                Text("clear")
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.black)
                                    .shadow(color: .white, radius: 1, x: 0, y: 0)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.5)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 30, height: 30)
                                    .allowsTightening(true)
                            } else if let pantoneMatch = pantoneLibrary.findClosestMatch(to: hsbColor) {
                                Text(pantoneMatch.pantone.replacingOccurrences(of: "-c", with: "").replacingOccurrences(of: " C", with: ""))
                                    .font(.system(size: 7, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(color: .black, radius: 1, x: 0, y: 0)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.5)
                                    .multilineTextAlignment(.center)
                                    .frame(width: 30, height: 30)
                                    .allowsTightening(true)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Click to add PMS/Pantone color to swatches (converts to closest Pantone match)")
                }
            }
            .padding(.top, 8)

        }
        .padding(.vertical, 6)
        .onAppear {
            loadFromSharedColor()
            // HSB sliders stay isolated - no updateSharedColor() here
        }
        .onChange(of: sharedColor) { _, newColor in
            // Always load from shared color when it changes (like CMYKInputSection does)
            loadFromSharedColor()
        }
    }
    
    // MARK: - Default HSB Colors
    
    private var defaultHSBColors: [HSBColorModel] {
        [
            // Essential colors only
            HSBColorModel(hue: 0, saturation: 0, brightness: 0),      // Black
            HSBColorModel(hue: 0, saturation: 0, brightness: 1),      // White
            HSBColorModel(hue: 0, saturation: 0, brightness: 1, alpha: 0),  // Clear
            HSBColorModel(hue: 0, saturation: 1, brightness: 1)       // Red
        ]
    }
    
    // MARK: - Helper Methods
    
    private func updateHexFromHSB() {
        // PRESERVE EXACT USER INPUT: Handle H=360 specially to prevent normalization to 0
        let userHue = Double(hueValue) ?? 0
        let normalizedHue = userHue >= 360 ? 0 : userHue  // Only normalize for calculation, preserve user input
        let s = (Double(saturationValue) ?? 0) / 100.0
        let b = (Double(brightnessValue) ?? 0) / 100.0
        
        // Create HSB with normalized hue for calculation only
        let calculationColor = HSBColorModel(hue: normalizedHue, saturation: s, brightness: b)
        let rgbColor = calculationColor.rgbColor
        let r = Int(rgbColor.red * 255)
        let g = Int(rgbColor.green * 255)
        let b_value = Int(rgbColor.blue * 255)
        
        // Set flag to prevent feedback loop
        isUpdatingHexFromHSB = true
        hexValue = String(format: "%02x%02x%02x", r, g, b_value)
        isUpdatingHexFromHSB = false
        
        // CRITICAL: Never modify hueValue, saturationValue, or brightnessValue here
        // User's H=360 stays exactly as H=360, never normalized to 0
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
        sharedColor = .hsb(currentColor)
        // FIXED: Also update the document's default color when HSB values change
        let vectorColor = VectorColor.hsb(currentColor)
        document.setActiveColor(vectorColor)
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
        case .gradient(let gradient):
            // For gradients, use the first stop color as representative
            if let firstStop = gradient.stops.first {
                switch firstStop.color {
                case .hsb(let hsb):
                    hsbColor = hsb
                default:
                    // Convert any other color type to HSB for display
                    let swiftUIColor = firstStop.color.color
                    let components = swiftUIColor.components
                    let rgbColor = RGBColor(red: components.red, green: components.green, blue: components.blue, alpha: components.alpha)
                    hsbColor = HSBColorModel.fromRGB(rgbColor)
                }
            } else {
                hsbColor = HSBColorModel(hue: 0, saturation: 0, brightness: 0)
            }
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
        // Ensure we create HSB color with exact user input values
        let exactHSBColor = HSBColorModel(
            hue: Double(hueValue) ?? 0,
            saturation: (Double(saturationValue) ?? 0) / 100.0,
            brightness: (Double(brightnessValue) ?? 0) / 100.0
        )
        let vectorColor = VectorColor.hsb(exactHSBColor)
        document.addColorToSwatches(vectorColor)
        
        // Debug: Confirm HSB format is being added
        print("🎨 HSB: Added color as HSB format - H:\(exactHSBColor.hue)° S:\(Int(exactHSBColor.saturation * 100))% B:\(Int(exactHSBColor.brightness * 100))%")
    }
    
    private func addPMSColorToSwatches() {
        // Add current HSB color as a PMS color using the closest Pantone match name
        if let pantoneColor = closestPantoneColor {
            // Create a PMS color based on current HSB values but with Pantone naming
            let pmsColor = VectorColor.pantone(pantoneColor)
            document.addColorSwatch(pmsColor)
            
            // Debug: Confirm Pantone format is being added
            print("🎨 PMS: Added color as Pantone format - \(pantoneColor.pantone) (\(pantoneColor.name))")
        } else {
            // Fallback: Add as HSB color if no PMS match found
            let hsbColor = VectorColor.hsb(currentColor)
            document.addColorSwatch(hsbColor)
            
            // Debug: Fallback to HSB when no Pantone match
            print("🎨 PMS: No Pantone match found, added as HSB format instead")
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
    
    // MARK: - Live PMS Search
    
    private func performLivePMSSearch(_ query: String) {
        let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if cleanedQuery.isEmpty {
            // Clear live preview when text is empty
            livePMSPreview = nil
            return
        }
        
        // Search for exact PMS color match as user types
        let searchResults = pantoneLibrary.searchColors(query: cleanedQuery)
        
        if let foundColor = searchResults.first {
            // Update live preview
            livePMSPreview = foundColor
            
            // REAL-TIME HSB SLIDER UPDATE: Convert PMS to HSB and update sliders
            let hsbColor = HSBColorModel.fromRGB(foundColor.rgbEquivalent)
            
            // Update all HSB slider values and text fields in real-time
            hueValue = String(Int(hsbColor.hue))
            saturationValue = String(Int(hsbColor.saturation * 100))
            brightnessValue = String(Int(hsbColor.brightness * 100))
            hueSlider = hsbColor.hue
            saturationSlider = hsbColor.saturation * 100
            brightnessSlider = hsbColor.brightness * 100
            
            // Update hex value to match
            updateHexFromHSB()
            
            // Update shared color to sync with other color modes (only when manually typing PMS)
            updateSharedColor()
        } else {
            // Clear live preview if no match found
            livePMSPreview = nil
        }
    }
    
    private func searchAndApplyPMSColor() {
        let cleanedEntry = pmsEntryText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        
        if cleanedEntry.isEmpty { return }
        
        // Search for PMS color by number or name
        let searchResults = pantoneLibrary.searchColors(query: cleanedEntry)
        
        if let foundColor = searchResults.first {
            // Convert PMS color to HSB and update sliders
            let hsbColor = HSBColorModel.fromRGB(foundColor.rgbEquivalent)
            
            // Update all slider values
            hueValue = String(Int(hsbColor.hue))
            saturationValue = String(Int(hsbColor.saturation * 100))
            brightnessValue = String(Int(hsbColor.brightness * 100))
            hueSlider = hsbColor.hue
            saturationSlider = hsbColor.saturation * 100
            brightnessSlider = hsbColor.brightness * 100
            
            // Update hex value
            updateHexFromHSB()
            
            // Clear the search field and live preview
            pmsEntryText = ""
            livePMSPreview = nil
            
            // Add to swatches
            let pmsColor = VectorColor.pantone(foundColor)
            document.addColorSwatch(pmsColor)
        }
    }
} 