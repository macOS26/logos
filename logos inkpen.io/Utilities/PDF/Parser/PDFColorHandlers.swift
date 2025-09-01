//
//  PDFColorHandlers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//  Extracted from PDFContent.swift - Color handling functions
//

import Foundation
import CoreGraphics

// MARK: - PDF Color Handlers Extension
extension PDFCommandParser {
    
    // MARK: - Color Handlers
    
    func handleRGBFillColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else { 
            print("PDF: Failed to read RGB fill color")
            return 
        }
        
        currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set fill color to RGB(\(r), \(g), \(b))")
    }
    
    func handleRGBStrokeColor(scanner: CGPDFScannerRef) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else { return }
        
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
    }
    
    func handleGrayFillColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        
        currentFillColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
    }
    
    func handleGrayStrokeColor(scanner: CGPDFScannerRef) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else { return }
        
        currentStrokeColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
        print("PDF: Set stroke color to Gray(\(gray))")
    }
    
    func handleCMYKFillColor(scanner: CGPDFScannerRef) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else { 
            print("PDF: Failed to read CMYK fill color")
            return 
        }
        
        // Convert CMYK to RGB
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        
        currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set fill color to CMYK(\(c), \(m), \(y), \(k)) -> RGB(\(r), \(g), \(b))")
    }
    
    func handleCMYKStrokeColor(scanner: CGPDFScannerRef) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else { 
            print("PDF: Failed to read CMYK stroke color")
            return 
        }
        
        // Convert CMYK to RGB
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set stroke color to CMYK(\(c), \(m), \(y), \(k)) -> RGB(\(r), \(g), \(b))")
    }
    
    func handleGenericFillColor(scanner: CGPDFScannerRef) {
        // Try to read as RGB first, but also check for RGBA or other formats
        var values: [CGFloat] = []
        var value: CGFloat = 0
        
        // Read all available numeric values
        while CGPDFScannerPopNumber(scanner, &value) {
            values.insert(value, at: 0) // Insert at beginning to reverse stack order
        }
        
        print("PDF: Generic fill color - found \(values.count) values: \(values)")
        
        if values.count >= 3 {
            let r = values[0]
            let g = values[1] 
            let b = values[2]
            let a = values.count >= 4 ? values[3] : 1.0
            
            // Check if this might be transparency encoded in a different way
            if values.count == 4 {
                print("PDF: ⚠️ FOUND 4-component color - might be RGBA or transparency: \(values)")
                currentFillOpacity = Double(a)
            }
            
            currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
            print("PDF: Generic fill color - RGB(\(r), \(g), \(b)) with potential alpha: \(a)")
        } else {
            print("PDF: Generic fill color - could not parse parameters, got \(values.count) values")
        }
    }
    
    func handleGenericStrokeColor(scanner: CGPDFScannerRef) {
        // Try to read as RGB first
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        if CGPDFScannerPopNumber(scanner, &b) &&
           CGPDFScannerPopNumber(scanner, &g) &&
           CGPDFScannerPopNumber(scanner, &r) {
            currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
            print("PDF: Generic stroke color - assuming RGB(\(r), \(g), \(b))")
        } else {
            print("PDF: Generic stroke color - could not parse parameters")
        }
    }
}