//
//  ColorModels.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI

// MARK: - Color Modes
enum ColorMode: String, CaseIterable, Codable {
    case rgb = "RGB"
    case cmyk = "CMYK"
    case pantone = "Pantone"
    
    var iconName: String {
        switch self {
        case .rgb: return "display"
        case .cmyk: return "printer"
        case .pantone: return "paintbrush"
        }
    }
}

// MARK: - Active Color Target
enum ColorTarget: String, CaseIterable, Codable {
    case fill = "Fill"
    case stroke = "Stroke"
}

// MARK: - Color Definitions
struct RGBColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double
    
    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    var color: Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
    
    var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

struct CMYKColor: Codable, Hashable {
    var cyan: Double
    var magenta: Double
    var yellow: Double
    var black: Double
    var alpha: Double
    
    init(cyan: Double, magenta: Double, yellow: Double, black: Double, alpha: Double = 1.0) {
        self.cyan = cyan
        self.magenta = magenta
        self.yellow = yellow
        self.black = black
        self.alpha = alpha
    }
    
    var rgbColor: RGBColor {
        // Convert CMYK to RGB
        let r = (1.0 - cyan) * (1.0 - black)
        let g = (1.0 - magenta) * (1.0 - black)
        let b = (1.0 - yellow) * (1.0 - black)
        return RGBColor(red: r, green: g, blue: b, alpha: alpha)
    }
    
    var color: Color {
        rgbColor.color
    }
}

struct PantoneColor: Codable, Hashable {
    var name: String
    var number: String
    var rgbEquivalent: RGBColor
    var cmykEquivalent: CMYKColor
    var alpha: Double
    
    init(name: String, number: String, rgbEquivalent: RGBColor, cmykEquivalent: CMYKColor, alpha: Double = 1.0) {
        self.name = name
        self.number = number
        self.rgbEquivalent = rgbEquivalent
        self.cmykEquivalent = cmykEquivalent
        self.alpha = alpha
    }
    
    var color: Color {
        Color(.sRGB, red: rgbEquivalent.red, green: rgbEquivalent.green, blue: rgbEquivalent.blue, opacity: alpha)
    }
}

// MARK: - Vector Color
enum VectorColor: Codable, Hashable {
    case rgb(RGBColor)
    case cmyk(CMYKColor)
    case pantone(PantoneColor)
    case appleSystem(AppleSystemColor)
    case clear
    case black
    case white
    
    var color: Color {
        switch self {
        case .rgb(let rgb):
            return rgb.color
        case .cmyk(let cmyk):
            return cmyk.color
        case .pantone(let pantone):
            return pantone.color
        case .appleSystem(let systemColor):
            return systemColor.color
        case .clear:
            return Color.clear
        case .black:
            return Color.black
        case .white:
            return Color.white
        }
    }
    
    var cgColor: CGColor {
        switch self {
        case .rgb(let rgb):
            return rgb.cgColor
        case .cmyk(let cmyk):
            return cmyk.rgbColor.cgColor
        case .pantone(let pantone):
            return pantone.rgbEquivalent.cgColor
        case .appleSystem(let systemColor):
            return systemColor.rgbEquivalent.cgColor
        case .clear:
            return CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .black:
            return CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .white:
            return CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    }
    
    // Basic colors available in all modes
    static let basicColors: [VectorColor] = [
        .black, .white, .clear
    ]
}

// MARK: - Blend Modes
enum BlendMode: String, CaseIterable, Codable {
    case normal = "Normal"
    case multiply = "Multiply"
    case screen = "Screen"
    case overlay = "Overlay"
    case softLight = "Soft Light"
    case hardLight = "Hard Light"
    case colorDodge = "Color Dodge"
    case colorBurn = "Color Burn"
    case darken = "Darken"
    case lighten = "Lighten"
    case difference = "Difference"
    case exclusion = "Exclusion"
    case hue = "Hue"
    case saturation = "Saturation"
    case color = "Color"
    case luminosity = "Luminosity"
    
    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .darken: return .darken
        case .lighten: return .lighten
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }
}

// MARK: - Apple System Colors
struct AppleSystemColor: Codable, Hashable {
    var name: String
    var lightMode: RGBColor
    var darkMode: RGBColor
    
    init(name: String, lightMode: RGBColor, darkMode: RGBColor) {
        self.name = name
        self.lightMode = lightMode
        self.darkMode = darkMode
    }
    
