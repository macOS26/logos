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

    // Porter-Duff compositing modes
    case clear = "Clear"
    case copy = "Copy"
    case sourceIn = "Source In"
    case sourceOut = "Source Out"
    case sourceAtop = "Source Atop"
    case destinationOver = "Destination Over"
    case destinationIn = "Destination In"
    case destinationOut = "Destination Out"
    case destinationAtop = "Destination Atop"
    case xor = "XOR"

    // Additional modes
    case plusDarker = "Plus Darker"
    case plusLighter = "Plus Lighter"

    /// Display name for UI
    var displayName: String {
        return rawValue
    }

    /// Convert to CGBlendMode for PDF export
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
        case .clear: return .clear
        case .copy: return .copy
        case .sourceIn: return .sourceIn
        case .sourceOut: return .sourceOut
        case .sourceAtop: return .sourceAtop
        case .destinationOver: return .destinationOver
        case .destinationIn: return .destinationIn
        case .destinationOut: return .destinationOut
        case .destinationAtop: return .destinationAtop
        case .xor: return .xor

        // Additional modes
        case .plusDarker: return .plusDarker
        case .plusLighter: return .plusLighter
        }
    }

    /// Convert to SVG mix-blend-mode for SVG export
    /// Note: Porter-Duff modes are not supported in SVG and fall back to "normal"
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
        case .clear: return "normal"
        case .copy: return "normal"
        case .sourceIn: return "normal"
        case .sourceOut: return "normal"
        case .sourceAtop: return "normal"
        case .destinationOver: return "normal"
        case .destinationIn: return "normal"
        case .destinationOut: return "normal"
        case .destinationAtop: return "normal"
        case .xor: return "normal"

        // Additional modes (plus-lighter and plus-darker are supported in SVG)
        case .plusDarker: return "plus-darker"
        case .plusLighter: return "plus-lighter"
        }
    }
}

