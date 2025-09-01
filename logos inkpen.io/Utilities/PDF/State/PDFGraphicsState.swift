//
//  PDFGraphicsState.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit

// MARK: - Graphics State Management

/// Manages PDF graphics state including transformations, opacity, and extended graphics states
class PDFGraphicsState {
    
    // MARK: - State Properties
    
    /// Current transformation matrix for coordinate transformations
    var currentTransformMatrix: CGAffineTransform = .identity
    
    /// Fill opacity (PDF 1.4+)
    var fillOpacity: Double = 1.0
    
    /// Stroke opacity (PDF 1.4+) 
    var strokeOpacity: Double = 1.0
    
    /// Stored graphics state opacity values for XObject inheritance
    var gs1FillOpacity: Double = 1.0
    var gs1StrokeOpacity: Double = 1.0
    var gs3FillOpacity: Double = 1.0 
    var gs3StrokeOpacity: Double = 1.0
    
    /// XObject saved opacity values
    var xObjectSavedFillOpacity: Double = 1.0
    var xObjectSavedStrokeOpacity: Double = 1.0
    
    /// PDF version for proper feature support
    let detectedPDFVersion: String
    
    init(pdfVersion: String = "PDF1.7") {
        self.detectedPDFVersion = pdfVersion
    }
    
    // MARK: - Matrix Operations
    
    /// Apply a matrix concatenation to current transform
    func concatenateMatrix(_ transform: CGAffineTransform) {
        currentTransformMatrix = currentTransformMatrix.concatenating(transform)
        
        let angle = atan2(currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        print("PDF: 📐 Matrix concatenation - Current CTM rotation: \(angle)°")
    }
    
    /// Get rotation angle from current transformation matrix
    var rotationAngle: CGFloat {
        return atan2(currentTransformMatrix.b, currentTransformMatrix.a)
    }
    
    /// Get rotation angle in degrees
    var rotationAngleDegrees: CGFloat {
        return rotationAngle * 180.0 / .pi
    }
    
    /// Get Y-axis flipped angle for screen coordinates
    var screenCorrectedAngle: CGFloat {
        return -rotationAngleDegrees
    }
    
    // MARK: - Opacity Management
    
    /// Set fill opacity
    func setFillOpacity(_ opacity: Double) {
        fillOpacity = opacity
        print("PDF: Fill opacity set to \(fillOpacity)")
    }
    
    /// Set stroke opacity
    func setStrokeOpacity(_ opacity: Double) {
        strokeOpacity = opacity
        print("PDF: Stroke opacity set to \(strokeOpacity)")
    }
    
    /// Save opacity state for XObject processing
    func saveOpacityForXObject(fillOpacity: Double, strokeOpacity: Double) {
        xObjectSavedFillOpacity = fillOpacity
        xObjectSavedStrokeOpacity = strokeOpacity
        print("PDF: 🎯 Saved opacity for XObject - fill: \(fillOpacity), stroke: \(strokeOpacity)")
    }
    
    /// Get opacity for specific XObject
    func getOpacityForXObject(name: String) -> (fill: Double, stroke: Double) {
        switch name {
        case "Fm1":
            return (gs1FillOpacity, gs1StrokeOpacity)
        case "Fm2": 
            return (gs3FillOpacity, gs3StrokeOpacity)
        default:
            return (fillOpacity, strokeOpacity)
        }
    }
    
    // MARK: - Extended Graphics State Handling
    
    /// Process extended graphics state dictionary
    func processExtGState(name: String, stateDict: CGPDFDictionaryRef) {
        print("PDF: 🔍 Processing ExtGState '\(name)'...")
        
        // Parse opacity values from the ExtGState dictionary
        var fillOpacityValue: CGFloat = 1.0
        var strokeOpacityValue: CGFloat = 1.0
        
        if CGPDFDictionaryGetNumber(stateDict, "ca", &fillOpacityValue) {
            fillOpacity = Double(fillOpacityValue)
            print("PDF: ✅ ExtGState '\(name)' - Fill opacity (ca): \(fillOpacity)")
        } else {
            fillOpacity = 1.0
            print("PDF: ExtGState '\(name)' - No 'ca' entry, reset to 1.0")
        }
        
        if CGPDFDictionaryGetNumber(stateDict, "CA", &strokeOpacityValue) {
            strokeOpacity = Double(strokeOpacityValue)
            print("PDF: ✅ ExtGState '\(name)' - Stroke opacity (CA): \(strokeOpacity)")
        } else {
            strokeOpacity = 1.0
            print("PDF: ExtGState '\(name)' - No 'CA' entry, reset to 1.0")
        }
        
        // Store specific graphics state values for XObject inheritance
        if name == "Gs1" {
            gs1FillOpacity = fillOpacity
            gs1StrokeOpacity = strokeOpacity
            print("PDF: 🎯 SAVED Gs1 opacity for XObject Fm1")
        } else if name == "Gs3" {
            gs3FillOpacity = fillOpacity
            gs3StrokeOpacity = strokeOpacity
            print("PDF: 🎯 SAVED Gs3 opacity for XObject Fm2")
        }
        
        print("PDF: 🎯 ExtGState '\(name)' final - fill: \(fillOpacity), stroke: \(strokeOpacity)")
    }
}

// MARK: - Graphics State Operations Handler

/// Handles graphics state-related PDF operations
struct PDFGraphicsStateOperations {
    