    var color: Color {
        // Use the system color directly which adapts to light/dark mode
        switch name {
        case "systemBlue": return Color(.systemBlue)
        case "systemRed": return Color(.systemRed)
        case "systemGreen": return Color(.systemGreen)
        case "systemYellow": return Color(.systemYellow)
        case "systemOrange": return Color(.systemOrange)
        case "systemPurple": return Color(.systemPurple)
        case "systemPink": return Color(.systemPink)
        case "systemTeal": return Color(.systemTeal)
        case "systemIndigo": return Color(.systemIndigo)
        case "systemBrown": return Color(.systemBrown)
        case "systemGray": return Color(.systemGray)
        case "systemGray2": return lightMode.color
        case "systemGray3": return lightMode.color
        case "systemGray4": return lightMode.color
        case "systemGray5": return lightMode.color
        case "systemGray6": return lightMode.color
        case "label": return Color(.labelColor)
        case "secondaryLabel": return Color(.secondaryLabelColor)
        case "tertiaryLabel": return Color(.tertiaryLabelColor)
        case "quaternaryLabel": return Color(.quaternaryLabelColor)
        case "link": return Color(.linkColor)
        case "placeholderText": return Color(.placeholderTextColor)
        case "separator": return Color(.separatorColor)
        case "opaqueSeparator": return Color(.separatorColor)
        case "systemBackground": return Color(.windowBackgroundColor)
        case "secondarySystemBackground": return Color(.controlBackgroundColor)
        case "tertiarySystemBackground": return Color(.controlBackgroundColor)
        case "systemGroupedBackground": return Color(.windowBackgroundColor)
        case "secondarySystemGroupedBackground": return Color(.controlBackgroundColor)
        case "tertiarySystemGroupedBackground": return Color(.controlBackgroundColor)
        case "systemFill": return Color(.controlBackgroundColor)
        case "secondarySystemFill": return Color(.controlBackgroundColor)
        case "tertiarySystemFill": return Color(.controlBackgroundColor)
        case "quaternarySystemFill": return Color(.controlBackgroundColor)
        default: return lightMode.color
        }
    }
    
    var rgbEquivalent: RGBColor {
        // Return light mode RGB for conversion purposes
        return lightMode
    }
    
    // Predefined Apple System Colors with light/dark mode RGB values
    static let systemBlue = AppleSystemColor(
        name: "systemBlue",
        lightMode: RGBColor(red: 0.0, green: 0.478, blue: 1.0), // #007AFF
        darkMode: RGBColor(red: 0.04, green: 0.518, blue: 1.0)  // #0A84FF
    )
    
    static let systemRed = AppleSystemColor(
        name: "systemRed",
        lightMode: RGBColor(red: 1.0, green: 0.231, blue: 0.188), // #FF3B30
        darkMode: RGBColor(red: 1.0, green: 0.271, blue: 0.227)   // #FF453A
    )
    
    static let systemGreen = AppleSystemColor(
        name: "systemGreen",
        lightMode: RGBColor(red: 0.204, green: 0.780, blue: 0.349), // #34C759
        darkMode: RGBColor(red: 0.188, green: 0.820, blue: 0.345)   // #30D158
    )
    
    static let systemYellow = AppleSystemColor(
        name: "systemYellow",
        lightMode: RGBColor(red: 1.0, green: 0.800, blue: 0.0), // #FFCC00
        darkMode: RGBColor(red: 1.0, green: 0.839, blue: 0.039) // #FFD60A
    )
    
    static let systemOrange = AppleSystemColor(
        name: "systemOrange",
        lightMode: RGBColor(red: 1.0, green: 0.584, blue: 0.0), // #FF9500
        darkMode: RGBColor(red: 1.0, green: 0.624, blue: 0.039) // #FF9F0A
    )
    
    static let systemPurple = AppleSystemColor(
        name: "systemPurple",
        lightMode: RGBColor(red: 0.686, green: 0.322, blue: 0.871), // #AF52DE
        darkMode: RGBColor(red: 0.749, green: 0.352, blue: 0.949)   // #BF5AF2
    )
    
    static let systemPink = AppleSystemColor(
        name: "systemPink",
        lightMode: RGBColor(red: 1.0, green: 0.176, blue: 0.333), // #FF2D55
        darkMode: RGBColor(red: 1.0, green: 0.216, blue: 0.373)   // #FF375F
    )
    
    static let systemTeal = AppleSystemColor(
        name: "systemTeal",
        lightMode: RGBColor(red: 0.353, green: 0.784, blue: 0.980), // #5AC8FA
        darkMode: RGBColor(red: 0.251, green: 0.878, blue: 1.0)     // #40E0FF
    )
    
