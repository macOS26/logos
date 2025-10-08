//
//  PDFContent+ImageSupport.swift
//  logos inkpen.io
//
//  Created by Claude on 1/13/25.
//

import SwiftUI
import PDFKit
import AppKit

// MARK: - PDF Image XObject Support Extension
extension PDFCommandParser {

    /// Process an Image XObject
    func processImageXObject(name: String, xObjectStream: CGPDFStreamRef, currentTransform: CGAffineTransform) {

        // Check if we have a pending clip operator - this means the W was for image clipping
        if hasClipOperatorPending {
            createClippingPathFromPending()
        }

        // Get the stream dictionary
        guard let streamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            Log.error("PDF: Failed to get stream dictionary for image '\(name)'", category: .error)
            return
        }

        // Get image dimensions
        var width: CGPDFInteger = 0
        var height: CGPDFInteger = 0

        guard CGPDFDictionaryGetInteger(streamDict, "Width", &width),
              CGPDFDictionaryGetInteger(streamDict, "Height", &height) else {
            Log.error("PDF: Failed to get image dimensions for '\(name)'", category: .error)
            return
        }


        // Check for SMask (Soft Mask) - indicates transparency
        var sMaskRef: CGPDFStreamRef?
        let hasSMask = CGPDFDictionaryGetStream(streamDict, "SMask", &sMaskRef)

        // Extract SMask data if present
        var maskData: Data?
        if hasSMask, let sMask = sMaskRef {
            var maskFormat: CGPDFDataFormat = .raw
            if let sMaskData = CGPDFStreamCopyData(sMask, &maskFormat) {
                maskData = sMaskData as Data

                // Mark that we found a transparent image
                hasUpcomingTransparentImage = true
            }
        }

        // Check ColorSpace to determine image format
        var colorSpaceObj: CGPDFObjectRef?
        var colorSpaceName: String = "Unknown"
        var isIndexedColor = false
        var colorPalette: Data?

