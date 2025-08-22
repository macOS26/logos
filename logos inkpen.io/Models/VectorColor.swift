//
//  VectorColor.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import CoreGraphics
import SwiftUI

// MARK: - Vector Color
enum VectorColor: Codable, Hashable {
    case rgb(RGBColor)
    case cmyk(CMYKColor)
    case hsb(HSBColorModel)
    case pantone(PantoneLibraryColor) // Pantone library colors
    case spot(SPOTColor)              // New SPOT colors
    case appleSystem(AppleSystemColor)
    case gradient(VectorGradient)     // Gradient support
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
        case .gradient(let gradient):
            // For gradients, return the first stop color as a fallback (already VectorColor → Color path will hit working space)
            return gradient.stops.first?.color.color ?? Color.black
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
            return ColorManager.shared.convert(pantone.rgbEquivalent.cgColor, to: ColorManager.shared.displayP3CG)
        case .spot(let spot):
            return ColorManager.shared.convert(spot.rgbEquivalent.cgColor, to: ColorManager.shared.displayP3CG)
        case .appleSystem(let systemColor):
            return systemColor.rgbEquivalent.cgColor
        case .gradient(let gradient):
            // For gradients, return the first stop color as a fallback
            return gradient.stops.first?.color.cgColor ?? CGColor(red: 0, green: 0, blue: 0, alpha: 1)
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
    
    var svgColor: String {
        switch self {
        case .clear:
            return "none"
        case .black:
            return "#000000"
        case .white:
            return "#FFFFFF"
        case .rgb(let rgbColor):
            return String(format: "#%02X%02X%02X",
                         Int(rgbColor.red * 255),
                         Int(rgbColor.green * 255),
                         Int(rgbColor.blue * 255))
        case .cmyk(let cmykColor):
            // Convert CMYK to RGB for SVG
            let r = (1 - cmykColor.cyan) * (1 - cmykColor.black)
            let g = (1 - cmykColor.magenta) * (1 - cmykColor.black)
            let b = (1 - cmykColor.yellow) * (1 - cmykColor.black)
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        case .hsb(let hsbColor):
            // Convert HSB to RGB for SVG
            let rgb = hsbToRgb(h: hsbColor.hue, s: hsbColor.saturation, b: hsbColor.brightness)
            return String(format: "#%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255))
        case .pantone(let pantoneColor):
            return String(format: "#%02X%02X%02X",
                         Int(pantoneColor.rgbEquivalent.red * 255),
                         Int(pantoneColor.rgbEquivalent.green * 255),
                         Int(pantoneColor.rgbEquivalent.blue * 255))
        case .spot(let spotColor):
            return String(format: "#%02X%02X%02X",
                         Int(spotColor.rgbEquivalent.red * 255),
                         Int(spotColor.rgbEquivalent.green * 255),
                         Int(spotColor.rgbEquivalent.blue * 255))
        case .appleSystem(let systemColor):
            return String(format: "#%02X%02X%02X",
                         Int(systemColor.rgbEquivalent.red * 255),
                         Int(systemColor.rgbEquivalent.green * 255),
                         Int(systemColor.rgbEquivalent.blue * 255))
        case .gradient(let gradient):
            // For gradients, return the first stop color as a fallback
            return gradient.stops.first?.color.svgColor ?? "#000000"
        }
    }
    
    private func hsbToRgb(h: Double, s: Double, b: Double) -> (r: Double, g: Double, b: Double) {
        let hue = h * 360
        let saturation = s
        let brightness = b
        
        let c = brightness * saturation
        let x = c * (1 - abs((hue / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = brightness - c
        
        let (r, g, b): (Double, Double, Double)
        
        switch Int(hue) / 60 {
        case 0:
            (r, g, b) = (c, x, 0)
        case 1:
            (r, g, b) = (x, c, 0)
        case 2:
            (r, g, b) = (0, c, x)
        case 3:
            (r, g, b) = (0, x, c)
        case 4:
            (r, g, b) = (x, 0, c)
        case 5:
            (r, g, b) = (c, 0, x)
        default:
            (r, g, b) = (0, 0, 0)
        }
        
        return (r + m, g + m, b + m)
    }
}
