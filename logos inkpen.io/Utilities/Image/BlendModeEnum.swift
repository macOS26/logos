//
//  BlendMode.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Blend Modes
enum BlendMode: String, CaseIterable, Codable {
    // Standard blend modes
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

    // Porter-Duff compositing modes (SwiftUI supported)
    case sourceAtop = "Source Atop"
    case destinationOver = "Destination Over"
    case destinationOut = "Destination Out"

    // Additional modes
    case plusDarker = "Plus Darker"
    case plusLighter = "Plus Lighter"

    /// Display name for UI
    var displayName: String {
        return rawValue
    }

    /// Convert to CGBlendMode for PDF/PNG export
    var cgBlendMode: CGBlendMode {
        switch self {
        // Standard blend modes
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

        // Porter-Duff compositing modes
        case .sourceAtop: return .sourceAtop
        case .destinationOver: return .destinationOver
        case .destinationOut: return .destinationOut

        // Additional modes
        case .plusDarker: return .plusDarker
        case .plusLighter: return .plusLighter
        }
    }

    /// Convert to SVG mix-blend-mode for SVG export
    var svgBlendMode: String {
        switch self {
        // Standard blend modes (fully supported in SVG)
        case .normal: return "normal"
        case .multiply: return "multiply"
        case .screen: return "screen"
        case .overlay: return "overlay"
        case .softLight: return "soft-light"
        case .hardLight: return "hard-light"
        case .colorDodge: return "color-dodge"
        case .colorBurn: return "color-burn"
        case .darken: return "darken"
        case .lighten: return "lighten"
        case .difference: return "difference"
        case .exclusion: return "exclusion"
        case .hue: return "hue"
        case .saturation: return "saturation"
        case .color: return "color"
        case .luminosity: return "luminosity"

        // Porter-Duff compositing modes (not supported in SVG - fallback to normal)
        case .sourceAtop: return "normal"
        case .destinationOver: return "normal"
        case .destinationOut: return "normal"

        // Additional modes (supported in SVG)
        case .plusDarker: return "plus-darker"
        case .plusLighter: return "plus-lighter"
        }
    }
}