        if CGPDFDictionaryGetObject(streamDict, "ColorSpace", &colorSpaceObj), let csObj = colorSpaceObj {
            var namePtr: UnsafePointer<CChar>?
            if CGPDFObjectGetValue(csObj, .name, &namePtr), let name = namePtr {
                colorSpaceName = String(cString: name)
            } else if CGPDFObjectGetValue(csObj, .array, &colorSpaceObj) {
                // ColorSpace is an array - likely [/Indexed /DeviceRGB ...]
                var arrayRef: CGPDFArrayRef?
                if CGPDFObjectGetValue(csObj, .array, &arrayRef), let array = arrayRef {
                    var firstElement: CGPDFObjectRef?
                    if CGPDFArrayGetObject(array, 0, &firstElement), let first = firstElement {
                        if CGPDFObjectGetValue(first, .name, &namePtr), let name = namePtr {
                            colorSpaceName = String(cString: name)
                            isIndexedColor = (colorSpaceName == "Indexed")

                            // For indexed color, extract the palette
                            if isIndexedColor && CGPDFArrayGetCount(array) >= 4 {
                                var paletteString: CGPDFStringRef?
                                var paletteStream: CGPDFStreamRef?
                                if CGPDFArrayGetString(array, 3, &paletteString), let palString = paletteString {
                                    let length = CGPDFStringGetLength(palString)
                                    if let bytePtr = CGPDFStringGetBytePtr(palString) {
                                        colorPalette = Data(bytes: bytePtr, count: length)
                                    }
                                } else if CGPDFArrayGetStream(array, 3, &paletteStream), let palStream = paletteStream {
                                    var palFormat: CGPDFDataFormat = .raw
                                    if let palData = CGPDFStreamCopyData(palStream, &palFormat) {
                                        colorPalette = palData as Data
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }


        // Get the image data from the stream
        var format: CGPDFDataFormat = .raw
        guard let imageData = CGPDFStreamCopyData(xObjectStream, &format) else {
            Log.error("PDF: Failed to extract image data for '\(name)'", category: .error)
            return
        }


        // Convert to NSData
        let nsData = imageData as NSData

        // DEBUG: Save raw PDF image data to disk for inspection
        let debugPath = "/Users/toddbruss/Documents/pdf_raw_image_\(name)_\(width)x\(height).dat"
        try? (nsData as Data).write(to: URL(fileURLWithPath: debugPath))

        // Create a shape to represent the image
        var imageShape = VectorShape(name: "Image \(name)", path: VectorPath(elements: []))

        // Check if the data is already in a usable format or needs decoding
        if format == .jpegEncoded {
            // JPEG data can be used directly
            imageShape.embeddedImageData = nsData as Data
        } else if format == .JPEG2000 {
            // JPEG2000 data can be used directly
            imageShape.embeddedImageData = nsData as Data
        } else {
            // Raw format - this is likely raw RGB pixel data
            // Create an NSImage from the raw pixel data

            // Calculate bytes per pixel (usually 3 for RGB, 4 for RGBA, or 1 for indexed/gray)
            let totalPixels = width * height
            let bytesPerPixel = nsData.length / totalPixels

            // Handle indexed color (1 byte per pixel with color palette)
            if bytesPerPixel == 1 && isIndexedColor, let palette = colorPalette {

                // Try GPU acceleration first (MUCH faster for large images)
                if let gpuRGBAData = PDFMetalProcessor.shared.convertIndexedToRGBA(
                    indexData: nsData as Data,
                    paletteData: palette,
                    maskData: maskData,
                    width: width,
                    height: height
                ) {
                    // GPU conversion succeeded!
                    let rgbaData = NSMutableData(data: gpuRGBAData)

                // DEBUG: Save RGBA data
                let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_indexed_rgba_image_\(name)_\(width)x\(height).dat"
                try? (rgbaData as Data).write(to: URL(fileURLWithPath: rgbaDebugPath))

                // Create bitmap representation
                let bitmapRep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: width,
                    pixelsHigh: height,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bitmapFormat: hasSMask ? [.alphaNonpremultiplied] : [],
                    bytesPerRow: width * 4,
                    bitsPerPixel: 32
                )

                if let bitmapRep = bitmapRep {
                    // Copy RGBA data to bitmap
                    let bitmapData = bitmapRep.bitmapData!
                    rgbaData.getBytes(bitmapData, length: width * height * 4)

                    // Create NSImage from bitmap
                    let nsImage = NSImage(size: NSSize(width: width, height: height))
                    nsImage.addRepresentation(bitmapRep)

                    // Convert to PNG
                    if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        imageShape.embeddedImageData = pngData

                        // DEBUG: Save PNG data
                        let pngDebugPath = "/Users/toddbruss/Documents/pdf_indexed_final_image_\(name).png"
                        try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                    } else {
                        // Fallback: store RGBA data directly
                        imageShape.embeddedImageData = rgbaData as Data
                    }
                } else {
                    imageShape.embeddedImageData = nsData as Data
                }
                } else {
                    // GPU failed or unavailable - fall back to CPU
                    Log.warning("⚠️ Using CPU fallback for indexed->RGBA conversion", category: .general)

                    guard let rgbaData = NSMutableData(capacity: width * height * 4) else {
                        Log.error("PDF: Failed to allocate RGBA data for indexed image", category: .error)
                        return
                    }

                    let indexBytes = nsData.bytes.assumingMemoryBound(to: UInt8.self)
                    let paletteBytes = palette.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }
                    let paletteEntries = palette.count / 3  // Each palette entry is 3 bytes (RGB)


                    for i in 0..<(width * height) {
                        let paletteIndex = Int(indexBytes[i])

                        // Bounds check
                        if paletteIndex < paletteEntries {
                            let paletteOffset = paletteIndex * 3
                            rgbaData.append(paletteBytes.baseAddress! + paletteOffset, length: 3) // RGB from palette
                        } else {
                            // Out of bounds - use black
                            var black: [UInt8] = [0, 0, 0]
                            rgbaData.append(&black, length: 3)
                        }

                        // Add alpha channel
                        var alpha: UInt8
                        if let maskBytes = maskData?.withUnsafeBytes({ $0.bindMemory(to: UInt8.self) }), i < (maskData?.count ?? 0) {
                            alpha = maskBytes[i]
                        } else {
                            alpha = 255 // Full opacity
                        }
                        rgbaData.append(&alpha, length: 1)
                    }

                    // DEBUG: Save RGBA data
                    let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_indexed_rgba_image_\(name)_\(width)x\(height).dat"
                    try? (rgbaData as Data).write(to: URL(fileURLWithPath: rgbaDebugPath))

                    // Create bitmap representation
                    let bitmapRep = NSBitmapImageRep(
                        bitmapDataPlanes: nil,
                        pixelsWide: width,
                        pixelsHigh: height,
                        bitsPerSample: 8,
                        samplesPerPixel: 4,
                        hasAlpha: true,
                        isPlanar: false,
                        colorSpaceName: .deviceRGB,
                        bitmapFormat: hasSMask ? [.alphaNonpremultiplied] : [],
                        bytesPerRow: width * 4,
                        bitsPerPixel: 32
                    )

                    if let bitmapRep = bitmapRep {
                        // Copy RGBA data to bitmap
                        let bitmapData = bitmapRep.bitmapData!
                        rgbaData.getBytes(bitmapData, length: width * height * 4)

                        // Create NSImage from bitmap
                        let nsImage = NSImage(size: NSSize(width: width, height: height))
                        nsImage.addRepresentation(bitmapRep)

                        // Convert to PNG
                        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                            imageShape.embeddedImageData = pngData

                            // DEBUG: Save PNG data
                            let pngDebugPath = "/Users/toddbruss/Documents/pdf_indexed_final_image_\(name).png"
                            try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                        } else {
                            // Fallback: store RGBA data directly
                            imageShape.embeddedImageData = rgbaData as Data
                        }
                    } else {
                        imageShape.embeddedImageData = nsData as Data
                    }
                }
            }
            // Handle RGB (3 bytes per pixel) by converting to RGBA
            else if bytesPerPixel == 3 {
                // Try GPU acceleration first (MUCH faster for large images)
                if let gpuRGBAData = PDFMetalProcessor.shared.convertRGBtoRGBA(
                    rgbData: nsData as Data,
                    maskData: maskData,
                    width: width,
                    height: height
                ) {
                    // GPU conversion succeeded!
                    let rgbaData = NSMutableData(data: gpuRGBAData)

                // DEBUG: Save RGBA data
                let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_rgba_image_\(name)_\(width)x\(height).dat"
                try? (rgbaData as Data).write(to: URL(fileURLWithPath: rgbaDebugPath))

                // Create bitmap representation with proper alpha handling
                let bitmapRep = NSBitmapImageRep(
                    bitmapDataPlanes: nil,
                    pixelsWide: width,
                    pixelsHigh: height,
                    bitsPerSample: 8,
                    samplesPerPixel: 4,
                    hasAlpha: true,
                    isPlanar: false,
                    colorSpaceName: .deviceRGB,
                    bitmapFormat: hasSMask ? [.alphaNonpremultiplied] : [],
                    bytesPerRow: width * 4,
                    bitsPerPixel: 32
                )

                if let bitmapRep = bitmapRep {
                    // Copy RGBA data to bitmap
                    let bitmapData = bitmapRep.bitmapData!
                    rgbaData.getBytes(bitmapData, length: width * height * 4)

                    // Create NSImage from bitmap
                    let nsImage = NSImage(size: NSSize(width: width, height: height))
                    nsImage.addRepresentation(bitmapRep)

                    // Convert to PNG
                    if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                        imageShape.embeddedImageData = pngData

                        // DEBUG: Save PNG data
                        let pngDebugPath = "/Users/toddbruss/Documents/pdf_final_image_\(name).png"
                        try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                    } else {
                        // Fallback: store RGBA data directly
                        imageShape.embeddedImageData = rgbaData as Data
                    }
                } else {
                    imageShape.embeddedImageData = nsData as Data
                }
                } else {
                    // GPU failed or unavailable - fall back to CPU
                    Log.warning("⚠️ Using CPU fallback for RGB->RGBA conversion", category: .general)

                    guard let rgbaData = NSMutableData(capacity: width * height * 4) else {
                        Log.error("PDF: Failed to allocate RGBA data", category: .error)
                        return
                    }
                    let sourceBytes = nsData.bytes.assumingMemoryBound(to: UInt8.self)
                    let maskBytes = maskData?.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }

                    for i in 0..<(width * height) {
                        let srcOffset = i * 3
                        rgbaData.append(sourceBytes + srcOffset, length: 3) // RGB

                        // Use mask data for alpha if available, otherwise full opacity
                        var alpha: UInt8
                        if let maskBytes = maskBytes, i < (maskData?.count ?? 0) {
                            alpha = maskBytes[i]
                        } else {
                            alpha = 255 // Full opacity if no mask
                        }
                        rgbaData.append(&alpha, length: 1) // A
                    }

                    // DEBUG: Save RGBA data
                    let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_rgba_image_\(name)_\(width)x\(height).dat"
                    try? (rgbaData as Data).write(to: URL(fileURLWithPath: rgbaDebugPath))

                    // Create bitmap representation with proper alpha handling
                    let bitmapRep = NSBitmapImageRep(
                        bitmapDataPlanes: nil,
                        pixelsWide: width,
                        pixelsHigh: height,
                        bitsPerSample: 8,
                        samplesPerPixel: 4,
                        hasAlpha: true,
                        isPlanar: false,
                        colorSpaceName: .deviceRGB,
                        bitmapFormat: hasSMask ? [.alphaNonpremultiplied] : [],
                        bytesPerRow: width * 4,
                        bitsPerPixel: 32
                    )

                    if let bitmapRep = bitmapRep {
                        // Copy RGBA data to bitmap
                        let bitmapData = bitmapRep.bitmapData!
                        rgbaData.getBytes(bitmapData, length: width * height * 4)

                        // Create NSImage from bitmap
                        let nsImage = NSImage(size: NSSize(width: width, height: height))
                        nsImage.addRepresentation(bitmapRep)

                        // Convert to PNG
                        if let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                            imageShape.embeddedImageData = pngData

                            // DEBUG: Save PNG data
                            let pngDebugPath = "/Users/toddbruss/Documents/pdf_final_image_\(name).png"
                            try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                        } else {
                            // Fallback: store RGBA data directly
                            imageShape.embeddedImageData = rgbaData as Data
                        }
                    } else {
                        imageShape.embeddedImageData = nsData as Data
                    }
                }
            } else if bytesPerPixel == 4 {
                // RGBA data - handle with proper alpha premultiplication
                let colorSpace = CGColorSpaceCreateDeviceRGB()
                // Use premultipliedLast for proper transparency handling
                let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

                if let context = CGContext(
                    data: UnsafeMutableRawPointer(mutating: nsData.bytes),
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width * 4,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo.rawValue
                ) {
                    if let cgImage = context.makeImage() {
                        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

                        if let tiffData = nsImage.tiffRepresentation,
                           let bitmap = NSBitmapImageRep(data: tiffData),
                           let pngData = bitmap.representation(using: .png, properties: [:]) {
                            imageShape.embeddedImageData = pngData
                        } else {
                            imageShape.embeddedImageData = nsData as Data
                        }
                    } else {
                        imageShape.embeddedImageData = nsData as Data
                    }
                } else {
                    imageShape.embeddedImageData = nsData as Data
                }
            } else {
                // Unknown format - try as-is
                if NSImage(data: nsData as Data) != nil {
                    imageShape.embeddedImageData = nsData as Data
                } else {
                    imageShape.embeddedImageData = nsData as Data
                    Log.warning("PDF: WARNING - Storing raw data as-is, may not render", category: .general)
                }
            }
        }

