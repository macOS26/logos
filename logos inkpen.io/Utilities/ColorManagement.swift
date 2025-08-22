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

