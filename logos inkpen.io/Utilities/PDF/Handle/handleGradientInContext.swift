//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func handleGradientInContext(gradient: VectorGradient) {
        Log.info("PDF: 🎯 CONTEXT-BASED GRADIENT APPLICATION", category: .general)
        
        // Check the current PDF parsing context to determine how to apply the gradient
        if !currentPath.isEmpty {
            // Case 1: We have a current path - create a shape immediately with this gradient
            Log.info("PDF: 🔥 DIRECT PATH GRADIENT - Creating shape immediately from current path", category: .general)
            createShapeFromCurrentPath(filled: true, stroked: false, customFillStyle: FillStyle(gradient: gradient))
            
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            // Case 2: We're building compound paths - gradient applies to the compound shape
            Log.info("PDF: 🔗 COMPOUND PATH GRADIENT - Shading applies to compound shape being built", category: .general)
            activeGradient = gradient
            // This will be applied during compound path creation
            
        } else {
            // Case 3: Standalone shading - create a shape from the shading itself
            Log.info("PDF: 🎨 STANDALONE SHADING - Creating shape directly from shading", category: .general)
            createShapeFromShading(gradient: gradient)
        }
    }
}
