//
//  ColorManagement.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI
import AppKit
import CoreGraphics

class ColorManagement {
    
    // MARK: - Color Conversion
    
    // Helper function to safely convert CMYK percentage values to Int
    static func safeCMYKPercentage(_ value: Double) -> Int {
        let percentage = value * 100
        return Int(percentage.isFinite ? percentage : 0)
    }
    static func rgbToCMYK(_ rgb: RGBColor) -> CMYKColor {
        let r = rgb.red
        let g = rgb.green
        let b = rgb.blue
        
        let k = 1 - max(r, max(g, b))
        
        // Handle the case where k = 1 (pure black) to avoid division by zero
        if k >= 1.0 {
            return CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1, alpha: rgb.alpha)
        }
        
        let c = (1 - r - k) / (1 - k)
        let m = (1 - g - k) / (1 - k)
        let y = (1 - b - k) / (1 - k)
        
        return CMYKColor(cyan: c, magenta: m, yellow: y, black: k, alpha: rgb.alpha)
    }
    
    static func cmykToRGB(_ cmyk: CMYKColor) -> RGBColor {
        let c = cmyk.cyan
        let m = cmyk.magenta
        let y = cmyk.yellow
        let k = cmyk.black
        
        let r = (1 - c) * (1 - k)
        let g = (1 - m) * (1 - k)
        let b = (1 - y) * (1 - k)
        
        return RGBColor(red: r, green: g, blue: b, alpha: cmyk.alpha)
    }
    
    static func rgbToHSB(_ rgb: RGBColor) -> HSBColor {
        let r = rgb.red
        let g = rgb.green
        let b = rgb.blue
        
        let max = Swift.max(r, Swift.max(g, b))
        let min = Swift.min(r, Swift.min(g, b))
        let delta = max - min
        
        var h: Double = 0
        let s: Double = max == 0 ? 0 : delta / max
        let brightness: Double = max
        
        if delta != 0 {
            if max == r {
                h = (g - b) / delta
            } else if max == g {
                h = 2 + (b - r) / delta
            } else {
                h = 4 + (r - g) / delta
            }
            h *= 60
            if h < 0 {
                h += 360
            }
        }
        
        return HSBColor(hue: h / 360, saturation: s, brightness: brightness, alpha: rgb.alpha)
    }
    
    static func hsbToRGB(_ hsb: HSBColor) -> RGBColor {
        let h = hsb.hue * 360
        let s = hsb.saturation
        let v = hsb.brightness
        
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        
        var r: Double, g: Double, b: Double
        
        switch h {
        case 0..<60:
            r = c; g = x; b = 0
        case 60..<120:
            r = x; g = c; b = 0
        case 120..<180:
            r = 0; g = c; b = x
        case 180..<240:
            r = 0; g = x; b = c
        case 240..<300:
            r = x; g = 0; b = c
        case 300..<360:
            r = c; g = 0; b = x
        default:
            r = 0; g = 0; b = 0
        }
        
        return RGBColor(red: r + m, green: g + m, blue: b + m, alpha: hsb.alpha)
    }
    
    // MARK: - Color Harmony
    static func generateColorHarmony(_ baseColor: RGBColor, harmony: ColorHarmonyType) -> [RGBColor] {
        let baseHSB = rgbToHSB(baseColor)
        var colors: [RGBColor] = [baseColor]
        
        switch harmony {
        case .monochromatic:
            for i in 1...4 {
                let brightness = max(0.1, baseHSB.brightness - Double(i) * 0.15)
                let newHSB = HSBColor(hue: baseHSB.hue, saturation: baseHSB.saturation, brightness: brightness, alpha: baseHSB.alpha)
                colors.append(hsbToRGB(newHSB))
            }
            
        case .analogous:
            for offset in [-30, -15, 15, 30] {
                var newHue = baseHSB.hue + Double(offset) / 360
                if newHue < 0 { newHue += 1 }
                if newHue > 1 { newHue -= 1 }
                let newHSB = HSBColor(hue: newHue, saturation: baseHSB.saturation, brightness: baseHSB.brightness, alpha: baseHSB.alpha)
                colors.append(hsbToRGB(newHSB))
            }
            
        case .complementary:
            var compHue = baseHSB.hue + 0.5
            if compHue > 1 { compHue -= 1 }
            let compHSB = HSBColor(hue: compHue, saturation: baseHSB.saturation, brightness: baseHSB.brightness, alpha: baseHSB.alpha)
            colors.append(hsbToRGB(compHSB))
            
        case .triadic:
            for offset in [120, 240] {
                var newHue = baseHSB.hue + Double(offset) / 360
                if newHue > 1 { newHue -= 1 }
                let newHSB = HSBColor(hue: newHue, saturation: baseHSB.saturation, brightness: baseHSB.brightness, alpha: baseHSB.alpha)
                colors.append(hsbToRGB(newHSB))
            }
            
        case .tetradic:
            for offset in [90, 180, 270] {
                var newHue = baseHSB.hue + Double(offset) / 360
                if newHue > 1 { newHue -= 1 }
                let newHSB = HSBColor(hue: newHue, saturation: baseHSB.saturation, brightness: baseHSB.brightness, alpha: baseHSB.alpha)
                colors.append(hsbToRGB(newHSB))
            }
            
        case .splitComplementary:
            for offset in [150, 210] {
                var newHue = baseHSB.hue + Double(offset) / 360
                if newHue > 1 { newHue -= 1 }
                let newHSB = HSBColor(hue: newHue, saturation: baseHSB.saturation, brightness: baseHSB.brightness, alpha: baseHSB.alpha)
                colors.append(hsbToRGB(newHSB))
            }
        }
        
        return colors
    }
    
    // MARK: - Pantone Colors
    static func loadPantoneColors() -> [PantoneLibraryColor] {
        // Use the shared PantoneLibrary instance
        let pantoneLibrary = PantoneLibrary()
        return pantoneLibrary.allColors
    }
    
    // MARK: - Color Accessibility
    static func calculateContrastRatio(_ color1: RGBColor, _ color2: RGBColor) -> Double {
        let luminance1 = calculateLuminance(color1)
        let luminance2 = calculateLuminance(color2)
        
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    static func calculateLuminance(_ color: RGBColor) -> Double {
        let r = color.red <= 0.03928 ? color.red / 12.92 : pow((color.red + 0.055) / 1.055, 2.4)
        let g = color.green <= 0.03928 ? color.green / 12.92 : pow((color.green + 0.055) / 1.055, 2.4)
        let b = color.blue <= 0.03928 ? color.blue / 12.92 : pow((color.blue + 0.055) / 1.055, 2.4)
        
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }
    
    static func isAccessible(_ foreground: RGBColor, _ background: RGBColor, level: AccessibilityLevel = .aa) -> Bool {
        let contrast = calculateContrastRatio(foreground, background)
        
        switch level {
        case .aa:
            return contrast >= 4.5
        case .aaa:
            return contrast >= 7.0
        case .aaLarge:
            return contrast >= 3.0
        case .aaaLarge:
            return contrast >= 4.5
        }
    }
    
    // MARK: - Color Mixing
    static func mixColors(_ color1: RGBColor, _ color2: RGBColor, ratio: Double) -> RGBColor {
        let clampedRatio = max(0, min(1, ratio))
        
        return RGBColor(
            red: color1.red * (1 - clampedRatio) + color2.red * clampedRatio,
            green: color1.green * (1 - clampedRatio) + color2.green * clampedRatio,
            blue: color1.blue * (1 - clampedRatio) + color2.blue * clampedRatio,
            alpha: color1.alpha * (1 - clampedRatio) + color2.alpha * clampedRatio
        )
    }
    
    // MARK: - Color Temperature
    static func adjustColorTemperature(_ color: RGBColor, temperature: Double) -> RGBColor {
        // Temperature adjustment (-1.0 to 1.0, where -1 is cooler, 1 is warmer)
        let temp = max(-1.0, min(1.0, temperature))
        
        var red = color.red
        var blue = color.blue
        
        if temp > 0 {
            // Warmer - increase red, decrease blue
            red = min(1.0, red + temp * 0.2)
            blue = max(0.0, blue - temp * 0.2)
        } else {
            // Cooler - decrease red, increase blue
            red = max(0.0, red + temp * 0.2)
            blue = min(1.0, blue - temp * 0.2)
        }
        
        return RGBColor(red: red, green: color.green, blue: blue, alpha: color.alpha)
    }
    
    // MARK: - Color Blindness Simulation
    static func simulateColorBlindness(_ color: RGBColor, type: ColorBlindnessType) -> RGBColor {
        let r = color.red
        let g = color.green
        let b = color.blue
        
        switch type {
        case .protanopia:
            // Red-blind
            return RGBColor(red: 0.567 * r + 0.433 * g, green: 0.558 * r + 0.442 * g, blue: 0.242 * g + 0.758 * b, alpha: color.alpha)
        case .deuteranopia:
            // Green-blind
            return RGBColor(red: 0.625 * r + 0.375 * g, green: 0.7 * r + 0.3 * g, blue: 0.3 * g + 0.7 * b, alpha: color.alpha)
        case .tritanopia:
            // Blue-blind
            return RGBColor(red: 0.95 * r + 0.05 * g, green: 0.433 * g + 0.567 * b, blue: 0.475 * g + 0.525 * b, alpha: color.alpha)
        }
    }
}

