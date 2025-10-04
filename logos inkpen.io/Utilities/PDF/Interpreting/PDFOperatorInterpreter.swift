//
//  PDFOperatorInterpreter.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

// MARK: - PDF Operator Callback Setup and Interpretation

/// Manages PDF operator callbacks and interpretation
class PDFOperatorInterpreter {
    
    /// Setup all PDF operator callbacks for the given parser
    static func setupOperatorCallbacks(_ operatorTable: CGPDFOperatorTableRef, parser: PDFCommandParser) {
        
        // MARK: - Path Construction Operators
        
        // MoveTo operator
        CGPDFOperatorTableSetCallback(operatorTable, "m") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleMoveTo(scanner: scanner)
        }
        
        // LineTo operator
        CGPDFOperatorTableSetCallback(operatorTable, "l") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleLineTo(scanner: scanner)
        }
        
        // CurveTo operator (cubic Bézier)
        CGPDFOperatorTableSetCallback(operatorTable, "c") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveTo(scanner: scanner)
        }
        
        // CurveTo variant 1 (v operator)
        CGPDFOperatorTableSetCallback(operatorTable, "v") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveToV(scanner: scanner)
        }
        
        // CurveTo variant 2 (y operator)
        CGPDFOperatorTableSetCallback(operatorTable, "y") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveToY(scanner: scanner)
        }
        
        // ClosePath operator
        CGPDFOperatorTableSetCallback(operatorTable, "h") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleClosePath()
        }
        
        // Rectangle operator
        CGPDFOperatorTableSetCallback(operatorTable, "re") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleRectangle(scanner: scanner)
        }
        
        // MARK: - Color Operators
        
        // RGB Fill color operators
        CGPDFOperatorTableSetCallback(operatorTable, "rg") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleRGBFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "RG") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleRGBStrokeColor(scanner: scanner)
        }
        
        // Gray color operators
        CGPDFOperatorTableSetCallback(operatorTable, "g") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGrayFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "G") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGrayStrokeColor(scanner: scanner)
        }
        
        // CMYK color operators
        CGPDFOperatorTableSetCallback(operatorTable, "k") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCMYKFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "K") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCMYKStrokeColor(scanner: scanner)
        }
        
        // Generic color operators
        CGPDFOperatorTableSetCallback(operatorTable, "sc") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGenericFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "SC") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGenericStrokeColor(scanner: scanner)
        }
        
        // MARK: - Paint Operators
        
        // Fill operators
        CGPDFOperatorTableSetCallback(operatorTable, "f") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "F") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFill()
        }
        
        // Stroke operators
        CGPDFOperatorTableSetCallback(operatorTable, "S") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleStroke()
        }
        
        // Fill and stroke operators
        CGPDFOperatorTableSetCallback(operatorTable, "B") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAndStroke()
        }

        // MARK: - Clipping Path Operators

        // Clip with non-zero winding rule
        CGPDFOperatorTableSetCallback(operatorTable, "W") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleClipOperator()
        }

        // Clip with even-odd rule
        CGPDFOperatorTableSetCallback(operatorTable, "W*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleClipOperator()
        }

        // MARK: - Graphics State Operators

        // Save/restore graphics state
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
            Log.fileOperation("PDF: 'q' (save graphics state) operator encountered")
        }

        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            Log.info("PDF: 'Q' (restore graphics state) - FINALIZING clipping group", category: .general)
            parser.finalizeClippingGroup()  // Finalize the clipping group (separate clipping mask)
        }
        
        // Extended graphics state
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        
        // MARK: - Transparency Operators
        
        // Fill opacity
        CGPDFOperatorTableSetCallback(operatorTable, "ca") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillOpacity(scanner: scanner)
        }
        
        // Stroke opacity
        CGPDFOperatorTableSetCallback(operatorTable, "CA") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleStrokeOpacity(scanner: scanner)
        }
        
        // MARK: - XObject and Resource Operators
        
        // XObject invocation
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleXObjectWithOpacitySaving(scanner: scanner)
        }
        
        // MARK: - Line Style Operators

        // Line width
        CGPDFOperatorTableSetCallback(operatorTable, "w") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            var width: CGFloat = 1.0
            if CGPDFScannerPopNumber(scanner, &width) {
                parser.currentLineWidth = Double(width)
                Log.info("PDF: Set line width to \(width)", category: .general)
            }
        }

        // Line cap
        CGPDFOperatorTableSetCallback(operatorTable, "J") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            var cap: CGPDFInteger = 0
            if CGPDFScannerPopInteger(scanner, &cap) {
                parser.currentLineCap = CGLineCap(rawValue: Int32(cap)) ?? .butt
                Log.info("PDF: Set line cap to \(cap)", category: .general)
            }
        }

        // Line join
        CGPDFOperatorTableSetCallback(operatorTable, "j") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            var join: CGPDFInteger = 0
            if CGPDFScannerPopInteger(scanner, &join) {
                parser.currentLineJoin = CGLineJoin(rawValue: Int32(join)) ?? .miter
                Log.info("PDF: Set line join to \(join)", category: .general)
            }
        }

        // Miter limit
        CGPDFOperatorTableSetCallback(operatorTable, "M") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            var limit: CGFloat = 10.0
            if CGPDFScannerPopNumber(scanner, &limit) {
                parser.currentMiterLimit = Double(limit)
                Log.info("PDF: Set miter limit to \(limit)", category: .general)
            }
        }

        // Line dash pattern
        CGPDFOperatorTableSetCallback(operatorTable, "d") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            // For now, just clear dash pattern - full implementation would parse array
            parser.currentLineDashPattern = []
            Log.info("PDF: Set dash pattern (simplified)", category: .general)
        }

        // MARK: - Specialty Operators

        // Path no-op
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (scanner, info) in
            Log.info("PDF: Path construction (no-op) operator 'n' encountered", category: .general)
        }
        
        // Color space operators
        CGPDFOperatorTableSetCallback(operatorTable, "cs") { (scanner, info) in
            Log.info("PDF: Color space operator 'cs' (non-stroking)", category: .general)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "CS") { (scanner, info) in
            Log.info("PDF: Color space operator 'CS' (stroking)", category: .general)
        }
        
        // Setup text operators for text extraction
        setupTextOperators(operatorTable)

        // Setup gradient operators - from existing setupGradientOperatorCallbacks
        setupGradientOperators(operatorTable)
    }

    /// Setup text-specific operator callbacks
    private static func setupTextOperators(_ operatorTable: CGPDFOperatorTableRef) {
        // MARK: - Text Object Operators

        // Begin text object
        CGPDFOperatorTableSetCallback(operatorTable, "BT") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleBeginText()
        }

        // End text object
        CGPDFOperatorTableSetCallback(operatorTable, "ET") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleEndText()
        }

        // MARK: - Text State Operators

        // Set font and size
        CGPDFOperatorTableSetCallback(operatorTable, "Tf") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetFont(scanner: scanner)
        }

        // Set character spacing
        CGPDFOperatorTableSetCallback(operatorTable, "Tc") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetCharacterSpacing(scanner: scanner)
        }

        // Set word spacing
        CGPDFOperatorTableSetCallback(operatorTable, "Tw") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetWordSpacing(scanner: scanner)
        }

        // Set horizontal scaling
        CGPDFOperatorTableSetCallback(operatorTable, "Tz") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetHorizontalScaling(scanner: scanner)
        }

        // Set text leading
        CGPDFOperatorTableSetCallback(operatorTable, "TL") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextLeading(scanner: scanner)
        }

        // Set text rendering mode
        CGPDFOperatorTableSetCallback(operatorTable, "Tr") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextRenderingMode(scanner: scanner)
        }

        // Set text rise
        CGPDFOperatorTableSetCallback(operatorTable, "Ts") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextRise(scanner: scanner)
        }

        // MARK: - Text Positioning Operators

        // Move text position
        CGPDFOperatorTableSetCallback(operatorTable, "Td") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleTextMove(scanner: scanner)
        }

        // Move text position and set leading
        CGPDFOperatorTableSetCallback(operatorTable, "TD") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleTextMoveWithLeading(scanner: scanner)
        }

        // Set text matrix and line matrix
        CGPDFOperatorTableSetCallback(operatorTable, "Tm") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSetTextMatrix(scanner: scanner)
        }

        // Move to start of next line
        CGPDFOperatorTableSetCallback(operatorTable, "T*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleTextNewLine()
        }

        // MARK: - Text Showing Operators

        // Show text string
        CGPDFOperatorTableSetCallback(operatorTable, "Tj") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleShowText(scanner: scanner)
        }

        // Show text with individual glyph positioning
        CGPDFOperatorTableSetCallback(operatorTable, "TJ") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleShowTextWithPositioning(scanner: scanner)
        }

        // Move to next line and show text
        CGPDFOperatorTableSetCallback(operatorTable, "'") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleMoveAndShowText(scanner: scanner)
        }

        // Set word and char spacing, move to next line, show text
        CGPDFOperatorTableSetCallback(operatorTable, "\"") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleSpacingMoveAndShowText(scanner: scanner)
        }
    }

    /// Setup gradient-specific operator callbacks
    private static func setupGradientOperators(_ operatorTable: CGPDFOperatorTableRef) {
        // Pattern color space operators
        CGPDFOperatorTableSetCallback(operatorTable, "SCN") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handlePatternColorStroke(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "scn") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handlePatternColorFill(scanner: scanner)
        }
        
        // Matrix concatenation operator (cm)
        CGPDFOperatorTableSetCallback(operatorTable, "cm") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleConcatMatrix(scanner: scanner)
        }
        
        // Shading operator
        CGPDFOperatorTableSetCallback(operatorTable, "sh") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleShading(scanner: scanner)
        }
    }
}
