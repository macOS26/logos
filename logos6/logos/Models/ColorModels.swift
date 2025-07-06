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
        case .clear:
            return CGColor(red: 0, green: 0, blue: 0, alpha: 0)
        case .black:
            return CGColor(red: 0, green: 0, blue: 0, alpha: 1)
        case .white:
            return CGColor(red: 1, green: 1, blue: 1, alpha: 1)
        }
    }
    
    static let defaultColors: [VectorColor] = [
        .black, .white, .clear,
        .rgb(RGBColor(red: 1, green: 0, blue: 0)),
        .rgb(RGBColor(red: 0, green: 1, blue: 0)),
        .rgb(RGBColor(red: 0, green: 0, blue: 1)),
        .rgb(RGBColor(red: 1, green: 1, blue: 0)),
        .rgb(RGBColor(red: 1, green: 0, blue: 1)),
        .rgb(RGBColor(red: 0, green: 1, blue: 1)),
        .rgb(RGBColor(red: 0.5, green: 0.5, blue: 0.5))
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