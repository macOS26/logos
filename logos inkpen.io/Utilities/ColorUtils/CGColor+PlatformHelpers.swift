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
}
