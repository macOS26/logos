//
//  PDFContent+PDF17.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI
import PDFKit

// MARK: - PDF 1.4 XObject Support Extension
extension PDFCommandParser {
    
    /// Enhanced XObject handler that properly parses PDF 1.4+ Form XObject content streams
    func handleXObjectPDF17(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("\(detectedPDFVersion): Failed to read XObject name", category: .error)
            return
        }
        
        let name = String(cString: namePtr!)
        processXObjectPDF17(name: name)
    }
    
    /// Process an XObject by name (called directly with opacity saving)
    func processXObjectPDF17(name: String, parentResourcesDict: CGPDFDictionaryRef? = nil) {
        
        // Try to find the XObject in parent resources first, then page resources
        var foundXObject: CGPDFObjectRef? = nil
        var foundResourcesDict: CGPDFDictionaryRef? = nil
        
        // First try parent XObject resources (for nested XObjects like Fm2 inside Fm1)
        if let parentResources = parentResourcesDict {
            var parentXObjectDictRef: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(parentResources, "XObject", &parentXObjectDictRef),
               let parentXObjectDict = parentXObjectDictRef {
                var parentXObjectRef: CGPDFObjectRef? = nil
                if CGPDFDictionaryGetObject(parentXObjectDict, name, &parentXObjectRef),
                   let parentXObject = parentXObjectRef {
                    foundXObject = parentXObject
                    foundResourcesDict = parentResources
                } else {
                }
            }
        }
        
        // If not found in parent resources, try page resources
        if foundXObject == nil {
            guard let page = currentPage else {
                return
            }
            
            guard let resourceDict = page.dictionary else {
                return
            }
            
            var resourcesRef: CGPDFDictionaryRef? = nil
            guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),
                  let resourcesDict = resourcesRef else {
                return
            }
            
            
            // Store page resources for shading access
            pageResourcesDict = resourcesDict
            
            var xObjectDictRef: CGPDFDictionaryRef? = nil
            guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),
                  let xObjectDict = xObjectDictRef else {
                return
            }
            
            
            var xObjectRef: CGPDFObjectRef? = nil
            guard CGPDFDictionaryGetObject(xObjectDict, name, &xObjectRef),
                  let xObject = xObjectRef else {
                return
            }
            
            foundXObject = xObject
            foundResourcesDict = resourcesDict
        }
        
        guard let xObject = foundXObject else {
            return
        }
        
        
        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFObjectGetValue(xObject, .stream, &xObjectStreamRef),
              let xObjectStream = xObjectStreamRef else {
            return
        }
        
        
        // Check if it's a Form XObject
        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            return
        }
        
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),
              let subtypeName = subtypeNamePtr,
              String(cString: subtypeName) == "Form" else {
            return
        }
        
        
        // Check if XObject has its own Resources dictionary  
        var xObjectResourcesDict: CGPDFDictionaryRef? = nil
        if CGPDFDictionaryGetDictionary(xObjectStreamDict, "Resources", &xObjectResourcesDict) {
        } else {
            xObjectResourcesDict = foundResourcesDict
        }
        
        // Parse the XObject content stream, passing the XObject's resources for nested XObject lookup
        parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name, resourcesDict: xObjectResourcesDict)
    }
    
    func parseXObjectContentStream(_ xObjectStream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, name: String, resourcesDict: CGPDFDictionaryRef? = nil) {
        
        // CRITICAL FIX: Use the saved outer scope opacity values from when XObject was referenced
        let savedFillOpacity = xObjectSavedFillOpacity
        let savedStrokeOpacity = xObjectSavedStrokeOpacity
        Log.fileOperation("\(detectedPDFVersion): XObject '\(name)' - USING saved outer opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        
        // Get the raw stream data to see what's inside
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(xObjectStream, &format) else {
            Log.error("\(detectedPDFVersion): XObject '\(name)' - FAILED to get stream data", category: .error)
            return
        }
        
        let dataLength = CFDataGetLength(data)
        
        if let dataPtr = CFDataGetBytePtr(data), dataLength > 0 {
            // Convert first 200 characters to string to see the PDF operations
            let previewLength = min(dataLength, 200)
            let previewData = Data(bytes: dataPtr, count: previewLength)
            
            // NOW ACTUALLY PARSE THE CONTENT STREAM!
            
            // Create a simple content stream from the data and parse it
            if String(data: previewData, encoding: .ascii) != nil, dataLength < 1000 {
                // For small streams, show full content
            }
            
            // Use the decompressed data to create a content stream and parse it
            parseDecompressedXObjectContent(data: data, name: name, 
                                          savedFillOpacity: savedFillOpacity, 
                                          savedStrokeOpacity: savedStrokeOpacity,
                                          resourcesDict: resourcesDict)
            
        } else {
        }
    }
    
    private func parseDecompressedXObjectContent(data: CFData, name: String, 
                                                savedFillOpacity: Double, savedStrokeOpacity: Double,
                                                resourcesDict: CGPDFDictionaryRef? = nil) {
        
        guard let dataPtr = CFDataGetBytePtr(data) else {
            return
        }
        
        let dataLength = CFDataGetLength(data)
        let fullData = Data(bytes: dataPtr, count: dataLength)
        
        guard let contentString = String(data: fullData, encoding: .ascii) else {
            return
        }
        
        
        // Parse the operations manually for now
        let operations = contentString.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        // Look for specific patterns we know create shapes
        if operations.contains("f") || operations.contains("F") {
            
            // Extract path operations with saved outer opacity values
            parseXObjectOperations(operations, name: name, 
                                 savedFillOpacity: savedFillOpacity, 
                                 savedStrokeOpacity: savedStrokeOpacity,
                                 resourcesDict: resourcesDict)
        } else {
        }
    }
    
    private func parseXObjectOperations(_ operations: [String], name: String, 
                                       savedFillOpacity: Double, savedStrokeOpacity: Double,
                                       resourcesDict: CGPDFDictionaryRef? = nil) {
        
        var i = 0
        var hasPath = false
        
        while i < operations.count {
            let op = operations[i]
            
            switch op {
            case "sc": // RGB color (follows the 3 RGB values)
                if i >= 3,
                   let r = Double(operations[i - 3]),
                   let g = Double(operations[i - 2]), 
                   let b = Double(operations[i - 1]) {
                    currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
                }
                i += 1
                
            case "m": // moveTo - parameters come BEFORE the 'm'
                if i >= 2,
                   let x = Double(operations[i - 2]),
                   let y = Double(operations[i - 1]) {
                    currentPath.append(.moveTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    i += 1
                } else { 
                    Log.error("\(detectedPDFVersion): XObject '\(name)' - ERROR: moveTo missing parameters before index \(i)", category: .error)
                    i += 1 
                }
                
            case "l": // lineTo - parameters come BEFORE the 'l'
                if i >= 2,
                   let x = Double(operations[i - 2]),
                   let y = Double(operations[i - 1]) {
                    currentPath.append(.lineTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    i += 1
                } else { i += 1 }
                
            case "c": // curveTo - 6 parameters come BEFORE the 'c'
                if i >= 6,
                   let x1 = Double(operations[i - 6]),
                   let y1 = Double(operations[i - 5]),
                   let x2 = Double(operations[i - 4]),
                   let y2 = Double(operations[i - 3]),
                   let x3 = Double(operations[i - 2]),
                   let y3 = Double(operations[i - 1]) {
                    let cp1 = CGPoint(x: x1, y: y1)
                    let cp2 = CGPoint(x: x2, y: y2)
                    let to = CGPoint(x: x3, y: y3)
                    currentPath.append(.curveTo(cp1: cp1, cp2: cp2, to: to))
                    hasPath = true
                    i += 1
                } else { i += 1 }
                
            case "h": // closePath
                currentPath.append(.closePath)
                hasPath = true
                i += 1
                
            case "W": // clip - set clipping path
                handleClipOperator()
                i += 1
                
            case "cm": // matrix concatenation - 6 parameters before 'cm'
                if i >= 6,
                   let a = Double(operations[i - 6]),
                   let b = Double(operations[i - 5]),
                   let c = Double(operations[i - 4]),
                   let d = Double(operations[i - 3]),
                   let tx = Double(operations[i - 2]),
                   let ty = Double(operations[i - 1]) {
                    let newTransform = CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
                    currentTransformMatrix = currentTransformMatrix.concatenating(newTransform)
                    i += 1
                } else { i += 1 }
                
            case "sh": // shading - shading name comes BEFORE 'sh'
                if i >= 1,
                   let shadingName = operations[i - 1].hasPrefix("/") ? String(operations[i - 1].dropFirst()) : nil {
                    
                    // Extract gradient from XObject's own resources, not page resources
                    if let gradient = extractGradientFromXObjectResources(shadingName: shadingName, resourcesDict: resourcesDict) {
                        
                        // Apply gradient to the current path or create a clipped gradient shape
                        if hasPath {
                            let customFillStyle = FillStyle(gradient: gradient)
                            // Use the outer parser's method to create the shape
                            let tempFillOpacity = currentFillOpacity
                            let tempStrokeOpacity = currentStrokeOpacity
                            currentFillOpacity = savedFillOpacity
                            currentStrokeOpacity = savedStrokeOpacity
                            
                            createShapeFromCurrentPath(filled: true, stroked: false, customFillStyle: customFillStyle)
                            
                            // Restore XObject opacity values
                            currentFillOpacity = tempFillOpacity  
                            currentStrokeOpacity = tempStrokeOpacity
                            hasPath = false
                        } else {
                            // Create a gradient shape that will be clipped
                            activeGradient = gradient
                        }
                    } else {
                        Log.error("\(detectedPDFVersion): XObject '\(name)' - ❌ Failed to extract gradient from shading '\(shadingName)'", category: .error)
                    }
                    i += 1
                } else { i += 1 }
                
            case "n": // no-op path (often used with clipping)
                if hasPath {
                    // In PDF, 'n' after 'W' means the path is used only for clipping, not drawing
                    // But the clipping path itself can still be filled or stroked later
                    // For now, keep the path for potential later use
                }
                i += 1
                
            case "Do": // XObject - XObject name comes BEFORE 'Do'
                if i >= 1,
                   let xobjectName = operations[i - 1].hasPrefix("/") ? String(operations[i - 1].dropFirst()) : nil {
                    // Handle nested XObjects - this is likely where the black background is!
                    if xobjectName == "Fm2" {
                    }
                    // CRITICAL FIX: Pass the current XObject's resources as parent for nested lookup
                    // Use the image-supporting version for nested XObjects
                    processXObjectWithImageSupport(name: xobjectName)
                    i += 1
                } else { i += 1 }
                
            case "f", "F": // fill
                if hasPath {
                    // CRITICAL FIX: Temporarily restore outer scope opacity for shape creation
                    let tempFillOpacity = currentFillOpacity
                    let tempStrokeOpacity = currentStrokeOpacity
                    currentFillOpacity = savedFillOpacity
                    currentStrokeOpacity = savedStrokeOpacity
                    
                    createShapeFromCurrentPath(filled: true, stroked: false)
                    
                    // Restore XObject opacity values
                    currentFillOpacity = tempFillOpacity  
                    currentStrokeOpacity = tempStrokeOpacity
                    hasPath = false
                } else {
                }
                i += 1
                
            default:
                i += 1
            }
        }
        
        // CRITICAL FIX: Use the saved opacity for shape creation
    }
}
