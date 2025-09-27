//
//  ColorManager.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI
import Combine

// MARK: - Centralized Working Color Space and Conversions
final class ColorManager {
	static let shared = ColorManager()

	// MARK: - Default Colors
	/// Standard Display P3 blue used as default fill color throughout the app
	static let defaultBlue = VectorColor.rgb(RGBColor(red: 0.0, green: 0.478, blue: 1.0, colorSpace: .displayP3))

	/// Standard red used as default stroke color
	static let defaultRed = VectorColor.rgb(RGBColor(red: 1, green: 0, blue: 0))

	// MARK: - Color Defaults Storage
	private(set) var colorDefaults: ColorDefaults

	private init() {
		colorDefaults = ColorDefaults()
	}

	/// Update color defaults
	func updateColorDefaults(_ newDefaults: ColorDefaults) {
		colorDefaults = newDefaults
		colorDefaults.saveToUserDefaults()
	}

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
		// Create a guaranteed fallback color space
		let fallback = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

		switch workingSpace {
		case .displayP3:
			return CGColorSpace(name: CGColorSpace.displayP3) ?? fallback
		case .sRGB:
			return CGColorSpace(name: CGColorSpace.sRGB) ?? fallback
		case .linearSRGB:
			return CGColorSpace(name: CGColorSpace.extendedLinearSRGB) ?? fallback
		case .extendedSRGB:
			return CGColorSpace(name: CGColorSpace.extendedSRGB) ?? fallback
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
	/// Create a SwiftUI Color in the working space from raw RGBA assumed in the given source space
	func makeColor(r: Double, g: Double, b: Double, a: Double = 1.0, source: CGColorSpace) -> Color {
		let components: [CGFloat] = [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)]
		guard let srcColor = CGColor(colorSpace: source, components: components) else {
			return Color(workingSwiftUIColorSpace, red: r, green: g, blue: b, opacity: a)
		}
		let working = toWorking(srcColor)
		return Color(working)
	}
	// MARK: - Convenience for common spaces
	var sRGBCG: CGColorSpace {
		CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
	}
	var displayP3CG: CGColorSpace {
		CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
 }
	
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
