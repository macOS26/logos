//
//  SPOTColor.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - SPOT Color Library (Professional Grade)
struct SPOTColor: Codable, Hashable {
    var number: String
    var name: String
    var rgbEquivalent: RGBColor
    var cmykEquivalent: CMYKColor
    var hsbEquivalent: HSBColorModel
    var alpha: Double

    var color: Color {
        // Pantone is stored with sRGB equivalents; present in working space
        return ColorManager.shared.makeColor(r: rgbEquivalent.red, g: rgbEquivalent.green, b: rgbEquivalent.blue, a: alpha, source: ColorManager.shared.sRGBCG)
    }
}