//
//  createGradientFromShading.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func createGradientFromShading(from shadingDict: CGPDFDictionaryRef? = nil) -> VectorGradient {
        Log.info("PDF: 🌈 Creating gradient with proper transformation from PDF stream data", category: .general)
        
        var stops: [GradientStop] = []
        
        // Try to extract actual gradient stops from PDF stream if dictionary is provided
        if let shadingDict = shadingDict {
            stops = extractGradientStopsFromPDFStream(shadingDict: shadingDict)
            Log.info("PDF: 📊 Extracted \(stops.count) stops from PDF stream", category: .debug)
        }
        
        // If no stops were extracted, this is an error - we should never use hardcoded stops
        if stops.isEmpty {
            Log.error("PDF: ❌ CRITICAL ERROR: No gradient stops extracted from PDF stream!", category: .error)
            Log.error("PDF: ❌ Cannot create gradient without actual PDF data", category: .error)
            // Return a simple two-color gradient as absolute fallback
            stops = [
                GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), opacity: 1.0),
                GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)), opacity: 1.0)
            ]
        }
        
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
        
        Log.info("PDF: ✅ Created gradient with \(stops.count) stops from PDF stream data, angle: \(correctedAngle)°", category: .general)
        return .linear(linearGradient)
    }
}
