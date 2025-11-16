import Foundation

#if os(macOS)
import AppKit
/// Platform-specific font type (NSFont on macOS, UIFont on iOS)
///
/// Usage:
///   let font = PlatformFont(name: "Helvetica", size: 24)
///   let systemFont = PlatformFont.systemFont(ofSize: 12)
///   let size = PlatformFont.smallSystemFontSize
///
/// All NSFont/UIFont methods are available directly via the typealias.
public typealias PlatformFont = NSFont

#elseif os(iOS)
import UIKit
/// Platform-specific font type (NSFont on macOS, UIFont on iOS)
///
/// Usage:
///   let font = PlatformFont(name: "Helvetica", size: 24)
///   let systemFont = PlatformFont.systemFont(ofSize: 12)
///   let size = PlatformFont.smallSystemFontSize
///
/// All NSFont/UIFont methods are available directly via the typealias.
public typealias PlatformFont = UIFont
#endif
