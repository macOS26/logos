//
//  extractColorsFromFunction.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractColorsFromFunction(_ function: CGPDFDictionaryRef) -> (VectorColor, VectorColor) {
        
        // Debug: Print all keys in the function dictionary
        CGPDFDictionaryApplyFunction(function, { (_, _, _) in
        }, nil)
        
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        var colors: [VectorColor] = []
        
        switch functionType {
        case 0: // Sampled function
            colors = extractColorsFromSampledFunction(function)
            
        case 2: // Exponential interpolation function
            // Get C0 and C1 arrays (start and end colors)
            var c0Array: CGPDFArrayRef?
            var c1Array: CGPDFArrayRef?
            
            var startColor = VectorColor.black
            var endColor = VectorColor.white
            
            if CGPDFDictionaryGetArray(function, "C0", &c0Array),
               let c0 = c0Array {
                startColor = extractColorFromArray(c0)
            } else {
                // Log.error("PDF: ❌ No C0 array found in function", category: .error)
            }
            
            if CGPDFDictionaryGetArray(function, "C1", &c1Array),
               let c1 = c1Array {
                endColor = extractColorFromArray(c1)
            } else {
                // Log.error("PDF: ❌ No C1 array found in function", category: .error)
            }
            
            colors = [startColor, endColor]
            
        case 3: // Stitching function
            colors = [.black, .white]
            
        default:
            // Log.error("PDF: ❌ Unsupported function type \(functionType)", category: .error)
            colors = [.black, .white]
        }
        
        // Create gradient stops from all colors
        
        // For now, still return start/end for compatibility, but we have all colors
        return (colors.first ?? .black, colors.last ?? .white)
    }
}
