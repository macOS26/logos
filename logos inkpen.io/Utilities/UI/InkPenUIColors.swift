//
//  UIColors.swift
//  logos inkpen.io
//
//  Centralized UI color system with Dark/Light mode support
//  Consolidates duplicate color constants used throughout the app
//

import SwiftUI
import Combine


/// Centralized UI color system that adapts to Dark and Light modes
/// Access colors via UIColors.shared.colorName
class InkPenUIColors: ObservableObject {
    static let shared = InkPenUIColors()
    
    private init() {}
    
    // MARK: - Background Colors
    
    /// Primary window background that adapts to system appearance
    var windowBackground: Color {
        Color(NSColor.windowBackgroundColor)
    }
    
    /// Control background for panels, toolbars, etc.
    var controlBackground: Color {
        Color(NSColor.controlBackgroundColor)
    }
    
    /// Light gray background for containers and panels
    var lightGrayBackground: Color {
        Color.gray.opacity(0.1)
    }
    
    /// Very light gray background for subtle containers
    var veryLightGrayBackground: Color {
        Color.gray.opacity(0.05)
    }
    
    /// Medium gray background for intermediate elements
    var mediumGrayBackground: Color {
        Color.gray.opacity(0.2)
    }
    
    /// Semi-transparent control background for overlays
    var semiTransparentControlBackground: Color {
        Color(NSColor.controlBackgroundColor).opacity(0.5)
    }
    
    // MARK: - Accent and Selection Colors

    /// Primary blue accent color for selections and highlights - Using P3 system blue
    var primaryBlue: Color {
        // P3 system blue for vibrant UI
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 1.0, source: ColorManager.shared.displayP3CG)
    }

    /// Light blue background for selection states
    var lightBlueBackground: Color {
        // P3 system blue with opacity
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 0.1, source: ColorManager.shared.displayP3CG)
    }

    /// Medium blue for active states
    var mediumBlueBackground: Color {
        // P3 system blue with opacity
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 0.6, source: ColorManager.shared.displayP3CG)
    }

    /// Very light blue for subtle highlights
    var veryLightBlueBackground: Color {
        // P3 system blue with opacity
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 0.05, source: ColorManager.shared.displayP3CG)
    }

    /// Strong blue for selected tools (full opacity to match lock button)
    var toolSelectionBlue: Color {
        // P3 system blue with full opacity for tool selection
        ColorManager.shared.makeColor(r: 0.0, g: 0.478, b: 1.0, a: 1.0, source: ColorManager.shared.displayP3CG)
    }
    
    /// Accent color that adapts to system settings
    var accentColor: Color {
        Color.accentColor
    }
    
    /// Light accent background
    var lightAccentBackground: Color {
        Color.accentColor.opacity(0.1)
    }
    
    /// Medium accent background
    var mediumAccentBackground: Color {
        Color.accentColor.opacity(0.3)
    }
    
    // MARK: - Border and Stroke Colors
    
    /// Standard gray border color
    var standardBorder: Color {
        Color.gray
    }
    
    /// Light gray border for subtle divisions
    var lightGrayBorder: Color {
        Color.gray.opacity(0.3)
    }
    
    /// Very light gray border
    var veryLightGrayBorder: Color {
        Color.gray.opacity(0.2)
    }
    
    /// Separator color that adapts to system
    var separator: Color {
        Color(NSColor.separatorColor)
    }
    
    // MARK: - Text Colors
    
    /// Primary text color that adapts to system
    var primaryText: Color {
        Color.primary
    }
    
    /// Secondary text color that adapts to system
    var secondaryText: Color {
        Color.secondary
    }
    
    /// Label color for form labels
    var labelColor: Color {
        Color(NSColor.labelColor)
    }
    
    /// Secondary label color
    var secondaryLabelColor: Color {
        Color(NSColor.secondaryLabelColor)
    }
    
    /// Tertiary label color for less important text
    var tertiaryLabelColor: Color {
        Color(NSColor.tertiaryLabelColor)
    }
    
    // MARK: - Overlay and Modal Colors
    
    /// Dark overlay for modals and popovers
    var darkOverlay: Color {
        Color.black.opacity(0.8)
    }
    
    /// Semi-dark overlay
    var semiDarkOverlay: Color {
        Color.black.opacity(0.9)
    }
    
    /// Light modal background
    var modalBackground: Color {
        Color.black.opacity(0.3)
    }
    
    // MARK: - Status and State Colors
    
    /// Success/positive state color
    var successColor: Color {
        Color.green
    }
    
    /// Light success background
    var lightSuccessBackground: Color {
        Color.green.opacity(0.1)
    }
    
    /// Warning/caution color
    var warningColor: Color {
        Color.orange
    }
    
    /// Light warning background
    var lightWarningBackground: Color {
        Color.orange.opacity(0.1)
    }
    
    /// Error/danger color
    var errorColor: Color {
        Color.red
    }
    
    /// Light error background
    var lightErrorBackground: Color {
        Color.red.opacity(0.1)
    }
    
    /// Light error background (alternative)
    var lightErrorBackground2: Color {
        Color.red.opacity(0.2)
    }
    
    // MARK: - Special UI Colors
    
    /// Clear/transparent color
    var clear: Color {
        Color.clear
    }
    
    /// Pure white color
    var white: Color {
        Color.white
    }
    
    /// Pure black color
    var black: Color {
        Color.black
    }
    
    /// White with high opacity for overlays
    var whiteOverlay: Color {
        Color.white.opacity(0.9)
    }
    
    /// White with medium opacity
    var whiteMediumOverlay: Color {
        Color.white.opacity(0.3)
    }
    
    // MARK: - Tool and Editor Colors

    /// Orange color for tools and editing states - Using P3 vibrant orange
    var toolOrange: Color {
        // P3 vibrant orange for UI consistency
        ColorManager.shared.makeColor(r: 1.0, g: 0.584, b: 0.0, a: 1.0, source: ColorManager.shared.displayP3CG)
    }

    /// Orange with opacity for tool backgrounds
    var lightToolOrange: Color {
        // P3 vibrant orange with opacity
        ColorManager.shared.makeColor(r: 1.0, g: 0.584, b: 0.0, a: 0.8, source: ColorManager.shared.displayP3CG)
    }
    
    /// Purple for special UI elements
    var specialPurple: Color {
        Color.purple
    }
    
    /// Light purple background
    var lightPurpleBackground: Color {
        Color.purple.opacity(0.2)
    }
    
    /// Light purple background (alternative)
    var veryLightPurpleBackground: Color {
        Color.purple.opacity(0.1)
    }
    
    // MARK: - Content and Drawing Colors
    
    /// Text background color
    var textBackground: Color {
        Color(NSColor.textBackgroundColor)
    }
    
    /// Fill color for drawing backgrounds
    var drawingBackground: Color {
        Color(NSColor.textBackgroundColor)
    }
    
    // MARK: - Utility Methods
    
    /// Returns a color with custom opacity
    func color(_ baseColor: Color, opacity: Double) -> Color {
        baseColor.opacity(opacity)
    }
    
    /// Returns a system color with custom opacity
    func systemColor(_ nsColor: NSColor, opacity: Double = 1.0) -> Color {
        Color(nsColor).opacity(opacity)
    }
}

// MARK: - Convenience Extensions

extension Color {
    /// Quick access to shared UIColors instance
    static var ui: InkPenUIColors {
        InkPenUIColors.shared
    }
}
