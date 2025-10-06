//
//  applyGradientToWhiteShapes.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func applyGradientToWhiteShapes(gradient: VectorGradient) {
        // Log.info("PDF: 🔍 Gradient/shading operation encountered - analyzing context", category: .debug)
        
        // Set the active gradient for any shapes that follow this shading command
        activeGradient = gradient
        gradientShapes.removeAll()
        
        // SMART GRADIENT DETECTION: Determine if this gradient needs compound path or applies to single shape
        // Check if we have a current path being built (indicating single shape gradient)
        // or if we have compound path parts (indicating compound path gradient)
        
        if !currentPath.isEmpty {
            // Case 1: We have a current path - this gradient applies to the shape being built
            // Log.info("PDF: 🎯 SINGLE SHAPE GRADIENT - Current path exists, gradient will apply to next shape", category: .general)
            // activeGradient will be picked up by the next fill operation
            
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            // Case 2: We're building a compound path - gradient applies to compound shape
            // Log.info("PDF: 🔗 COMPOUND PATH GRADIENT - No current path, gradient for compound shape", category: .general)
            // Look for existing white shapes to retroactively apply gradient
            
            // Find recent white shapes that should be part of this compound path
            let recentShapeCount = min(5, shapes.count) // Look at last 5 shapes
            let startIndex = max(0, shapes.count - recentShapeCount)
            
            for i in startIndex..<shapes.count {
                let shape = shapes[i]
                if let fillStyle = shape.fillStyle,
                   case .rgb(let rgbColor) = fillStyle.color,
                   rgbColor.red > 0.95 && rgbColor.green > 0.95 && rgbColor.blue > 0.95 {
                    // This is a white shape - mark it for gradient application
                    gradientShapes.append(i)
                    // Log.info("PDF: 📝 Tagged white shape '\(shape.name)' for compound gradient", category: .general)
                }
            }
            
        } else {
            // Case 3: No current path and no compound path - gradient for next shape created
            // Log.info("PDF: 🎯 STANDALONE GRADIENT - No current path or compound, gradient for next shape", category: .general)
        }
        
        // Log.info("PDF: 🎨 Gradient marked as active - detection mode determined", category: .general)
        // Log.info("PDF: 📊 Tagged \(gradientShapes.count) white shapes for compound path (if applicable)", category: .debug)
    }
}
