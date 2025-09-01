//
//  PDFStyleResolver.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit

// MARK: - Style Resolution for Rendering Pipeline

/// Manages color resolution and style creation for the rendering pipeline
class PDFStyleResolver {
    
    // MARK: - Color State
    
    /// Current fill color
    private(set) var currentFillColor = CGColor(red: 0, green: 0, blue: 1, alpha: 1) // Default blue
    
    /// Current stroke color  
    private(set) var currentStrokeColor = CGColor(red: 0, green: 0, blue: 0, alpha: 1) // Default black
    
    /// Current fill gradient
    private(set) var currentFillGradient: VectorGradient?
    
    /// Current stroke gradient
    private(set) var currentStrokeGradient: VectorGradient?
    
    /// Active gradient for compound shapes
    private(set) var activeGradient: VectorGradient?
    
    /// Tracked shapes for gradient application
    private(set) var gradientShapes: [Int] = []
    
    // MARK: - Color Setting Operations
    
    /// Set RGB fill color
    func setRGBFillColor(r: CGFloat, g: CGFloat, b: CGFloat) {
        currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set fill color to RGB(\(r), \(g), \(b))")
    }
    
    /// Set RGB stroke color
    func setRGBStrokeColor(r: CGFloat, g: CGFloat, b: CGFloat) {
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set stroke color to RGB(\(r), \(g), \(b))")
    }
    
    /// Set grayscale fill color
    func setGrayFillColor(_ gray: CGFloat) {
        currentFillColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
        print("PDF: Set fill color to Gray(\(gray))")
    }
    
    /// Set grayscale stroke color
    func setGrayStrokeColor(_ gray: CGFloat) {
        currentStrokeColor = CGColor(red: gray, green: gray, blue: gray, alpha: 1.0)
        print("PDF: Set stroke color to Gray(\(gray))")
    }
    
    /// Set CMYK fill color with RGB conversion
    func setCMYKFillColor(c: CGFloat, m: CGFloat, y: CGFloat, k: CGFloat) {
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        
        currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set fill color to CMYK(\(c), \(m), \(y), \(k)) -> RGB(\(r), \(g), \(b))")
    }
    
    /// Set CMYK stroke color with RGB conversion
    func setCMYKStrokeColor(c: CGFloat, m: CGFloat, y: CGFloat, k: CGFloat) {
        let r = (1.0 - c) * (1.0 - k)
        let g = (1.0 - m) * (1.0 - k)
        let b = (1.0 - y) * (1.0 - k)
        
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Set stroke color to CMYK(\(c), \(m), \(y), \(k)) -> RGB(\(r), \(g), \(b))")
    }
    
    /// Set generic fill color with multi-component support
    func setGenericFillColor(_ values: [CGFloat]) {
        print("PDF: Generic fill color - found \(values.count) values: \(values)")
        
        if values.count >= 3 {
            let r = values[0]
            let g = values[1]
            let b = values[2]
            
            currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
            print("PDF: Generic fill color - RGB(\(r), \(g), \(b))")
        }
    }
    
    /// Set generic stroke color with RGB assumption
    func setGenericStrokeColor(r: CGFloat, g: CGFloat, b: CGFloat) {
        currentStrokeColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
        print("PDF: Generic stroke color - RGB(\(r), \(g), \(b))")
    }
    
    // MARK: - Gradient Management
    
    /// Set active gradient for shape creation
    func setActiveGradient(_ gradient: VectorGradient) {
        activeGradient = gradient
        print("PDF: 🎨 Active gradient set")
    }
    
    /// Clear active gradient
    func clearActiveGradient() {
        activeGradient = nil
        gradientShapes.removeAll()
        print("PDF: 🔄 Active gradient cleared")
    }
    
    /// Track shape for compound gradient application
    func trackShapeForGradient(shapeIndex: Int) {
        gradientShapes.append(shapeIndex)
        print("PDF: 📝 Shape \(shapeIndex) tracked for gradient")
    }
    
    /// Set pattern gradient for fill
    func setPatternFillGradient(_ gradient: VectorGradient) {
        currentFillGradient = gradient
        print("PDF: Pattern fill gradient set")
    }
    
    /// Set pattern gradient for stroke
    func setPatternStrokeGradient(_ gradient: VectorGradient) {
        currentStrokeGradient = gradient
        print("PDF: Pattern stroke gradient set")
    }
    
    // MARK: - Style Creation
    
