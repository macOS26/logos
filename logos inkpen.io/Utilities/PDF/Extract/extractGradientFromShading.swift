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
        
        // Extract gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)

        if !extractedStops.isEmpty {
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
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }

    // Helper method to extract gradient from page resources
    func extractGradientFromPageResources(shadingName: String) -> VectorGradient? {
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
        
        // Extract gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDictionary)

        if !extractedStops.isEmpty {
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
        let gradient = parseGradientFromDictionary(shadingDictionary)
        return gradient
    }

    // Helper method to extract gradient from shading (scanner version - kept for compatibility)
    func extractGradientFromShading(shadingName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let shadingCString = shadingName.cString(using: .utf8),
              let pdfShading = CGPDFContentStreamGetResource(stream, "Shading", shadingCString) else {
            Log.error("PDF: ❌ Could not find shading resource '\(shadingName)' in content stream resources", category: .error)
            return nil
        }
        
        var shadingDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfShading, .dictionary, &shadingDict) || shadingDict == nil {
            Log.error("PDF: ❌ Could not extract shading dictionary for '\(shadingName)'", category: .error)
            return nil
        }
        
        // First try to extract actual gradient stops from the PDF stream
        let extractedStops = extractGradientStopsFromPDFStream(shadingDict: shadingDict!)
        
        if !extractedStops.isEmpty {
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
        let gradient = parseGradientFromDictionary(shadingDict!)
        return gradient
    }
}
