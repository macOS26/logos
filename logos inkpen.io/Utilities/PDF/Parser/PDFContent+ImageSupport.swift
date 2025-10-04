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
        Log.info("PDF: 🖼️ =================  IMAGE PROCESSING START =================  🖼️", category: .general)
        Log.info("PDF: Processing Image XObject '\(name)'...", category: .general)
        Log.info("PDF: Current transform matrix: \(currentTransform)", category: .general)

        // Check if we have a pending clip operator - this means the W was for image clipping
        if hasClipOperatorPending {
            Log.info("PDF: 🎯 Image after W operator - creating clipping path for image", category: .general)
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

        Log.info("PDF: Image '\(name)' dimensions: \(width)x\(height)", category: .general)
        Log.info("PDF: Current CTM for image: \(currentTransform)", category: .general)

        // Check for SMask (Soft Mask) - indicates transparency
        var sMaskRef: CGPDFStreamRef?
        let hasSMask = CGPDFDictionaryGetStream(streamDict, "SMask", &sMaskRef)
        Log.info("PDF: Has SMask (transparency): \(hasSMask)", category: .general)

        // Extract SMask data if present
        var maskData: Data?
        if hasSMask, let sMask = sMaskRef {
            var maskFormat: CGPDFDataFormat = .raw
            if let sMaskData = CGPDFStreamCopyData(sMask, &maskFormat) {
                maskData = sMaskData as Data
                Log.info("PDF: Extracted SMask data: \(maskData?.count ?? 0) bytes", category: .general)

                // Mark that we found a transparent image
                hasUpcomingTransparentImage = true
            }
        }

        Log.info("PDF: 📏 Expected total bytes: \(width * height * 3) for RGB or \(width * height * 4) for RGBA", category: .general)

        // Get the image data from the stream
        var format: CGPDFDataFormat = .raw
        guard let imageData = CGPDFStreamCopyData(xObjectStream, &format) else {
            Log.error("PDF: Failed to extract image data for '\(name)'", category: .error)
            return
        }

        Log.info("PDF: Image data format: \(format.rawValue) (0=raw, 1=JPEG, 2=JPEG2000)", category: .general)

        // Convert to NSData
        let nsData = imageData as NSData
        Log.info("PDF: 📦 Actual data size: \(nsData.length) bytes", category: .general)

        // DEBUG: Save raw PDF image data to disk for inspection
        let debugPath = "/Users/toddbruss/Documents/pdf_raw_image_\(name)_\(width)x\(height).dat"
        try? (nsData as Data).write(to: URL(fileURLWithPath: debugPath))
        Log.info("PDF: 💾 DEBUG - Saved raw image data to: \(debugPath)", category: .debug)

        // Create a shape to represent the image
        var imageShape = VectorShape(name: "Image \(name)", path: VectorPath(elements: []))

        // Check if the data is already in a usable format or needs decoding
        if format == .jpegEncoded {
            // JPEG data can be used directly
            imageShape.embeddedImageData = nsData as Data
            Log.info("PDF: ✅ Stored JPEG image data (\(nsData.length) bytes)", category: .general)
            Log.info("PDF: 🔍 Shape ID for image: \(imageShape.id)", category: .debug)
        } else if format == .JPEG2000 {
            // JPEG2000 data can be used directly
            imageShape.embeddedImageData = nsData as Data
            Log.info("PDF: ✅ Stored JPEG2000 image data (\(nsData.length) bytes)", category: .general)
            Log.info("PDF: 🔍 Shape ID for image: \(imageShape.id)", category: .debug)
        } else {
            // Raw format - this is likely raw RGB pixel data
            // Create an NSImage from the raw pixel data
            Log.info("PDF: Processing raw image data (\(nsData.length) bytes)", category: .general)

            // Calculate bytes per pixel (usually 3 for RGB or 4 for RGBA)
            let totalPixels = width * height
            let bytesPerPixel = nsData.length / totalPixels
            Log.info("PDF: Calculated \(bytesPerPixel) bytes per pixel for \(width)x\(height) image", category: .general)

            // Handle RGB (3 bytes per pixel) by converting to RGBA
            if bytesPerPixel == 3 {
                // Convert RGB to RGBA by adding alpha channel
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
                Log.info("PDF: 💾 DEBUG - Saved RGBA data to: \(rgbaDebugPath)", category: .debug)

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
                        Log.info("PDF: ✅ Successfully converted RGB to PNG via NSBitmapImageRep (\(pngData.count) bytes)", category: .general)
                        Log.info("PDF: 🔍 Shape ID for image: \(imageShape.id)", category: .debug)

                        // DEBUG: Save PNG data
                        let pngDebugPath = "/Users/toddbruss/Documents/pdf_final_image_\(name).png"
                        try? pngData.write(to: URL(fileURLWithPath: pngDebugPath))
                        Log.info("PDF: 💾 DEBUG - Saved final PNG to: \(pngDebugPath)", category: .debug)
                    } else {
                        // Fallback: store RGBA data directly
                        imageShape.embeddedImageData = rgbaData as Data
                        Log.info("PDF: Stored as RGBA data (fallback)", category: .general)
                    }
                } else {
                    Log.info("PDF: Could not create NSBitmapImageRep", category: .general)
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
                            Log.info("PDF: Successfully converted RGBA to PNG (\(pngData.count) bytes)", category: .general)
                        } else {
                            imageShape.embeddedImageData = nsData as Data
                            Log.info("PDF: Stored as RGBA data", category: .general)
                        }
                    } else {
                        Log.info("PDF: Could not create CGImage from context", category: .general)
                        imageShape.embeddedImageData = nsData as Data
                    }
                } else {
                    Log.info("PDF: Could not create RGBA context", category: .general)
                    imageShape.embeddedImageData = nsData as Data
                }
            } else {
                // Unknown format - try as-is
                Log.info("PDF: Unknown image format with \(bytesPerPixel) bytes per pixel", category: .general)
                if NSImage(data: nsData as Data) != nil {
                    imageShape.embeddedImageData = nsData as Data
                    Log.info("PDF: Raw data is actually a valid image format", category: .general)
                } else {
                    imageShape.embeddedImageData = nsData as Data
                    Log.warning("PDF: WARNING - Storing raw data as-is, may not render", category: .general)
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
            Log.info("PDF: Stored transparent image bounds: \(finalRect)", category: .general)
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
                Log.info("PDF: Image '\(name)' is clipped by path ID: \(clipId)", category: .general)
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
            Log.info("PDF: ✅ Added clipping path AFTER image for correct layer order", category: .general)

            // CRITICAL: Clear clipping state and compound path state after processing image
            // This prevents the next clipping mask from being combined with this one
            isInsideClippingPath = false
            currentClippingPathId = nil
            isInCompoundPath = false
            compoundPathParts.removeAll()
            moveToCount = 0
            hasClipOperatorPending = false
            clipOperatorPath.removeAll()
            Log.info("PDF: 🔄 Cleared clipping and compound path state after image - ready for next clipping mask", category: .general)
        }

        // Clear the transparent image flag now that we've processed it
        if hasUpcomingTransparentImage {
            hasUpcomingTransparentImage = false
            Log.info("PDF: Cleared transparent image flag after processing", category: .general)
        }

        Log.info("PDF: ✅ Created image shape '\(imageShape.name)' at \(finalRect.origin) size: \(finalRect.size)", category: .general)
        Log.info("PDF: 📦 Image has embedded data: \(imageShape.embeddedImageData != nil) (\(imageShape.embeddedImageData?.count ?? 0) bytes)", category: .general)
        Log.info("PDF: 🆔 Final shape ID: \(imageShape.id)", category: .general)
        Log.info("PDF: 🖼️ =================  IMAGE PROCESSING END =================  🖼️", category: .general)
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
        Log.info("PDF: Processing XObject '\(name)' with image support...", category: .general)

        guard let page = currentPage,
              let resourceDict = page.dictionary else {
            Log.info("PDF: No current page or dictionary available", category: .general)
            return
        }

        var resourcesRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourceDict, "Resources", &resourcesRef),
              let resourcesDict = resourcesRef else {
            Log.info("PDF: Page has no Resources dictionary", category: .general)
            return
        }

        var xObjectDictRef: CGPDFDictionaryRef? = nil
        guard CGPDFDictionaryGetDictionary(resourcesDict, "XObject", &xObjectDictRef),
              let xObjectDict = xObjectDictRef else {
            Log.info("PDF: Resources has no XObject dictionary", category: .general)
            return
        }

        var xObjectStreamRef: CGPDFStreamRef? = nil
        guard CGPDFDictionaryGetStream(xObjectDict, name, &xObjectStreamRef),
              let xObjectStream = xObjectStreamRef else {
            Log.info("PDF: XObject '\(name)' is not a valid stream", category: .general)
            return
        }

        guard let xObjectStreamDict = CGPDFStreamGetDictionary(xObjectStream) else {
            Log.info("PDF: XObject '\(name)' has no stream dictionary", category: .general)
            return
        }

        // Get the subtype
        var subtypeNamePtr: UnsafePointer<CChar>? = nil
        guard CGPDFDictionaryGetName(xObjectStreamDict, "Subtype", &subtypeNamePtr),
              let subtypeName = subtypeNamePtr else {
            Log.info("PDF: XObject '\(name)' has no Subtype", category: .general)
            return
        }

        let subtype = String(cString: subtypeName)

        switch subtype {
        case "Form":
            // Handle Form XObject - parse the form content stream directly
            Log.info("PDF: XObject '\(name)' is a Form XObject - parsing content stream...", category: .general)

            // Check if XObject has its own Resources dictionary
            var xObjectResourcesDict: CGPDFDictionaryRef? = nil
            if CGPDFDictionaryGetDictionary(xObjectStreamDict, "Resources", &xObjectResourcesDict) {
                Log.info("PDF: XObject '\(name)' has its own Resources dictionary", category: .general)
            } else {
                Log.info("PDF: XObject '\(name)' will inherit parent Resources", category: .general)
                xObjectResourcesDict = resourcesDict
            }

            // Parse the Form XObject content stream directly
            parseXObjectContentStream(xObjectStream, dictionary: xObjectStreamDict, name: name, resourcesDict: xObjectResourcesDict)

        case "Image":
            // Handle Image XObject
            Log.info("PDF: XObject '\(name)' is an Image XObject - extracting image data...", category: .general)
            processImageXObject(name: name, xObjectStream: xObjectStream, currentTransform: currentTransformMatrix)

        default:
            Log.info("PDF: XObject '\(name)' has unknown subtype: \(subtype)", category: .general)
        }
    }
}

