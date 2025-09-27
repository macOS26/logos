//
//  extractColorFromArray.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

extension PDFCommandParser {
    
    func extractColorFromArray(_ array: CGPDFArrayRef) -> VectorColor {
        let count = CGPDFArrayGetCount(array)
        Log.info("PDF: 🎨 Extracting color from array with \(count) components", category: .general)
        
        if count >= 3 {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &r)
            CGPDFArrayGetNumber(array, 1, &g)
            CGPDFArrayGetNumber(array, 2, &b)
            
            Log.info("PDF: 🌈 RGB values: R=\(r), G=\(g), B=\(b)", category: .general)
            return .rgb(RGBColor(red: Double(r), green: Double(g), blue: Double(b)))
        } else if count == 1 {
            // Grayscale
            var gray: CGFloat = 0
            CGPDFArrayGetNumber(array, 0, &gray)
            Log.info("PDF: ⚫ Grayscale value: \(gray)", category: .general)
            return .rgb(RGBColor(red: Double(gray), green: Double(gray), blue: Double(gray)))
        }
        
        Log.error("PDF: ❌ Invalid color array, using black", category: .error)
        return .black
    }
}
