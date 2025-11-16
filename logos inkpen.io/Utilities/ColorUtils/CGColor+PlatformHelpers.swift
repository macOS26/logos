import Foundation
import CoreGraphics
import SwiftUI

#if canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#elseif canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#endif

extension Color {
    static var platformControlBackground: Color {
        #if canImport(AppKit)
        return Color(NSColor.controlBackgroundColor)
        #elseif canImport(UIKit)
        return Color(UIColor.systemBackground)
        #endif
    }
}

extension CGColor {
    /// Converts CGColor to platform-specific color (NSColor on macOS, UIColor on iOS/iPadOS)
    var platformColor: PlatformColor {
        #if canImport(AppKit)
        return NSColor(cgColor: self) ?? NSColor.black
        #elseif canImport(UIKit)
        return UIColor(cgColor: self)
        #endif
    }

    /// Common color constants as CGColor
    static var black: CGColor {
        CGColor(red: 0, green: 0, blue: 0, alpha: 1)
    }

    static var white: CGColor {
        CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    }

    static var clear: CGColor {
        CGColor(red: 0, green: 0, blue: 0, alpha: 0)
    }

    /// Extract RGBA components from CGColor, converting to RGB if needed
    var rgbaComponents: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let components = self.components else {
            return (0, 0, 0, 1)
        }

        let numComponents = self.numberOfComponents

        if numComponents == 4 {
            // RGB or CMYK color space
            return (components[0], components[1], components[2], components[3])
        } else if numComponents == 2 {
            // Grayscale
            return (components[0], components[0], components[0], components[1])
        } else if numComponents >= 3 {
            // At least RGB
            let alpha = numComponents > 3 ? components[3] : 1.0
            return (components[0], components[1], components[2], alpha)
        }

        return (0, 0, 0, 1)
    }

    /// Create CGColor with alpha component
    func withAlpha(_ alpha: CGFloat) -> CGColor {
        let rgba = self.rgbaComponents
        return CGColor(red: rgba.r, green: rgba.g, blue: rgba.b, alpha: alpha)
    }
}
