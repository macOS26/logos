//
//  ColorDefaults.swift
//  logos inkpen.io
//
//  Created by Claude on 9/22/25.
//

import SwiftUI

// MARK: - Color Defaults Structure
struct ColorDefaults: Codable {
    var fillColor: VectorColor
    var strokeColor: VectorColor
    var fillOpacity: Double
    var strokeOpacity: Double
    var strokeWidth: Double
    var rgbSwatches: [VectorColor]
    var cmykSwatches: [VectorColor]
    var hsbSwatches: [VectorColor]

    // MARK: - Initialization
    init() {
        // Use ColorManager's centralized defaults
        self.fillColor = ColorManager.defaultBlue
        self.strokeColor = ColorManager.defaultRed
        self.fillOpacity = 1.0
        self.strokeOpacity = 1.0
        self.strokeWidth = 1.0

        // Create 40-color palettes
        self.rgbSwatches = Self.createDefaultRGBSwatches()
        self.cmykSwatches = Self.createDefaultCMYKSwatches()
        self.hsbSwatches = Self.createDefaultHSBSwatches()

        // Load any saved preferences
        loadFromUserDefaults()
    }

    // MARK: - UserDefaults Management
    private static let userDefaultsKey = "logosinkpen-colorsv2"

    mutating func loadFromUserDefaults() {
        guard let data = UserDefaults.standard.data(forKey: Self.userDefaultsKey),
              let dict = try? JSONDecoder().decode([String: Data].self, from: data) else {
            return
        }

        // Load color settings
        if let fillData = dict["fill"],
           let color = try? JSONDecoder().decode(VectorColor.self, from: fillData) {
            // Only load if it's not black (prevent old black default from overriding blue)
            if color != .black {
                fillColor = color
            }
        }

        if let strokeData = dict["stroke"],
           let color = try? JSONDecoder().decode(VectorColor.self, from: strokeData) {
            strokeColor = color
        }

        if let fillOpData = dict["fillOp"],
           let value = try? JSONDecoder().decode(Double.self, from: fillOpData) {
            fillOpacity = value
        }

        if let strokeOpData = dict["strokeOp"],
           let value = try? JSONDecoder().decode(Double.self, from: strokeOpData) {
            strokeOpacity = value
        }

        if let strokeWData = dict["strokeW"],
           let value = try? JSONDecoder().decode(Double.self, from: strokeWData) {
            strokeWidth = value
        }

        // Load swatches
        if let rgbData = dict["rgb"],
           let swatches = try? JSONDecoder().decode([VectorColor].self, from: rgbData) {
            rgbSwatches = swatches.count == 40 ? swatches : Self.createDefaultRGBSwatches()
        }

        if let cmykData = dict["cmyk"],
           let swatches = try? JSONDecoder().decode([VectorColor].self, from: cmykData) {
            cmykSwatches = swatches.count == 40 ? swatches : Self.createDefaultCMYKSwatches()
        }

        if let hsbData = dict["hsb"],
           let swatches = try? JSONDecoder().decode([VectorColor].self, from: hsbData) {
            hsbSwatches = swatches.count == 40 ? swatches : Self.createDefaultHSBSwatches()
        }
    }

    func saveToUserDefaults() {
        var dict: [String: Data] = [:]

        // Save color settings with short keys (but never save black as fill color)
        if fillColor != .black, let data = try? JSONEncoder().encode(fillColor) {
            dict["fill"] = data
        }
        if let data = try? JSONEncoder().encode(strokeColor) {
            dict["stroke"] = data
        }
        if let data = try? JSONEncoder().encode(fillOpacity) {
            dict["fillOp"] = data
        }
        if let data = try? JSONEncoder().encode(strokeOpacity) {
            dict["strokeOp"] = data
        }
        if let data = try? JSONEncoder().encode(strokeWidth) {
            dict["strokeW"] = data
        }

        // Save swatches
        if let data = try? JSONEncoder().encode(rgbSwatches) {
            dict["rgb"] = data
        }
        if let data = try? JSONEncoder().encode(cmykSwatches) {
            dict["cmyk"] = data
        }
        if let data = try? JSONEncoder().encode(hsbSwatches) {
            dict["hsb"] = data
        }

        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }

    // MARK: - Default Palette Creation (40 colors each)
    static func createDefaultRGBSwatches() -> [VectorColor] {
        var colors: [VectorColor] = []

        // Core colors (4) - Always first
        colors.append(.black)
        colors.append(.white)
        colors.append(.clear)
        colors.append(ColorManager.defaultBlue) // 4th color - Display P3 Blue

        // Sorted by hue (36 colors)
        // Reds (Hue 0°)
        colors.append(ColorManager.defaultRed) // Red
        colors.append(.rgb(RGBColor(red: 0.5, green: 0, blue: 0))) // Maroon
        colors.append(.rgb(RGBColor(red: 1, green: 0.8, blue: 0.8))) // Light Pink

        // Red-Oranges (Hue 15-30°)
        colors.append(.rgb(RGBColor(red: 1, green: 0.5, blue: 0))) // Orange
        colors.append(.rgb(RGBColor(red: 0.8, green: 0.5, blue: 0.2))) // Gold
        colors.append(.rgb(RGBColor(red: 1, green: 0.75, blue: 0.5))) // Peach

        // Browns/Tans (Hue 30-45°)
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.25, blue: 0))) // Brown
        colors.append(.rgb(RGBColor(red: 0.3, green: 0.2, blue: 0.1))) // Dark Brown
        colors.append(.rgb(RGBColor(red: 0.6, green: 0.4, blue: 0.2))) // Tan
        colors.append(.rgb(RGBColor(red: 1, green: 0.9, blue: 0.7))) // Cream

        // Yellows (Hue 60°)
        colors.append(.rgb(RGBColor(red: 1, green: 1, blue: 0))) // Yellow
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.5, blue: 0))) // Olive
        colors.append(.rgb(RGBColor(red: 1, green: 1, blue: 0.8))) // Light Yellow

        // Yellow-Greens (Hue 90°)
        colors.append(.rgb(RGBColor(red: 0.9, green: 1, blue: 0.7))) // Light Lime
        colors.append(.rgb(RGBColor(red: 0.6, green: 0.8, blue: 0.4))) // Lime Green

        // Greens (Hue 120°)
        colors.append(.rgb(RGBColor(red: 0, green: 1, blue: 0))) // Green
        colors.append(.rgb(RGBColor(red: 0, green: 0.5, blue: 0))) // Dark Green
        colors.append(.rgb(RGBColor(red: 0.5, green: 1, blue: 0.5))) // Light Green
        colors.append(.rgb(RGBColor(red: 0.8, green: 1, blue: 0.8))) // Light Mint

        // Cyan-Greens (Hue 150-180°)
        colors.append(.rgb(RGBColor(red: 0, green: 0.5, blue: 0.5))) // Teal
        colors.append(.rgb(RGBColor(red: 0.7, green: 1, blue: 0.9))) // Mint
        colors.append(.rgb(RGBColor(red: 0, green: 1, blue: 1))) // Cyan

        // Blues (Hue 210-240°)
        colors.append(.rgb(RGBColor(red: 0.7, green: 0.9, blue: 1))) // Sky Blue
        colors.append(.rgb(RGBColor(red: 0.4, green: 0.6, blue: 0.8))) // Steel Blue
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.5, blue: 1))) // Light Blue
        colors.append(.rgb(RGBColor(red: 0.8, green: 0.8, blue: 1))) // Lavender
        colors.append(.rgb(RGBColor(red: 0, green: 0, blue: 0.5))) // Navy

        // Purples (Hue 270°)
        colors.append(.rgb(RGBColor(red: 0.5, green: 0, blue: 1))) // Purple
        colors.append(.rgb(RGBColor(red: 0.5, green: 0, blue: 0.5))) // Dark Purple
        colors.append(.rgb(RGBColor(red: 0.9, green: 0.7, blue: 1))) // Light Purple

        // Magentas/Pinks (Hue 300-330°)
        colors.append(.rgb(RGBColor(red: 1, green: 0.5, blue: 1))) // Magenta
        colors.append(.rgb(RGBColor(red: 1, green: 0.7, blue: 0.9))) // Pink
        colors.append(.rgb(RGBColor(red: 1, green: 0, blue: 0.5))) // Rose

        // Grays (No hue)
        colors.append(.rgb(RGBColor(red: 0.25, green: 0.25, blue: 0.25))) // Dark Gray
        colors.append(.rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5))) // Gray
        colors.append(.rgb(RGBColor(red: 0.75, green: 0.75, blue: 0.75))) // Light Gray

        return Array(colors.prefix(40)) // Ensure exactly 40
    }

    static func createDefaultCMYKSwatches() -> [VectorColor] {
        var colors: [VectorColor] = []

        // Core colors (4)
        colors.append(.black)
        colors.append(.white)
        colors.append(.clear)
        colors.append(ColorManager.defaultBlue) // 4th color - Display P3 Blue

        // CMYK primaries and combinations (36 more)
        for c in stride(from: 0, through: 1, by: 0.25) {
            for m in stride(from: 0, through: 1, by: 0.5) {
                for y in stride(from: 0, through: 1, by: 0.5) {
                    if colors.count < 40 {
                        colors.append(.cmyk(CMYKColor(cyan: c, magenta: m, yellow: y, black: 0)))
                    }
                }
            }
        }

        // Add some with black component
        for k in stride(from: 0.2, through: 0.8, by: 0.2) {
            if colors.count < 40 {
                colors.append(.cmyk(CMYKColor(cyan: 0.5, magenta: 0.5, yellow: 0, black: k)))
            }
        }

        return Array(colors.prefix(40)) // Ensure exactly 40
    }

    static func createDefaultHSBSwatches() -> [VectorColor] {
        var colors: [VectorColor] = []

        // Core colors (4)
        colors.append(.black)
        colors.append(.white)
        colors.append(.clear)
        colors.append(ColorManager.defaultBlue) // 4th color - Display P3 Blue

        // HSB spectrum (36 more)
        // Full saturation, full brightness rainbow (12)
        for hue in stride(from: 0, to: 360, by: 30.0) {
            if colors.count < 40 {
                colors.append(.hsb(HSBColorModel(hue: hue, saturation: 1, brightness: 1)))
            }
        }

        // Half saturation variations (12)
        for hue in stride(from: 0, to: 360, by: 30.0) {
            if colors.count < 40 {
                colors.append(.hsb(HSBColorModel(hue: hue, saturation: 0.5, brightness: 1)))
            }
        }

        // Darker variations (12)
        for hue in stride(from: 0, to: 360, by: 30.0) {
            if colors.count < 40 {
                colors.append(.hsb(HSBColorModel(hue: hue, saturation: 1, brightness: 0.5)))
            }
        }

        return Array(colors.prefix(40)) // Ensure exactly 40
    }
}