    /// Handle matrix concatenation operation (cm operator)
    static func handleConcatMatrix(scanner: CGPDFScannerRef, state: PDFGraphicsState) {
        var a: CGFloat = 1, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 1, tx: CGFloat = 0, ty: CGFloat = 0
        
        // Pop matrix values in reverse order (PDF stack)
        guard CGPDFScannerPopNumber(scanner, &ty),
              CGPDFScannerPopNumber(scanner, &tx),
              CGPDFScannerPopNumber(scanner, &d),
              CGPDFScannerPopNumber(scanner, &c),
              CGPDFScannerPopNumber(scanner, &b),
              CGPDFScannerPopNumber(scanner, &a) else { return }
        
        let newTransform = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
        state.concatenateMatrix(newTransform)
        
        print("PDF: 📐 Matrix 'cm': [\(a), \(b), \(c), \(d), \(tx), \(ty)]")
    }
    
    /// Handle fill opacity operation (ca operator)
    static func handleFillOpacity(scanner: CGPDFScannerRef, state: PDFGraphicsState) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            print("PDF: Failed to read fill opacity")
            return
        }
        
        state.setFillOpacity(Double(opacity))
    }
    
    /// Handle stroke opacity operation (CA operator)
    static func handleStrokeOpacity(scanner: CGPDFScannerRef, state: PDFGraphicsState) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            print("PDF: Failed to read stroke opacity")
            return
        }
        
        state.setStrokeOpacity(Double(opacity))
    }
    
    /// Handle extended graphics state operation (gs operator)
    static func handleGraphicsState(
        scanner: CGPDFScannerRef, 
        state: PDFGraphicsState, 
        currentPage: CGPDFPage?
    ) {
        // Get graphics state name
        var nameRef: CGPDFStringRef?
        var namePtr: UnsafePointer<CChar>?
        var name: String
        
        if CGPDFScannerPopName(scanner, &namePtr) {
            name = String(cString: namePtr!)
            print("PDF: Graphics state '\(name)' (as name)")
        } else if CGPDFScannerPopString(scanner, &nameRef) {
            name = CGPDFStringCopyTextString(nameRef!)! as String
            print("PDF: Graphics state '\(name)' (as string)")
        } else {
            print("PDF: Failed to read graphics state name")
            return
        }
        
        // Get ExtGState dictionary from page resources
        guard let page = currentPage,
              let resourceDict = page.dictionary else {
            print("PDF: No page dictionary available")
            return
        }
        
        var resourcesRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),
              let resourcesDict = resourcesRef else {
            print("PDF: No Resources dictionary found")
            return
        }
        
        var extGStateDict: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourcesDict, "ExtGState", &extGStateDict),
              let extGState = extGStateDict else {
            print("PDF: No ExtGState dictionary found")
            return
        }
        
        var stateDict: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(extGState, name, &stateDict),
              let stateDictionary = stateDict else {
            print("PDF: ExtGState '\(name)' not found")
            return
        }
        
        state.processExtGState(name: name, stateDict: stateDictionary)
    }
}