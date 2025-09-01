//
//  extractAllColorsFromFunction.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    func extractAllColorsFromFunction(_ function: CGPDFDictionaryRef) -> [VectorColor] {
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        switch functionType {
        case 0: // Sampled function
            return extractColorsFromSampledFunction(function)
        case 2: // Exponential interpolation function
            let (start, end) = extractColorsFromFunction(function)
            return [start, end]
        default:
            return [.black, .white]
        }
    }
}