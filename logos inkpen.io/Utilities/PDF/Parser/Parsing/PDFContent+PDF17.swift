//
//  PDFContent+PDF17.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import Foundation
import SwiftUI
import CoreGraphics
import PDFKit

// MARK: - PDF 1.4 XObject Support Extension
extension PDFCommandParser {
    
    /// Enhanced XObject handler that properly parses PDF 1.4+ Form XObject content streams
    func handleXObjectPDF17(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            print("\(detectedPDFVersion): Failed to read XObject name")
            return
        }
        
        let name = String(cString: namePtr!)
        processXObjectPDF17(name: name)
    }
    
    /// Process an XObject by name (called directly with opacity saving)
    func processXObjectPDF17(name: String, parentResourcesDict: CGPDFDictionaryRef? = nil) {
        print("\(detectedPDFVersion): Processing XObject '\(name)'...")
        
        // Try to find the XObject in parent resources first, then page resources
        var foundXObject: CGPDFObjectRef? = nil
        var foundResourcesDict: CGPDFDictionaryRef? = nil
        
        // First try parent XObject resources (for nested XObjects like Fm2 inside Fm1)
        if let parentResources = parentResourcesDict {
            print("\(detectedPDFVersion): Searching for '\(name)' in parent XObject resources first...")
            var parentXObjectDictRef: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(parentResources, "XObject", &parentXObjectDictRef),
               let parentXObjectDict = parentXObjectDictRef {
                var parentXObjectRef: CGPDFObjectRef? = nil
                if CGPDFDictionaryGetObject(parentXObjectDict, name, &parentXObjectRef),
                   let parentXObject = parentXObjectRef {
                    foundXObject = parentXObject
                    foundResourcesDict = parentResources
                    print("\(detectedPDFVersion): Found '\(name)' in parent XObject resources!")
                } else {
                    print("\(detectedPDFVersion): '\(name)' not found in parent XObject resources, trying page resources...")
                }
            }
        }
        
        // If not found in parent resources, try page resources
        if foundXObject == nil {
            guard let page = currentPage else {
                print("\(detectedPDFVersion): No current page available")
                return
            }
            
            guard let resourceDict = page.dictionary else {
                print("\(detectedPDFVersion): Page has no dictionary")
                return
            }
            
            var resourcesRef: CGPDFDictionaryRef? = nil
            guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),
                  let resourcesDict = resourcesRef else {
                print("\(detectedPDFVersion): Page has no Resources dictionary")
                return
            }
            
            print("\(detectedPDFVersion): Found page Resources dictionary")
            
            // Store page resources for shading access
            pageResourcesDict = resourcesDict
            
            var xObjectDictRef: CGPDFDictionaryRef? = nil
            guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),
                  let xObjectDict = xObjectDictRef else {
                print("\(detectedPDFVersion): Resources has no XObject dictionary")
                return
            }
            
            print("\(detectedPDFVersion): Found XObject dictionary")
            
            var xObjectRef: CGPDFObjectRef? = nil
            guard CGPDFDictionaryGetObject(xObjectDict, name, &xObjectRef),
                  let xObject = xObjectRef else {
                print("\(detectedPDFVersion): XObject '\(name)' not found in XObject dictionary")
                return
            }
            
            foundXObject = xObject
            foundResourcesDict = resourcesDict
        }
        
        guard let xObject = foundXObject else {
            print("\(detectedPDFVersion): XObject '\(name)' not found in any resource dictionary")
            return
        }
        
        print("\(detectedPDFVersion): Found XObject '\(name)' reference")
        
        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFObjectGetValue(xObject, .stream, &xObjectStreamRef),
              let xObjectStream = xObjectStreamRef else {
            print("\(detectedPDFVersion): XObject '\(name)' is not a stream object")
            return
        }
        
        print("\(detectedPDFVersion): XObject '\(name)' is a valid stream")
        
        // Check if it's a Form XObject
        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            print("\(detectedPDFVersion): Could not get XObject '\(name)' stream dictionary")
            return
        }
        
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),
              let subtypeName = subtypeNamePtr,
              String(cString: subtypeName) == "Form" else {
            let subtypeStr = subtypeNamePtr != nil ? String(cString: subtypeNamePtr!) : "unknown"
            print("\(detectedPDFVersion): XObject '\(name)' is not a Form XObject (\(subtypeStr)), skipping")
            return
        }
        
        print("\(detectedPDFVersion): XObject '\(name)' is a Form XObject - parsing content stream...")
        
        // Check if XObject has its own Resources dictionary  
        var xObjectResourcesDict: CGPDFDictionaryRef? = nil
        if CGPDFDictionaryGetDictionary(xObjectStreamDict, "Resources", &xObjectResourcesDict) {
            print("\(detectedPDFVersion): XObject '\(name)' has its own Resources dictionary")
        } else {
            print("\(detectedPDFVersion): XObject '\(name)' will inherit parent Resources")
            xObjectResourcesDict = foundResourcesDict
        }
        
        // Parse the XObject content stream, passing the XObject's resources for nested XObject lookup
        parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name, resourcesDict: xObjectResourcesDict)
    }
    
    private func parseXObjectContentStream(_ xObjectStream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, name: String, resourcesDict: CGPDFDictionaryRef? = nil) {
        print("\(detectedPDFVersion): 🚨🚨🚨 DEBUG VERSION IS RUNNING FOR '\(name)' 🚨🚨🚨")
        print("\(detectedPDFVersion): XObject '\(name)' - reading content stream data...")
        
        // CRITICAL FIX: Use the saved outer scope opacity values from when XObject was referenced
        let savedFillOpacity = xObjectSavedFillOpacity
        let savedStrokeOpacity = xObjectSavedStrokeOpacity
        print("\(detectedPDFVersion): XObject '\(name)' - USING saved outer opacity - fill: \(savedFillOpacity), stroke: \(savedStrokeOpacity)")
        
        // Get the raw stream data to see what's inside
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(xObjectStream, &format) else {
            print("\(detectedPDFVersion): XObject '\(name)' - FAILED to get stream data")
            return
        }
        
        let dataLength = CFDataGetLength(data)
        print("\(detectedPDFVersion): XObject '\(name)' - content stream is \(dataLength) bytes")
        
        if let dataPtr = CFDataGetBytePtr(data), dataLength > 0 {
            // Convert first 200 characters to string to see the PDF operations
            let previewLength = min(dataLength, 200)
            let previewData = Data(bytes: dataPtr, count: previewLength)
            
            if let previewString = String(data: previewData, encoding: .ascii) {
                print("\(detectedPDFVersion): XObject '\(name)' - CONTENT PREVIEW:")
                print("=== START CONTENT ===")
                print(previewString)
                print("=== END CONTENT ===")
            } else {
                print("\(detectedPDFVersion): XObject '\(name)' - content is binary/compressed")
            }
            
            // Also check if it's compressed
            var compressionName: UnsafePointer<CChar>?
            if CGPDFDictionaryGetName(dictionary, "Filter", &compressionName),
               let compression = compressionName {
                print("\(detectedPDFVersion): XObject '\(name)' - compressed with: \(String(cString: compression))")
            } else {
                print("\(detectedPDFVersion): XObject '\(name)' - NOT compressed (raw content)")
            }
            
            // NOW ACTUALLY PARSE THE CONTENT STREAM!
            print("\(detectedPDFVersion): XObject '\(name)' - PARSING CONTENT STREAM FOR REAL!")
            
            // Create a simple content stream from the data and parse it
            if let _ = String(data: previewData, encoding: .ascii), dataLength < 1000 {
                // For small streams, show full content
                print("\(detectedPDFVersion): XObject '\(name)' - FULL CONTENT:")
                print(String(data: Data(bytes: dataPtr, count: dataLength), encoding: .ascii) ?? "binary")
            }
            
            // Use the decompressed data to create a content stream and parse it
            parseDecompressedXObjectContent(data: data, name: name, 
                                          savedFillOpacity: savedFillOpacity, 
                                          savedStrokeOpacity: savedStrokeOpacity,
                                          resourcesDict: resourcesDict)
            
        } else {
            print("\(detectedPDFVersion): XObject '\(name)' - EMPTY content stream!")
        }
    }
    
    private func parseDecompressedXObjectContent(data: CFData, name: String, 
                                                savedFillOpacity: Double, savedStrokeOpacity: Double,
                                                resourcesDict: CGPDFDictionaryRef? = nil) {
        print("\(detectedPDFVersion): XObject '\(name)' - parsing content manually...")
        
        guard let dataPtr = CFDataGetBytePtr(data) else {
            print("\(detectedPDFVersion): XObject '\(name)' - no data pointer")
            return
        }
        
        let dataLength = CFDataGetLength(data)
        let fullData = Data(bytes: dataPtr, count: dataLength)
        
        guard let contentString = String(data: fullData, encoding: .ascii) else {
            print("\(detectedPDFVersion): XObject '\(name)' - content is not ASCII readable")
            return
        }
        
        print("\(detectedPDFVersion): XObject '\(name)' - FULL CONTENT TO PARSE:")
        print("'" + contentString + "'")
        
        // Parse the operations manually for now
        let operations = contentString.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        print("\(detectedPDFVersion): XObject '\(name)' - found \(operations.count) operations: \(operations)")
        
        // Look for specific patterns we know create shapes
        if operations.contains("f") || operations.contains("F") {
            print("\(detectedPDFVersion): XObject '\(name)' - ✅ CONTAINS FILL OPERATION - this should create a shape!")
            
            // Extract path operations with saved outer opacity values
            parseXObjectOperations(operations, name: name, 
                                 savedFillOpacity: savedFillOpacity, 
                                 savedStrokeOpacity: savedStrokeOpacity,
                                 resourcesDict: resourcesDict)
        } else {
            print("\(detectedPDFVersion): XObject '\(name)' - no fill operations found")
        }
    }
    
    private func parseXObjectOperations(_ operations: [String], name: String, 
                                       savedFillOpacity: Double, savedStrokeOpacity: Double,
                                       resourcesDict: CGPDFDictionaryRef? = nil) {
        print("\(detectedPDFVersion): XObject '\(name)' - manually parsing operations to create shape...")
        
        var i = 0
        var hasPath = false
        
        while i < operations.count {
            let op = operations[i]
            print("\(detectedPDFVersion): XObject '\(name)' - parsing operation [\(i)]: '\(op)'")
            
            switch op {
            case "sc": // RGB color (follows the 3 RGB values)
                if i >= 3,
                   let r = Double(operations[i - 3]),
                   let g = Double(operations[i - 2]), 
                   let b = Double(operations[i - 1]) {
                    currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
                    print("\(detectedPDFVersion): XObject '\(name)' - RGB color: (\(r), \(g), \(b))")
                }
                i += 1
                
            case "m": // moveTo - parameters come BEFORE the 'm'
                if i >= 2,
                   let x = Double(operations[i - 2]),
                   let y = Double(operations[i - 1]) {
                    currentPath.append(.moveTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    print("\(detectedPDFVersion): XObject '\(name)' - moveTo(\(x), \(y))")
                    i += 1
                } else { 
                    print("\(detectedPDFVersion): XObject '\(name)' - ERROR: moveTo missing parameters before index \(i)")
                    i += 1 
                }
                
            case "l": // lineTo - parameters come BEFORE the 'l'
                if i >= 2,
                   let x = Double(operations[i - 2]),
                   let y = Double(operations[i - 1]) {
                    currentPath.append(.lineTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    print("\(detectedPDFVersion): XObject '\(name)' - lineTo(\(x), \(y))")
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
                    print("\(detectedPDFVersion): XObject '\(name)' - curveTo(\(x1), \(y1), \(x2), \(y2), \(x3), \(y3))")
                    i += 1
                } else { i += 1 }
                
            case "h": // closePath
                currentPath.append(.closePath)
                hasPath = true
                print("\(detectedPDFVersion): XObject '\(name)' - closePath")
                i += 1
                
            case "W": // clip - set clipping path
                print("\(detectedPDFVersion): XObject '\(name)' - 🖇️ CLIPPING PATH - this creates transparency!")
                // For now, detect that this should be a clipping mask
                // In a proper implementation, this would set a clipping region
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
                    print("\(detectedPDFVersion): XObject '\(name)' - 📐 Matrix concatenation 'cm': [\(a), \(b), \(c), \(d), \(tx), \(ty)]")
                    print("\(detectedPDFVersion): XObject '\(name)' - 🔄 Current CTM: [\(currentTransformMatrix.a), \(currentTransformMatrix.b), \(currentTransformMatrix.c), \(currentTransformMatrix.d), \(currentTransformMatrix.tx), \(currentTransformMatrix.ty)]")
                    i += 1
                } else { i += 1 }
                
            case "sh": // shading - shading name comes BEFORE 'sh'
                if i >= 1,
                   let shadingName = operations[i - 1].hasPrefix("/") ? String(operations[i - 1].dropFirst()) : nil {
                    print("\(detectedPDFVersion): XObject '\(name)' - 🎨 SHADING OPERATION: \(shadingName)")
                    
                    // Extract gradient from XObject's own resources, not page resources
                    if let gradient = extractGradientFromXObjectResources(shadingName: shadingName, resourcesDict: resourcesDict) {
                        print("\(detectedPDFVersion): XObject '\(name)' - ✅ Extracted gradient from PDF shading '\(shadingName)'")
                        
                        // Apply gradient to the current path or create a clipped gradient shape
                        if hasPath {
                            print("\(detectedPDFVersion): XObject '\(name)' - 🎯 APPLYING GRADIENT to current path")
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
                            print("\(detectedPDFVersion): XObject '\(name)' - 🎯 CREATING GRADIENT SHAPE for clipped area")
                            // Create a gradient shape that will be clipped
                            activeGradient = gradient
                        }
                    } else {
                        print("\(detectedPDFVersion): XObject '\(name)' - ❌ Failed to extract gradient from shading '\(shadingName)'")
                    }
                    i += 1
                } else { i += 1 }
                
            case "n": // no-op path (often used with clipping)
                if hasPath {
                    print("\(detectedPDFVersion): XObject '\(name)' - 📐 PATH NO-OP - clipping path defined")
                    // In PDF, 'n' after 'W' means the path is used only for clipping, not drawing
                    // But the clipping path itself can still be filled or stroked later
                    // For now, keep the path for potential later use
                    print("\(detectedPDFVersion): XObject '\(name)' - 🖇️ Clipping path preserved for later operations")
                }
                i += 1
                
            case "Do": // XObject - XObject name comes BEFORE 'Do'
                if i >= 1,
                   let xobjectName = operations[i - 1].hasPrefix("/") ? String(operations[i - 1].dropFirst()) : nil {
                    print("\(detectedPDFVersion): XObject '\(name)' - 🚨 NESTED XObject reference: \(xobjectName)")
                    // Handle nested XObjects - this is likely where the black background is!
                    if xobjectName == "Fm2" {
                        print("\(detectedPDFVersion): XObject '\(name)' - 🔍 PROCESSING NESTED Fm2 - likely contains black background!")
                    }
                    // CRITICAL FIX: Pass the current XObject's resources as parent for nested lookup
                    processXObjectPDF17(name: xobjectName, parentResourcesDict: resourcesDict)
                    i += 1
                } else { i += 1 }
                
            case "f", "F": // fill
                if hasPath {
                    print("\(detectedPDFVersion): XObject '\(name)' - 🎨 FILL OPERATION - creating shape!")
                    // CRITICAL FIX: Temporarily restore outer scope opacity for shape creation
                    let tempFillOpacity = currentFillOpacity
                    let tempStrokeOpacity = currentStrokeOpacity
                    currentFillOpacity = savedFillOpacity
                    currentStrokeOpacity = savedStrokeOpacity
                    print("\(detectedPDFVersion): XObject '\(name)' - Using OUTER opacity for shape: fill=\(currentFillOpacity), stroke=\(currentStrokeOpacity)")
                    
                    createShapeFromCurrentPath(filled: true, stroked: false)
                    
                    // Restore XObject opacity values
                    currentFillOpacity = tempFillOpacity  
                    currentStrokeOpacity = tempStrokeOpacity
                    hasPath = false
                } else {
                    print("\(detectedPDFVersion): XObject '\(name)' - fill operation but no path!")
                }
                i += 1
                
            default:
                i += 1
            }
        }
        
        // CRITICAL FIX: Use the saved opacity for shape creation
        print("\(detectedPDFVersion): XObject '\(name)' - Using outer scope opacity for shape creation")
    }
}
