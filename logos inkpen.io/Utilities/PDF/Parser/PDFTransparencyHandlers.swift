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
        Log.info("PDF: Fill opacity set to \(currentFillOpacity)", category: .general)
    }
    
    func handleStrokeOpacity(scanner: CGPDFScannerRef) {
        var opacity: CGFloat = 1.0
        
        guard CGPDFScannerPopNumber(scanner, &opacity) else {
            Log.error("PDF: Failed to read stroke opacity", category: .error)
            return
        }
        
        currentStrokeOpacity = Double(opacity)
        Log.info("PDF: Stroke opacity set to \(currentStrokeOpacity)", category: .general)
    }
    
    func handleGraphicsState(scanner: CGPDFScannerRef) {
        // PDF 1.4+ uses names, PDF 1.3 uses strings - try both
        var nameRef: CGPDFStringRef?
        var namePtr: UnsafePointer<CChar>?
        var name: String
        
        if CGPDFScannerPopName(scanner, &namePtr), let namePtrUnwrapped = namePtr {
            // PDF 1.4+ format - name
            name = String(cString: namePtrUnwrapped)
            Log.info("PDF: Graphics state '\(name)' (as name) - attempting to parse ExtGState...", category: .general)
        } else if CGPDFScannerPopString(scanner, &nameRef) {
            // PDF 1.3 format - string
            guard let nameRefUnwrapped = nameRef,
                  let textString = CGPDFStringCopyTextString(nameRefUnwrapped) else {
                Log.error("PDF: Failed to copy text string from graphics state name", category: .error)
                return
            }
            name = textString as String
            Log.info("PDF: Graphics state '\(name)' (as string) - attempting to parse ExtGState...", category: .general)
        } else {
            Log.error("PDF: Failed to read graphics state name (tried both name and string formats)", category: .error)
            return
        }
        
        // Enhanced ExtGState parsing with better error handling
        guard let page = currentPage else {
            Log.info("PDF: No current page available for ExtGState lookup", category: .general)
            return
        }
        
        guard let resourceDict = page.dictionary else {
            Log.info("PDF: Page dictionary not available", category: .general)
            return
        }
        
        // Try to get Resources dictionary - could be directly on page or inherited
        var resourcesRef: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef) {
            Log.info("PDF: No Resources dictionary found on page", category: .general)
            return
        }
        
        guard let resourcesDict = resourcesRef else {
            Log.info("PDF: Resources dictionary is nil", category: .general)
            return
        }
        
        // Debug: List all keys in Resources dictionary
        Log.info("PDF: 🔍 DEBUG - Listing Resources dictionary contents:", category: .debug)
        listDictionaryKeys(resourcesDict, prefix: "  Resources")
        
        var extGStateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(resourcesDict, "ExtGState", &extGStateDict) {
            Log.info("PDF: No ExtGState dictionary found in Resources", category: .general)
            return
        }
        
        guard let extGState = extGStateDict else {
            Log.info("PDF: ExtGState dictionary is nil", category: .general)
            return
        }
        
        // Debug: List all ExtGState entries
        Log.info("PDF: 🔍 DEBUG - Listing ExtGState dictionary contents:", category: .debug)
        listDictionaryKeys(extGState, prefix: "  ExtGState")
        
        var stateDict: CGPDFDictionaryRef? = nil
        if !CGPDFDictionaryGetDictionary(extGState, name, &stateDict) {
            Log.info("PDF: ExtGState '\(name)' not found in ExtGState dictionary", category: .general)
            return
        }
        
        guard let state = stateDict else {
            Log.info("PDF: ExtGState '\(name)' dictionary is nil", category: .general)
            return
        }
        
        // Debug: List all entries in the specific ExtGState
        Log.info("PDF: 🔍 DEBUG - ExtGState '\(name)' contents:", category: .debug)
        listDictionaryKeys(state, prefix: "  \(name)")
        
        // Parse opacity values from the ExtGState dictionary
        var fillOpacity: CGFloat = 1.0
        var strokeOpacity: CGFloat = 1.0
        
        if CGPDFDictionaryGetNumber(state, "ca", &fillOpacity) {
            currentFillOpacity = Double(fillOpacity)
            Log.info("PDF: ✅ ExtGState '\(name)' - Fill opacity (ca): \(currentFillOpacity)", category: .general)
        } else {
            currentFillOpacity = 1.0  // Reset to full opacity when no 'ca' entry
            Log.info("PDF: ExtGState '\(name)' - No 'ca' (fill opacity) entry found, reset to 1.0", category: .general)
        }
        
        if CGPDFDictionaryGetNumber(state, "CA", &strokeOpacity) {
            currentStrokeOpacity = Double(strokeOpacity)
            Log.info("PDF: ✅ ExtGState '\(name)' - Stroke opacity (CA): \(currentStrokeOpacity)", category: .general)
        } else {
            currentStrokeOpacity = 1.0  // Reset to full opacity when no 'CA' entry
            Log.info("PDF: ExtGState '\(name)' - No 'CA' (stroke opacity) entry found, reset to 1.0", category: .general)
        }
        
        Log.info("PDF: 🎯 ExtGState '\(name)' final opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)", category: .general)
        
        // CRITICAL FIX: Store specific graphics state opacity values for XObject inheritance
        if name == "Gs1" {
            gs1FillOpacity = currentFillOpacity
            gs1StrokeOpacity = currentStrokeOpacity
            Log.fileOperation("PDF: 🎯 SAVED Gs1 opacity for XObject Fm1 - fill: \(gs1FillOpacity), stroke: \(gs1StrokeOpacity)")
        } else if name == "Gs3" {
            gs3FillOpacity = currentFillOpacity
            gs3StrokeOpacity = currentStrokeOpacity
            Log.fileOperation("PDF: 🎯 SAVED Gs3 opacity for XObject Fm2 - fill: \(gs3FillOpacity), stroke: \(gs3StrokeOpacity)")
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
        
        Log.info("\(prefix): Found \(keys.count) keys: \(keys.joined(separator: ", "))", category: .general)
    }
    
    func handleXObject(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("PDF: Failed to read XObject name", category: .error)
            return
        }
        
        let name = String(cString: namePtr!)
        Log.info("PDF: 🚨 'Do' XObject '\(name)' encountered with current opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)", category: .general)
        
        // CRITICAL FIX: Save graphics state BEFORE processing XObject
        // At this point we have the correct outer scope opacity values
        let savedFillOpacity = currentFillOpacity
        let savedStrokeOpacity = currentStrokeOpacity
        Log.fileOperation("PDF: 🎯 XObject '\(name)' - SAVING outer state - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        
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
        Log.info("PDF: 🚨 'Do' XObject '\(name)' encountered with current opacity - fill: \(currentFillOpacity), stroke: \(currentStrokeOpacity)", category: .general)
        
        // CRITICAL FIX: Use the correct graphics state opacity based on XObject name
        var savedFillOpacity: Double
        var savedStrokeOpacity: Double
        
        if name == "Fm1" {
            // Fm1 should use Gs1 opacity (0.5)
            savedFillOpacity = gs1FillOpacity
            savedStrokeOpacity = gs1StrokeOpacity
            Log.fileOperation("PDF: 🎯 XObject '\(name)' - Using Gs1 opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        } else if name == "Fm2" {
            // Fm2 should use Gs3 opacity (0.75)
            savedFillOpacity = gs3FillOpacity
            savedStrokeOpacity = gs3StrokeOpacity
            Log.fileOperation("PDF: 🎯 XObject '\(name)' - Using Gs3 opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        } else {
            // Default to current opacity for other XObjects
            savedFillOpacity = currentFillOpacity
            savedStrokeOpacity = currentStrokeOpacity
            Log.fileOperation("PDF: 🎯 XObject '\(name)' - Using current opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        }
        
        // Store these values for the PDF17 XObject handler to use
        xObjectSavedFillOpacity = savedFillOpacity
        xObjectSavedStrokeOpacity = savedStrokeOpacity
        
        // Now directly process the XObject content using the saved name (with image support)
        processXObjectWithImageSupport(name: name)
    }
}
