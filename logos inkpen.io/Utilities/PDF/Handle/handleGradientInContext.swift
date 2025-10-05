//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func handleGradientInContext(gradient: VectorGradient) {
        
        // Check the current PDF parsing context to determine how to apply the gradient
        if !currentPath.isEmpty {
            // Case 1: We have a current path - create a shape immediately with this gradient
            createShapeFromCurrentPath(filled: true, stroked: false, customFillStyle: FillStyle(gradient: gradient))

            // CRITICAL: Clear compound path state after gradient shape creation
            compoundPathParts.removeAll()
            isInCompoundPath = false
            
        } else if isInCompoundPath || !compoundPathParts.isEmpty {
            // Case 2: We're building compound paths - gradient applies to the compound shape

            // Create the gradient compound shape immediately
            if !compoundPathParts.isEmpty || !currentPath.isEmpty {
                activeGradient = gradient
                createCompoundShapeFromParts(filled: true, stroked: false)
                // Clear state to prevent duplicate flat shape creation
                compoundPathParts.removeAll()
                currentPath.removeAll()
                isInCompoundPath = false
                activeGradient = nil
            }
            
        } else {
            // Case 3: Standalone shading - create a shape from the shading itself
            createShapeFromShading(gradient: gradient)
        }
    }
}
