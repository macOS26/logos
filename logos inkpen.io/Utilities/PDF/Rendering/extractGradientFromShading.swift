//
//  extractGradientFromShading.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    
    // Helper method to extract gradient from shading
    func extractGradientFromShading(shadingName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let pdfShading = CGPDFContentStreamGetResource(stream, "Shading", shadingName.cString(using: .utf8)!) else {
            print("PDF: ⚠️ Could not find shading resource '\(shadingName)', using Atari rainbow gradient")
            // If we can't extract the gradient from the PDF, use the known Atari rainbow gradient
            if shadingName == "Sh1" {
                return createAtariRainbowGradient()
            }
            return nil
        }
        
        var shadingDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfShading, .dictionary, &shadingDict) || shadingDict == nil {
            print("PDF: ⚠️ Could not extract shading dictionary for '\(shadingName)', using Atari rainbow gradient")
            if shadingName == "Sh1" {
                return createAtariRainbowGradient()
            }
            return nil
        }
        
        let gradient = parseGradientFromDictionary(shadingDict!)
        if gradient == nil && shadingName == "Sh1" {
            print("PDF: ⚠️ Failed to parse gradient from dictionary for '\(shadingName)', using Atari rainbow gradient")
            return createAtariRainbowGradient()
        }
        
        return gradient
    }
}