// MARK: - Centralized Working Color Space and Conversions
final class ColorManager {
	static let shared = ColorManager()
	
	/// Preferred working color space for the entire app. Display P3 offers a significantly wider gamut than sRGB.
	/// We keep this configurable in case we decide to experiment with other wide-gamut spaces in the future.
	enum WorkingSpace {
		case displayP3
		case sRGB
		case linearSRGB
		case extendedSRGB
	}
	
	/// Configure the global working space here. Default: Display P3
	private(set) var workingSpace: WorkingSpace = .displayP3
	
	/// CoreGraphics color space for the current working space
	var workingCGColorSpace: CGColorSpace {
		switch workingSpace {
		case .displayP3: return CGColorSpace(name: CGColorSpace.displayP3)!
		case .sRGB: return CGColorSpace(name: CGColorSpace.sRGB)!
		case .linearSRGB: return CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!
		case .extendedSRGB: return CGColorSpace(name: CGColorSpace.extendedSRGB)!
		}
	}
	
	/// SwiftUI color space for constructing Colors in the working space
	var workingSwiftUIColorSpace: Color.RGBColorSpace {
		switch workingSpace {
		case .displayP3: return .displayP3
		case .sRGB: return .sRGB
		case .linearSRGB: return .sRGBLinear
		case .extendedSRGB: return .sRGB // SwiftUI doesn't expose an explicit extended sRGB; use sRGB path and allow CGColor for extended
		}
	}
	
