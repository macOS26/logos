//
//  ColorManager.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI
import AppKit
import CoreGraphics

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
