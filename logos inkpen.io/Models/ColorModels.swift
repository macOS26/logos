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
    case hsb = "HSB"
    case pantone = "SPOT"
    
    var iconName: String {
        switch self {
        case .rgb: return "display"
        case .cmyk: return "printer"
        case .hsb: return "slider.horizontal.3"
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

// MARK: - HSB Color Model
struct HSBColorModel: Codable, Hashable {
    var hue: Double        // 0.0 - 360.0 degrees
    var saturation: Double // 0.0 - 1.0 (0% - 100%)
    var brightness: Double // 0.0 - 1.0 (0% - 100%)
    var alpha: Double
    
    init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1.0) {
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.alpha = alpha
    }
    
    var rgbColor: RGBColor {
        // Convert HSB to RGB
        let h = hue / 60.0
        let c = brightness * saturation
        let x = c * (1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = brightness - c
        
        var rgb: (Double, Double, Double)
        
        if h >= 0 && h < 1 {
            rgb = (c, x, 0)
        } else if h >= 1 && h < 2 {
            rgb = (x, c, 0)
        } else if h >= 2 && h < 3 {
            rgb = (0, c, x)
        } else if h >= 3 && h < 4 {
            rgb = (0, x, c)
        } else if h >= 4 && h < 5 {
            rgb = (x, 0, c)
        } else {
            rgb = (c, 0, x)
        }
        
        return RGBColor(
            red: rgb.0 + m,
            green: rgb.1 + m,
            blue: rgb.2 + m,
            alpha: alpha
        )
    }
    
    var color: Color {
        rgbColor.color
    }
    
    // Create HSB from RGB
    static func fromRGB(_ rgb: RGBColor) -> HSBColorModel {
        let max = Swift.max(rgb.red, rgb.green, rgb.blue)
        let min = Swift.min(rgb.red, rgb.green, rgb.blue)
        let delta = max - min
        
        var hue: Double = 0
        let saturation: Double = max == 0 ? 0 : delta / max
        let brightness: Double = max
        
        if delta != 0 {
            if max == rgb.red {
                hue = 60 * (((rgb.green - rgb.blue) / delta).truncatingRemainder(dividingBy: 6))
            } else if max == rgb.green {
                hue = 60 * (((rgb.blue - rgb.red) / delta) + 2)
            } else {
                hue = 60 * (((rgb.red - rgb.green) / delta) + 4)
            }
        }
        
        if hue < 0 {
            hue += 360
        }
        
        return HSBColorModel(hue: hue, saturation: saturation, brightness: brightness, alpha: rgb.alpha)
    }
}

// MARK: - SPOT Color Library (Professional Grade)
struct SPOTColor: Codable, Hashable {
    var number: String
    var name: String
    var rgbEquivalent: RGBColor
    var cmykEquivalent: CMYKColor
    var hsbEquivalent: HSBColorModel
    var alpha: Double
    
    init(number: String, name: String, rgbEquivalent: RGBColor, cmykEquivalent: CMYKColor, alpha: Double = 1.0) {
        self.number = number
        self.name = name
        self.rgbEquivalent = rgbEquivalent
        self.cmykEquivalent = cmykEquivalent
        self.hsbEquivalent = HSBColorModel.fromRGB(rgbEquivalent)
        self.alpha = alpha
    }
    
    var color: Color {
        Color(.sRGB, red: rgbEquivalent.red, green: rgbEquivalent.green, blue: rgbEquivalent.blue, opacity: alpha)
    }
    
    // Distance calculation for color matching
    func distanceFrom(hsb: HSBColorModel) -> Double {
        let hueDiff = min(abs(hsbEquivalent.hue - hsb.hue), 360 - abs(hsbEquivalent.hue - hsb.hue))
        let satDiff = abs(hsbEquivalent.saturation - hsb.saturation)
        let briDiff = abs(hsbEquivalent.brightness - hsb.brightness)
        
        // Weighted distance calculation (hue is most important for perceptual matching)
        return hueDiff * 0.5 + satDiff * 100 * 0.3 + briDiff * 100 * 0.2
    }
    
    func distanceFrom(rgb: RGBColor) -> Double {
        let rDiff = abs(rgbEquivalent.red - rgb.red)
        let gDiff = abs(rgbEquivalent.green - rgb.green)
        let bDiff = abs(rgbEquivalent.blue - rgb.blue)
        
        // Euclidean distance in RGB space
        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
    }
    
    // Comprehensive SPOT Color Library
    static let allSPOTColors: [SPOTColor] = [
        // Primary SPOT Colors (Popular)
        SPOTColor(number: "032", name: "Reflex Blue", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.14, blue: 0.4),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.65, yellow: 0.0, black: 0.6)),
        
        SPOTColor(number: "185", name: "Red 032", 
                 rgbEquivalent: RGBColor(red: 0.9, green: 0.1, blue: 0.14),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.9, yellow: 0.86, black: 0.1)),
        
        SPOTColor(number: "286", name: "Blue 072", 
                 rgbEquivalent: RGBColor(red: 0.15, green: 0.2, blue: 0.51),
                 cmykEquivalent: CMYKColor(cyan: 0.85, magenta: 0.8, yellow: 0.0, black: 0.49)),
        
        SPOTColor(number: "355", name: "Green", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.4, blue: 0.25),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.0, yellow: 0.75, black: 0.6)),
        
        SPOTColor(number: "Yellow", name: "Yellow", 
                 rgbEquivalent: RGBColor(red: 1.0, green: 0.93, blue: 0.0),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.07, yellow: 1.0, black: 0.0)),
        
        SPOTColor(number: "Magenta", name: "Magenta", 
                 rgbEquivalent: RGBColor(red: 0.91, green: 0.0, blue: 0.55),
                 cmykEquivalent: CMYKColor(cyan: 0.09, magenta: 1.0, yellow: 0.0, black: 0.0)),
        
        SPOTColor(number: "Cyan", name: "Process Cyan", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.67, blue: 0.93),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.0, yellow: 0.0, black: 0.0)),
        
        // Orange Series
        SPOTColor(number: "021", name: "Orange 021", 
                 rgbEquivalent: RGBColor(red: 1.0, green: 0.23, blue: 0.0),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.77, yellow: 1.0, black: 0.0)),
        
        SPOTColor(number: "1375", name: "Orange 1375", 
                 rgbEquivalent: RGBColor(red: 1.0, green: 0.47, blue: 0.0),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.53, yellow: 1.0, black: 0.0)),
        
        SPOTColor(number: "1495", name: "Orange 1495", 
                 rgbEquivalent: RGBColor(red: 1.0, green: 0.58, blue: 0.11),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.42, yellow: 0.89, black: 0.0)),
        
        // Red Series
        SPOTColor(number: "18-1664", name: "Red 18-1664", 
                 rgbEquivalent: RGBColor(red: 0.8, green: 0.16, blue: 0.22),
                 cmykEquivalent: CMYKColor(cyan: 0.2, magenta: 0.84, yellow: 0.78, black: 0.0)),
        
        SPOTColor(number: "199", name: "Red 199", 
                 rgbEquivalent: RGBColor(red: 0.93, green: 0.09, blue: 0.38),
                 cmykEquivalent: CMYKColor(cyan: 0.07, magenta: 0.91, yellow: 0.62, black: 0.0)),
        
        SPOTColor(number: "1797", name: "Red 1797", 
                 rgbEquivalent: RGBColor(red: 0.77, green: 0.12, blue: 0.23),
                 cmykEquivalent: CMYKColor(cyan: 0.23, magenta: 0.88, yellow: 0.77, black: 0.0)),
        
        // Blue Series
        SPOTColor(number: "2925", name: "Blue 2925", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.38, blue: 0.65),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.42, yellow: 0.0, black: 0.35)),
        
        SPOTColor(number: "2935", name: "Blue 2935", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.28, blue: 0.57),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.52, yellow: 0.0, black: 0.43)),
        
        SPOTColor(number: "3005", name: "Navy Blue", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.2, blue: 0.4),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.5, yellow: 0.0, black: 0.6)),
        
        // Green Series
        SPOTColor(number: "348", name: "Green 348", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.6, blue: 0.4),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.0, yellow: 0.6, black: 0.4)),
        
        SPOTColor(number: "364", name: "Green 364", 
                 rgbEquivalent: RGBColor(red: 0.31, green: 0.73, blue: 0.4),
                 cmykEquivalent: CMYKColor(cyan: 0.69, magenta: 0.0, yellow: 0.6, black: 0.27)),
        
        SPOTColor(number: "375", name: "Green 375", 
                 rgbEquivalent: RGBColor(red: 0.53, green: 0.75, blue: 0.0),
                 cmykEquivalent: CMYKColor(cyan: 0.47, magenta: 0.0, yellow: 1.0, black: 0.25)),
        
        // Purple Series
        SPOTColor(number: "2587", name: "Purple 2587", 
                 rgbEquivalent: RGBColor(red: 0.4, green: 0.2, blue: 0.6),
                 cmykEquivalent: CMYKColor(cyan: 0.6, magenta: 0.8, yellow: 0.0, black: 0.4)),
        
        SPOTColor(number: "2593", name: "Purple 2593", 
                 rgbEquivalent: RGBColor(red: 0.35, green: 0.15, blue: 0.55),
                 cmykEquivalent: CMYKColor(cyan: 0.65, magenta: 0.85, yellow: 0.0, black: 0.45)),
        
        SPOTColor(number: "268", name: "Purple 268", 
                 rgbEquivalent: RGBColor(red: 0.42, green: 0.26, blue: 0.65),
                 cmykEquivalent: CMYKColor(cyan: 0.58, magenta: 0.74, yellow: 0.0, black: 0.35)),
        
        // Pink Series
        SPOTColor(number: "213", name: "Pink 213", 
                 rgbEquivalent: RGBColor(red: 0.95, green: 0.4, blue: 0.76),
                 cmykEquivalent: CMYKColor(cyan: 0.05, magenta: 0.6, yellow: 0.0, black: 0.0)),
        
        SPOTColor(number: "219", name: "Pink 219", 
                 rgbEquivalent: RGBColor(red: 0.87, green: 0.62, blue: 0.87),
                 cmykEquivalent: CMYKColor(cyan: 0.13, magenta: 0.38, yellow: 0.0, black: 0.0)),
        
        SPOTColor(number: "230", name: "Pink 230", 
                 rgbEquivalent: RGBColor(red: 0.95, green: 0.75, blue: 0.9),
                 cmykEquivalent: CMYKColor(cyan: 0.05, magenta: 0.25, yellow: 0.0, black: 0.0)),
        
        // Brown Series
        SPOTColor(number: "4695", name: "Brown 4695", 
                 rgbEquivalent: RGBColor(red: 0.4, green: 0.27, blue: 0.13),
                 cmykEquivalent: CMYKColor(cyan: 0.6, magenta: 0.73, yellow: 0.87, black: 0.0)),
        
        SPOTColor(number: "476", name: "Brown 476", 
                 rgbEquivalent: RGBColor(red: 0.55, green: 0.4, blue: 0.15),
                 cmykEquivalent: CMYKColor(cyan: 0.45, magenta: 0.6, yellow: 0.85, black: 0.0)),
        
        SPOTColor(number: "4975", name: "Brown 4975", 
                 rgbEquivalent: RGBColor(red: 0.35, green: 0.22, blue: 0.1),
                 cmykEquivalent: CMYKColor(cyan: 0.65, magenta: 0.78, yellow: 0.9, black: 0.0)),
        
        // Metallic Series
        SPOTColor(number: "871", name: "Metallic Gold", 
                 rgbEquivalent: RGBColor(red: 0.68, green: 0.5, blue: 0.16),
                 cmykEquivalent: CMYKColor(cyan: 0.32, magenta: 0.5, yellow: 0.84, black: 0.0)),
        
        SPOTColor(number: "877", name: "Metallic Silver", 
                 rgbEquivalent: RGBColor(red: 0.64, green: 0.64, blue: 0.65),
                 cmykEquivalent: CMYKColor(cyan: 0.36, magenta: 0.28, yellow: 0.27, black: 0.0)),
        
        SPOTColor(number: "8003", name: "Metallic Copper", 
                 rgbEquivalent: RGBColor(red: 0.55, green: 0.27, blue: 0.07),
                 cmykEquivalent: CMYKColor(cyan: 0.45, magenta: 0.73, yellow: 0.93, black: 0.0)),
        
        // Neutral Series
        SPOTColor(number: "Cool Gray 1", name: "Cool Gray 1", 
                 rgbEquivalent: RGBColor(red: 0.93, green: 0.93, blue: 0.93),
                 cmykEquivalent: CMYKColor(cyan: 0.05, magenta: 0.02, yellow: 0.02, black: 0.05)),
        
        SPOTColor(number: "Cool Gray 3", name: "Cool Gray 3", 
                 rgbEquivalent: RGBColor(red: 0.85, green: 0.85, blue: 0.85),
                 cmykEquivalent: CMYKColor(cyan: 0.1, magenta: 0.05, yellow: 0.05, black: 0.1)),
        
        SPOTColor(number: "Cool Gray 5", name: "Cool Gray 5", 
                 rgbEquivalent: RGBColor(red: 0.7, green: 0.7, blue: 0.7),
                 cmykEquivalent: CMYKColor(cyan: 0.2, magenta: 0.12, yellow: 0.12, black: 0.18)),
        
        SPOTColor(number: "Cool Gray 7", name: "Cool Gray 7", 
                 rgbEquivalent: RGBColor(red: 0.55, green: 0.55, blue: 0.55),
                 cmykEquivalent: CMYKColor(cyan: 0.3, magenta: 0.22, yellow: 0.22, black: 0.3)),
        
        SPOTColor(number: "Cool Gray 9", name: "Cool Gray 9", 
                 rgbEquivalent: RGBColor(red: 0.4, green: 0.4, blue: 0.4),
                 cmykEquivalent: CMYKColor(cyan: 0.45, magenta: 0.35, yellow: 0.35, black: 0.45)),
        
        SPOTColor(number: "Cool Gray 11", name: "Cool Gray 11", 
                 rgbEquivalent: RGBColor(red: 0.25, green: 0.25, blue: 0.25),
                 cmykEquivalent: CMYKColor(cyan: 0.6, magenta: 0.5, yellow: 0.5, black: 0.6)),
        
        // Warm Gray Series
        SPOTColor(number: "Warm Gray 1", name: "Warm Gray 1", 
                 rgbEquivalent: RGBColor(red: 0.93, green: 0.92, blue: 0.9),
                 cmykEquivalent: CMYKColor(cyan: 0.04, magenta: 0.05, yellow: 0.08, black: 0.05)),
        
        SPOTColor(number: "Warm Gray 3", name: "Warm Gray 3", 
                 rgbEquivalent: RGBColor(red: 0.84, green: 0.82, blue: 0.78),
                 cmykEquivalent: CMYKColor(cyan: 0.1, magenta: 0.12, yellow: 0.18, black: 0.12)),
        
        SPOTColor(number: "Warm Gray 5", name: "Warm Gray 5", 
                 rgbEquivalent: RGBColor(red: 0.68, green: 0.65, blue: 0.6),
                 cmykEquivalent: CMYKColor(cyan: 0.25, magenta: 0.28, yellow: 0.35, black: 0.25)),
        
        SPOTColor(number: "Warm Gray 7", name: "Warm Gray 7", 
                 rgbEquivalent: RGBColor(red: 0.52, green: 0.48, blue: 0.42),
                 cmykEquivalent: CMYKColor(cyan: 0.4, magenta: 0.45, yellow: 0.55, black: 0.4)),
        
        SPOTColor(number: "Warm Gray 9", name: "Warm Gray 9", 
                 rgbEquivalent: RGBColor(red: 0.36, green: 0.32, blue: 0.26),
                 cmykEquivalent: CMYKColor(cyan: 0.55, magenta: 0.6, yellow: 0.7, black: 0.55)),
        
        SPOTColor(number: "Warm Gray 11", name: "Warm Gray 11", 
                 rgbEquivalent: RGBColor(red: 0.22, green: 0.18, blue: 0.14),
                 cmykEquivalent: CMYKColor(cyan: 0.7, magenta: 0.75, yellow: 0.82, black: 0.7)),
        
        // Process Colors
        SPOTColor(number: "Process Black", name: "Process Black", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.0, blue: 0.0),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.0, yellow: 0.0, black: 1.0)),
        
        SPOTColor(number: "Process Blue", name: "Process Blue", 
                 rgbEquivalent: RGBColor(red: 0.0, green: 0.67, blue: 0.93),
                 cmykEquivalent: CMYKColor(cyan: 1.0, magenta: 0.0, yellow: 0.0, black: 0.0)),
        
        // Bright/Fluorescent Colors
        SPOTColor(number: "804", name: "Safety Yellow", 
                 rgbEquivalent: RGBColor(red: 1.0, green: 0.95, blue: 0.0),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.05, yellow: 1.0, black: 0.0)),
        
        SPOTColor(number: "805", name: "Safety Orange", 
                 rgbEquivalent: RGBColor(red: 1.0, green: 0.4, blue: 0.0),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.6, yellow: 1.0, black: 0.0)),
        
        SPOTColor(number: "806", name: "Safety Pink", 
                 rgbEquivalent: RGBColor(red: 1.0, green: 0.2, blue: 0.6),
                 cmykEquivalent: CMYKColor(cyan: 0.0, magenta: 0.8, yellow: 0.0, black: 0.0)),
        
        // Pastel Series
        SPOTColor(number: "9043", name: "Pale Yellow", 
                 rgbEquivalent: RGBColor(red: 0.98, green: 0.95, blue: 0.85),
                 cmykEquivalent: CMYKColor(cyan: 0.02, magenta: 0.05, yellow: 0.15, black: 0.0)),
        
        SPOTColor(number: "9044", name: "Pale Pink", 
                 rgbEquivalent: RGBColor(red: 0.95, green: 0.9, blue: 0.9),
                 cmykEquivalent: CMYKColor(cyan: 0.05, magenta: 0.1, yellow: 0.05, black: 0.0)),
        
        SPOTColor(number: "9045", name: "Pale Blue", 
                 rgbEquivalent: RGBColor(red: 0.85, green: 0.9, blue: 0.95),
                 cmykEquivalent: CMYKColor(cyan: 0.15, magenta: 0.05, yellow: 0.0, black: 0.0)),
        
        SPOTColor(number: "9046", name: "Pale Green", 
                 rgbEquivalent: RGBColor(red: 0.85, green: 0.95, blue: 0.85),
                 cmykEquivalent: CMYKColor(cyan: 0.15, magenta: 0.0, yellow: 0.15, black: 0.0))
    ]
    
    // Find closest SPOT color match
    static func findClosestMatch(to hsb: HSBColorModel) -> SPOTColor {
        var closestColor = allSPOTColors[0]
        var smallestDistance = Double.greatestFiniteMagnitude
        
        for spotColor in allSPOTColors {
            let distance = spotColor.distanceFrom(hsb: hsb)
            if distance < smallestDistance {
                smallestDistance = distance
                closestColor = spotColor
            }
        }
        
        return closestColor
    }
    
    static func findClosestMatch(to rgb: RGBColor) -> SPOTColor {
        var closestColor = allSPOTColors[0]
        var smallestDistance = Double.greatestFiniteMagnitude
        
        for spotColor in allSPOTColors {
            let distance = spotColor.distanceFrom(rgb: rgb)
            if distance < smallestDistance {
                smallestDistance = distance
                closestColor = spotColor
            }
        }
        
        return closestColor
    }
}

