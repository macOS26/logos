//
//  TypographyHelper.swift
//  logos inkpen.io
//
//  Helper functions for typography that don't use deprecated fontStyle
//

import Foundation

extension TypographyProperties {

    /// Check if this typography uses italic style by checking variant name
    var isItalic: Bool {
        guard let variant = fontVariant else { return false }
        let lowercased = variant.lowercased()
        return lowercased.contains("italic") || lowercased.contains("oblique")
    }

    /// Get SVG font-style attribute value
    var svgFontStyle: String? {
        return isItalic ? "italic" : nil
    }
}
