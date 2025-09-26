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
        lightMode: RGBColor(red: 0.0, green: 0.478, blue: 1.0, colorSpace: .displayP3), // P3 link blue
        darkMode: RGBColor(red: 0.04, green: 0.518, blue: 1.0, colorSpace: .displayP3)  // P3 link blue dark
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
        .systemRed, .systemGreen, .systemYellow, .systemOrange,
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

