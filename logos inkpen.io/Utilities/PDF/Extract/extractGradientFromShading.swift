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
        Log.info("PDF: 🔍 DEBUG: Extracting gradient from XObject resources for '\(shadingName)'", category: .debug)
        
        guard let xObjectResourcesDict = resourcesDict else {
            Log.error("PDF: ❌ No XObject resources dictionary provided", category: .error)
            return nil
        }
        
        // Get the Shading dictionary from XObject resources
        var shadingResourceDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(xObjectResourcesDict, "Shading", &shadingResourceDict),
              let shadingDict = shadingResourceDict else {
            Log.error("PDF: ❌ No Shading resources found in XObject dictionary", category: .error)
            return nil
        }
        
        // Get the specific shading by name
        var shadingObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, shadingName, &shadingObj),
              let shadingObject = shadingObj else {
            Log.error("PDF: ❌ Shading '\(shadingName)' not found in XObject Shading resources", category: .error)
            return nil
        }
        
        // Get the shading dictionary
        var pdfShadingDict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(shadingObject, .dictionary, &pdfShadingDict),
              let shadingDictionary = pdfShadingDict else {
            Log.error("PDF: ❌ Could not extract shading dictionary for '\(shadingName)' from XObject resources", category: .error)
            return nil
        }
        
        Log.info("PDF: ✅ Found and extracted shading dictionary for '\(shadingName)' from XObject resources", category: .general)
        
        // DEBUG: Print all keys in the shading dictionary
        Log.info("PDF: 🔍 DEBUG: XObject shading dictionary contents:", category: .debug)
        CGPDFDictionaryApplyFunction(shadingDictionary, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            Log.info("PDF: 📋 XObject Shading key: '\(keyString)' -> type: \(objectType.rawValue)", category: .general)
        }, nil)
        
        // Extract gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)
        
        if !extractedStops.isEmpty {
            Log.info("PDF: ✅ Successfully extracted \(extractedStops.count) gradient stops from PDF stream for '\(shadingName)' from XObject", category: .general)
            
            // Create gradient with extracted stops
            let gradient = parseGradientFromDictionary(shadingDictionary)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            Log.error("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)' from XObject", category: .error)
        }
        
        // Fallback to standard parsing
        Log.info("PDF: 🔄 Falling back to standard gradient parsing for '\(shadingName)' from XObject", category: .general)
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }
    
    // Helper method to extract gradient from page resources
    func extractGradientFromPageResources(shadingName: String) -> VectorGradient? {
        Log.info("PDF: 🔍 DEBUG: Extracting gradient from page resources for '\(shadingName)'", category: .debug)
        
        // Access the page resources to get shading
        guard let pageResourcesDict = pageResourcesDict else {
            Log.error("PDF: ❌ No page resources dictionary available", category: .error)
            return nil
        }
        
        // Get the Shading dictionary from page resources
        var shadingResourceDict: CGPDFDictionaryRef?
        guard CGPDFDictionaryGetDictionary(pageResourcesDict, "Shading", &shadingResourceDict),
              let shadingDict = shadingResourceDict else {
            Log.error("PDF: ❌ No Shading resources found in page dictionary", category: .error)
            return nil
        }
        
        // Get the specific shading by name
        var shadingObj: CGPDFObjectRef?
        guard CGPDFDictionaryGetObject(shadingDict, shadingName, &shadingObj),
              let shadingObject = shadingObj else {
            Log.error("PDF: ❌ Shading '\(shadingName)' not found in Shading resources", category: .error)
            return nil
        }
        
        // Get the shading dictionary
        var pdfShadingDict: CGPDFDictionaryRef?
        guard CGPDFObjectGetValue(shadingObject, .dictionary, &pdfShadingDict),
              let shadingDictionary = pdfShadingDict else {
            Log.error("PDF: ❌ Could not extract shading dictionary for '\(shadingName)'", category: .error)
            return nil
        }
        
        Log.info("PDF: ✅ Found and extracted shading dictionary for '\(shadingName)' from page resources", category: .general)
        
        // DEBUG: Print all keys in the shading dictionary
        Log.info("PDF: 🔍 DEBUG: Shading dictionary contents:", category: .debug)
        CGPDFDictionaryApplyFunction(shadingDictionary, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            Log.info("PDF: 📋 Shading key: '\(keyString)' -> type: \(objectType.rawValue)", category: .general)
        }, nil)
        
        // Extract gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)
        
        if !extractedStops.isEmpty {
            Log.info("PDF: ✅ Successfully extracted \(extractedStops.count) gradient stops from PDF stream for '\(shadingName)'", category: .general)
            
            // Create gradient with extracted stops
            let gradient = parseGradientFromDictionary(shadingDictionary)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            Log.error("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)'", category: .error)
        }
        
        // Fallback to standard parsing
        Log.info("PDF: 🔄 Falling back to standard gradient parsing for '\(shadingName)'", category: .general)
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }
    
    // Helper method to extract gradient from shading (scanner version - kept for compatibility)
    func extractGradientFromShading(shadingName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        Log.info("PDF: 🔍 DEBUG: Extracting gradient from shading '\(shadingName)'", category: .debug)
        
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let shadingCString = shadingName.cString(using: .utf8),
              let pdfShading = CGPDFContentStreamGetResource(stream, "Shading", shadingCString) else {
            Log.error("PDF: ❌ Could not find shading resource '\(shadingName)' in content stream resources", category: .error)
            
            // DEBUG: Let's see what resources are available
            Log.info("PDF: 🔍 DEBUG: Shading resource '\(shadingName)' not found in content stream", category: .debug)
            return nil
        }
        
        Log.info("PDF: ✅ Found shading resource '\(shadingName)'", category: .general)
        
        var shadingDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfShading, .dictionary, &shadingDict) || shadingDict == nil {
            Log.error("PDF: ❌ Could not extract shading dictionary for '\(shadingName)'", category: .error)
            return nil
        }
        
        Log.info("PDF: ✅ Extracted shading dictionary for '\(shadingName)'", category: .general)
        
        // DEBUG: Print all keys in the shading dictionary
        Log.info("PDF: 🔍 DEBUG: Shading dictionary contents:", category: .debug)
        CGPDFDictionaryApplyFunction(shadingDict!, { (key, object, info) in
            let keyString = String(cString: key)
            let objectType = CGPDFObjectGetType(object)
            Log.info("PDF: 📋 Shading key: '\(keyString)' -> type: \(objectType.rawValue)", category: .general)
        }, nil)
        
        // First try to extract actual gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDict!)
        
        if !extractedStops.isEmpty {
            Log.info("PDF: ✅ Successfully extracted \(extractedStops.count) gradient stops from PDF stream for '\(shadingName)'", category: .general)
            
            // Create gradient with extracted stops
            let gradient = parseGradientFromDictionary(shadingDict!)
            if let linearGradient = gradient, case .linear(var linear) = linearGradient {
                linear.stops = extractedStops
                return .linear(linear)
            }
        } else {
            Log.error("PDF: ❌ FAILED to extract gradient stops from PDF stream for '\(shadingName)'", category: .error)
        }
        
        // Fallback to standard parsing if stream extraction fails
        Log.info("PDF: 🔄 Falling back to standard gradient parsing for '\(shadingName)'", category: .general)
        let gradient = parseGradientFromDictionary(shadingDict!)
        return gradient
    }
}