// MARK: - Pantone Library Structure
struct PantoneLibraryColor: Codable, Hashable {
    var pantone: String
    var name: String
    var hex: String
    var rgbEquivalent: RGBColor
    var cmykEquivalent: CMYKColor
    var hsbEquivalent: HSBColorModel
    
    init(pantone: String, hex: String) {
        self.pantone = pantone
        self.name = "Pantone \(pantone.uppercased())"
        self.hex = hex
        self.rgbEquivalent = PantoneLibraryColor.hexToRGB(hex)
        self.cmykEquivalent = PantoneLibraryColor.rgbToCMYK(self.rgbEquivalent)
        self.hsbEquivalent = HSBColorModel.fromRGB(self.rgbEquivalent)
    }
    
    var color: Color {
        rgbEquivalent.color
    }
    
    // Convert to SPOTColor for compatibility
    var spotColor: SPOTColor {
        SPOTColor(number: pantone, name: name, rgbEquivalent: rgbEquivalent, cmykEquivalent: cmykEquivalent)
    }
    
    // Helper function to convert hex to RGB
    static func hexToRGB(_ hex: String) -> RGBColor {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0
        
        return RGBColor(red: red, green: green, blue: blue)
    }
    
    // Helper function to convert RGB to CMYK
    static func rgbToCMYK(_ rgb: RGBColor) -> CMYKColor {
        let k = 1.0 - max(rgb.red, max(rgb.green, rgb.blue))
        
        if k == 1.0 {
            return CMYKColor(cyan: 0, magenta: 0, yellow: 0, black: 1.0)
        }
        
        let c = (1.0 - rgb.red - k) / (1.0 - k)
        let m = (1.0 - rgb.green - k) / (1.0 - k)
        let y = (1.0 - rgb.blue - k) / (1.0 - k)
        
        return CMYKColor(cyan: c, magenta: m, yellow: y, black: k)
    }
    
