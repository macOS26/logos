//
//  extractGradientFromShading.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    // Helper method to extract gradient from XObject resources
    func extractGradientFromXObjectResources(shadingName: String, resourcesDict: CGPDFDictionaryRef?) -> VectorGradient? {
        print("PDF: 🔍 DEBUG: Extracting gradient from XObject resources for '\(shadingName)'")
        
        guard let xObjectResourcesDict = resourcesDict else {
            print("PDF: ❌ No XObject resources dictionary provided")
            return nil
        }
        
        // Get the Shading dictionary from XObject resources
        var shadingResourceDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(xObjectResourcesDict, "Shading", &shadingResourceDict),
              let shadingDict = shadingResourceDict else {
            print("PDF: ❌ No Shading resources found in XObject dictionary")
            return nil
        }
        
        // Get the specific shading by name
        var shadingObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, shadingName, &shadingObj),
              let shadingObject = shadingObj else {
            print("PDF: ❌ Shading '\(shadingName)' not found in XObject Shading resources")
            return nil
        }
        
        // Get the shading dictionary
        var pdfShadingDict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(shadingObject, .dictionary, &pdfShadingDict),
              let shadingDictionary = pdfShadingDict else {
            print("PDF: ❌ Could not extract shading dictionary for '\(shadingName)' from XObject resources")
            return nil
        }
        
        print("PDF: ✅ Found and extracted shading dictionary for '\(shadingName)' from XObject resources")
        
        // DEBUG: Print all keys in the shading dictionary
        print("PDF: 🔍 DEBUG: XObject shading dictionary contents:")
        CGPDFDictionaryApplyFunction(shadingDictionary, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            print("PDF: 📋 XObject Shading key: '\(keyString)' -> type: \(objectType.rawValue)")
        }, nil)
        
        // Extract gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)
        
        if !extractedStops.isEmpty {
            print("PDF: ✅ Successfully extracted \(extractedStops.count) gradient stops from PDF stream for '\(shadingName)' from XObject")
            
            // Create gradient with extracted stops
            let gradient = parseGradientFromDictionary(shadingDictionary)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            print("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)' from XObject")
        }
        
        // Fallback to standard parsing
        print("PDF: 🔄 Falling back to standard gradient parsing for '\(shadingName)' from XObject")
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }
    
    // Helper method to extract gradient from page resources
    func extractGradientFromPageResources(shadingName: String) -> VectorGradient? {
        print("PDF: 🔍 DEBUG: Extracting gradient from page resources for '\(shadingName)'")
        
        // Access the page resources to get shading
        guard let pageResourcesDict = pageResourcesDict else {
            print("PDF: ❌ No page resources dictionary available")
            return nil
        }
        
        // Get the Shading dictionary from page resources
        var shadingResourceDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageResourcesDict, "Shading", &shadingResourceDict),
              let shadingDict = shadingResourceDict else {
            print("PDF: ❌ No Shading resources found in page dictionary")
            return nil
        }
        
        // Get the specific shading by name
        var shadingObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, shadingName, &shadingObj),
              let shadingObject = shadingObj else {
            print("PDF: ❌ Shading '\(shadingName)' not found in Shading resources")
            return nil
        }
        
        // Get the shading dictionary
        var pdfShadingDict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(shadingObject, .dictionary, &pdfShadingDict),
              let shadingDictionary = pdfShadingDict else {
            print("PDF: ❌ Could not extract shading dictionary for '\(shadingName)'")
            return nil
        }
        
        print("PDF: ✅ Found and extracted shading dictionary for '\(shadingName)' from page resources")
        
        // DEBUG: Print all keys in the shading dictionary
        print("PDF: 🔍 DEBUG: Shading dictionary contents:")
        CGPDFDictionaryApplyFunction(shadingDictionary, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            print("PDF: 📋 Shading key: '\(keyString)' -> type: \(objectType.rawValue)")
        }, nil)
        
        // Extract gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)
        
        if !extractedStops.isEmpty {
            print("PDF: ✅ Successfully extracted \(extractedStops.count) gradient stops from PDF stream for '\(shadingName)'")
            
            // Create gradient with extracted stops
            let gradient = parseGradientFromDictionary(shadingDictionary)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            print("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)'")
        }
        
        // Fallback to standard parsing
        print("PDF: 🔄 Falling back to standard gradient parsing for '\(shadingName)'")
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }
    
    // Helper method to extract gradient from shading (scanner version - kept for compatibility)
    func extractGradientFromShading(shadingName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        print("PDF: 🔍 DEBUG: Extracting gradient from shading '\(shadingName)'")
        
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let pdfShading = CGPDFContentStreamGetResource(stream, "Shading", shadingName.cString(using: .utf8)!) else {
            print("PDF: ❌ Could not find shading resource '\(shadingName)' in content stream resources")
            
            // DEBUG: Let's see what resources are available
            print("PDF: 🔍 DEBUG: Shading resource '\(shadingName)' not found in content stream")
            return nil
        }
        
        print("PDF: ✅ Found shading resource '\(shadingName)'")
        
        var shadingDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfShading, .dictionary, &shadingDict) || shadingDict == nil {
            print("PDF: ❌ Could not extract shading dictionary for '\(shadingName)'")
            return nil
        }
        
        print("PDF: ✅ Extracted shading dictionary for '\(shadingName)'")
        
        // DEBUG: Print all keys in the shading dictionary
        print("PDF: 🔍 DEBUG: Shading dictionary contents:")
        CGPDFDictionaryApplyFunction(shadingDict!, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            print("PDF: 📋 Shading key: '\(keyString)' -> type: \(objectType.rawValue)")
        }, nil)
        
        // First try to extract actual gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDict!)
        
        if !extractedStops.isEmpty {
            print("PDF: ✅ Successfully extracted \(extractedStops.count) gradient stops from PDF stream for '\(shadingName)'")
            
            // Create gradient with extracted stops
            let gradient = parseGradientFromDictionary(shadingDict!)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            print("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)'")
        }
        
        // Fallback to standard parsing if stream extraction fails
        print("PDF: 🔄 Falling back to standard gradient parsing for '\(shadingName)'")
        let gradient = parseGradientFromDictionary(shadingDict!)
        return gradient
    }
}
