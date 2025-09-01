//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit

extension PDFCommandParser {
    
    func PDF17OperatorTable() -> CGPDFOperatorTableRef? {
        guard let operatorTable = CGPDFOperatorTableCreate() else { return nil }
        
        // Path construction operators
        CGPDFOperatorTableSetCallback(operatorTable, "m") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleMoveTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "l") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleLineTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "c") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "v") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToV(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "y") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToY(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "h") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleClosePath()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "re") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRectangle(scanner: scanner)
        }
        
        // Color operators
        CGPDFOperatorTableSetCallback(operatorTable, "rg") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "RG") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBStrokeColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "g") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "G") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayStrokeColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "k") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "K") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKStrokeColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "sc") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "SC") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericStrokeColor(scanner: scanner)
        }
        
        // Fill and stroke operators
        CGPDFOperatorTableSetCallback(operatorTable, "f") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "F") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "S") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        // Graphics state operators
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            print("\(parser.detectedPDFVersion): XObject 'q' (save graphics state)")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            print("\(parser.detectedPDFVersion): XObject 'Q' (restore graphics state)")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        
        // Nested XObject support
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleXObjectPDF14(scanner: scanner)
        }
        
        // Path construction no-op
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            print("\(parser.detectedPDFVersion): XObject path construction no-op 'n'")
        }
        
        return operatorTable
    }
}
