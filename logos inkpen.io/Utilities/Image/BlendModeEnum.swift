//
//  BlendMode.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Blend Modes (PDF + SVG Intersection)
// Only includes blend modes supported by BOTH PDF (ISO 32000) AND SVG (CSS Compositing Level 1)
enum BlendMode: String, CaseIterable, Codable {
    // Standard blend modes (supported in PDF 1.4+ and SVG)
    case normal = "Normal"
    case multiply = "Multiply"
    case screen = "Screen"
    case overlay = "Overlay"
    case darken = "Darken"
    case lighten = "Lighten"
    case colorDodge = "Color Dodge"
    case colorBurn = "Color Burn"
    case hardLight = "Hard Light"
    case softLight = "Soft Light"
    case difference = "Difference"
    case exclusion = "Exclusion"
    case hue = "Hue"
    case saturation = "Saturation"
    case color = "Color"
    case luminosity = "Luminosity"

    /// Display name for UI
    var displayName: String {
        return rawValue
    }

    /// Custom decoder that falls back to .normal for invalid/removed blend modes
    /// This allows opening old .inkpen files that used removed blend modes (sourceAtop, plusDarker, etc.)
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        // Try to initialize from raw value
        if let mode = BlendMode(rawValue: rawValue) {
            self = mode
        } else {
            // Unknown/removed blend mode - fall back to normal and log warning
            Log.fileOperation("⚠️ Unknown blend mode '\(rawValue)' found - using .normal instead", level: .warning)
            self = .normal
        }
    }

    /// Convert to CGBlendMode for PDF/PNG export
    var cgBlendMode: CGBlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .hardLight: return .hardLight
        case .softLight: return .softLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }

    /// Convert to SVG mix-blend-mode for SVG export
    var svgBlendMode: String {
        switch self {
        case .normal: return "normal"
        case .multiply: return "multiply"
        case .screen: return "screen"
        case .overlay: return "overlay"
        case .darken: return "darken"
        case .lighten: return "lighten"
        case .colorDodge: return "color-dodge"
        case .colorBurn: return "color-burn"
        case .hardLight: return "hard-light"
        case .softLight: return "soft-light"
        case .difference: return "difference"
        case .exclusion: return "exclusion"
        case .hue: return "hue"
        case .saturation: return "saturation"
        case .color: return "color"
        case .luminosity: return "luminosity"
        }
    }

    /// Convert to SwiftUI BlendMode for UI rendering
    /// Note: SwiftUI only supports a subset of blend modes
    var swiftUIBlendMode: SwiftUI.BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .darken: return .darken
        case .lighten: return .lighten
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .hardLight: return .hardLight
        case .softLight: return .softLight
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }
}

