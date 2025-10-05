//
//  extractGradientStopsFromPDFStream.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractGradientStopsFromPDFStream(shadingDict: CGPDFDictionaryRef) -> [GradientStop] {
        
        // DEBUG: Print all keys in the shading dictionary first
        CGPDFDictionaryApplyFunction(shadingDict, { (key, _, _) in
            let keyString = String(cString: key)

            // Look for Adobe private data or additional references
            if keyString.hasPrefix("Adobe") || keyString.hasPrefix("AI") || keyString.hasPrefix("Private") {
            }
        }, nil)
        
        // Check if there are any additional references to gradient objects
        var additionalRefs: CGPDFObjectRef?
        if CGPDFDictionaryGetObject(shadingDict, "GradientStops", &additionalRefs) ||
           CGPDFDictionaryGetObject(shadingDict, "Adobe", &additionalRefs) ||
           CGPDFDictionaryGetObject(shadingDict, "AI", &additionalRefs) {
        }
        
        // Get the Function object from the shading dictionary
        var functionObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, "Function", &functionObj),
              let funcObj = functionObj else {
            Log.error("PDF: ❌ No Function found in shading dictionary - falling back to subsampling", category: .error)
            return createSubsampledGradientStops(from: shadingDict)
        }
        
        
        // Check if it's a stream (FunctionType 0 - Sampled function)
        var functionStream: CGPDFStreamRef?
        if CGPDFObjectGetValue(funcObj, .stream, &functionStream),
           let stream = functionStream {
            
            guard let streamDict = CGPDFStreamGetDictionary(stream) else {
                Log.error("PDF: Failed to get stream dictionary", category: .error)
                return []
            }
            
            // DEBUG: Check function stream dictionary for Adobe metadata or original gradient info
            CGPDFDictionaryApplyFunction(streamDict, { (key, _, _) in
                let keyString = String(cString: key)

                // Look for any clues about original gradient structure
                if keyString.contains("Stop") || keyString.contains("Color") || keyString.contains("Adobe") || keyString.contains("AI") {
                }
            }, nil)
            
            // Get function parameters
            var functionType: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(streamDict, "FunctionType", &functionType)
            
            if functionType == 0 {
                // Sampled function - extract ALL colors first, then subsample like PDF 1.3
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                if allColors.count > 11 {
                    // More than 11 colors - subsample to 11 stops (0%, 10%, 20%, ..., 100%)
                    let subsampledStops = createGradientStopsFromColors(allColors)
                    return subsampledStops
                } else if allColors.count >= 2 {
                    // 2-11 colors - use all of them including 2-color gradients
                    var stops: [GradientStop] = []
                    for i in 0..<allColors.count {
                        let position = Double(i) / Double(max(1, allColors.count - 1))
                        stops.append(GradientStop(position: position, color: allColors[i], opacity: 1.0))
                    }
                    return stops
                }
                // If extraction fails, use fallback subsampling
                Log.error("PDF: 🔄 Color extraction failed, using fallback subsampling", category: .error)
                return createSubsampledGradientStops(from: shadingDict)
            }
        }
        
        // Check if it's a dictionary (FunctionType 2 - Exponential function)
        var functionDict: CGPDFDictionaryRef?
        if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),
           let funcDict = functionDict {
            
            var functionType: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(funcDict, "FunctionType", &functionType)
            
            if functionType == 2 {
                // Exponential function - extract C0 and C1 colors
                let nativeStops = extractExponentialFunctionGradientStops(dictionary: funcDict)
                if nativeStops.count >= 2 {
                    return nativeStops
                }
                // Only if extraction completely fails
                Log.error("PDF: 🔄 Exponential function extraction failed, using fallback", category: .error)
                return createSubsampledGradientStops(from: shadingDict)
            } else if functionType == 3 {
                // Stitching function - extract the ORIGINAL Adobe gradient stops
                let nativeStops = extractStitchingFunctionGradientStops(dictionary: funcDict)
                if !nativeStops.isEmpty {
                    return nativeStops
                } else {
                    Log.error("PDF: ❌ FAILED to extract original stops from stitching function", category: .error)
                    return createSubsampledGradientStops(from: shadingDict)
                }
            }
        }
        
        Log.error("PDF: ❌ Could not extract gradient stops from PDF Function - using subsampling fallback", category: .error)
        return createSubsampledGradientStops(from: shadingDict)
    }
    
    private func createSubsampledGradientStops(from shadingDict: CGPDFDictionaryRef? = nil) -> [GradientStop] {
        
        var allColors: [VectorColor] = []
        
        // Try to extract actual colors from the PDF shading dictionary
        if let shadingDict = shadingDict {
            // Get the Function object from the shading dictionary
            var functionObj: CGPDFObjectRef?
            if CGPDFDictionaryGetObject(shadingDict, "Function", &functionObj),
               let funcObj = functionObj {
                
                // Check if it's a dictionary (Function)
                var functionDict: CGPDFDictionaryRef?
                if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),
                   let funcDict = functionDict {
                    
                    // Extract all colors from the function like PDF 1.3 does
                    allColors = extractAllColorsFromFunction(funcDict)
                }
                
                // Check if it's a stream (Sampled function)
                var functionStream: CGPDFStreamRef?
                if allColors.isEmpty,
                   CGPDFObjectGetValue(funcObj, .stream, &functionStream),
                   let stream = functionStream {
                    
                    guard let streamDict = CGPDFStreamGetDictionary(stream) else {
                Log.error("PDF: Failed to get stream dictionary", category: .error)
                return []
            }
                    // Extract colors from stream like PDF 1.3 does
                    allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                }
            }
        }
        
        // If we successfully extracted colors, subsample them like PDF 1.3
        if allColors.count > 2 {
            let subsampledStops = createGradientStopsFromColors(allColors)
            return subsampledStops
        }
        
        // Fallback only if no colors could be extracted at all
        Log.error("PDF: ❌ Could not extract any colors from PDF - using basic two-color fallback", category: .error)
        return [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), opacity: 1.0),
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)), opacity: 1.0)
        ]
    }
    
    private func extractExponentialFunctionGradientStops(dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        
        var c0Array: CGPDFArrayRef?
        var c1Array: CGPDFArrayRef?
        
        var startColor = VectorColor.black
        var endColor = VectorColor.white
        
        if CGPDFDictionaryGetArray(dictionary, "C0", &c0Array),
           let c0 = c0Array {
            startColor = extractColorFromArray(c0)
        }
        
        if CGPDFDictionaryGetArray(dictionary, "C1", &c1Array),
           let c1 = c1Array {
            endColor = extractColorFromArray(c1)
        }
        
        let gradientStops = [
            GradientStop(position: 0.0, color: startColor, opacity: 1.0),
            GradientStop(position: 1.0, color: endColor, opacity: 1.0)
        ]
        
        return gradientStops
    }
    
    private func extractStitchingFunctionGradientStops(dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        
        var functionsArray: CGPDFArrayRef?
        var boundsArray: CGPDFArrayRef?
        var encodeArray: CGPDFArrayRef?
        var domainArray: CGPDFArrayRef?
        
        guard CGPDFDictionaryGetArray(dictionary, "Functions", &functionsArray),
              let functions = functionsArray else {
            Log.error("PDF: ❌ No Functions array in stitching function", category: .error)
            return []
        }
        
        CGPDFDictionaryGetArray(dictionary, "Bounds", &boundsArray)
        CGPDFDictionaryGetArray(dictionary, "Encode", &encodeArray)
        CGPDFDictionaryGetArray(dictionary, "Domain", &domainArray)
        
        let functionCount = CGPDFArrayGetCount(functions)
        
        // Extract bounds to understand the gradient stop positions
        var bounds: [Double] = [0.0] // Always starts at 0
        if let boundsArr = boundsArray {
            let boundsCount = CGPDFArrayGetCount(boundsArr)
            for i in 0..<boundsCount {
                var boundValue: CGPDFReal = 0
                if CGPDFArrayGetNumber(boundsArr, i, &boundValue) {
                    bounds.append(Double(boundValue))
                }
            }
        }
        bounds.append(1.0) // Always ends at 1
        
        
        var gradientStops: [GradientStop] = []
        
        // Extract colors from each sub-function at the correct positions
        for i in 0..<functionCount {
            var functionObj: CGPDFObjectRef?
            guard CGPDFArrayGetObject(functions, i, &functionObj),
                  let funcObj = functionObj else {
                Log.error("PDF: ❌ Could not get function \(i)", category: .error)
                continue
            }
            
            // Extract colors from this sub-function
            var functionDict: CGPDFDictionaryRef?
            if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),
               let funcDict = functionDict {
                
                let subStops = extractExponentialFunctionGradientStops(dictionary: funcDict)
                
                if subStops.count >= 2 {
                    // Add the start color of this sub-function at the correct position
                    let startPosition = bounds[i]
                    let startStop = GradientStop(
                        position: startPosition,
                        color: subStops[0].color,
                        opacity: 1.0
                    )
                    gradientStops.append(startStop)
                    
                    // For the last function, also add the end color
                    if i == functionCount - 1 {
                        let endPosition = bounds[i + 1]
                        let endStop = GradientStop(
                            position: endPosition,
                            color: subStops[1].color,
                            opacity: 1.0
                        )
                        gradientStops.append(endStop)
                    }
                }
            }
        }
        
        // Sort by position to ensure correct order
        gradientStops.sort { $0.position < $1.position }

        return gradientStops
    }
}
