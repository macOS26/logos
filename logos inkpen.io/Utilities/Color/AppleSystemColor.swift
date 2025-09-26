//
//  AppleSystemColor.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

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
    // Using P3 color space for more vibrant colors
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    // System background colors
    
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
    
}

// MARK: - Helper Extensions