        // CRITICAL: In PDFs, images are ALWAYS defined as 1x1 unit squares at origin (0,0) -> (1,1)
        // The CTM (Current Transform Matrix) transforms this unit square to final position/size
        // We MUST apply the CTM to get accurate image positioning in ANY PDF file
        let unitRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
        let pdfRect = unitRect.applying(currentTransform)

        // CRITICAL: Flip Y-axis because PDF has origin at bottom-left, we use top-left
        let flippedY = pageSize.height - pdfRect.maxY  // maxY becomes minY after flip
        let finalRect = CGRect(x: pdfRect.minX, y: flippedY, width: pdfRect.width, height: pdfRect.height)


        // Store transparent image bounds if applicable
        if hasUpcomingTransparentImage {
            transparentImageBounds = finalRect
        }

        // Create a rectangle path for the image bounds
        var imagePath = VectorPath(elements: [])
        imagePath.elements.append(.move(to: VectorPoint(finalRect.minX, finalRect.minY)))
        imagePath.elements.append(.line(to: VectorPoint(finalRect.maxX, finalRect.minY)))
        imagePath.elements.append(.line(to: VectorPoint(finalRect.maxX, finalRect.maxY)))
        imagePath.elements.append(.line(to: VectorPoint(finalRect.minX, finalRect.maxY)))
        imagePath.elements.append(.close)