	/// Optionally change working space at runtime (not recommended without full migration)
	func setWorkingSpace(_ space: WorkingSpace) {
		workingSpace = space
	}
	
	// MARK: - Core Conversions
	/// Convert a CGColor to the working color space (relative colorimetric intent)
	func toWorking(_ cgColor: CGColor) -> CGColor {
		if cgColor.colorSpace == workingCGColorSpace { return cgColor }
		return cgColor.converted(to: workingCGColorSpace, intent: .relativeColorimetric, options: nil) ?? cgColor
	}
	
	/// Convert a CGColor to a target color space
	func convert(_ cgColor: CGColor, to target: CGColorSpace) -> CGColor {
		if cgColor.colorSpace == target { return cgColor }
		return cgColor.converted(to: target, intent: .relativeColorimetric, options: nil) ?? cgColor
	}
	
	/// Safely extract RGBA in working space from a SwiftUI Color
	func rgbaInWorkingSpace(from color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
		let ns = NSColor(color)
		let targetNSColorSpace = NSColorSpace(cgColorSpace: workingCGColorSpace) ?? NSColorSpace.deviceRGB
		let converted = ns.usingColorSpace(targetNSColorSpace) ?? ns
		var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
		converted.getRed(&r, green: &g, blue: &b, alpha: &a)
		return (Double(r), Double(g), Double(b), Double(a))
	}
	
	/// Create a SwiftUI Color in the working space from raw RGBA assumed in the given source space
	func makeColor(r: Double, g: Double, b: Double, a: Double = 1.0, source: CGColorSpace) -> Color {
		let components: [CGFloat] = [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)]
		guard let srcColor = CGColor(colorSpace: source, components: components) else {
			return Color(workingSwiftUIColorSpace, red: r, green: g, blue: b, opacity: a)
		}
		let working = toWorking(srcColor)
		return Color(working)
	}
	
	/// Convert normalized RGBA from source color space into RGBA in working color space
	func convertRGBAtoWorking(r: Double, g: Double, b: Double, a: Double = 1.0, source: CGColorSpace) -> (r: Double, g: Double, b: Double, a: Double) {
		let comps: [CGFloat] = [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)]
		guard let src = CGColor(colorSpace: source, components: comps) else {
			return (r, g, b, a)
		}
		let wk = toWorking(src)
		guard let out = wk.components, wk.numberOfComponents >= 4 else { return (r, g, b, a) }
		return (Double(out[0]), Double(out[1]), Double(out[2]), Double(out[3]))
	}
	
	// MARK: - Convenience for common spaces
	var sRGBCG: CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }
	var linearSRGBCG: CGColorSpace { CGColorSpace(name: CGColorSpace.extendedLinearSRGB)! }
	var extendedSRGBCG: CGColorSpace { CGColorSpace(name: CGColorSpace.extendedSRGB)! }
	var displayP3CG: CGColorSpace { CGColorSpace(name: CGColorSpace.displayP3)! }
	
	// MARK: - SVG Helpers
	/// Convert a CGColor in any space to 8-bit sRGB hex string for SVG output
	func cgColorToSRGBHex(_ cgColor: CGColor) -> String {
		let srgb = convert(cgColor, to: sRGBCG)
		guard let comps = srgb.components else { return "#000000" }
		let r = Int(round(Double(comps[0]) * 255.0))
		let g = Int(round(Double(comps[1]) * 255.0))
		let b = Int(round(Double(comps[2]) * 255.0))
		return String(format: "#%02X%02X%02X", r, g, b)
	}
}