    static let systemIndigo = AppleSystemColor(
        name: "systemIndigo",
        lightMode: RGBColor(red: 0.345, green: 0.337, blue: 0.839), // #5856D6
        darkMode: RGBColor(red: 0.365, green: 0.365, blue: 0.949)   // #5D5DFF
    )
    
    static let systemBrown = AppleSystemColor(
        name: "systemBrown",
        lightMode: RGBColor(red: 0.635, green: 0.518, blue: 0.368), // #A2845E
        darkMode: RGBColor(red: 0.675, green: 0.557, blue: 0.407)   // #AC8E68
    )
    
    static let systemGray = AppleSystemColor(
        name: "systemGray",
        lightMode: RGBColor(red: 0.557, green: 0.557, blue: 0.576), // #8E8E93
        darkMode: RGBColor(red: 0.557, green: 0.557, blue: 0.576)   // #8E8E93
    )
    
    static let systemGray2 = AppleSystemColor(
        name: "systemGray2",
        lightMode: RGBColor(red: 0.682, green: 0.682, blue: 0.698), // #AEAEB2
        darkMode: RGBColor(red: 0.388, green: 0.388, blue: 0.400)   // #636366
    )
    
    static let systemGray3 = AppleSystemColor(
        name: "systemGray3",
        lightMode: RGBColor(red: 0.780, green: 0.780, blue: 0.800), // #C7C7CC
        darkMode: RGBColor(red: 0.282, green: 0.282, blue: 0.290)   // #48484A
    )
    
    static let systemGray4 = AppleSystemColor(
        name: "systemGray4",
        lightMode: RGBColor(red: 0.820, green: 0.820, blue: 0.839), // #D1D1D6
        darkMode: RGBColor(red: 0.227, green: 0.227, blue: 0.235)   // #3A3A3C
    )
    
    static let systemGray5 = AppleSystemColor(
        name: "systemGray5",
        lightMode: RGBColor(red: 0.898, green: 0.898, blue: 0.918), // #E5E5EA
        darkMode: RGBColor(red: 0.173, green: 0.173, blue: 0.180)   // #2C2C2E
    )
    
    static let systemGray6 = AppleSystemColor(
        name: "systemGray6",
        lightMode: RGBColor(red: 0.949, green: 0.949, blue: 0.969), // #F2F2F7
        darkMode: RGBColor(red: 0.110, green: 0.110, blue: 0.118)   // #1C1C1E
    )
    
    static let label = AppleSystemColor(
        name: "label",
        lightMode: RGBColor(red: 0.0, green: 0.0, blue: 0.0), // #000000
        darkMode: RGBColor(red: 1.0, green: 1.0, blue: 1.0)   // #FFFFFF
    )
    
