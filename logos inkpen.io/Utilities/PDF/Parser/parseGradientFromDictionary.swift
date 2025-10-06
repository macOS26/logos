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
        
        
        switch shadingType {
        case 2: // Axial (linear) shading
            return parseLinearGradient(from: dict)
        case 3: // Radial shading
            return parseRadialGradient(from: dict)
        default:
            return nil
        }
    }
}