        imageShape.path = imagePath
        imageShape.bounds = finalRect

        // Store the transform for proper rendering
        imageShape.transform = .identity  // The bounds already contain the final position

        // Check if we're inside a clipping path
        if isInsideClippingPath {
            // Mark this image as clipped by the current clipping path
            if let clipId = currentClippingPathId {
                imageShape.clippedByShapeID = clipId
            }
        }

        // Apply current opacity
        imageShape.opacity = Double(currentFillOpacity)

        // Add the image shape to our shapes array
        // CRITICAL FIX: If there's a pending clipping path, add image first, then clipping path
        shapes.append(imageShape)

        // If we have a pending clipping path, add it now AFTER the image
        if let pendingClip = pendingClippingPath {
            shapes.append(pendingClip)
            pendingClippingPath = nil

            // CRITICAL: Completely reset ALL clipping and compound path state
            // This ensures the NEXT image with clipping path is treated as SEPARATE, not combined
            isInsideClippingPath = false
            currentClippingPathId = nil
            isInCompoundPath = false
            compoundPathParts.removeAll()
            moveToCount = 0
            hasClipOperatorPending = false
            clipOperatorPath.removeAll()
        }

        // Clear the transparent image flag now that we've processed it
        if hasUpcomingTransparentImage {
            hasUpcomingTransparentImage = false
        }

    }

    /// Enhanced XObject handler that supports both Form and Image XObjects
    func handleXObjectWithImageSupport(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?

        guard CGPDFScannerPopName(scanner, &namePtr) else {
            Log.error("PDF: Failed to read XObject name", category: .error)
            return
        }

        let name = String(cString: namePtr!)
        processXObjectWithImageSupport(name: name)
    }

    /// Process an XObject with support for both Form and Image types
    func processXObjectWithImageSupport(name: String) {

        guard let page = currentPage,
              let resourceDict = page.dictionary else {
            return
        }

        var resourcesRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),
              let resourcesDict = resourcesRef else {
            return
        }

        var xObjectDictRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),
              let xObjectDict = xObjectDictRef else {
            return
        }

        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFDictionaryGetStream(xObjectDict, name, &xObjectStreamRef),
              let xObjectStream = xObjectStreamRef else {
            return
        }

        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            return
        }

        // Get the subtype
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),
              let subtypeName = subtypeNamePtr else {
            return
        }

        let subtype = String(cString: subtypeName)

        switch subtype {
        case "Form":
            // Handle Form XObject - parse the form content stream directly

            // Check if XObject has its own Resources dictionary
            var xObjectResourcesDict: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(xObjectStreamDict, "Resources", &xObjectResourcesDict) {
            } else {
                xObjectResourcesDict = resourcesDict
            }

            // Parse the Form XObject content stream directly
            parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name, resourcesDict: xObjectResourcesDict)

        case "Image":
            // Handle Image XObject
            processImageXObject(name: name, xObjectStream: xObjectStream, currentTransform: currentTransformMatrix)

        default:
            break
        }
    }
}

