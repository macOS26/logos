//
//  FileOperations+ExportToPNG.swift
//  logos inkpen.io
//
//  Raster (PNG/JPEG) export functionality extracted from FileOperations.swift
//

import SwiftUI

extension FileOperations {
    
    // MARK: - PNG Export
    
    static func exportToPNG(_ document: VectorDocument, url: URL, scale: CGFloat, includeBackground: Bool = true) throws {
        Log.fileOperation("🖼️ Exporting document to PNG: \(url.path) at \(scale)x scale", level: .info)

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

        // Draw each layer
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

            // Apply layer opacity
            context.saveGState()
            context.setAlpha(layer.opacity)

            // Draw shapes in layer
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

        // Use ColorExportManager for proper P3 export with ICC profile embedding
        _ = try ColorExportManager.shared.exportFromContext(
            context,
            format: .png,
            colorSpace: .displayP3,
            to: url
        )

        Log.info("✅ Successfully exported PNG document", category: .fileOperations)
    }
    
    
    // MARK: - Helper Functions for Drawing
    
    internal static func drawShapeInPDF(_ shape: VectorShape, context: CGContext) {
        context.saveGState()

        // Apply shape's overall opacity
        context.setAlpha(shape.opacity)

        // Apply transform
        if !shape.transform.isIdentity {
            context.concatenate(shape.transform)
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
