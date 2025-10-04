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
            
            // Check if we have a gradient shading for this pattern
            if let gradient = extractGradientFromPattern(patternName: patternName, scanner: scanner) {
                // Store gradient for later use in fill operations
                currentFillGradient = gradient
                // Note: We can't store gradient in CGColor, need to handle differently
            }
        }
    }
}