// MARK: - Clipping Path Support
extension PDFCommandParser {

    /// Handle clip operator 'W' or 'W*'
    func handleClipOperator() {

        // For both single and compound paths, defer the decision until we see what comes next
        // We need to determine if it's for a gradient or an image

        if isInCompoundPath || !compoundPathParts.isEmpty {
            hasClipOperatorPending = true

            // Store the compound path parts
            if !currentPath.isEmpty {
                compoundPathParts.append(currentPath)
            }
            clipOperatorPath = currentPath  // Store current part
            // Note: Keep compound path state intact for now
            return
        }

        // For single paths, defer the decision
        if !currentPath.isEmpty {
            hasClipOperatorPending = true
            clipOperatorPath = currentPath  // Store the path
            // Don't clear currentPath - it will be used for gradient or converted to clipping for image
            return
        }


        // Create a clipping path shape from current path (only for actual image clipping)
        if !currentPath.isEmpty {
            // Convert PathCommands to PathElements
            var pathElements: [PathElement] = []
            for cmd in currentPath {
                switch cmd {
                case .moveTo(let pt):
                    // Flip Y coordinate: PDF has origin at bottom-left, we need top-left
                    pathElements.append(.move(to: VectorPoint(pt.x, pageSize.height - pt.y)))
                case .lineTo(let pt):
                    pathElements.append(.line(to: VectorPoint(pt.x, pageSize.height - pt.y)))
                case .curveTo(let cp1, let cp2, let pt):
                    pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                              control1: VectorPoint(cp1.x, pageSize.height - cp1.y),
                                              control2: VectorPoint(cp2.x, pageSize.height - cp2.y)))
                case .quadCurveTo(let cp, let pt):
                    // Convert quadratic to cubic bezier with flipped Y
                    pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                              control1: VectorPoint(cp.x, pageSize.height - cp.y),
                                              control2: VectorPoint(cp.x, pageSize.height - cp.y)))
                case .rectangle(let rect):
                    // Convert rectangle to path elements with flipped Y
                    let flippedMinY = pageSize.height - rect.maxY  // maxY becomes minY after flip
                    let flippedMaxY = pageSize.height - rect.minY  // minY becomes maxY after flip
                    pathElements.append(.move(to: VectorPoint(rect.minX, flippedMinY)))
                    pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMinY)))
                    pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMaxY)))
                    pathElements.append(.line(to: VectorPoint(rect.minX, flippedMaxY)))
                    pathElements.append(.close)
                case .closePath:
                    pathElements.append(.close)
                }
            }
            let clipPath = VectorPath(elements: pathElements)
            var clipShape = VectorShape(name: "Clipping Path", path: clipPath)
            clipShape.isClippingPath = true

            // Store the clip ID for associating with clipped content
            currentClippingPathId = clipShape.id
            isInsideClippingPath = true

            // Don't add the clipping path immediately - store it as pending
            // It will be added AFTER the content it clips
            pendingClippingPath = clipShape

        }
    }

    /// Create clipping path from pending W operator path
    func createClippingPathFromPending() {
        guard hasClipOperatorPending else { return }


        // Check if we have a compound path
        var allPathCommands: [[PathCommand]] = []

        if !compoundPathParts.isEmpty {
            allPathCommands = compoundPathParts
            // Add current path if not empty
            if !clipOperatorPath.isEmpty {
                allPathCommands.append(clipOperatorPath)
            }
        } else if !clipOperatorPath.isEmpty {
            allPathCommands = [clipOperatorPath]
        } else {
            return
        }

        // Convert all path parts to PathElements
        var pathElements: [PathElement] = []
        for pathCommands in allPathCommands {
            for cmd in pathCommands {
            switch cmd {
            case .moveTo(let pt):
                // Flip Y coordinate: PDF has origin at bottom-left, we need top-left
                pathElements.append(.move(to: VectorPoint(pt.x, pageSize.height - pt.y)))
            case .lineTo(let pt):
                pathElements.append(.line(to: VectorPoint(pt.x, pageSize.height - pt.y)))
            case .curveTo(let cp1, let cp2, let pt):
                pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                          control1: VectorPoint(cp1.x, pageSize.height - cp1.y),
                                          control2: VectorPoint(cp2.x, pageSize.height - cp2.y)))
            case .quadCurveTo(let cp, let pt):
                // Convert quadratic to cubic bezier with flipped Y
                pathElements.append(.curve(to: VectorPoint(pt.x, pageSize.height - pt.y),
                                          control1: VectorPoint(cp.x, pageSize.height - cp.y),
                                          control2: VectorPoint(cp.x, pageSize.height - cp.y)))
            case .rectangle(let rect):
                // Convert rectangle to path elements with flipped Y
                let flippedMinY = pageSize.height - rect.maxY  // maxY becomes minY after flip
                let flippedMaxY = pageSize.height - rect.minY  // minY becomes maxY after flip
                pathElements.append(.move(to: VectorPoint(rect.minX, flippedMinY)))
                pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMinY)))
                pathElements.append(.line(to: VectorPoint(rect.maxX, flippedMaxY)))
                pathElements.append(.line(to: VectorPoint(rect.minX, flippedMaxY)))
                pathElements.append(.close)
            case .closePath:
                pathElements.append(.close)
            }
            }
        }

        let clipPath = VectorPath(elements: pathElements)
        var clipShape = VectorShape(name: "Clipping Path", path: clipPath)
        clipShape.isClippingPath = true

        // Store the clip ID for associating with clipped content
        currentClippingPathId = clipShape.id
        isInsideClippingPath = true

        // Don't add the clipping path immediately - store it as pending
        // It will be added AFTER the content it clips
        pendingClippingPath = clipShape


        // Clear the pending state and compound path state if used
        hasClipOperatorPending = false
        clipOperatorPath.removeAll()

        // Clear compound path state if we used it for clipping
        if !compoundPathParts.isEmpty {
            compoundPathParts.removeAll()
            isInCompoundPath = false
            currentPath.removeAll()
        }
    }

    /// Reset clipping state (called on restore graphics state 'Q')
    func resetClippingState() {
        if isInsideClippingPath {

            // If we still have a pending clipping path, add it now
            if let pendingClip = pendingClippingPath {
                shapes.append(pendingClip)
                pendingClippingPath = nil
            }

            isInsideClippingPath = false
            currentClippingPathId = nil
        }
    }

    /// Finalize clipping group - called when Q operator ends a clipping group
    /// This ensures each q/Q block with a clipping mask is treated as SEPARATE
    func finalizeClippingGroup() {

        // If we have a pending clipping path, add it now
        if let pendingClip = pendingClippingPath {
            shapes.append(pendingClip)
            pendingClippingPath = nil
        }

        // CRITICAL: Completely reset ALL clipping and compound path state
        // Each q/Q block is a SEPARATE clipping group
        isInsideClippingPath = false
        currentClippingPathId = nil
        isInCompoundPath = false
        compoundPathParts.removeAll()
        moveToCount = 0
        hasClipOperatorPending = false
        clipOperatorPath.removeAll()
        currentPath.removeAll()  // Also clear current path

    }

    // MARK: - Graphics State Stack for q/Q operators

    /// Save graphics state (q operator)
    func saveGraphicsState() {
        let state = PDFGraphicsState(
            transformMatrix: currentTransformMatrix,
            simdTransformMatrix: simdTransformMatrix, // SIMD-accelerated matrix
            fillOpacity: currentFillOpacity,
            strokeOpacity: currentStrokeOpacity,
            clippingPathId: currentClippingPathId,
            isInsideClippingPath: isInsideClippingPath,
            pendingClippingPath: pendingClippingPath
        )
        graphicsStateStack.append(state)
    }

    /// Restore graphics state (Q operator)
    func restoreGraphicsState() {
        // First finalize the current clipping group
        finalizeClippingGroup()

        // Then restore the saved state
        guard !graphicsStateStack.isEmpty else {
            return
        }

        let state = graphicsStateStack.removeLast()
        currentTransformMatrix = state.transformMatrix
        simdTransformMatrix = state.simdTransformMatrix // Restore SIMD matrix
        currentFillOpacity = state.fillOpacity
        currentStrokeOpacity = state.strokeOpacity
        currentClippingPathId = state.clippingPathId
        isInsideClippingPath = state.isInsideClippingPath
        pendingClippingPath = state.pendingClippingPath

    }
}
