//
//  File.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    // Matrix transformation handler
    func handleConcatMatrix(scanner: CGPDFScannerRef) {
        var a: CGFloat = 1, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 1, tx: CGFloat = 0, ty: CGFloat = 0
        
        // Pop matrix values in reverse order (PDF stack)
        CGPDFScannerPopNumber(scanner, &ty)
        CGPDFScannerPopNumber(scanner, &tx)
        CGPDFScannerPopNumber(scanner, &d)
        CGPDFScannerPopNumber(scanner, &c)
        CGPDFScannerPopNumber(scanner, &b)
        CGPDFScannerPopNumber(scanner, &a)
        
        let newTransform = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
        currentTransformMatrix = currentTransformMatrix.concatenating(newTransform)
    }
}
