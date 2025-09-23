//
//  extractColorsFromFunction.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractColorsFromFunction(_ function: CGPDFDictionaryRef) -> (VectorColor, VectorColor) {
        print("PDF: 🔍 DEBUG: Examining function dictionary for colors...")
        
        // Debug: Print all keys in the function dictionary
        CGPDFDictionaryApplyFunction(function, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            print("PDF: 🔑 Function key: '\(keyString)' -> type: \(objectType.rawValue)")
        }, nil)
        
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        var colors: [VectorColor] = []
        
        switch functionType {
        case 0: // Sampled function
            print("PDF: 📊 Processing sampled function (Type 0)")
            colors = extractColorsFromSampledFunction(function)
            
        case 2: // Exponential interpolation function
            print("PDF: 📊 Processing exponential function (Type 2)")
            // Get C0 and C1 arrays (start and end colors)
            var c0Array: CGPDFArrayRef?
            var c1Array: CGPDFArrayRef?
            
            var startColor = VectorColor.black
            var endColor = VectorColor.white
            
            if CGPDFDictionaryGetArray(function, "C0", &c0Array),
               let c0 = c0Array {
                startColor = extractColorFromArray(c0)
                print("PDF: ✅ Found C0 color: \(startColor)")
            } else {
                print("PDF: ❌ No C0 array found in function")
            }
            
            if CGPDFDictionaryGetArray(function, "C1", &c1Array),
               let c1 = c1Array {
                endColor = extractColorFromArray(c1)
                print("PDF: ✅ Found C1 color: \(endColor)")
            } else {
                print("PDF: ❌ No C1 array found in function")
            }
            
            colors = [startColor, endColor]
            
        case 3: // Stitching function
            print("PDF: 📊 Processing stitching function (Type 3) - using default colors for now")
            colors = [.black, .white]
            
        default:
            print("PDF: ❌ Unsupported function type \(functionType)")
            colors = [.black, .white]
        }
        
        // Create gradient stops from all colors
        print("PDF: 🎨 Creating gradient stops from \(colors.count) colors")
        
        // For now, still return start/end for compatibility, but we have all colors
        return (colors.first ?? .black, colors.last ?? .white)
    }
}
