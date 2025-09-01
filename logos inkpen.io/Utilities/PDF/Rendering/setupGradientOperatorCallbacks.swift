//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics

extension PDFCommandParser {
    // Add this to your setupOperatorCallbacks method:
    func setupGradientOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef) {
        
        // Pattern color space operators
        CGPDFOperatorTableSetCallback(operatorTable, "SCN") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handlePatternColorStroke(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "scn") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handlePatternColorFill(scanner: scanner)
        }
        
        // Matrix concatenation operator (cm)
        CGPDFOperatorTableSetCallback(operatorTable, "cm") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleConcatMatrix(scanner: scanner)
        }
        
        // Shading operator
        CGPDFOperatorTableSetCallback(operatorTable, "sh") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleShading(scanner: scanner)
        }
    }
}
