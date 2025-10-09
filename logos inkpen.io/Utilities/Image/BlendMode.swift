//
//  BlendMode.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI

// Extensions for SwiftUI compatibility
extension BlendMode {
    var swiftUIBlendMode: SwiftUI.BlendMode {
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
        case .clear: return .sourceAtop  // SwiftUI doesn't have .clear, use closest equivalent
        case .copy: return .normal  // SwiftUI doesn't have .copy, fallback to normal
        case .sourceIn: return .sourceAtop  // SwiftUI doesn't have .sourceIn, use closest equivalent
        case .sourceOut: return .sourceAtop  // SwiftUI doesn't have .sourceOut, use closest equivalent
        case .sourceAtop: return .sourceAtop
        case .destinationOver: return .destinationOver
        case .destinationIn: return .sourceAtop  // SwiftUI doesn't have .destinationIn, use closest equivalent
        case .destinationOut: return .destinationOut
        case .destinationAtop: return .sourceAtop  // SwiftUI doesn't have .destinationAtop, use closest equivalent
        case .xor: return .sourceAtop  // SwiftUI doesn't have .xor, use closest equivalent

        // Additional modes
        case .plusDarker: return .plusDarker
        case .plusLighter: return .plusLighter
        }
    }
}