    static let secondaryLabel = AppleSystemColor(
        name: "secondaryLabel",
        lightMode: RGBColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.6), // #3C3C43 60%
        darkMode: RGBColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.6)   // #EBEBF5 60%
    )
    
    static let tertiaryLabel = AppleSystemColor(
        name: "tertiaryLabel",
        lightMode: RGBColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.3), // #3C3C43 30%
        darkMode: RGBColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.3)   // #EBEBF5 30%
    )
    
    static let quaternaryLabel = AppleSystemColor(
        name: "quaternaryLabel",
        lightMode: RGBColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.18), // #3C3C43 18%
        darkMode: RGBColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.16)   // #EBEBF5 16%
    )
    
    static let link = AppleSystemColor(
        name: "link",
        lightMode: RGBColor(red: 0.0, green: 0.478, blue: 1.0), // #007AFF
        darkMode: RGBColor(red: 0.04, green: 0.518, blue: 1.0)  // #0A84FF
    )
    
    static let placeholderText = AppleSystemColor(
        name: "placeholderText",
        lightMode: RGBColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.3), // #3C3C43 30%
        darkMode: RGBColor(red: 0.922, green: 0.922, blue: 0.961, alpha: 0.3)   // #EBEBF5 30%
    )
    
    static let separator = AppleSystemColor(
        name: "separator",
        lightMode: RGBColor(red: 0.235, green: 0.235, blue: 0.263, alpha: 0.29), // #3C3C43 29%
        darkMode: RGBColor(red: 0.329, green: 0.329, blue: 0.345, alpha: 0.6)    // #545458 60%
    )
    
    static let opaqueSeparator = AppleSystemColor(
        name: "opaqueSeparator",
        lightMode: RGBColor(red: 0.776, green: 0.776, blue: 0.784), // #C6C6C8
        darkMode: RGBColor(red: 0.220, green: 0.220, blue: 0.227)   // #38383A
    )
    
    // System background colors
    static let systemBackground = AppleSystemColor(
        name: "systemBackground",
        lightMode: RGBColor(red: 1.0, green: 1.0, blue: 1.0), // #FFFFFF
        darkMode: RGBColor(red: 0.0, green: 0.0, blue: 0.0)   // #000000
    )
    
    static let secondarySystemBackground = AppleSystemColor(
        name: "secondarySystemBackground",
        lightMode: RGBColor(red: 0.949, green: 0.949, blue: 0.969), // #F2F2F7
        darkMode: RGBColor(red: 0.110, green: 0.110, blue: 0.118)   // #1C1C1E
    )
    
    static let tertiarySystemBackground = AppleSystemColor(
        name: "tertiarySystemBackground",
        lightMode: RGBColor(red: 1.0, green: 1.0, blue: 1.0), // #FFFFFF
        darkMode: RGBColor(red: 0.173, green: 0.173, blue: 0.180)   // #2C2C2E
    )
    
    static let systemGroupedBackground = AppleSystemColor(
        name: "systemGroupedBackground",
        lightMode: RGBColor(red: 0.949, green: 0.949, blue: 0.969), // #F2F2F7
        darkMode: RGBColor(red: 0.0, green: 0.0, blue: 0.0)         // #000000
    )
    
    static let secondarySystemGroupedBackground = AppleSystemColor(
        name: "secondarySystemGroupedBackground",
        lightMode: RGBColor(red: 1.0, green: 1.0, blue: 1.0), // #FFFFFF
        darkMode: RGBColor(red: 0.110, green: 0.110, blue: 0.118)   // #1C1C1E
    )
    
    static let tertiarySystemGroupedBackground = AppleSystemColor(
        name: "tertiarySystemGroupedBackground",
        lightMode: RGBColor(red: 0.949, green: 0.949, blue: 0.969), // #F2F2F7
        darkMode: RGBColor(red: 0.173, green: 0.173, blue: 0.180)   // #2C2C2E
    )
    
    // System fill colors
    static let systemFill = AppleSystemColor(
        name: "systemFill",
        lightMode: RGBColor(red: 0.471, green: 0.471, blue: 0.502, alpha: 0.2), // #787880 20%
        darkMode: RGBColor(red: 0.471, green: 0.471, blue: 0.502, alpha: 0.36)  // #787880 36%
    )
    
    static let secondarySystemFill = AppleSystemColor(
        name: "secondarySystemFill",
        lightMode: RGBColor(red: 0.471, green: 0.471, blue: 0.502, alpha: 0.16), // #787880 16%
        darkMode: RGBColor(red: 0.471, green: 0.471, blue: 0.502, alpha: 0.32)   // #787880 32%
    )
    
    static let tertiarySystemFill = AppleSystemColor(
        name: "tertiarySystemFill",
        lightMode: RGBColor(red: 0.463, green: 0.463, blue: 0.502, alpha: 0.12), // #767680 12%
        darkMode: RGBColor(red: 0.463, green: 0.463, blue: 0.502, alpha: 0.24)   // #767680 24%
    )
    
    static let quaternarySystemFill = AppleSystemColor(
        name: "quaternarySystemFill",
        lightMode: RGBColor(red: 0.455, green: 0.455, blue: 0.502, alpha: 0.08), // #747480 8%
        darkMode: RGBColor(red: 0.455, green: 0.455, blue: 0.502, alpha: 0.18)   // #747480 18%
    )
    
    // Get all available system colors
    static let allSystemColors: [AppleSystemColor] = [
        .systemBlue, .systemRed, .systemGreen, .systemYellow, .systemOrange,
        .systemPurple, .systemPink, .systemTeal, .systemIndigo, .systemBrown,
        .systemGray, .systemGray2, .systemGray3, .systemGray4, .systemGray5, .systemGray6,
        .label, .secondaryLabel, .tertiaryLabel, .quaternaryLabel,
        .link, .placeholderText, .separator, .opaqueSeparator,
        .systemBackground, .secondarySystemBackground, .tertiarySystemBackground,
        .systemGroupedBackground, .secondarySystemGroupedBackground, .tertiarySystemGroupedBackground,
        .systemFill, .secondarySystemFill, .tertiarySystemFill, .quaternarySystemFill
    ]
}

// MARK: - Helper Extensions

// Helper extension for Color components
extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let nsColor = NSColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        nsColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))
    }
}