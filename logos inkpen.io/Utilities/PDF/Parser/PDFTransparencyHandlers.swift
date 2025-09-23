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
            print("PDF: Failed to read fill opacity")
            return
        }
        
        currentFillOpacity = Double(opacity)
        print("PDF: Fill opacity set to \(currentFillOpacity)")
    }
    
    func handleStrokeOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            print("PDF: Failed to read stroke opacity")
            return
        }
        
        currentStrokeOpacity = Double(opacity)
        print("PDF: Stroke opacity set to \(currentStrokeOpacity)")
    }
    
    func handleGraphicsState(scanner: CGPDFScannerRef) {
        // PDF 1.4+ uses names, PDF 1.3 uses strings - try both
        var nameRef: CGPDFStringRef?
        var namePtr: UnsafePointer<CChar>?
        var name: String
        
        if CGPDFScannerPopName(scanner, &namePtr) {
            // PDF 1.4+ format - name
            name = String(cString: namePtr!)
            print("PDF: Graphics state '\(name)' (as name) - attempting to parse ExtGState...")
        } else if CGPDFScannerPopString(scanner, &nameRef) {
            // PDF 1.3 format - string
            name = CGPDFStringCopyTextString(nameRef!)! as String
            print("PDF: Graphics state '\(name)' (as string) - attempting to parse ExtGState...")
        } else {
            print("PDF: Failed to read graphics state name (tried both name and string formats)")
            return
        }
        
        // Enhanced ExtGState parsing with better error handling
        guard let page = currentPage else {
            print("PDF: No current page available for ExtGState lookup")
            return
        }
        
        guard let resourceDict = page.dictionary else {
            print("PDF: Page dictionary not available")
            return
        }
        
        // Try to get Resources dictionary - could be directly on page or inherited
        var resourcesRef: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef) {
            print("PDF: No Resources dictionary found on page")
            return
        }
        
        guard let resourcesDict = resourcesRef else {
            print("PDF: Resources dictionary is nil")
            return
        }
        
        // Debug: List all keys in Resources dictionary
        print("PDF: 🔍 DEBUG - Listing Resources dictionary contents:")
        listDictionaryKeys(resourcesDict, prefix: "  Resources")
        
        var extGStateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourcesDict, "ExtGState", &extGStateDict) {
            print("PDF: No ExtGState dictionary found in Resources")
            return
        }
        
        guard let extGState = extGStateDict else {
            print("PDF: ExtGState dictionary is nil")
            return
        }
        
        // Debug: List all ExtGState entries
        print("PDF: 🔍 DEBUG - Listing ExtGState dictionary contents:")
        listDictionaryKeys(extGState, prefix: "  ExtGState")
        
        var stateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(extGState, name, &stateDict) {
            print("PDF: ExtGState '\(name)' not found in ExtGState dictionary")
            return
        }
        
        guard let state = stateDict else {
            print("PDF: ExtGState '\(name)' dictionary is nil")
            return
        }
        
        // Debug: List all entries in the specific ExtGState
        print("PDF: 🔍 DEBUG - ExtGState '\(name)' contents:")
        listDictionaryKeys(state, prefix: "  \(name)")
        
        // Parse opacity values from the ExtGState dictionary
        var fillOpacity: CGFloat = 1.0
        var strokeOpacity: CGFloat = 1.0
        
        if CGPDFDictionaryGetNumber(state, "ca", &fillOpacity) {
            currentFillOpacity = Double(fillOpacity)
            print("PDF: ✅ ExtGState '\(name)' - Fill opacity (ca): \(currentFillOpacity)")
        } else {
            currentFillOpacity = 1.0  // Reset to full opacity when no 'ca' entry
            print("PDF: ExtGState '\(name)' - No 'ca' (fill opacity) entry found, reset to 1.0")
        }
        
        if CGPDFDictionaryGetNumber(state, "CA", &strokeOpacity) {
            currentStrokeOpacity = Double(strokeOpacity)
            print("PDF: ✅ ExtGState '\(name)' - Stroke opacity (CA): \(currentStrokeOpacity)")
        } else {
            currentStrokeOpacity = 1.0  // Reset to full opacity when no 'CA' entry
            print("PDF: ExtGState '\(name)' - No 'CA' (stroke opacity) entry found, reset to 1.0")
        }
        
        print("PDF: 🎯 ExtGState '\(name)' final opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)")
        
        // CRITICAL FIX: Store specific graphics state opacity values for XObject inheritance
        if name == "Gs1" {
            gs1FillOpacity = currentFillOpacity
            gs1StrokeOpacity = currentStrokeOpacity
            print("PDF: 🎯 SAVED Gs1 opacity for XObject Fm1 - fill: \(gs1FillOpacity), stroke: \(gs1StrokeOpacity)")
        } else if name == "Gs3" {
            gs3FillOpacity = currentFillOpacity
            gs3StrokeOpacity = currentStrokeOpacity
            print("PDF: 🎯 SAVED Gs3 opacity for XObject Fm2 - fill: \(gs3FillOpacity), stroke: \(gs3StrokeOpacity)")
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
        
        print("\(prefix): Found \(keys.count) keys: \(keys.joined(separator: ", "))")
    }
    
    func handleXObject(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            print("PDF: Failed to read XObject name")
            return
        }
        
        let name = String(cString: namePtr!)
        print("PDF: 🚨 'Do' XObject '\(name)' encountered with current opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)")
        
        // CRITICAL FIX: Save graphics state BEFORE processing XObject
        // At this point we have the correct outer scope opacity values
        let savedFillOpacity = currentFillOpacity
        let savedStrokeOpacity = currentStrokeOpacity
        print("PDF: 🎯 XObject '\(name)' - SAVING outer state - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        
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
            print("PDF: Failed to read XObject name")
            return
        }
        
        let name = String(cString: namePtr!)
        print("PDF: 🚨 'Do' XObject '\(name)' encountered with current opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)")
        
        // CRITICAL FIX: Use the correct graphics state opacity based on XObject name
        var savedFillOpacity: Double
        var savedStrokeOpacity: Double
        
        if name == "Fm1" {
            // Fm1 should use Gs1 opacity (0.5)
            savedFillOpacity = gs1FillOpacity
            savedStrokeOpacity = gs1StrokeOpacity
            print("PDF: 🎯 XObject '\(name)' - Using Gs1 opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        } else if name == "Fm2" {
            // Fm2 should use Gs3 opacity (0.75)
            savedFillOpacity = gs3FillOpacity
            savedStrokeOpacity = gs3StrokeOpacity
            print("PDF: 🎯 XObject '\(name)' - Using Gs3 opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        } else {
            // Default to current opacity for other XObjects
            savedFillOpacity = currentFillOpacity
            savedStrokeOpacity = currentStrokeOpacity
            print("PDF: 🎯 XObject '\(name)' - Using current opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        }
        
        // Store these values for the PDF17 XObject handler to use
        xObjectSavedFillOpacity = savedFillOpacity
        xObjectSavedStrokeOpacity = savedStrokeOpacity
        
        // Now directly process the XObject content using the saved name (with image support)
        processXObjectWithImageSupport(name: name)
    }
}
