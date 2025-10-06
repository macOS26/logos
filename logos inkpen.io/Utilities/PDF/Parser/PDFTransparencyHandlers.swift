//
//  PDFTransparencyHandlers.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//  Extracted from PDFContent.swift - Transparency and opacity handlers
//

import SwiftUI

// MARK: - PDF Transparency Handlers Extension
extension PDFCommandParser {
    
    // MARK: - Opacity/Transparency Handlers
    
    func handleFillOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            Log.error("PDF: Failed to read fill opacity", category: .error)
            return
        }
        
        currentFillOpacity = Double(opacity)
    }
    
    func handleStrokeOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            Log.error("PDF: Failed to read stroke opacity", category: .error)
            return
        }
        
        currentStrokeOpacity = Double(opacity)
    }
    
    func handleGraphicsState(scanner: CGPDFScannerRef) {
        // PDF 1.4+ uses names, PDF 1.3 uses strings - try both
        var nameRef: CGPDFStringRef?
        var namePtr: UnsafePointer<CChar>?
        var name: String
        
        if CGPDFScannerPopName(scanner, &namePtr), let namePtrUnwrapped = namePtr {
            // PDF 1.4+ format - name
            name = String(cString: namePtrUnwrapped)
        } else if CGPDFScannerPopString(scanner, &nameRef) {
            // PDF 1.3 format - string
            guard let nameRefUnwrapped = nameRef,
                  let textString = CGPDFStringCopyTextString(nameRefUnwrapped) else {
                Log.error("PDF: Failed to copy text string from graphics state name", category: .error)
                return
            }
            name = textString as String
        } else {
            Log.error("PDF: Failed to read graphics state name (tried both name and string formats)", category: .error)
            return
        }
        
        // Enhanced ExtGState parsing with better error handling
        guard let page = currentPage else {
            return
        }
        
        guard let resourceDict = page.dictionary else {
            return
        }
        
        // Try to get Resources dictionary - could be directly on page or inherited
        var resourcesRef: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef) {
            return
        }
        
        guard let resourcesDict = resourcesRef else {
            return
        }
        
        // Debug: List all keys in Resources dictionary
        listDictionaryKeys(resourcesDict, prefix: "  Resources")
        
        var extGStateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourcesDict, "ExtGState", &extGStateDict) {
            return
        }
        
        guard let extGState = extGStateDict else {
            return
        }
        
        // Debug: List all ExtGState entries
        listDictionaryKeys(extGState, prefix: "  ExtGState")
        
        var stateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(extGState, name, &stateDict) {
            return
        }
        
        guard let state = stateDict else {
            return
        }
        
        // Debug: List all entries in the specific ExtGState
        listDictionaryKeys(state, prefix: "  \(name)")
        
        // Parse opacity values from the ExtGState dictionary
        var fillOpacity: CGFloat = 1.0
        var strokeOpacity: CGFloat = 1.0
        
        if CGPDFDictionaryGetNumber(state, "ca", &fillOpacity) {
            currentFillOpacity = Double(fillOpacity)
        } else {
            currentFillOpacity = 1.0  // Reset to full opacity when no 'ca' entry
        }
        
        if CGPDFDictionaryGetNumber(state, "CA", &strokeOpacity) {
            currentStrokeOpacity = Double(strokeOpacity)
        } else {
            currentStrokeOpacity = 1.0  // Reset to full opacity when no 'CA' entry
        }
        
        
        // CRITICAL FIX: Store specific graphics state opacity values for XObject inheritance
        if name == "Gs1" {
            gs1FillOpacity = currentFillOpacity
            gs1StrokeOpacity = currentStrokeOpacity
        } else if name == "Gs3" {
            gs3FillOpacity = currentFillOpacity
            gs3StrokeOpacity = currentStrokeOpacity
        }
    }
    
    // Helper function to debug dictionary contents
    private func listDictionaryKeys(_ dictionary: CGPDFDictionaryRef, prefix: String) {
        var keys: [String] = []
        
        // Callback to collect all keys
        let callback: CGPDFDictionaryApplierFunction = { (key, object, info) in
            let keyString = String(cString: key)
            if let keysArray = info?.assumingMemoryBound(to: [String].self) {
                keysArray.pointee.append(keyString)
            }
        }
        
        withUnsafeMutablePointer(to: &keys) { keysPtr in
            CGPDFDictionaryApplyFunction(dictionary, callback, keysPtr)
        }
        
    }
    
    func handleXObject(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("PDF: Failed to read XObject name", category: .error)
            return
        }
        
        let name = String(cString: namePtr!)
        
        // CRITICAL FIX: Save graphics state BEFORE processing XObject
        // At this point we have the correct outer scope opacity values
        let savedFillOpacity = currentFillOpacity
        let savedStrokeOpacity = currentStrokeOpacity
        
        // Store these values for the PDF17 XObject handler to use
        xObjectSavedFillOpacity = savedFillOpacity
        xObjectSavedStrokeOpacity = savedStrokeOpacity
        
        // TODO: Parse XObject content streams - this is where PDF 1.4 actual drawing operations likely are
        // For now, just log that we encountered it
    }
    
    func handleXObjectWithOpacitySaving(scanner: CGPDFScannerRef) {
        // First get the name to know which XObject we're processing
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("PDF: Failed to read XObject name", category: .error)
            return
        }
        
        let name = String(cString: namePtr!)
        
        // CRITICAL FIX: Use the correct graphics state opacity based on XObject name
        var savedFillOpacity: Double
        var savedStrokeOpacity: Double
        
        if name == "Fm1" {
            // Fm1 should use Gs1 opacity (0.5)
            savedFillOpacity = gs1FillOpacity
            savedStrokeOpacity = gs1StrokeOpacity
        } else if name == "Fm2" {
            // Fm2 should use Gs3 opacity (0.75)
            savedFillOpacity = gs3FillOpacity
            savedStrokeOpacity = gs3StrokeOpacity
        } else {
            // Default to current opacity for other XObjects
            savedFillOpacity = currentFillOpacity
            savedStrokeOpacity = currentStrokeOpacity
        }
        
        // Store these values for the PDF17 XObject handler to use
        xObjectSavedFillOpacity = savedFillOpacity
        xObjectSavedStrokeOpacity = savedStrokeOpacity
        
        // Now directly process the XObject content using the saved name (with image support)
        processXObjectWithImageSupport(name: name)
    }
}
