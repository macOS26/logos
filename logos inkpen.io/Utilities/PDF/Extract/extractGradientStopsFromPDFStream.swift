//
//  extractGradientStopsFromPDFStream.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractGradientStopsFromPDFStream(shadingDict: CGPDFDictionaryRef) -> [GradientStop] {
        Log.info("PDF: 🔍 READING ACTUAL PDF STREAM DATA FOR GRADIENT STOPS", category: .debug)
        
        // DEBUG: Print all keys in the shading dictionary first
        Log.info("PDF: 🔍 DEBUG: Available keys in shading dictionary:", category: .debug)
        CGPDFDictionaryApplyFunction(shadingDict, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            Log.info("PDF: 📋 Shading dict key: '\(keyString)' -> type: \(objectType.rawValue)", category: .general)
            
            // Look for Adobe private data or additional references
            if keyString.hasPrefix("Adobe") || keyString.hasPrefix("AI") || keyString.hasPrefix("Private") {
                Log.info("PDF: 🎯 FOUND ADOBE PRIVATE KEY: '\(keyString)' - this might contain original gradient!", category: .general)
            }
        }, nil)
        
        // Check if there are any additional references to gradient objects
        var additionalRefs: CGPDFObjectRef?
        if CGPDFDictionaryGetObject(shadingDict, "GradientStops", &additionalRefs) ||
           CGPDFDictionaryGetObject(shadingDict, "Adobe", &additionalRefs) ||
           CGPDFDictionaryGetObject(shadingDict, "AI", &additionalRefs) {
            Log.info("PDF: 🎯 FOUND ADDITIONAL GRADIENT REFERENCE - investigating...", category: .general)
        }
        
        // Get the Function object from the shading dictionary
        var functionObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, "Function", &functionObj),
              let funcObj = functionObj else {
            Log.error("PDF: ❌ No Function found in shading dictionary - falling back to subsampling", category: .error)
            return createSubsampledGradientStops(from: shadingDict)
        }
        
        Log.info("PDF: ✅ Found Function object in shading dictionary", category: .general)
        
        // Check if it's a stream (FunctionType 0 - Sampled function)
        var functionStream: CGPDFStreamRef?
        if CGPDFObjectGetValue(funcObj, .stream, &functionStream),
           let stream = functionStream {
            
            guard let streamDict = CGPDFStreamGetDictionary(stream) else {
                Log.error("PDF: Failed to get stream dictionary", category: .error)
                return []
            }
            Log.info("PDF: 📊 Found Function stream - extracting sampled function data", category: .debug)
            
            // DEBUG: Check function stream dictionary for Adobe metadata or original gradient info
            Log.info("PDF: 🔍 DEBUG: Function stream dictionary contents:", category: .debug)
            CGPDFDictionaryApplyFunction(streamDict, { (key, object, info) in
                let keyString = String(cString: key)
                let objectType = CGPDFObjectGetType(object)
                Log.info("PDF: 📋 Function key: '\(keyString)' -> type: \(objectType.rawValue)", category: .general)
                
                // Look for any clues about original gradient structure
                if keyString.contains("Stop") || keyString.contains("Color") || keyString.contains("Adobe") || keyString.contains("AI") {
                    Log.info("PDF: 🎯 POTENTIAL GRADIENT CLUE: '\(keyString)'", category: .general)
                }
            }, nil)
            
            // Get function parameters
            var functionType: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(streamDict, "FunctionType", &functionType)
            Log.info("PDF: 📊 Function Type: \(functionType)", category: .debug)
            
            if functionType == 0 {
                // Sampled function - extract ALL colors first, then subsample like PDF 1.3
                Log.info("PDF: 🔄 Sampled function - extracting all colors then subsampling like PDF 1.3", category: .general)
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                if allColors.count > 11 {
                    // More than 11 colors - subsample to 11 stops (0%, 10%, 20%, ..., 100%)
                    let subsampledStops = createGradientStopsFromColors(allColors)
                    Log.info("PDF: ✅ Created \(subsampledStops.count) subsampled gradient stops from \(allColors.count) PDF colors", category: .general)
                    return subsampledStops
                } else if allColors.count >= 2 {
                    // 2-11 colors - use all of them including 2-color gradients
                    var stops: [GradientStop] = []
                    for i in 0..<allColors.count {
                        let position = Double(i) / Double(max(1, allColors.count - 1))
                        stops.append(GradientStop(position: position, color: allColors[i], opacity: 1.0))
                    }
                    Log.info("PDF: ✅ Created \(stops.count) gradient stops from \(allColors.count) actual PDF colors", category: .general)
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
            Log.info("PDF: 📊 Function Type: \(functionType)", category: .debug)
            
            if functionType == 2 {
                // Exponential function - extract C0 and C1 colors
                let nativeStops = extractExponentialFunctionGradientStops(dictionary: funcDict)
                if nativeStops.count >= 2 {
                    Log.info("PDF: ✅ Using \(nativeStops.count) actual colors from exponential function", category: .general)
                    return nativeStops
                }
                // Only if extraction completely fails
                Log.error("PDF: 🔄 Exponential function extraction failed, using fallback", category: .error)
                return createSubsampledGradientStops(from: shadingDict)
            } else if functionType == 3 {
                // Stitching function - extract the ORIGINAL Adobe gradient stops
                Log.info("PDF: 🎯 STITCHING FUNCTION detected - extracting ORIGINAL Adobe gradient stops", category: .general)
                let nativeStops = extractStitchingFunctionGradientStops(dictionary: funcDict)
                if !nativeStops.isEmpty {
                    Log.info("PDF: ✅ SUCCESS: Found \(nativeStops.count) ORIGINAL Adobe gradient stops from stitching function", category: .general)
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
        Log.info("PDF: 🌈 Creating subsampled gradient stops from actual PDF data like PDF 1.3", category: .general)
        
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
                    Log.info("PDF: ✅ Extracted \(allColors.count) colors from PDF function", category: .general)
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
                    Log.info("PDF: ✅ Extracted \(allColors.count) colors from PDF stream", category: .general)
                }
            }
        }
        
        // If we successfully extracted colors, subsample them like PDF 1.3
        if allColors.count > 2 {
            let subsampledStops = createGradientStopsFromColors(allColors)
            Log.info("PDF: ✅ Created \(subsampledStops.count) subsampled gradient stops from actual PDF data", category: .general)
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
        Log.info("PDF: 📊 Extracting exponential function gradient stops", category: .debug)
        
        var c0Array: CGPDFArrayRef?
        var c1Array: CGPDFArrayRef?
        
        var startColor = VectorColor.black
        var endColor = VectorColor.white
        
        if CGPDFDictionaryGetArray(dictionary, "C0", &c0Array),
           let c0 = c0Array {
            startColor = extractColorFromArray(c0)
            Log.info("PDF: ✅ Extracted C0 color: \(startColor)", category: .general)
        }
        
        if CGPDFDictionaryGetArray(dictionary, "C1", &c1Array),
           let c1 = c1Array {
            endColor = extractColorFromArray(c1)
            Log.info("PDF: ✅ Extracted C1 color: \(endColor)", category: .general)
        }
        
        let gradientStops = [
            GradientStop(position: 0.0, color: startColor, opacity: 1.0),
            GradientStop(position: 1.0, color: endColor, opacity: 1.0)
        ]
        
        Log.info("PDF: ✅ Extracted 2 gradient stops from exponential function", category: .general)
        return gradientStops
    }
    
    private func extractStitchingFunctionGradientStops(dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        Log.info("PDF: 📊 Extracting stitching function gradient stops - this should give us the 5 native Adobe stops", category: .debug)
        
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
        Log.info("PDF: 📊 Stitching function has \(functionCount) sub-functions", category: .debug)
        
        // Extract bounds to understand the gradient stop positions
        var bounds: [Double] = [0.0] // Always starts at 0
        if let boundsArr = boundsArray {
            let boundsCount = CGPDFArrayGetCount(boundsArr)
            Log.info("PDF: 📊 Found \(boundsCount) bounds values", category: .debug)
            for i in 0..<boundsCount {
                var boundValue: CGPDFReal = 0
                if CGPDFArrayGetNumber(boundsArr, i, &boundValue) {
                    bounds.append(Double(boundValue))
                    Log.info("PDF: 📍 Bound[\(i)]: \(boundValue)", category: .general)
                }
            }
        }
        bounds.append(1.0) // Always ends at 1
        
        Log.info("PDF: 📊 Total bounds: \(bounds) - this gives us \(bounds.count) color stops", category: .debug)
        
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
                
                Log.info("PDF: 📊 Processing sub-function \(i)", category: .debug)
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
                    Log.info("PDF: 🎨 Added gradient stop at \(startPosition * 100)%: \(subStops[0].color)", category: .general)
                    
                    // For the last function, also add the end color
                    if i == functionCount - 1 {
                        let endPosition = bounds[i + 1]
                        let endStop = GradientStop(
                            position: endPosition,
                            color: subStops[1].color,
                            opacity: 1.0
                        )
                        gradientStops.append(endStop)
                        Log.info("PDF: 🎨 Added final gradient stop at \(endPosition * 100)%: \(subStops[1].color)", category: .general)
                    }
                }
            }
        }
        
        // Sort by position to ensure correct order
        gradientStops.sort { $0.position < $1.position }
        
        Log.info("PDF: ✅ Extracted \(gradientStops.count) NATIVE gradient stops from stitching function", category: .general)
        for (index, stop) in gradientStops.enumerated() {
            Log.info("PDF: 🌈 Native Stop \(index): \(Int(stop.position * 100))% = \(stop.color)", category: .general)
        }
        
        return gradientStops
    }
}
