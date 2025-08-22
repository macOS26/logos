//
//  ColorModels.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Color Modes
enum ColorMode: String, CaseIterable, Codable {
    case rgb = "RGB"
    case cmyk = "CMYK"
    case pms = "PMS"
    
    var iconName: String {
        switch self {
        case .rgb: return "display"
        case .cmyk: return "printer"
        case .pms: return "slider.horizontal.3"
        }
    }
}

// MARK: - Active Color Target
enum ColorTarget: String, CaseIterable, Codable {
    case fill = "Fill"
    case stroke = "Stroke"
}

// MARK: - Color Change Type for Notifications
enum ColorChangeType: String, CaseIterable, Codable {
    case fillColor = "FillColor"
    case fillOpacity = "FillOpacity"
    case strokeColor = "StrokeColor"
    case strokeOpacity = "StrokeOpacity"
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
        // Create color in the app's working space
        return ColorManager.shared.makeColor(r: red, g: green, b: blue, a: alpha, source: ColorManager.shared.sRGBCG)
    }
    
    var cgColor: CGColor {
        let comps: [CGFloat] = [CGFloat(red), CGFloat(green), CGFloat(blue), CGFloat(alpha)]
        return CGColor(colorSpace: ColorManager.shared.sRGBCG, components: comps) ?? CGColor(red: red, green: green, blue: blue, alpha: alpha)
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
        // CMYK components are device independent; render via sRGB-equivalent then into working space
        return ColorManager.shared.makeColor(r: rgbColor.red, g: rgbColor.green, b: rgbColor.blue, a: alpha, source: ColorManager.shared.sRGBCG)
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
        // HSB is interpreted in sRGB primaries. Convert to working space for UI
        return ColorManager.shared.makeColor(r: rgbColor.red, g: rgbColor.green, b: rgbColor.blue, a: alpha, source: ColorManager.shared.sRGBCG)
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
