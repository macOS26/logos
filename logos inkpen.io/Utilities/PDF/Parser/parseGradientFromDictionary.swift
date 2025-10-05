//
//  parseGradientFromDictionary.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    // Parse gradient from PDF dictionary
    func parseGradientFromDictionary(_ dict: CGPDFDictionaryRef) -> VectorGradient? {
        // Get shading type
        var shadingType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(dict, "ShadingType", &shadingType)
        
        Log.info("PDF: Found shading type \(shadingType)", category: .general)
        
        switch shadingType {
        case 2: // Axial (linear) shading
            return parseLinearGradient(from: dict)
        case 3: // Radial shading
            return parseRadialGradient(from: dict)
        default:
            Log.info("PDF: Unsupported shading type \(shadingType)", category: .general)
            return nil
        }
    }
}
