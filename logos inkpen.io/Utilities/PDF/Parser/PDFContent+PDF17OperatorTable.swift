//
//  PDF17OperatorTable.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI
import PDFKit

extension PDFCommandParser {
    
    func PDF17OperatorTable() -> CGPDFOperatorTableRef? {
        guard let operatorTable = CGPDFOperatorTableCreate() else { return nil }
        
        // Path construction operators
        CGPDFOperatorTableSetCallback(operatorTable, "m") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleMoveTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "l") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleLineTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "c") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "v") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveToV(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "y") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleCurveToY(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "h") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleClosePath()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "re") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleRectangle(scanner: scanner)
        }
        
        // Color operators
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
        
        // Fill and stroke operators
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
        
        CGPDFOperatorTableSetCallback(operatorTable, "S") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        // Graphics state operators
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
        }

        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.finalizeClippingGroup()  // Finalize the clipping group (separate clipping mask)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        
        // Nested XObject support (with Image XObject support)
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            guard let info = info else { return }
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info).takeUnretainedValue()
            parser.handleXObjectWithImageSupport(scanner: scanner)
        }
        
        // Path construction no-op
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (_, _) in
        }

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

        return operatorTable
    }
}