    /// Create fill style from current state and opacity
    func createFillStyle(opacity: Double) -> FillStyle? {
        // Priority: active gradient > pattern gradient > solid color
        if let gradient = activeGradient {
            return FillStyle(gradient: gradient)
        } else if let gradient = currentFillGradient {
            return FillStyle(gradient: gradient)
        } else {
            let vectorColor = createVectorColor(from: currentFillColor)
            return FillStyle(color: vectorColor, opacity: opacity)
        }
    }
    
    /// Create stroke style from current state and opacity
    func createStrokeStyle(opacity: Double, width: Double = 1.0) -> StrokeStyle? {
        // For now, use solid color for stroke (gradient strokes need special handling)
        let vectorColor = createVectorColor(from: currentStrokeColor)
        return StrokeStyle(
            color: vectorColor, 
            width: width, 
            placement: .center, 
            opacity: opacity
        )
    }
    
    /// Create VectorColor from CGColor
    private func createVectorColor(from cgColor: CGColor) -> VectorColor {
        let r = Double(cgColor.components?[0] ?? 0.0)
        let g = Double(cgColor.components?[1] ?? 0.0)
        let b = Double(cgColor.components?[2] ?? 1.0)
        let a = Double(cgColor.components?[3] ?? 1.0)
        
        return VectorColor.rgb(RGBColor(red: r, green: g, blue: b, alpha: a))
    }
    
    /// Check if current fill color is nearly white (for gradient detection)
    var isCurrentFillWhite: Bool {
        let r = Double(currentFillColor.components?[0] ?? 0.0)
        let g = Double(currentFillColor.components?[1] ?? 0.0)
        let b = Double(currentFillColor.components?[2] ?? 1.0)
        return (r > 0.95 && g > 0.95 && b > 0.95)
    }
}

// MARK: - Color Operations Handler

/// Handles color-related PDF operations for the rendering pipeline
struct PDFColorOperations {
    
    /// Handle RGB fill color operation (rg operator)
    static func handleRGBFillColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else {
            print("PDF: Failed to read RGB fill color")
            return
        }
        
        styleResolver.setRGBFillColor(r: r, g: g, b: b)
    }
    
    /// Handle RGB stroke color operation (RG operator)
    static func handleRGBStrokeColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &g),
              CGPDFScannerPopNumber(scanner, &r) else {
            print("PDF: Failed to read RGB stroke color")
            return
        }
        
        styleResolver.setRGBStrokeColor(r: r, g: g, b: b)
    }
    
    /// Handle gray fill color operation (g operator)
    static func handleGrayFillColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else {
            print("PDF: Failed to read gray fill color")
            return
        }
        
        styleResolver.setGrayFillColor(gray)
    }
    
    /// Handle gray stroke color operation (G operator)
    static func handleGrayStrokeColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var gray: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &gray) else {
            print("PDF: Failed to read gray stroke color")
            return
        }
        
        styleResolver.setGrayStrokeColor(gray)
    }
    
    /// Handle CMYK fill color operation (k operator)
    static func handleCMYKFillColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else {
            print("PDF: Failed to read CMYK fill color")
            return
        }
        
        styleResolver.setCMYKFillColor(c: c, m: m, y: y, k: k)
    }
    
    /// Handle CMYK stroke color operation (K operator)
    static func handleCMYKStrokeColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var c: CGFloat = 0, m: CGFloat = 0, y: CGFloat = 0, k: CGFloat = 0
        
        guard CGPDFScannerPopNumber(scanner, &k),
              CGPDFScannerPopNumber(scanner, &y),
              CGPDFScannerPopNumber(scanner, &m),
              CGPDFScannerPopNumber(scanner, &c) else {
            print("PDF: Failed to read CMYK stroke color")
            return
        }
        
        styleResolver.setCMYKStrokeColor(c: c, m: m, y: y, k: k)
    }
    
    /// Handle generic fill color operation (sc operator)
    static func handleGenericFillColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var values: [CGFloat] = []
        var value: CGFloat = 0
        
        // Read all available numeric values
        while CGPDFScannerPopNumber(scanner, &value) {
            values.insert(value, at: 0) // Insert at beginning to reverse stack order
        }
        
        styleResolver.setGenericFillColor(values)
    }
    
    /// Handle generic stroke color operation (SC operator)
    static func handleGenericStrokeColor(scanner: CGPDFScannerRef, styleResolver: PDFStyleResolver) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        
        if CGPDFScannerPopNumber(scanner, &b) &&
           CGPDFScannerPopNumber(scanner, &g) &&
           CGPDFScannerPopNumber(scanner, &r) {
            styleResolver.setGenericStrokeColor(r: r, g: g, b: b)
        } else {
            print("PDF: Generic stroke color - could not parse parameters")
        }
    }
}