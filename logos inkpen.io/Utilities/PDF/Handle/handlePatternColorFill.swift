//
//  handlePatternColorFill.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    // Pattern color handlers
    func handlePatternColorFill(scanner: CGPDFScannerRef) {
        // Try to get pattern name
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),
           let name = nameObj {
            let patternName = String(cString: name)
            print("PDF: Pattern fill color set to pattern: \(patternName)")
            
            // Check if we have a gradient shading for this pattern
            if let gradient = extractGradientFromPattern(patternName: patternName, scanner: scanner) {
                // Store gradient for later use in fill operations
                print("PDF: Found gradient fill from pattern \(patternName)")
                currentFillGradient = gradient
                // Note: We can't store gradient in CGColor, need to handle differently
            }
        }
    }
}