    // Distance calculation for color matching
    func distanceFrom(hsb: HSBColorModel) -> Double {
        let hueDiff = min(abs(hsbEquivalent.hue - hsb.hue), 360 - abs(hsbEquivalent.hue - hsb.hue))
        let satDiff = abs(hsbEquivalent.saturation - hsb.saturation)
        let briDiff = abs(hsbEquivalent.brightness - hsb.brightness)
        
        // Weighted distance calculation (hue is most important for perceptual matching)
        return hueDiff * 0.5 + satDiff * 100 * 0.3 + briDiff * 100 * 0.2
    }
    
    func distanceFrom(rgb: RGBColor) -> Double {
        let rDiff = abs(rgbEquivalent.red - rgb.red)
        let gDiff = abs(rgbEquivalent.green - rgb.green)
        let bDiff = abs(rgbEquivalent.blue - rgb.blue)
        
        // Euclidean distance in RGB space
        return sqrt(rDiff * rDiff + gDiff * gDiff + bDiff * bDiff)
    }
}

// MARK: - Pantone Library Manager
class PantoneLibrary: ObservableObject {
    @Published var allColors: [PantoneLibraryColor] = []
    
    init() {
        loadPantoneColors()
    }
    
    private func loadPantoneColors() {
        guard let url = Bundle.main.url(forResource: "pantone_library", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let pantoneData = try? JSONDecoder().decode([PantoneRawData].self, from: data) else {
            print("Failed to load Pantone library - using fallback colors")
            // Fallback to a small set of essential colors if file can't be loaded
            allColors = [
                PantoneLibraryColor(pantone: "032 C", hex: "#ef3340"),
                PantoneLibraryColor(pantone: "072 C", hex: "#10069f"),
                PantoneLibraryColor(pantone: "355 C", hex: "#00b140"),
                PantoneLibraryColor(pantone: "Yellow C", hex: "#fedd00"),
                PantoneLibraryColor(pantone: "Process Black C", hex: "#2d2926")
            ]
            return
        }
        
        allColors = pantoneData.map { rawColor in
            PantoneLibraryColor(pantone: rawColor.pantone, hex: rawColor.hex)
        }
        
        print("✅ Loaded \(allColors.count) Pantone colors from library")
    }
    
    // Find closest Pantone color match
    func findClosestMatch(to hsb: HSBColorModel) -> PantoneLibraryColor? {
        guard !allColors.isEmpty else { return nil }
        
        var closestColor = allColors[0]
        var smallestDistance = Double.greatestFiniteMagnitude
        
        for pantoneColor in allColors {
            let distance = pantoneColor.distanceFrom(hsb: hsb)
            if distance < smallestDistance {
                smallestDistance = distance
                closestColor = pantoneColor
            }
        }
        
        return closestColor
    }
    
    func findClosestMatch(to rgb: RGBColor) -> PantoneLibraryColor? {
        guard !allColors.isEmpty else { return nil }
        
        var closestColor = allColors[0]
        var smallestDistance = Double.greatestFiniteMagnitude
        
        for pantoneColor in allColors {
            let distance = pantoneColor.distanceFrom(rgb: rgb)
            if distance < smallestDistance {
                smallestDistance = distance
                closestColor = pantoneColor
            }
        }
        
        return closestColor
    }
    
    // Search by Pantone number or name
    func searchColors(query: String) -> [PantoneLibraryColor] {
        let lowercaseQuery = query.lowercased()
        return allColors.filter { color in
            color.pantone.lowercased().contains(lowercaseQuery) ||
            color.name.lowercased().contains(lowercaseQuery)
        }
    }
}

// MARK: - Raw Pantone Data Structure (for JSON loading)
struct PantoneRawData: Codable {
    let pantone: String
    let hex: String
}

// MARK: - Vector Color
enum VectorColor: Codable, Hashable {
    case rgb(RGBColor)
    case cmyk(CMYKColor)
    case hsb(HSBColorModel)
    case pantone(PantoneLibraryColor) // Pantone library colors
    case spot(SPOTColor)              // New SPOT colors
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
        case .hsb(let hsb):
            return hsb.color
        case .pantone(let pantone):
            return pantone.color
        case .spot(let spot):
            return spot.color
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
        case .hsb(let hsb):
            return hsb.rgbColor.cgColor
        case .pantone(let pantone):
            return pantone.rgbEquivalent.cgColor
        case .spot(let spot):
            return spot.rgbEquivalent.cgColor
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