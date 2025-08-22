//
//  SPOTColor.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

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
        // Pantone is stored with sRGB equivalents; present in working space
        return ColorManager.shared.makeColor(r: rgbEquivalent.red, g: rgbEquivalent.green, b: rgbEquivalent.blue, a: alpha, source: ColorManager.shared.sRGBCG)
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
