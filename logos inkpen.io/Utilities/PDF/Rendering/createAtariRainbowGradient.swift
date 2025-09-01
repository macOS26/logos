//
//  createAtariRainbowGradient.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    func createAtariRainbowGradient() -> VectorGradient {
        print("PDF: 🌈 Creating Atari rainbow gradient with proper transformation")
        
        // Create the correct Atari rainbow gradient
        let stops = createCorrectAtariRainbowStops()
        
        // Use the transformation matrix to create the correct gradient angle
        let ctmAngle = atan2(currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        let correctedAngle = -ctmAngle  // Flip for screen coordinates
        
        var linearGradient = LinearGradient(
            startPoint: CGPoint(x: 0.0, y: 0.5),
            endPoint: CGPoint(x: 1.0, y: 0.5),
            stops: stops,
            spreadMethod: GradientSpreadMethod.pad
        )
        
        // Apply the transformation matrix angle
        linearGradient.storedAngle = correctedAngle
        
        print("PDF: ✅ Created Atari rainbow gradient with angle: \(correctedAngle)°")
        return .linear(linearGradient)
    }
}
