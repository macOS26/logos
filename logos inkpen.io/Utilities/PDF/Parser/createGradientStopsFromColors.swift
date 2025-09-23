//
//  createGradientStopsFromColors.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func createGradientStopsFromColors(_ colors: [VectorColor]) -> [GradientStop] {
        guard colors.count > 1 else {
            return [GradientStop(position: 0.0, color: colors.first ?? .black, opacity: 1.0)]
        }
        
        // Sub-sample to reduce from ~1000 stops to 11 stops (0%, 10%, 20%, ..., 100%)
        let targetStops = 11
        let subSampledColors = subsampleColors(colors, targetCount: targetStops)
        
        var stops: [GradientStop] = []
        
        // Create stops at 10% intervals
        for i in 0..<targetStops {
            let position = Double(i) / Double(targetStops - 1) // 0.0, 0.1, 0.2, ..., 1.0
            let colorIndex = min(i, subSampledColors.count - 1)
            let color = subSampledColors[colorIndex]
            
            stops.append(GradientStop(position: position, color: color, opacity: 1.0))
            print("PDF: 📍 Sub-sampled gradient stop at \(Int(position * 100))%: \(color)")
        }
        
        return stops
    }
}
