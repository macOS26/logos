//
//  FileOperations+ExportToPNG.swift
//  logos inkpen.io
//
//  Raster (PNG/JPEG) export functionality extracted from FileOperations.swift
//

import SwiftUI

extension FileOperations {

    // MARK: - Single Icon Export

    static func exportSingleIcon(_ document: VectorDocument, url: URL, pixelSize: Int) throws {

        // Get artwork bounds for proper scaling
        let artworkBounds = calculateArtworkBounds(from: document)
        let artworkSize = artworkBounds.size

        // Calculate scale to fit artwork into icon size (maintaining aspect ratio)
        let scaleX = CGFloat(pixelSize) / artworkSize.width
        let scaleY = CGFloat(pixelSize) / artworkSize.height
        let scale = min(scaleX, scaleY)  // Use smaller scale to ensure it fits

        // Create exact pixel-sized context
        guard let context = CGContext(
            data: nil,
            width: pixelSize,
            height: pixelSize,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: ColorManager.shared.workingCGColorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw VectorImportError.parsingError("Failed to create bitmap context for \(pixelSize)×\(pixelSize)", line: nil)
        }

        // Clear to transparent
        context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))

        // Calculate centering offsets
        let scaledWidth = artworkSize.width * scale
        let scaledHeight = artworkSize.height * scale
        let offsetX = (CGFloat(pixelSize) - scaledWidth) / 2.0
        let offsetY = (CGFloat(pixelSize) - scaledHeight) / 2.0

        // Set coordinate system and apply centering
        context.translateBy(x: offsetX, y: CGFloat(pixelSize) - offsetY)
        context.scaleBy(x: scale, y: -scale)

        // Translate to compensate for artwork bounds origin
        context.translateBy(x: -artworkBounds.minX, y: -artworkBounds.minY)

        // Draw layers (skip pasteboard and canvas for icons)
        for (index, layer) in document.layers.enumerated() {
            if !layer.isVisible { continue }
            if index <= 1 { continue }  // Skip Pasteboard (0) and Canvas (1)

            context.saveGState()

            // Apply layer blend mode if not normal
            if layer.blendMode != .normal {
                context.setBlendMode(layer.blendMode.cgBlendMode)
            }

            // Apply layer opacity
            context.setAlpha(layer.opacity)

            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                drawShapeInPDF(shape, context: context)
            }

            context.restoreGState()
        }

        // Draw text objects
        document.forEachTextInOrder { text in
            if !text.isVisible { return }
            drawTextInPDF(text, context: context)
        }

        // Export the icon
        try ColorExportManager.shared.exportFromContext(
            context,
            format: .png,
            colorSpace: .displayP3,
            to: url
        )

    }

    // MARK: - Icon Set Export

    static func exportIconSet(_ document: VectorDocument, folderURL: URL) throws {

        // Icon sizes to export (in pixels)
        let iconSizes: [Int] = [1024, 512, 256, 128, 64, 32, 16]

        // Get artwork bounds for proper scaling
        let artworkBounds = calculateArtworkBounds(from: document)
        let artworkSize = artworkBounds.size

        for pixelSize in iconSizes {
            let filename = "icon_\(pixelSize)x\(pixelSize).png"
            let fileURL = folderURL.appendingPathComponent(filename)

            // Calculate scale to fit artwork into icon size (maintaining aspect ratio)
            let scaleX = CGFloat(pixelSize) / artworkSize.width
            let scaleY = CGFloat(pixelSize) / artworkSize.height
            let scale = min(scaleX, scaleY)  // Use smaller scale to ensure it fits

            // Create exact pixel-sized context
            guard let context = CGContext(
                data: nil,
                width: pixelSize,
                height: pixelSize,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: ColorManager.shared.workingCGColorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            ) else {
                throw VectorImportError.parsingError("Failed to create bitmap context for \(pixelSize)x\(pixelSize)", line: nil)
            }

            // Clear to transparent
            context.clear(CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize))

            // Calculate centering offsets
            let scaledWidth = artworkSize.width * scale
            let scaledHeight = artworkSize.height * scale
            let offsetX = (CGFloat(pixelSize) - scaledWidth) / 2.0
            let offsetY = (CGFloat(pixelSize) - scaledHeight) / 2.0

            // Set coordinate system and apply centering
            context.translateBy(x: offsetX, y: CGFloat(pixelSize) - offsetY)
            context.scaleBy(x: scale, y: -scale)

            // Translate to compensate for artwork bounds origin
            context.translateBy(x: -artworkBounds.minX, y: -artworkBounds.minY)

            // Draw layers (skip pasteboard and canvas for icons)
            for (index, layer) in document.layers.enumerated() {
                if !layer.isVisible { continue }
                if index <= 1 { continue }  // Skip Pasteboard (0) and Canvas (1)

                context.saveGState()

                // Apply layer blend mode if not normal
                if layer.blendMode != .normal {
                    context.setBlendMode(layer.blendMode.cgBlendMode)
                }

                // Apply layer opacity
                context.setAlpha(layer.opacity)

                let shapesInLayer = document.getShapesForLayer(index)
                for shape in shapesInLayer {
                    if !shape.isVisible { continue }
                    drawShapeInPDF(shape, context: context)
                }

                context.restoreGState()
            }

            // Draw text objects
            document.forEachTextInOrder { text in
                if !text.isVisible { return }
                drawTextInPDF(text, context: context)
            }

            // Export the icon
            try ColorExportManager.shared.exportFromContext(
                context,
                format: .png,
                colorSpace: .displayP3,
                to: fileURL
            )

        }

    }

    // Helper function to calculate artwork bounds (excluding background)
    private static func calculateArtworkBounds(from document: VectorDocument) -> CGRect {
        var bounds = CGRect.null

        // Calculate bounds from all visible shapes (excluding pasteboard and canvas)
        for (index, layer) in document.layers.enumerated() {
            if !layer.isVisible || index <= 1 { continue }  // Skip Pasteboard and Canvas

            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }
                let shapeBounds = shape.bounds
                bounds = bounds.isNull ? shapeBounds : bounds.union(shapeBounds)
            }
        }

        // Include text objects
        document.forEachTextInOrder { text in
            if text.isVisible {
                let textBounds = text.bounds
                bounds = bounds.isNull ? textBounds : bounds.union(textBounds)
            }
        }

        // If no bounds found, use document size
        if bounds.isNull {
            bounds = CGRect(origin: .zero, size: document.settings.sizeInPoints)
        }

        return bounds
    }

    // MARK: - PNG Export

    static func exportToPNGFromView(_ document: VectorDocument, url: URL, scale: CGFloat, includeBackground: Bool = true) throws {
        // Calculate output size
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)

        // CRITICAL FIX: Add size validation to prevent Core Image crashes
        guard outputSize.width > 0 && outputSize.height > 0 &&
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }

        // Create the SwiftUI view that matches screen rendering
        let contentView = UnifiedObjectView(
            document: document,
            zoomLevel: 1.0,
            canvasOffset: .zero,
            selectedObjectIDs: [],
            viewMode: .color,
            isShiftPressed: false,
            dragPreviewDelta: .zero,
            dragPreviewTrigger: false
        )
        .frame(width: pageSize.width, height: pageSize.height)
        .background(includeBackground ? Color.white : Color.clear)

        // Create NSHostingView to render SwiftUI
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = CGRect(origin: .zero, size: pageSize)

        // Force layout and display
        hostingView.layoutSubtreeIfNeeded()
        hostingView.display()

        // Create high-resolution bitmap
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(outputSize.width),
            pixelsHigh: Int(outputSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            throw VectorImportError.parsingError("Failed to create bitmap representation", line: nil)
        }

        // Render into bitmap at the specified scale
        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            throw VectorImportError.parsingError("Failed to create graphics context", line: nil)
        }
        NSGraphicsContext.current = context

        // Scale the context for high-DPI rendering
        context.cgContext.scaleBy(x: scale, y: scale)

        // Capture the hosting view's display
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        NSGraphicsContext.restoreGraphicsState()

        // Export as PNG
        guard let pngData = bitmapRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            throw VectorImportError.parsingError("Failed to create PNG data", line: nil)
        }

        try pngData.write(to: url)
    }

    static func exportToPNG(_ document: VectorDocument, url: URL, scale: CGFloat, includeBackground: Bool = true) throws {

        // Calculate output size
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)

        // CRITICAL FIX: Add size validation to prevent Core Image crashes
        guard outputSize.width > 0 && outputSize.height > 0 &&
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }

        // Create bitmap context with P3 color space for proper color preservation
        let colorSpace = ColorManager.shared.workingCGColorSpace
        // Use premultipliedFirst for better transparency support
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            throw VectorImportError.parsingError("Failed to create bitmap context", line: nil)
        }

        // Clear the context first to ensure it starts transparent
        context.clear(CGRect(x: 0, y: 0, width: outputSize.width, height: outputSize.height))

        // Set coordinate system to match our canvas (flip Y axis)
        context.translateBy(x: 0, y: outputSize.height)
        context.scaleBy(x: scale, y: -scale)

        // If not including background, the context remains transparent (no fill needed)

        // Draw each layer with proper compositing
        for (index, layer) in document.layers.enumerated() {
            if !layer.isVisible { continue }

            // Always skip pasteboard (layer 0), skip canvas (layer 1) only if not including background
            if index == 0 {
                // Always skip layer 0 (Pasteboard)
                continue
            }
            if !includeBackground && index == 1 {
                // Skip layer 1 (Canvas) only when background is disabled
                continue
            }

            // CRITICAL: Use transparency layers for proper blend mode and opacity compositing
            context.saveGState()

            // Begin transparency layer for proper compositing
            context.beginTransparencyLayer(auxiliaryInfo: nil)

            // Apply layer blend mode if not normal
            if layer.blendMode != .normal {
                context.setBlendMode(layer.blendMode.cgBlendMode)
            }

            // Apply layer opacity
            if layer.opacity < 1.0 {
                context.setAlpha(layer.opacity)
            }

            // Draw shapes in layer
            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer {
                if !shape.isVisible { continue }

                drawShapeInPDF(shape, context: context)
            }

            // End transparency layer
            context.endTransparencyLayer()

            context.restoreGState()
        }

        // Draw text objects
        document.forEachTextInOrder { text in
            if !text.isVisible { return }

            drawTextInPDF(text, context: context)
        }

        // Use ColorExportManager for proper P3 export with ICC profile embedding
        try ColorExportManager.shared.exportFromContext(
            context,
            format: .png,
            colorSpace: .displayP3,
            to: url
        )

    }
    
    
    
    internal static func drawShapeInPDF(_ shape: VectorShape, context: CGContext) {
        context.saveGState()

        // Apply shape's overall opacity
        context.setAlpha(shape.opacity)

        // Apply transform
        if !shape.transform.isIdentity {
            context.concatenate(shape.transform)
        }

        // Check if this is a group
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // Render each shape in the group recursively
            for groupedShape in shape.groupedShapes {
                drawShapeInPDF(groupedShape, context: context)
            }
            context.restoreGState()
            return
        }

        // Check if this is an image shape
        if let imageData = shape.embeddedImageData {
            // Handle embedded image data
            if let nsImage = NSImage(data: imageData),
               let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let bounds = shape.bounds

                // Flip the image vertically since we already flipped the context
                context.saveGState()
                context.translateBy(x: bounds.minX, y: bounds.maxY)
                context.scaleBy(x: 1.0, y: -1.0)

                // Draw the image at origin with bounds size
                context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))

                context.restoreGState()
            }
            context.restoreGState()
            return
        } else if let image = ImageContentRegistry.image(for: shape.id) {
            // Handle linked images via ImageContentRegistry
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                let bounds = shape.bounds

                // Flip the image vertically since we already flipped the context
                context.saveGState()
                context.translateBy(x: bounds.minX, y: bounds.maxY)
                context.scaleBy(x: 1.0, y: -1.0)

                // Draw the image at origin with bounds size
                context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))

                context.restoreGState()
            }
            context.restoreGState()
            return
        }

        // Create path from shape
        let path = shape.path.cgPath

        // Check if we have a valid stroke (not clear/none)
        var hasValidStroke = false
        if let strokeStyle = shape.strokeStyle {
            // DO NOT EXPORT STROKE IF COLOR IS CLEAR!
            if case .clear = strokeStyle.color {
                // Skip stroke completely - this is the "none" stroke (checkerboard)
                hasValidStroke = false
            } else if strokeStyle.width > 0 && strokeStyle.opacity > 0 {
                // Only export stroke if it has a real color, width, and opacity
                hasValidStroke = true
            }
        }

        // Check if we have a valid fill (not clear/none)
        var hasValidFill = false
        if let fillStyle = shape.fillStyle {
            // DO NOT EXPORT FILL IF COLOR IS CLEAR!
            if case .clear = fillStyle.color {
                // Skip fill completely - this is the "none" fill (checkerboard)
                hasValidFill = false
            } else if fillStyle.opacity > 0 {
                // Only export fill if it has a real color and opacity
                hasValidFill = true
            }
        }

        // Apply fill and stroke
        if hasValidFill, let fillStyle = shape.fillStyle {
            context.addPath(path)
            if hasValidStroke, let strokeStyle = shape.strokeStyle {
                // Both valid fill and valid stroke - set both colors
                FileOperations.setFillStyle(fillStyle, context: context)
                FileOperations.setStrokeStyle(strokeStyle, context: context)
                context.drawPath(using: .fillStroke)
            } else {
                // Only valid fill
                FileOperations.setFillStyle(fillStyle, context: context)
                context.fillPath()
            }
        } else if hasValidStroke, let strokeStyle = shape.strokeStyle {
            // Only valid stroke, no fill
            context.addPath(path)
            FileOperations.setStrokeStyle(strokeStyle, context: context)
            context.strokePath()
        }

        context.restoreGState()
    }
    
    internal static func drawTextInPDF(_ text: VectorText, context: CGContext) {
        context.saveGState()
        
        // Apply text opacity
        context.setAlpha(text.isVisible ? 1.0 : 0.0)
        
        // Apply transform
        if !text.transform.isIdentity {
            context.concatenate(text.transform)
        }
        
        // Create attributed string
        let font = text.typography.nsFont
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(cgColor: text.typography.fillColor.cgColor) ?? NSColor.black,
            .kern: text.typography.letterSpacing
        ]
        
        let attributedString = NSAttributedString(string: text.content, attributes: attributes)
        
        // Calculate text position (PDF coordinates)
        let textPosition = CGPoint(x: text.position.x, y: text.position.y)
        
        // Draw text
        let line = CTLineCreateWithAttributedString(attributedString)
        context.textPosition = textPosition
        CTLineDraw(line, context)
        
        context.restoreGState()
    }
}