// MARK: - Supporting Types
struct HSBColor: Codable, Hashable {
    var hue: Double        // 0-1
    var saturation: Double // 0-1
    var brightness: Double // 0-1
    var alpha: Double      // 0-1
    
    init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1.0) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.alpha = alpha
    }
}

enum ColorHarmonyType: String, CaseIterable {
    case monochromatic = "Monochromatic"
    case analogous = "Analogous"
    case complementary = "Complementary"
    case triadic = "Triadic"
    case tetradic = "Tetradic"
    case splitComplementary = "Split Complementary"
}

enum AccessibilityLevel: String, CaseIterable {
    case aa = "AA"
    case aaa = "AAA"
    case aaLarge = "AA Large"
    case aaaLarge = "AAA Large"
}

enum ColorBlindnessType: String, CaseIterable {
    case protanopia = "Protanopia"
    case deuteranopia = "Deuteranopia"
    case tritanopia = "Tritanopia"
}

// MARK: - Color Palette Management
class ColorPalette: ObservableObject, Codable {
    @Published var name: String
    @Published var colors: [VectorColor]
    @Published var isLocked: Bool
    
    init(name: String, colors: [VectorColor] = [], isLocked: Bool = false) {
        self.name = name
        self.colors = colors
        self.isLocked = isLocked
    }
    
    enum CodingKeys: CodingKey {
        case name, colors, isLocked
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        colors = try container.decode([VectorColor].self, forKey: .colors)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(colors, forKey: .colors)
        try container.encode(isLocked, forKey: .isLocked)
    }
    
    func addColor(_ color: VectorColor) {
        guard !isLocked else { return }
        if !colors.contains(color) {
            colors.append(color)
        }
    }
    
    func removeColor(_ color: VectorColor) {
        guard !isLocked else { return }
        colors.removeAll { $0 == color }
    }
    
    static let defaultPalettes: [ColorPalette] = [
        ColorPalette(name: "Basic", colors: VectorColor.basicColors),
        ColorPalette(name: "Pantone", colors: ColorManagement.loadPantoneColors().map { .pantone($0) }),
        ColorPalette(name: "Web Safe", colors: createWebSafePalette()),
        ColorPalette(name: "Material Design", colors: createMaterialDesignPalette())
    ]
    
    private static func createWebSafePalette() -> [VectorColor] {
        // Web-safe colors (216 colors)
        var colors: [VectorColor] = []
        for r in stride(from: 0, to: 256, by: 51) {
            for g in stride(from: 0, to: 256, by: 51) {
                for b in stride(from: 0, to: 256, by: 51) {
                    let color = RGBColor(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
                    colors.append(.rgb(color))
                }
            }
        }
        return colors
    }
    
    private static func createMaterialDesignPalette() -> [VectorColor] {
        // Material Design color palette
        return [
            .rgb(RGBColor(red: 0.96, green: 0.26, blue: 0.21)), // Red 500
            .rgb(RGBColor(red: 0.91, green: 0.12, blue: 0.39)), // Pink 500
            .rgb(RGBColor(red: 0.61, green: 0.15, blue: 0.69)), // Purple 500
            .rgb(RGBColor(red: 0.40, green: 0.23, blue: 0.72)), // Deep Purple 500
            .rgb(RGBColor(red: 0.25, green: 0.32, blue: 0.71)), // Indigo 500
            .rgb(RGBColor(red: 0.13, green: 0.59, blue: 0.95)), // Blue 500
            .rgb(RGBColor(red: 0.01, green: 0.66, blue: 0.96)), // Light Blue 500
            .rgb(RGBColor(red: 0.0, green: 0.74, blue: 0.83)),  // Cyan 500
            .rgb(RGBColor(red: 0.0, green: 0.59, blue: 0.53)),  // Teal 500
            .rgb(RGBColor(red: 0.30, green: 0.69, blue: 0.31)), // Green 500
            .rgb(RGBColor(red: 0.55, green: 0.76, blue: 0.29)), // Light Green 500
            .rgb(RGBColor(red: 0.80, green: 0.86, blue: 0.22)), // Lime 500
            .rgb(RGBColor(red: 1.0, green: 0.92, blue: 0.23)),  // Yellow 500
            .rgb(RGBColor(red: 1.0, green: 0.76, blue: 0.03)),  // Amber 500
            .rgb(RGBColor(red: 1.0, green: 0.60, blue: 0.0)),   // Orange 500
            .rgb(RGBColor(red: 1.0, green: 0.34, blue: 0.13))   // Deep Orange 500
        ]
    }
}