//
//  extractGradientFromPattern.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    // Helper method to extract gradient from pattern
    func extractGradientFromPattern(patternName: String, scanner: CGPDFScannerRef) -> VectorGradient? {
        // Get the current PDF page context
        let stream = CGPDFScannerGetContentStream(scanner)
        guard let patternCString = patternName.cString(using: .utf8),
              let pdfPage = CGPDFContentStreamGetResource(stream, "Pattern", patternCString) else {
            return nil
        }
        
        var patternDict: CGPDFDictionaryRef?
        if !CGPDFObjectGetValue(pdfPage, .dictionary, &patternDict) || patternDict == nil {
            return nil
        }
        
        return parseGradientFromDictionary(patternDict!)
    }
}