// MARK: - Clipping Path Support
extension PDFCommandParser {

    /// Handle clip operator 'W' or 'W*'
    func handleClipOperator() {
        Log.info("PDF: Clip operator 'W' encountered", category: .general)

        // For both single and compound paths, defer the decision until we see what comes next
        // We need to determine if it's for a gradient or an image

        if isInCompoundPath || !compoundPathParts.isEmpty {
            Log.info("PDF: W operator with compound path - deferring decision until we see gradient or image", category: .general)
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
            Log.info("PDF: W operator - deferring clipping path decision until we see gradient or image", category: .general)
            hasClipOperatorPending = true
            clipOperatorPath = currentPath  // Store the path
            // Don't clear currentPath - it will be used for gradient or converted to clipping for image
            return
        }

        Log.info("PDF: Setting up clipping path for image/content clipping", category: .general)

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

            Log.info("PDF: Created PENDING clipping path with ID: \(clipShape.id) - will add after clipped content", category: .general)
        }
    }

    /// Create clipping path from pending W operator path
    func createClippingPathFromPending() {
        guard hasClipOperatorPending else { return }

        Log.info("PDF: Creating clipping path from pending W operator path", category: .general)
        Log.info("PDF: 🔍 Current compound path parts count: \(compoundPathParts.count)", category: .general)
        Log.info("PDF: 🔍 Current isInCompoundPath: \(isInCompoundPath)", category: .general)

        // CRITICAL: For image clipping, we should ONLY have ONE path (the clip path)
        // Compound paths are ONLY for a single image with multiple subpaths (like a donut)
        // If we have compoundPathParts from a PREVIOUS image, ignore them - they're stale
        var allPathCommands: [[PathCommand]] = []

        // Only use compound path parts if we're actively in a compound path AND have the clip operator path
        // This prevents combining separate images into one compound path
        if isInCompoundPath && !compoundPathParts.isEmpty && !clipOperatorPath.isEmpty {
            Log.info("PDF: Creating compound clipping path from \(compoundPathParts.count) parts FOR SINGLE IMAGE", category: .general)
            allPathCommands = compoundPathParts
            allPathCommands.append(clipOperatorPath)
        } else if !clipOperatorPath.isEmpty {
            // Simple single-path clipping mask
            allPathCommands = [clipOperatorPath]
            Log.info("PDF: Creating SIMPLE clipping path (not compound) for single image", category: .general)
        } else {
            Log.info("PDF: ⚠️ No clip operator path to create clipping mask from", category: .general)
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

        Log.info("PDF: Created PENDING clipping path with ID: \(clipShape.id) - will add after clipped content", category: .general)

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
            Log.info("PDF: Resetting clipping state", category: .general)

            // If we still have a pending clipping path, add it now
            if let pendingClip = pendingClippingPath {
                shapes.append(pendingClip)
                pendingClippingPath = nil
                Log.info("PDF: Added pending clipping path at reset", category: .general)
            }

            isInsideClippingPath = false
            currentClippingPathId = nil
        }
    }

    /// Save current graphics state including clipping mask state
    func saveGraphicsState() {
        let state = GraphicsState(
            clippingPathId: currentClippingPathId,
            isInsideClippingPath: isInsideClippingPath,
            pendingClippingPath: pendingClippingPath,
            fillOpacity: currentFillOpacity,
            strokeOpacity: currentStrokeOpacity,
            transformMatrix: currentTransformMatrix,
            isInCompoundPath: isInCompoundPath,
            compoundPathParts: compoundPathParts,
            moveToCount: moveToCount
        )
        graphicsStateStack.append(state)
        Log.info("PDF: 💾 Saved graphics state (stack depth: \(graphicsStateStack.count))", category: .general)
        Log.info("PDF:    - Clipping path ID: \(currentClippingPathId?.uuidString ?? "none")", category: .general)
        Log.info("PDF:    - Inside clipping path: \(isInsideClippingPath)", category: .general)
        Log.info("PDF:    - Has pending clip: \(pendingClippingPath != nil)", category: .general)
        Log.info("PDF:    - Compound path parts: \(compoundPathParts.count)", category: .general)

        // CRITICAL: Reset compound path state for the new graphics state
        // Each clipping mask should start fresh, not inherit compound path state
        isInCompoundPath = false
        compoundPathParts.removeAll()
        moveToCount = 0
    }

    /// Restore previous graphics state including clipping mask state
    func restoreGraphicsState() {
        guard !graphicsStateStack.isEmpty else {
            Log.info("PDF: ⚠️ Cannot restore graphics state - stack is empty", category: .general)
            resetClippingState()  // Fallback to old behavior
            return
        }

        // If we have a pending clipping path in current state, add it before restoring
        if let pendingClip = pendingClippingPath {
            shapes.append(pendingClip)
            Log.info("PDF: Added pending clipping path before state restore", category: .general)
        }

        let state = graphicsStateStack.removeLast()
        currentClippingPathId = state.clippingPathId
        isInsideClippingPath = state.isInsideClippingPath
        pendingClippingPath = state.pendingClippingPath
        currentFillOpacity = state.fillOpacity
        currentStrokeOpacity = state.strokeOpacity
        currentTransformMatrix = state.transformMatrix
        isInCompoundPath = state.isInCompoundPath
        compoundPathParts = state.compoundPathParts
        moveToCount = state.moveToCount

        Log.info("PDF: 🔄 Restored graphics state (stack depth: \(graphicsStateStack.count))", category: .general)
        Log.info("PDF:    - Clipping path ID: \(currentClippingPathId?.uuidString ?? "none")", category: .general)
        Log.info("PDF:    - Inside clipping path: \(isInsideClippingPath)", category: .general)
        Log.info("PDF:    - Has pending clip: \(pendingClippingPath != nil)", category: .general)
        Log.info("PDF:    - Compound path parts: \(compoundPathParts.count)", category: .general)
    }
}
