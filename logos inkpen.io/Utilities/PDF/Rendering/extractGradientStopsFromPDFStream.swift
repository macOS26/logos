//
//  extractGradientStopsFromPDFStream.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    func extractGradientStopsFromPDFStream(shadingDict: CGPDFDictionaryRef) -> [GradientStop] {
        print("PDF: 🔍 READING ACTUAL PDF STREAM DATA FOR GRADIENT STOPS")
        
        // DEBUG: Print all keys in the shading dictionary first
        print("PDF: 🔍 DEBUG: Available keys in shading dictionary:")
        CGPDFDictionaryApplyFunction(shadingDict, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            print("PDF: 📋 Shading dict key: '\(keyString)' -> type: \(objectType.rawValue)")
            
            // Look for Adobe private data or additional references
            if keyString.hasPrefix("Adobe") || keyString.hasPrefix("AI") || keyString.hasPrefix("Private") {
                print("PDF: 🎯 FOUND ADOBE PRIVATE KEY: '\(keyString)' - this might contain original gradient!")
            }
        }, nil)
        
        // Check if there are any additional references to gradient objects
        var additionalRefs: CGPDFObjectRef?
        if CGPDFDictionaryGetObject(shadingDict, "GradientStops", &additionalRefs) ||
           CGPDFDictionaryGetObject(shadingDict, "Adobe", &additionalRefs) ||
           CGPDFDictionaryGetObject(shadingDict, "AI", &additionalRefs) {
            print("PDF: 🎯 FOUND ADDITIONAL GRADIENT REFERENCE - investigating...")
        }
        
        // Get the Function object from the shading dictionary
        var functionObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, "Function", &functionObj),
              let funcObj = functionObj else {
            print("PDF: ❌ No Function found in shading dictionary - falling back to subsampling")
            return createSubsampledGradientStops(from: shadingDict)
        }
        
        print("PDF: ✅ Found Function object in shading dictionary")
        
        // Check if it's a stream (FunctionType 0 - Sampled function)
        var functionStream: CGPDFStreamRef?
        if CGPDFObjectGetValue(funcObj, .stream, &functionStream),
           let stream = functionStream {
            
            let streamDict = CGPDFStreamGetDictionary(stream)!
            print("PDF: 📊 Found Function stream - extracting sampled function data")
            
            // DEBUG: Check function stream dictionary for Adobe metadata or original gradient info
            print("PDF: 🔍 DEBUG: Function stream dictionary contents:")
            CGPDFDictionaryApplyFunction(streamDict, { (key, object, info) in
                let keyString = String(cString: key)
                let objectType = CGPDFObjectGetType(object)
                print("PDF: 📋 Function key: '\(keyString)' -> type: \(objectType.rawValue)")
                
                // Look for any clues about original gradient structure
                if keyString.contains("Stop") || keyString.contains("Color") || keyString.contains("Adobe") || keyString.contains("AI") {
                    print("PDF: 🎯 POTENTIAL GRADIENT CLUE: '\(keyString)'")
                }
            }, nil)
            
            // Get function parameters
            var functionType: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(streamDict, "FunctionType", &functionType)
            print("PDF: 📊 Function Type: \(functionType)")
            
            if functionType == 0 {
                // Sampled function - extract ALL colors first, then subsample like PDF 1.3
                print("PDF: 🔄 Sampled function - extracting all colors then subsampling like PDF 1.3")
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                if allColors.count > 11 {
                    // More than 11 colors - subsample to 11 stops (0%, 10%, 20%, ..., 100%)
                    let subsampledStops = createGradientStopsFromColors(allColors)
                    print("PDF: ✅ Created \(subsampledStops.count) subsampled gradient stops from \(allColors.count) PDF colors")
                    return subsampledStops
                } else if allColors.count >= 2 {
                    // 2-11 colors - use all of them including 2-color gradients
                    var stops: [GradientStop] = []
                    for i in 0..<allColors.count {
                        let position = Double(i) / Double(max(1, allColors.count - 1))
                        stops.append(GradientStop(position: position, color: allColors[i], opacity: 1.0))
                    }
                    print("PDF: ✅ Created \(stops.count) gradient stops from \(allColors.count) actual PDF colors")
                    return stops
                }
                // If extraction fails, use fallback subsampling
                print("PDF: 🔄 Color extraction failed, using fallback subsampling")
                return createSubsampledGradientStops(from: shadingDict)
            }
        }
        
        // Check if it's a dictionary (FunctionType 2 - Exponential function)
        var functionDict: CGPDFDictionaryRef?
        if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),
           let funcDict = functionDict {
            
            var functionType: CGPDFInteger = 0
            CGPDFDictionaryGetInteger(funcDict, "FunctionType", &functionType)
            print("PDF: 📊 Function Type: \(functionType)")
            
            if functionType == 2 {
                // Exponential function - extract C0 and C1 colors
                let nativeStops = extractExponentialFunctionGradientStops(dictionary: funcDict)
                if nativeStops.count >= 2 {
                    print("PDF: ✅ Using \(nativeStops.count) actual colors from exponential function")
                    return nativeStops
                }
                // Only if extraction completely fails
                print("PDF: 🔄 Exponential function extraction failed, using fallback")
                return createSubsampledGradientStops(from: shadingDict)
            } else if functionType == 3 {
                // Stitching function - extract the ORIGINAL Adobe gradient stops
                print("PDF: 🎯 STITCHING FUNCTION detected - extracting ORIGINAL Adobe gradient stops")
                let nativeStops = extractStitchingFunctionGradientStops(dictionary: funcDict)
                if !nativeStops.isEmpty {
                    print("PDF: ✅ SUCCESS: Found \(nativeStops.count) ORIGINAL Adobe gradient stops from stitching function")
                    return nativeStops
                } else {
                    print("PDF: ❌ FAILED to extract original stops from stitching function")
                    return createSubsampledGradientStops(from: shadingDict)
                }
            }
        }
        
        print("PDF: ❌ Could not extract gradient stops from PDF Function - using subsampling fallback")
        return createSubsampledGradientStops(from: shadingDict)
    }
    
    private func createSubsampledGradientStops(from shadingDict: CGPDFDictionaryRef? = nil) -> [GradientStop] {
        print("PDF: 🌈 Creating subsampled gradient stops from actual PDF data like PDF 1.3")
        
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
                    print("PDF: ✅ Extracted \(allColors.count) colors from PDF function")
                }
                
                // Check if it's a stream (Sampled function)
                var functionStream: CGPDFStreamRef?
                if allColors.isEmpty,
                   CGPDFObjectGetValue(funcObj, .stream, &functionStream),
                   let stream = functionStream {
                    
                    let streamDict = CGPDFStreamGetDictionary(stream)!
                    // Extract colors from stream like PDF 1.3 does
                    allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict)
                    print("PDF: ✅ Extracted \(allColors.count) colors from PDF stream")
                }
            }
        }
        
        // If we successfully extracted colors, subsample them like PDF 1.3
        if allColors.count > 2 {
            let subsampledStops = createGradientStopsFromColors(allColors)
            print("PDF: ✅ Created \(subsampledStops.count) subsampled gradient stops from actual PDF data")
            return subsampledStops
        }
        
        // Fallback only if no colors could be extracted at all
        print("PDF: ❌ Could not extract any colors from PDF - using basic two-color fallback")
        return [
            GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0)), opacity: 1.0),
            GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0)), opacity: 1.0)
        ]
    }
    
    private func extractSampledFunctionGradientStops(stream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        print("PDF: 📊 Extracting sampled function gradient stops from stream data")
        
        // Get the raw stream data
        var format: CGPDFDataFormat = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(stream, &format) else {
            print("PDF: ❌ Could not read stream data")
            return []
        }
        
        let cfData = data as CFData
        let dataBytes = CFDataGetBytePtr(cfData)
        let dataLength = CFDataGetLength(cfData)
        
        // Get function parameters
        var sizeArray: CGPDFArrayRef?
        var bitsPerSample: CGPDFInteger = 8
        var rangeArray: CGPDFArrayRef?
        
        CGPDFDictionaryGetArray(dictionary, "Size", &sizeArray)
        CGPDFDictionaryGetInteger(dictionary, "BitsPerSample", &bitsPerSample)
        CGPDFDictionaryGetArray(dictionary, "Range", &rangeArray)
        
        print("PDF: 📊 Stream data: \(dataLength) bytes, BitsPerSample: \(bitsPerSample)")
        
        // Calculate number of samples and output components
        var totalSamples = 1
        if let size = sizeArray {
            let sizeCount = CGPDFArrayGetCount(size)
            for i in 0..<sizeCount {
                var sizeValue: CGPDFInteger = 0
                if CGPDFArrayGetInteger(size, i, &sizeValue) {
                    totalSamples *= Int(sizeValue)
                }
            }
        }
        
        var outputComponents = 3 // Assume RGB
        if let range = rangeArray {
            outputComponents = Int(CGPDFArrayGetCount(range)) / 2
        }
        
        print("PDF: 📊 Total samples: \(totalSamples), Output components: \(outputComponents)")
        
        let bytesPerSample = Int(bitsPerSample) / 8
        var gradientStops: [GradientStop] = []
        
        // Extract color samples and convert to gradient stops
        for sampleIndex in 0..<totalSamples {
            let baseOffset = sampleIndex * outputComponents * bytesPerSample
            
            if baseOffset + (outputComponents * bytesPerSample) <= dataLength {
                var r: Double = 0, g: Double = 0, b: Double = 0
                
                // Read RGB values
                switch bitsPerSample {
                case 8:
                    if outputComponents >= 3 {
                        r = Double(dataBytes![baseOffset]) / 255.0
                        g = Double(dataBytes![baseOffset + 1]) / 255.0
                        b = Double(dataBytes![baseOffset + 2]) / 255.0
                    }
                case 16:
                    if outputComponents >= 3 {
                        r = Double((UInt16(dataBytes![baseOffset]) << 8) | UInt16(dataBytes![baseOffset + 1])) / 65535.0
                        g = Double((UInt16(dataBytes![baseOffset + 2]) << 8) | UInt16(dataBytes![baseOffset + 3])) / 65535.0
                        b = Double((UInt16(dataBytes![baseOffset + 4]) << 8) | UInt16(dataBytes![baseOffset + 5])) / 65535.0
                    }
                default:
                    continue
                }
                
                // Apply range scaling if available
                if let range = rangeArray, CGPDFArrayGetCount(range) >= 6 {
                    var rMin: CGPDFReal = 0, rMax: CGPDFReal = 1
                    var gMin: CGPDFReal = 0, gMax: CGPDFReal = 1
                    var bMin: CGPDFReal = 0, bMax: CGPDFReal = 1
                    
                    CGPDFArrayGetNumber(range, 0, &rMin)
                    CGPDFArrayGetNumber(range, 1, &rMax)
                    CGPDFArrayGetNumber(range, 2, &gMin)
                    CGPDFArrayGetNumber(range, 3, &gMax)
                    CGPDFArrayGetNumber(range, 4, &bMin)
                    CGPDFArrayGetNumber(range, 5, &bMax)
                    
                    r = Double(rMin) + r * Double(rMax - rMin)
                    g = Double(gMin) + g * Double(gMax - gMin)
                    b = Double(bMin) + b * Double(bMax - bMin)
                }
                
                let position = Double(sampleIndex) / Double(max(1, totalSamples - 1))
                let color = VectorColor.rgb(RGBColor(red: r, green: g, blue: b))
                
                gradientStops.append(GradientStop(position: position, color: color, opacity: 1.0))
                print("PDF: 🎨 Sample \(sampleIndex): pos=\(position), RGB=(\(r),\(g),\(b))")
            }
        }
        
        print("PDF: ✅ Extracted \(gradientStops.count) gradient stops from sampled function")
        return gradientStops
    }
    
    private func extractExponentialFunctionGradientStops(dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        print("PDF: 📊 Extracting exponential function gradient stops")
        
        var c0Array: CGPDFArrayRef?
        var c1Array: CGPDFArrayRef?
        
        var startColor = VectorColor.black
        var endColor = VectorColor.white
        
        if CGPDFDictionaryGetArray(dictionary, "C0", &c0Array),
           let c0 = c0Array {
            startColor = extractColorFromArray(c0)
            print("PDF: ✅ Extracted C0 color: \(startColor)")
        }
        
        if CGPDFDictionaryGetArray(dictionary, "C1", &c1Array),
           let c1 = c1Array {
            endColor = extractColorFromArray(c1)
            print("PDF: ✅ Extracted C1 color: \(endColor)")
        }
        
        let gradientStops = [
            GradientStop(position: 0.0, color: startColor, opacity: 1.0),
            GradientStop(position: 1.0, color: endColor, opacity: 1.0)
        ]
        
        print("PDF: ✅ Extracted 2 gradient stops from exponential function")
        return gradientStops
    }
    
    private func extractStitchingFunctionGradientStops(dictionary: CGPDFDictionaryRef) -> [GradientStop] {
        print("PDF: 📊 Extracting stitching function gradient stops - this should give us the 5 native Adobe stops")
        
        var functionsArray: CGPDFArrayRef?
        var boundsArray: CGPDFArrayRef?
        var encodeArray: CGPDFArrayRef?
        var domainArray: CGPDFArrayRef?
        
        guard CGPDFDictionaryGetArray(dictionary, "Functions", &functionsArray),
              let functions = functionsArray else {
            print("PDF: ❌ No Functions array in stitching function")
            return []
        }
        
        CGPDFDictionaryGetArray(dictionary, "Bounds", &boundsArray)
        CGPDFDictionaryGetArray(dictionary, "Encode", &encodeArray)
        CGPDFDictionaryGetArray(dictionary, "Domain", &domainArray)
        
        let functionCount = CGPDFArrayGetCount(functions)
        print("PDF: 📊 Stitching function has \(functionCount) sub-functions")
        
        // Extract bounds to understand the gradient stop positions
        var bounds: [Double] = [0.0] // Always starts at 0
        if let boundsArr = boundsArray {
            let boundsCount = CGPDFArrayGetCount(boundsArr)
            print("PDF: 📊 Found \(boundsCount) bounds values")
            for i in 0..<boundsCount {
                var boundValue: CGPDFReal = 0
                if CGPDFArrayGetNumber(boundsArr, i, &boundValue) {
                    bounds.append(Double(boundValue))
                    print("PDF: 📍 Bound[\(i)]: \(boundValue)")
                }
            }
        }
        bounds.append(1.0) // Always ends at 1
        
        print("PDF: 📊 Total bounds: \(bounds) - this gives us \(bounds.count) color stops")
        
        var gradientStops: [GradientStop] = []
        
        // Extract colors from each sub-function at the correct positions
        for i in 0..<functionCount {
            var functionObj: CGPDFObjectRef?
            guard CGPDFArrayGetObject(functions, i, &functionObj),
                  let funcObj = functionObj else {
                print("PDF: ❌ Could not get function \(i)")
                continue
            }
            
            // Extract colors from this sub-function
            var functionDict: CGPDFDictionaryRef?
            if CGPDFObjectGetValue(funcObj, .dictionary, &functionDict),
               let funcDict = functionDict {
                
                print("PDF: 📊 Processing sub-function \(i)")
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
                    print("PDF: 🎨 Added gradient stop at \(startPosition * 100)%: \(subStops[0].color)")
                    
                    // For the last function, also add the end color
                    if i == functionCount - 1 {
                        let endPosition = bounds[i + 1]
                        let endStop = GradientStop(
                            position: endPosition,
                            color: subStops[1].color,
                            opacity: 1.0
                        )
                        gradientStops.append(endStop)
                        print("PDF: 🎨 Added final gradient stop at \(endPosition * 100)%: \(subStops[1].color)")
                    }
                }
            }
        }
        
        // Sort by position to ensure correct order
        gradientStops.sort { $0.position < $1.position }
        
        print("PDF: ✅ Extracted \(gradientStops.count) NATIVE gradient stops from stitching function")
        for (index, stop) in gradientStops.enumerated() {
            print("PDF: 🌈 Native Stop \(index): \(Int(stop.position * 100))% = \(stop.color)")
        }
        
        return gradientStops
    }
}
