//
//  PDFContent+PDF14.swift
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
    
    /// Enhanced XObject handler that properly parses PDF 1.4 Form XObject content streams
    func handleXObjectPDF14(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?
        
        guard CGPDFScannerPopName(scanner, &namePtr) else {
            print("PDF 1.4: Failed to read XObject name")
            return
        }
        
        let name = String(cString: namePtr!)
        print("PDF 1.4: Processing XObject '\(name)'...")
        
        // Get the XObject from page resources with detailed debugging
        guard let page = currentPage else {
            print("PDF 1.4: No current page available")
            return
        }
        
        guard let resourceDict = page.dictionary else {
            print("PDF 1.4: Page has no dictionary")
            return
        }
        
        var resourcesRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),
              let resourcesDict = resourcesRef else {
            print("PDF 1.4: Page has no Resources dictionary")
            return
        }
        
        print("PDF 1.4: Found page Resources dictionary")
        
        var xObjectDictRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),
              let xObjectDict = xObjectDictRef else {
            print("PDF 1.4: Resources has no XObject dictionary")
            return
        }
        
        print("PDF 1.4: Found XObject dictionary")
        
        var xObjectRef: CGPDFObjectRef? = nil
        guard CGPDFDictionaryGetObject(xObjectDict, name, &xObjectRef),
              let xObject = xObjectRef else {
            print("PDF 1.4: XObject '\(name)' not found in XObject dictionary")
            return
        }
        
        print("PDF 1.4: Found XObject '\(name)' reference")
        
        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFObjectGetValue(xObject, .stream, &xObjectStreamRef),
              let xObjectStream = xObjectStreamRef else {
            print("PDF 1.4: XObject '\(name)' is not a stream object")
            return
        }
        
        print("PDF 1.4: XObject '\(name)' is a valid stream")
        
        // Check if it's a Form XObject
        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            print("PDF 1.4: Could not get XObject '\(name)' stream dictionary")
            return
        }
        
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),
              let subtypeName = subtypeNamePtr,
              String(cString: subtypeName) == "Form" else {
            let subtypeStr = subtypeNamePtr != nil ? String(cString: subtypeNamePtr!) : "unknown"
            print("PDF 1.4: XObject '\(name)' is not a Form XObject (\(subtypeStr)), skipping")
            return
        }
        
        print("PDF 1.4: XObject '\(name)' is a Form XObject - parsing content stream...")
        
        // Parse the XObject content stream
        parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name)
    }
    
    private func parseXObjectContentStream(_ xObjectStream: CGPDFStreamRef, dictionary: CGPDFDictionaryRef, name: String) {
        print("PDF 1.4: 🚨🚨🚨 DEBUG VERSION IS RUNNING FOR '\(name)' 🚨🚨🚨")
        print("PDF 1.4: XObject '\(name)' - reading content stream data...")
        
        // Get the raw stream data to see what's inside
        var format = CGPDFDataFormat.raw
        guard let data = CGPDFStreamCopyData(xObjectStream, &format) else {
            print("PDF 1.4: XObject '\(name)' - FAILED to get stream data")
            return
        }
        
        let dataLength = CFDataGetLength(data)
        print("PDF 1.4: XObject '\(name)' - content stream is \(dataLength) bytes")
        
        if let dataPtr = CFDataGetBytePtr(data), dataLength > 0 {
            // Convert first 200 characters to string to see the PDF operations
            let previewLength = min(dataLength, 200)
            let previewData = Data(bytes: dataPtr, count: previewLength)
            
            if let previewString = String(data: previewData, encoding: .ascii) {
                print("PDF 1.4: XObject '\(name)' - CONTENT PREVIEW:")
                print("=== START CONTENT ===")
                print(previewString)
                print("=== END CONTENT ===")
            } else {
                print("PDF 1.4: XObject '\(name)' - content is binary/compressed")
            }
            
            // Also check if it's compressed
            var compressionName: UnsafePointer<CChar>?
            if CGPDFDictionaryGetName(dictionary, "Filter", &compressionName),
               let compression = compressionName {
                print("PDF 1.4: XObject '\(name)' - compressed with: \(String(cString: compression))")
            } else {
                print("PDF 1.4: XObject '\(name)' - NOT compressed (raw content)")
            }
            
            // NOW ACTUALLY PARSE THE CONTENT STREAM!
            print("PDF 1.4: XObject '\(name)' - PARSING CONTENT STREAM FOR REAL!")
            
            // Create a simple content stream from the data and parse it
            if let contentString = String(data: previewData, encoding: .ascii), dataLength < 1000 {
                // For small streams, show full content
                print("PDF 1.4: XObject '\(name)' - FULL CONTENT:")
                print(String(data: Data(bytes: dataPtr, count: dataLength), encoding: .ascii) ?? "binary")
            }
            
            // Use the decompressed data to create a content stream and parse it
            parseDecompressedXObjectContent(data: data, name: name)
            
        } else {
            print("PDF 1.4: XObject '\(name)' - EMPTY content stream!")
        }
    }
    
    private func parseDecompressedXObjectContent(data: CFData, name: String) {
        print("PDF 1.4: XObject '\(name)' - parsing content manually...")
        
        guard let dataPtr = CFDataGetBytePtr(data) else {
            print("PDF 1.4: XObject '\(name)' - no data pointer")
            return
        }
        
        let dataLength = CFDataGetLength(data)
        let fullData = Data(bytes: dataPtr, count: dataLength)
        
        guard let contentString = String(data: fullData, encoding: .ascii) else {
            print("PDF 1.4: XObject '\(name)' - content is not ASCII readable")
            return
        }
        
        print("PDF 1.4: XObject '\(name)' - FULL CONTENT TO PARSE:")
        print("'" + contentString + "'")
        
        // Parse the operations manually for now
        let operations = contentString.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        print("PDF 1.4: XObject '\(name)' - found \(operations.count) operations: \(operations)")
        
        // Look for specific patterns we know create shapes
        if operations.contains("f") || operations.contains("F") {
            print("PDF 1.4: XObject '\(name)' - ✅ CONTAINS FILL OPERATION - this should create a shape!")
            
            // Extract path operations
            parseXObjectOperations(operations, name: name)
        } else {
            print("PDF 1.4: XObject '\(name)' - no fill operations found")
        }
    }
    
    private func parseXObjectOperations(_ operations: [String], name: String) {
        print("PDF 1.4: XObject '\(name)' - manually parsing operations to create shape...")
        
        var i = 0
        var hasPath = false
        
        while i < operations.count {
            let op = operations[i]
            print("PDF 1.4: XObject '\(name)' - parsing operation [\(i)]: '\(op)'")
            
            switch op {
            case "sc": // RGB color (follows the 3 RGB values)
                if i >= 3,
                   let r = Double(operations[i - 3]),
                   let g = Double(operations[i - 2]), 
                   let b = Double(operations[i - 1]) {
                    currentFillColor = CGColor(red: r, green: g, blue: b, alpha: 1.0)
                    print("PDF 1.4: XObject '\(name)' - RGB color: (\(r), \(g), \(b))")
                }
                i += 1
                
            case "m": // moveTo - parameters come BEFORE the 'm'
                if i >= 2,
                   let x = Double(operations[i - 2]),
                   let y = Double(operations[i - 1]) {
                    currentPath.append(.moveTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    print("PDF 1.4: XObject '\(name)' - moveTo(\(x), \(y))")
                    i += 1
                } else { 
                    print("PDF 1.4: XObject '\(name)' - ERROR: moveTo missing parameters before index \(i)")
                    i += 1 
                }
                
            case "l": // lineTo - parameters come BEFORE the 'l'
                if i >= 2,
                   let x = Double(operations[i - 2]),
                   let y = Double(operations[i - 1]) {
                    currentPath.append(.lineTo(CGPoint(x: x, y: y)))
                    hasPath = true
                    print("PDF 1.4: XObject '\(name)' - lineTo(\(x), \(y))")
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
                    print("PDF 1.4: XObject '\(name)' - curveTo(\(x1), \(y1), \(x2), \(y2), \(x3), \(y3))")
                    i += 1
                } else { i += 1 }
                
            case "h": // closePath
                currentPath.append(.closePath)
                hasPath = true
                print("PDF 1.4: XObject '\(name)' - closePath")
                i += 1
                
            case "f", "F": // fill
                if hasPath {
                    print("PDF 1.4: XObject '\(name)' - 🎨 FILL OPERATION - creating shape!")
                    createShapeFromCurrentPath(filled: true, stroked: false)
                    hasPath = false
                } else {
                    print("PDF 1.4: XObject '\(name)' - fill operation but no path!")
                }
                i += 1
                
            default:
                i += 1
            }
        }
    }
    
    private func createPDF14OperatorTable() -> CGPDFOperatorTableRef? {
        guard let operatorTable = CGPDFOperatorTableCreate() else { return nil }
        
        // Path construction operators
        CGPDFOperatorTableSetCallback(operatorTable, "m") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleMoveTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "l") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleLineTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "c") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveTo(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "v") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToV(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "y") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCurveToY(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "h") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleClosePath()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "re") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRectangle(scanner: scanner)
        }
        
        // Color operators
        CGPDFOperatorTableSetCallback(operatorTable, "rg") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "RG") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleRGBStrokeColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "g") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "G") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGrayStrokeColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "k") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "K") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleCMYKStrokeColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "sc") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericFillColor(scanner: scanner)
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "SC") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGenericStrokeColor(scanner: scanner)
        }
        
        // Fill and stroke operators
        CGPDFOperatorTableSetCallback(operatorTable, "f") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "F") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "S") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "f*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFill()
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "B*") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleFillAndStroke()
        }
        
        // Graphics state operators
        CGPDFOperatorTableSetCallback(operatorTable, "q") { (scanner, info) in
            print("PDF 1.4: XObject 'q' (save graphics state)")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "Q") { (scanner, info) in
            print("PDF 1.4: XObject 'Q' (restore graphics state)")
        }
        
        CGPDFOperatorTableSetCallback(operatorTable, "gs") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleGraphicsState(scanner: scanner)
        }
        
        // Nested XObject support
        CGPDFOperatorTableSetCallback(operatorTable, "Do") { (scanner, info) in
            let parser = Unmanaged<PDFCommandParser>.fromOpaque(info!).takeUnretainedValue()
            parser.handleXObjectPDF14(scanner: scanner)
        }
        
        // Path construction no-op
        CGPDFOperatorTableSetCallback(operatorTable, "n") { (scanner, info) in
            print("PDF 1.4: XObject path construction no-op 'n'")
        }
        
        return operatorTable
    }
}
