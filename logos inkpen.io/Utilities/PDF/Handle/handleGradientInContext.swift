//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func handleGradientInContext(gradient: VectorGradient) {
        print("PDF: 🎯 CONTEXT-BASED GRADIENT APPLICATION")
        
        // Check the current PDF parsing context to determine how to apply the gradient
        if !currentPath.isEmpty {
            // Case 1: We have a current path - create a shape immediately with this gradient
            print("PDF: 🔥 DIRECT PATH GRADIENT - Creating shape immediately from current path")
            createShapeFromCurrentPath(filled: true, stroked: false, customFillStyle: FillStyle(gradient: gradient))
            
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            // Case 2: We're building compound paths - gradient applies to the compound shape
            print("PDF: 🔗 COMPOUND PATH GRADIENT - Shading applies to compound shape being built")
            activeGradient = gradient
            // This will be applied during compound path creation
            
        } else {
            // Case 3: Standalone shading - create a shape from the shading itself
            print("PDF: 🎨 STANDALONE SHADING - Creating shape directly from shading")
            createShapeFromShading(gradient: gradient)
        }
    }
}
