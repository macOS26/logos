//
//  createCompoundPathWithGradient.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func createCompoundPathWithGradient(gradient: VectorGradient) {
        // Use the tracked gradient shapes instead of hardcoded logic
        guard !gradientShapes.isEmpty else {
            print("PDF: ⚠️ No gradient shapes tracked")
            return
        }
        
        print("PDF: 🔍 Creating compound path from \(gradientShapes.count) tracked gradient shapes")
        
        var combinedPaths: [VectorPath] = []
        
        // Get the shapes that were marked for this gradient
        for shapeIndex in gradientShapes {
            if shapeIndex < shapes.count {
                let shape = shapes[shapeIndex]
                combinedPaths.append(shape.path)
                print("PDF: 📝 Adding tracked shape '\(shape.name)' to compound path")
            }
        }
        
        // Remove the individual shapes (in reverse order to maintain indices)
        for shapeIndex in gradientShapes.sorted(by: >) {
            if shapeIndex < shapes.count {
                shapes.remove(at: shapeIndex)
            }
        }
        
        // Combine all path elements into one compound path
        var allElements: [PathElement] = []
        for path in combinedPaths {
            allElements.append(contentsOf: path.elements)
        }
        
        let compoundPath = VectorPath(elements: allElements, isClosed: false, fillRule: .evenOdd)
        let fillStyle = FillStyle(gradient: gradient)
        
        let compoundShape = VectorShape(
            name: "PDF Compound Shape (Gradient)",
            path: compoundPath,
            strokeStyle: nil,
            fillStyle: fillStyle
        )
        
        shapes.append(compoundShape)
        print("PDF: ✅ Created compound shape with \(combinedPaths.count) subpaths")
        
        // Clear the tracking for next gradient
        gradientShapes.removeAll()
        activeGradient = nil
    }
}
