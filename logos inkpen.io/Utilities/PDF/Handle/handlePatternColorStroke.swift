//
//  handlePatternColorStroke.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    func handlePatternColorStroke(scanner: CGPDFScannerRef) {
        var nameObj: UnsafePointer<Int8>?
        if CGPDFScannerPopName(scanner, &nameObj),
           let name = nameObj {
            let patternName = String(cString: name)
            Log.info("PDF: Pattern stroke color set to pattern: \(patternName)", category: .general)
            
            if let gradient = extractGradientFromPattern(patternName: patternName, scanner: scanner) {
                Log.info("PDF: Found gradient stroke from pattern \(patternName)", category: .general)
                currentStrokeGradient = gradient
                // Note: We can't store gradient in CGColor, need to handle differently
            }
        }
    }
}
