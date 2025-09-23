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
        print("PDF: 🖼️ =================  IMAGE PROCESSING START =================  🖼️")
        print("PDF: Processing Image XObject '\(name)'...")
        print("PDF: Current transform matrix: \(currentTransform)")

        // Check if we have a pending clip operator - this means the W was for image clipping
        if hasClipOperatorPending {
            print("PDF: 🎯 Image after W operator - creating clipping path for image")
            createClippingPathFromPending()
        }

        // Get the stream dictionary
        guard let streamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            print("PDF: Failed to get stream dictionary for image '\(name)'")
            return
        }

        // Get image dimensions
        var width: CGPDFInteger = 0
        var height: CGPDFInteger = 0

        guard CGPDFDictionaryGetInteger(streamDict, "Width", &width),
              CGPDFDictionaryGetInteger(streamDict, "Height", &height) else {
            print("PDF: Failed to get image dimensions for '\(name)'")
            return
        }

        print("PDF: Image '\(name)' dimensions: \(width)x\(height)")
        print("PDF: Current CTM for image: \(currentTransform)")

        // Check for SMask (Soft Mask) - indicates transparency
        var sMaskRef: CGPDFStreamRef?
        let hasSMask = CGPDFDictionaryGetStream(streamDict, "SMask", &sMaskRef)
        print("PDF: Has SMask (transparency): \(hasSMask)")

        // Extract SMask data if present
        var maskData: Data?
        if hasSMask, let sMask = sMaskRef {
            var maskFormat: CGPDFDataFormat = .raw
            if let sMaskData = CGPDFStreamCopyData(sMask, &maskFormat) {
                maskData = sMaskData as Data
                print("PDF: Extracted SMask data: \(maskData!.count) bytes")

                // Mark that we found a transparent image
                hasUpcomingTransparentImage = true
            }
        }

        print("PDF: 📏 Expected total bytes: \(width * height * 3) for RGB or \(width * height * 4) for RGBA")

        // Get the image data from the stream
        var format: CGPDFDataFormat = .raw
        guard let imageData = CGPDFStreamCopyData(xObjectStream, &format) else {
            print("PDF: Failed to extract image data for '\(name)'")
            return
        }

        print("PDF: Image data format: \(format.rawValue) (0=raw, 1=JPEG, 2=JPEG2000)")

        // Convert to NSData
        let nsData = imageData as NSData
        print("PDF: 📦 Actual data size: \(nsData.length) bytes")

        // DEBUG: Save raw PDF image data to disk for inspection
        let debugPath = "/Users/toddbruss/Documents/pdf_raw_image_\(name)_\(width)x\(height).dat"
        try? (nsData as Data).write(to: URL(fileURLWithPath: debugPath))
        print("PDF: 💾 DEBUG - Saved raw image data to: \(debugPath)")

        // Create a shape to represent the image
        var imageShape = VectorShape(name: "Image \(name)", path: VectorPath(elements: []))

        // Check if the data is already in a usable format or needs decoding
        if format == .jpegEncoded {
            // JPEG data can be used directly
            imageShape.embeddedImageData = nsData as Data
            print("PDF: ✅ Stored JPEG image data (\(nsData.length) bytes)")
            print("PDF: 🔍 Shape ID for image: \(imageShape.id)")
        } else if format == .JPEG2000 {
            // JPEG2000 data can be used directly
            imageShape.embeddedImageData = nsData as Data
            print("PDF: ✅ Stored JPEG2000 image data (\(nsData.length) bytes)")
            print("PDF: 🔍 Shape ID for image: \(imageShape.id)")
        } else {
            // Raw format - this is likely raw RGB pixel data
            // Create an NSImage from the raw pixel data
            print("PDF: Processing raw image data (\(nsData.length) bytes)")

            // Calculate bytes per pixel (usually 3 for RGB or 4 for RGBA)
            let totalPixels = width * height
            let bytesPerPixel = nsData.length / totalPixels
            print("PDF: Calculated \(bytesPerPixel) bytes per pixel for \(width)x\(height) image")

            // Handle RGB (3 bytes per pixel) by converting to RGBA
            if bytesPerPixel == 3 {
                // Convert RGB to RGBA by adding alpha channel
                let rgbaData = NSMutableData(capacity: width * height * 4)!
                let sourceBytes = nsData.bytes.assumingMemoryBound(to: UInt8.self)
                let maskBytes = maskData?.withUnsafeBytes { $0.bindMemory(to: UInt8.self) }

                for i in 0..<(width * height) {
                    let srcOffset = i * 3
                    rgbaData.append(sourceBytes + srcOffset, length: 3) // RGB

                    // Use mask data for alpha if available, otherwise full opacity
                    var alpha: UInt8
                    if let maskBytes = maskBytes, i < maskData!.count {
                        alpha = maskBytes[i]
                    } else {
                        alpha = 255 // Full opacity if no mask
                    }
                    rgbaData.append(&alpha, length: 1) // A
                }

                // DEBUG: Save RGBA data
                let rgbaDebugPath = "/Users/toddbruss/Documents/pdf_rgba_image_\(name)_\(width)x\(height).dat"
                try? (rgbaData as Data).write(to: URL(fileURLWithPath: rgbaDebugPath))
                print("PDF: 💾 DEBUG - Saved RGBA data to: \(rgbaDebugPath)")

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
                        print("PDF: ✅ Successfully converted RGB to PNG via NSBitmapImageRep (\(pngData.count) bytes)")
                        print("PDF: 🔍 Shape ID for image: \(imageShape.id)")

                        // DEBUG: Save PNG data
                        let pngDebugPath = "/Users/toddbruss/Documents/pdf_final_image_\(name).png"
                        try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                        print("PDF: 💾 DEBUG - Saved final PNG to: \(pngDebugPath)")
                    } else {
                        // Fallback: store RGBA data directly
                        imageShape.embeddedImageData = rgbaData as Data
                        print("PDF: Stored as RGBA data (fallback)")
                    }
                } else {
                    print("PDF: Could not create NSBitmapImageRep")
                    imageShape.embeddedImageData = nsData as Data
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
                            print("PDF: Successfully converted RGBA to PNG (\(pngData.count) bytes)")
                        } else {
                            imageShape.embeddedImageData = nsData as Data
                            print("PDF: Stored as RGBA data")
                        }
                    } else {
                        print("PDF: Could not create CGImage from context")
                        imageShape.embeddedImageData = nsData as Data
                    }
                } else {
                    print("PDF: Could not create RGBA context")
                    imageShape.embeddedImageData = nsData as Data
                }
            } else {
                // Unknown format - try as-is
                print("PDF: Unknown image format with \(bytesPerPixel) bytes per pixel")
                if NSImage(data: nsData as Data) != nil {
                    imageShape.embeddedImageData = nsData as Data
                    print("PDF: Raw data is actually a valid image format")
                } else {
                    imageShape.embeddedImageData = nsData as Data
                    print("PDF: WARNING - Storing raw data as-is, may not render")
                }
            }
        }

        // IMPORTANT: In PDFs, images are inherently 1x1 unit squares at origin
        // The CTM transforms them to final size and position
        // We need to extract the actual size from the CTM and store it as bounds

        // The CTM format is [a, b, c, d, tx, ty] where:
        // - a, d are scale factors for x and y
        // - b, c are rotation/skew factors
        // - tx, ty are translation values

        // Apply the transform to get final position and size
        let unitRect = CGRect(x: 0, y: 0, width: 1.0, height: 1.0)
        let finalRect = unitRect.applying(currentTransform)

        // Store transparent image bounds if applicable
        if hasUpcomingTransparentImage {
            transparentImageBounds = finalRect
            print("PDF: Stored transparent image bounds: \(finalRect)")
        }

        // Create a rectangle path for the image bounds using actual dimensions
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
                print("PDF: Image '\(name)' is clipped by path ID: \(clipId)")
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
            print("PDF: ✅ Added clipping path AFTER image for correct layer order")
        }

        // Clear the transparent image flag now that we've processed it
        if hasUpcomingTransparentImage {
            hasUpcomingTransparentImage = false
            print("PDF: Cleared transparent image flag after processing")
        }

        print("PDF: ✅ Created image shape '\(imageShape.name)' at \(finalRect.origin) size: \(finalRect.size)")
        print("PDF: 📦 Image has embedded data: \(imageShape.embeddedImageData != nil) (\(imageShape.embeddedImageData?.count ?? 0) bytes)")
        print("PDF: 🆔 Final shape ID: \(imageShape.id)")
        print("PDF: 🖼️ =================  IMAGE PROCESSING END =================  🖼️")
    }

    /// Enhanced XObject handler that supports both Form and Image XObjects
    func handleXObjectWithImageSupport(scanner: CGPDFScannerRef) {
        var namePtr: UnsafePointer<CChar>?

        guard CGPDFScannerPopName(scanner, &namePtr) else {
            print("PDF: Failed to read XObject name")
            return
        }

        let name = String(cString: namePtr!)
        processXObjectWithImageSupport(name: name)
    }

    /// Process an XObject with support for both Form and Image types
    func processXObjectWithImageSupport(name: String) {
        print("PDF: Processing XObject '\(name)' with image support...")

        guard let page = currentPage,
              let resourceDict = page.dictionary else {
            print("PDF: No current page or dictionary available")
            return
        }

        var resourcesRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),
              let resourcesDict = resourcesRef else {
            print("PDF: Page has no Resources dictionary")
            return
        }

        var xObjectDictRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),
              let xObjectDict = xObjectDictRef else {
            print("PDF: Resources has no XObject dictionary")
            return
        }

        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFDictionaryGetStream(xObjectDict, name, &xObjectStreamRef),
              let xObjectStream = xObjectStreamRef else {
            print("PDF: XObject '\(name)' is not a valid stream")
            return
        }

        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            print("PDF: XObject '\(name)' has no stream dictionary")
            return
        }

        // Get the subtype
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),
              let subtypeName = subtypeNamePtr else {
            print("PDF: XObject '\(name)' has no Subtype")
            return
        }

        let subtype = String(cString: subtypeName)

        switch subtype {
        case "Form":
            // Handle Form XObject - parse the form content stream directly
            print("PDF: XObject '\(name)' is a Form XObject - parsing content stream...")

            // Check if XObject has its own Resources dictionary
            var xObjectResourcesDict: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(xObjectStreamDict, "Resources", &xObjectResourcesDict) {
                print("PDF: XObject '\(name)' has its own Resources dictionary")
            } else {
                print("PDF: XObject '\(name)' will inherit parent Resources")
                xObjectResourcesDict = resourcesDict
            }

            // Parse the Form XObject content stream directly
            parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name, resourcesDict: xObjectResourcesDict)

        case "Image":
            // Handle Image XObject
            print("PDF: XObject '\(name)' is an Image XObject - extracting image data...")
            processImageXObject(name: name, xObjectStream: xObjectStream, currentTransform: currentTransformMatrix)

        default:
            print("PDF: XObject '\(name)' has unknown subtype: \(subtype)")
        }
    }
}

