//
//  Color.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

// Helper extension for Color components
extension Color {
    var components: (red: Double, green: Double, blue: Double, alpha: Double) {
        let baseNSColor = NSColor(self)
        
        if let converted = baseNSColor.usingColorSpace(NSColorSpace.sRGB) ?? baseNSColor.usingColorSpace(NSColorSpace.deviceRGB) {
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            converted.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b), Double(a))
        }
        
        let cg = baseNSColor.cgColor
        if let comps = cg.components {
            if cg.numberOfComponents == 2 {
                let v = comps[0]
                let a = comps[1]
                return (Double(v), Double(v), Double(v), Double(a))
            } else if cg.numberOfComponents >= 4 {
                return (Double(comps[0]), Double(comps[1]), Double(comps[2]), Double(comps[3]))
            }
        }
        
        return (0, 0, 0, 1)
    }
}

