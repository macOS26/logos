//
//  PDFOperatorInterpreter.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit

// MARK: - PDF Operator Callback Setup and Interpretation

/// Manages PDF operator callbacks and interpretation
class PDFOperatorInterpreter {
    
    /// Setup all PDF operator callbacks for the given parser
    static func setupOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef, parser: PDFCommandParser) {
        
        // MARK: - Path Construction Operators
        
        // MoveTo operator
        CGPDFOperatorTableSetCallback(operatorTable, "m") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleMoveTo(scanner: scanner)
        }
        
        // LineTo operator
        CGPDFOperatorTableSetCallback(operatorTable, "l") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleLineTo(scanner: scanner)
        }
        
        // CurveTo operator (cubic Bézier)
        CGPDFOperatorTableSetCallback(operatorTable, "c") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveTo(scanner: scanner)
        }
        
        // CurveTo variant 1 (v operator)
        CGPDFOperatorTableSetCallback(operatorTable, "v") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToV(scanner: scanner)
        }
        
        // CurveTo variant 2 (y operator)
        CGPDFOperatorTableSetCallback(operatorTable, "y") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToY(scanner: scanner)
        }
        
        // ClosePath operator
        CGPDFOperatorTableSetCallback(operatorTable, "h") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleClosePath()
        }
        
        // Rectangle operator
        CGPDFOperatorTableSetCallback(operatorTable, "re") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRectangle(scanner: scanner)
        }
        
        // MARK: - Color Operators
        
        // RGB Fill color operators
        CGPDFOperatorTableSetCallback(operatorTable, "rg") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "RG") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBStrokeColor(scanner: scanner)
        }
        
        // Gray color operators
        CGPDFOperatorTableSetCallback(operatorTable, "g") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "G") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayStrokeColor(scanner: scanner)
        }
        
        // CMYK color operators
        CGPDFOperatorTableSetCallback(operatorTable, "k") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "K") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKStrokeColor(scanner: scanner)
        }
        
        // Generic color operators
        CGPDFOperatorTableSetCallback(operatorTable, "sc") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "SC") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericStrokeColor(scanner: scanner)
        }
        
        // MARK: - Paint Operators
        
        // Fill operators
        CGPDFOperatorTableSetCallback(operatorTable, "f") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "F") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        // Stroke operators
        CGPDFOperatorTableSetCallback(operatorTable, "S") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleStroke()
        }
        
        // Fill and stroke operators
        CGPDFOperatorTableSetCallback(operatorTable, "B") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        // MARK: - Graphics State Operators
        
        // Save/restore graphics state
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
            print("PDF: 'q' (save graphics state) operator encountered")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            print("PDF: 'Q' (restore graphics state) operator encountered")
        }
        
        // Extended graphics state
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        
        // MARK: - Transparency Operators
        
        // Fill opacity
        CGPDFOperatorTableSetCallback(operatorTable, "ca") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillOpacity(scanner: scanner)
        }
        
        // Stroke opacity
        CGPDFOperatorTableSetCallback(operatorTable, "CA") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleStrokeOpacity(scanner: scanner)
        }
        
        // MARK: - XObject and Resource Operators
        
        // XObject invocation
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleXObjectWithOpacitySaving(scanner: scanner)
        }
        
        // MARK: - Specialty Operators
        
        // Path no-op
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (scanner, info) in
            print("PDF: Path construction (no-op) operator 'n' encountered")
        }
        
        // Color space operators
        CGPDFOperatorTableSetCallback(operatorTable, "cs") { (scanner, info) in
            print("PDF: Color space operator 'cs' (non-stroking)")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "CS") { (scanner, info) in
            print("PDF: Color space operator 'CS' (stroking)")
        }
        
        // Setup gradient operators - from existing setupGradientOperatorCallbacks
        setupGradientOperators(operatorTable)
    }
    
    /// Setup gradient-specific operator callbacks
    private static func setupGradientOperators(_ operatorTable: CGPDFOperatorTableRef) {
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