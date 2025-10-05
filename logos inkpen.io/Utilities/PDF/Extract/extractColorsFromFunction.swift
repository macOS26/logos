//
//  extractColorsFromFunction.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractColorsFromFunction(_ function: CGPDFDictionaryRef) -> (VectorColor, VectorColor) {
        Log.info("PDF: 🔍 DEBUG: Examining function dictionary for colors...", category: .debug)
        
        // Debug: Print all keys in the function dictionary
        CGPDFDictionaryApplyFunction(function, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            Log.info("PDF: 🔑 Function key: '\(keyString)' -> type: \(objectType.rawValue)", category: .general)
        }, nil)
        
        // Check function type
        var functionType: CGPDFInteger = 0
        CGPDFDictionaryGetInteger(function, "FunctionType", &functionType)
        
        var colors: [VectorColor] = []
        
        switch functionType {
        case 0: // Sampled function
            Log.info("PDF: 📊 Processing sampled function (Type 0)", category: .debug)
            colors = extractColorsFromSampledFunction(function)
            
        case 2: // Exponential interpolation function
            Log.info("PDF: 📊 Processing exponential function (Type 2)", category: .debug)
            // Get C0 and C1 arrays (start and end colors)
            var c0Array: CGPDFArrayRef?
            var c1Array: CGPDFArrayRef?
            
            var startColor = VectorColor.black
            var endColor = VectorColor.white
            
            if CGPDFDictionaryGetArray(function, "C0", &c0Array),
               let c0 = c0Array {
                startColor = extractColorFromArray(c0)
                Log.info("PDF: ✅ Found C0 color: \(startColor)", category: .general)
            } else {
                Log.error("PDF: ❌ No C0 array found in function", category: .error)
            }
            
            if CGPDFDictionaryGetArray(function, "C1", &c1Array),
               let c1 = c1Array {
                endColor = extractColorFromArray(c1)
                Log.info("PDF: ✅ Found C1 color: \(endColor)", category: .general)
            } else {
                Log.error("PDF: ❌ No C1 array found in function", category: .error)
            }
            
            colors = [startColor, endColor]
            
        case 3: // Stitching function
            Log.info("PDF: 📊 Processing stitching function (Type 3) - using default colors for now", category: .debug)
            colors = [.black, .white]
            
        default:
            Log.error("PDF: ❌ Unsupported function type \(functionType)", category: .error)
            colors = [.black, .white]
        }
        
        // Create gradient stops from all colors
        Log.info("PDF: 🎨 Creating gradient stops from \(colors.count) colors", category: .general)
        
        // For now, still return start/end for compatibility, but we have all colors
        return (colors.first ?? .black, colors.last ?? .white)
    }
}
