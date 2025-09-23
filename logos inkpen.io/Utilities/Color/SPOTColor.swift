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

    init(number: String, name: String, rgbEquivalent: RGBColor, cmykEquivalent: CMYKColor, alpha: Double = 1.0) {
        self.number = number
        self.name = name
        self.rgbEquivalent = rgbEquivalent
        self.cmykEquivalent = cmykEquivalent
        self.hsbEquivalent = HSBColorModel.fromRGB(rgbEquivalent)
        self.alpha = alpha
    }

    var color: Color {
        // Pantone is stored with sRGB equivalents; present in working space
        return ColorManager.shared.makeColor(r: rgbEquivalent.red, g: rgbEquivalent.green, b: rgbEquivalent.blue, a: alpha, source: ColorManager.shared.sRGBCG)
    }
}