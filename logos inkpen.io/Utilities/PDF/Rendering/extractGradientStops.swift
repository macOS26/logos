//
//  extractGradientStops.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    func extractGradientStops(from dict: CGPDFDictionaryRef) -> [GradientStop] {
        var stops: [GradientStop] = []
        
        print("PDF: 🔍 DEBUG: Examining shading dictionary for Function...")
        
        // Get the function dictionary
        var functionObj: CGPDFObjectRef?
        if !CGPDFDictionaryGetObject(dict, "Function", &functionObj) || functionObj == nil {
            // Try to extract colors directly from the shading if no function
            print("PDF: ❌ No Function found in shading dictionary")
            print("PDF: 🔍 Let's see what keys ARE in this dictionary...")
            
            // Debug: Print all keys in the dictionary
            CGPDFDictionaryApplyFunction(dict, { (key, object, info) in
                let keyString = String(cString: key)
                let objectType = CGPDFObjectGetType(object)
                print("PDF: 🔑 Dictionary key: '\(keyString)' -> type: \(objectType.rawValue)")
            }, nil)
            
            // No function found - try to extract colors from other parts of the shading
            print("PDF: 🎨 Using default gradient (no function found)")
            stops = [
                GradientStop(position: 0.0, color: .black, opacity: 1.0),
                GradientStop(position: 1.0, color: .white, opacity: 1.0)
            ]
            return stops
        }
        
        print("PDF: ✅ Found Function object, analyzing...")
        
        // Check if it's an array of functions (multiple stops)
        var functionArray: CGPDFArrayRef?
        if CGPDFObjectGetValue(functionObj!, .array, &functionArray),
           let functions = functionArray {
            
            let count = CGPDFArrayGetCount(functions)
            print("PDF: Found \(count) gradient functions")
            
            // For stitching functions, create stops at regular intervals
            for i in 0..<count {
                let position = Double(i) / Double(max(1, count - 1))
                let color = extractColorFromFunctionIndex(functions, index: i)
                stops.append(GradientStop(position: position, color: color, opacity: 1.0))
            }
            
        } else {
            // Single function - examine what type it actually is
            let objectType = CGPDFObjectGetType(functionObj!)
            print("PDF: 🔍 Function object type: \(objectType.rawValue)")
            
            var functionDict: CGPDFDictionaryRef?
            var functionStream: CGPDFStreamRef?
            
            if CGPDFObjectGetValue(functionObj!, .dictionary, &functionDict),
               let function = functionDict {
                
                print("PDF: 📊 Extracting colors from single function dictionary")
                let (startColor, endColor) = extractColorsFromFunction(function)
                
                // Try to get all colors from the function for multi-stop gradients
                let allColors = extractAllColorsFromFunction(function)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                    print("PDF: 🎨 Created \(stops.count) gradient stops from \(allColors.count) extracted colors")
                } else {
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                    print("PDF: 🎨 Created \(stops.count) gradient stops from function")
                }
                
            } else if CGPDFObjectGetValue(functionObj!, .stream, &functionStream),
                      let stream = functionStream {
                
                print("PDF: 📊 Function is a stream, extracting colors from stream data")
                let streamDict = CGPDFStreamGetDictionary(stream)
                
                // Extract colors from the stream data itself, not the dictionary
                let allColors = extractColorsFromSampledFunctionStream(stream: stream, dictionary: streamDict!)
                if allColors.count > 2 {
                    stops = createGradientStopsFromColors(allColors)
                    print("PDF: 🎨 Created \(stops.count) gradient stops from \(allColors.count) stream colors")
                } else {
                    let (startColor, endColor) = extractColorsFromFunction(streamDict!)
                    stops = [
                        GradientStop(position: 0.0, color: startColor, opacity: 1.0),
                        GradientStop(position: 1.0, color: endColor, opacity: 1.0)
                    ]
                    print("PDF: 🎨 Created \(stops.count) gradient stops from stream function fallback")
                }
                
            } else {
                print("PDF: ❌ Failed to extract function (type \(objectType.rawValue)), creating default gradient")
                // Create default gradient stops as fallback
                stops = [
                    GradientStop(position: 0.0, color: .rgb(RGBColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)), opacity: 1.0),
                    GradientStop(position: 1.0, color: .rgb(RGBColor(red: 0.0, green: 0.0, blue: 1.0, alpha: 1.0)), opacity: 1.0)
                ]
            }
        }
        
        return stops
    }
}