//
//  SwiftUIExtensions.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// Extensions for SwiftUI compatibility
extension BlendMode {
    var swiftUIBlendMode: SwiftUI.BlendMode {
        switch self {
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
        }
    }
}

extension CGLineCap {
    var swiftUILineCap: SwiftUI.CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        @unknown default: return .butt
        }
    }
}

extension CGLineJoin {
    var swiftUILineJoin: SwiftUI.CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        @unknown default: return .miter
        }
    }
}
