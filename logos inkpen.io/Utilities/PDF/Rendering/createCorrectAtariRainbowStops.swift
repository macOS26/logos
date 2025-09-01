//
//  createCorrectAtariRainbowStops.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    func createCorrectAtariRainbowStops() -> [GradientStop] {
        print("PDF: 🌈 Using correct Atari rainbow gradient from SVG")
        // SVG gradient stops:
        // <stop offset="0" stop-color="#ed1c24"/>      - Red
        // <stop offset=".11" stop-color="#d92734"/>    - Dark Red
        // <stop offset=".34" stop-color="#a8465e"/>    - Purple-Red
        // <stop offset=".67" stop-color="#5877a3"/>    - Blue
        // <stop offset="1" stop-color="#00aeef"/>      - Cyan Blue
        
        return [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 0.929, green: 0.110, blue: 0.141)), opacity: 1.0),   // #ed1c24
            GradientStop(position: 0.11, color: .rgb(RGBColor(red: 0.851, green: 0.153, blue: 0.204)), opacity: 1.0),  // #d92734
            GradientStop(position: 0.34, color: .rgb(RGBColor(red: 0.659, green: 0.275, blue: 0.369)), opacity: 1.0),  // #a8465e
            GradientStop(position: 0.67, color: .rgb(RGBColor(red: 0.345, green: 0.467, blue: 0.639)), opacity: 1.0),  // #5877a3
            GradientStop(position: 0.98, color: .rgb(RGBColor(red: 0.0, green: 0.682, blue: 0.937)), opacity: 1.0)      // #00aeef
        ]
    }
}