// MARK: - Clipping Path Support
extension PDFCommandParser {

    /// Handle clip operator 'W' or 'W*'
    func handleClipOperator() {
        print("PDF: Clip operator 'W' encountered")

        // For both single and compound paths, defer the decision until we see what comes next
        // We need to determine if it's for a gradient or an image

        if isInCompoundPath || !compoundPathParts.isEmpty {
            print("PDF: W operator with compound path - deferring decision until we see gradient or image")
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
            print("PDF: W operator - deferring clipping path decision until we see gradient or image")
            hasClipOperatorPending = true
            clipOperatorPath = currentPath  // Store the path
            // Don't clear currentPath - it will be used for gradient or converted to clipping for image
            return
        }

        print("PDF: Setting up clipping path for image/content clipping")

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

            print("PDF: Created PENDING clipping path with ID: \(clipShape.id) - will add after clipped content")
        }
    }

    /// Create clipping path from pending W operator path
    func createClippingPathFromPending() {
        guard hasClipOperatorPending else { return }

        print("PDF: Creating clipping path from pending W operator path")

        // Check if we have a compound path
        var allPathCommands: [[PathCommand]] = []

        if !compoundPathParts.isEmpty {
            print("PDF: Creating compound clipping path from \(compoundPathParts.count) parts")
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

        print("PDF: Created PENDING clipping path with ID: \(clipShape.id) - will add after clipped content")

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
            print("PDF: Resetting clipping state")

            // If we still have a pending clipping path, add it now
            if let pendingClip = pendingClippingPath {
                shapes.append(pendingClip)
                pendingClippingPath = nil
                print("PDF: Added pending clipping path at reset")
            }

            isInsideClippingPath = false
            currentClippingPathId = nil
        }
    }
}
