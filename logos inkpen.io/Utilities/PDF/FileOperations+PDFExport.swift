//
//  FileOperations+PDFExport.swift
//  logos inkpen.io
//
//  Created by Claude on 1/13/25.
//

import SwiftUI

// MARK: - PDF Export Extensions with Clipping Path and Image Support
extension FileOperations {

    /// Generate PDF data from VectorDocument with proper clipping path and image support
    static func generatePDFDataWithClippingSupport(from document: VectorDocument) throws -> Data {
        Log.fileOperation("📄 Generating PDF data from document with clipping path support", level: .info)

        // Get document dimensions - use sizeInPoints which is already in points
        let documentSize = document.settings.sizeInPoints
        Log.fileOperation("📐 PDF document size: \(documentSize.width) × \(documentSize.height) pts", level: .info)

        // Create PDF context with correct media box size
        let pdfData = NSMutableData()

        // CRITICAL FIX: Set media box in context creation to avoid default 8.5x11
        var mediaBox = CGRect(origin: .zero, size: documentSize)

        // Create PDF context with proper media box
        guard let pdfConsumer = CGDataConsumer(data: pdfData),
              let pdfContext = CGContext(consumer: pdfConsumer, mediaBox: &mediaBox, nil) else {
            throw VectorImportError.parsingError("Failed to create PDF context", line: nil)
        }

        // Begin PDF page with the same media box and metadata
        let pageInfo = [
            kCGPDFContextMediaBox as String: mediaBox,
            kCGPDFContextCreator as String: "Inkpen.io"
        ] as [String : Any]
        pdfContext.beginPDFPage(pageInfo as CFDictionary)

        // Flip Y-axis to match standard coordinate system
        pdfContext.translateBy(x: 0, y: documentSize.height)
        pdfContext.scaleBy(x: 1.0, y: -1.0)

        // Set background color from document settings
        if document.settings.backgroundColor != .clear {
            pdfContext.setFillColor(document.settings.backgroundColor.cgColor)
            pdfContext.fill(mediaBox)
        }

        // Render document content with clipping path support
        try renderDocumentToPDFWithClipping(document: document, context: pdfContext, canvasSize: documentSize)

        // End PDF document
        pdfContext.endPDFPage()
        pdfContext.closePDF()

        Log.fileOperation("✅ PDF data generation completed with clipping support", level: .info)
        return pdfData as Data
    }

    /// Render VectorDocument to PDF context with clipping path support
    static func renderDocumentToPDFWithClipping(document: VectorDocument, context: CGContext, canvasSize: CGSize) throws {
        Log.fileOperation("🎨 Rendering document to PDF context with clipping support", level: .info)

        // Save graphics state
        context.saveGState()

        // Build a map of clipping relationships
        var clippingMasks: [UUID: VectorShape] = [:]
        var clippedShapes: [UUID: [VectorShape]] = [:]

        // First pass: organize shapes by clipping relationships
        for (index, layer) in document.layers.enumerated() {
            // Skip pasteboard (index 0) and canvas (index 1) for PDF export
            guard index >= 2, !layer.isLocked, layer.isVisible else { continue }

            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer where shape.isVisible {
                if shape.isClippingPath {
                    clippingMasks[shape.id] = shape
                    if clippedShapes[shape.id] == nil {
                        clippedShapes[shape.id] = []
                    }
                } else if let clipId = shape.clippedByShapeID {
                    if clippedShapes[clipId] == nil {
                        clippedShapes[clipId] = []
                    }
                    clippedShapes[clipId]?.append(shape)
                }
            }
        }

        // Set to track already rendered shapes
        var renderedShapeIds = Set<UUID>()

        // Render layers (skip pasteboard and canvas background)
        for (index, layer) in document.layers.enumerated() {
            // Skip pasteboard (index 0) and canvas (index 1) for PDF export
            guard index >= 2, !layer.isLocked, layer.isVisible else { continue }

            Log.fileOperation("🎨 Rendering layer: \(layer.name)", level: .info)

            // Render shapes in layer using unified objects
            let shapesInLayer = document.getShapesForLayer(index)
            for shape in shapesInLayer where shape.isVisible {
                // Skip if already rendered as part of a clipping group
                guard !renderedShapeIds.contains(shape.id) else { continue }

                // If this shape is clipped by another shape, skip it here
                // It will be rendered with its clipping mask
                if shape.clippedByShapeID != nil {
                    continue
                }

                // If this is a clipping mask, render it with its clipped shapes
                if shape.isClippingPath, let clipped = clippedShapes[shape.id], !clipped.isEmpty {
                    try renderClippingGroup(
                        clippingMask: shape,
                        clippedShapes: clipped,
                        context: context
                    )
                    renderedShapeIds.insert(shape.id)
                    clipped.forEach { renderedShapeIds.insert($0.id) }
                } else if !shape.isClippingPath {
                    // Regular shape without clipping
                    try renderShapeToPDFWithImageSupport(shape: shape, context: context)
                    renderedShapeIds.insert(shape.id)
                }
            }
        }

        // Restore graphics state
        context.restoreGState()

        Log.fileOperation("✅ Document rendered to PDF context with clipping support", level: .info)
    }

    /// Render a clipping group (mask and clipped shapes)
    static func renderClippingGroup(clippingMask: VectorShape, clippedShapes: [VectorShape], context: CGContext) throws {
        Log.fileOperation("🎭 Rendering clipping group with mask: \(clippingMask.name)", level: .debug)

        // Save graphics state for clipping
        context.saveGState()

        // Apply the clipping mask's transform
        context.concatenate(clippingMask.transform)

        // Set up the clipping path
        let clipPath = convertVectorPathToCGPath(clippingMask.path)
        context.addPath(clipPath)
        context.clip()

        // Reset transform for clipped content
        context.concatenate(clippingMask.transform.inverted())

        // Render all clipped shapes
        for shape in clippedShapes {
            Log.fileOperation("   📎 Rendering clipped shape: \(shape.name)", level: .debug)
            try renderShapeToPDFWithImageSupport(shape: shape, context: context)
        }

        // Restore graphics state to remove clipping
        context.restoreGState()
    }

    /// Render individual shape to PDF context with image support
    static func renderShapeToPDFWithImageSupport(shape: VectorShape, context: CGContext) throws {
        // Check if this is a group
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // Save graphics state for group
            context.saveGState()

            // Apply group transform if any
            context.concatenate(shape.transform)

            // Render each shape in the group recursively
            for groupedShape in shape.groupedShapes {
                try renderShapeToPDFWithImageSupport(shape: groupedShape, context: context)
            }

            // Restore graphics state
            context.restoreGState()
            return
        }

        // Check if this is an image shape
        // First check for embedded data
        if let imageData = shape.embeddedImageData {
            try renderImageToPDF(shape: shape, imageData: imageData, context: context)
            return
        }

        // Try to hydrate linked images if available
        if let image = ImageContentRegistry.hydrateImageIfAvailable(for: shape) {
            // Convert to data for rendering
            if let tiffRep = image.tiffRepresentation {
                try renderImageToPDF(shape: shape, imageData: tiffRep, context: context)
                return
            }
        }

        // Regular vector shape rendering
        let cgPath = convertVectorPathToCGPath(shape.path)

        // Save graphics state for this shape
        context.saveGState()

        // Apply shape transform
        context.concatenate(shape.transform)

        // Handle fill
        if let fillStyle = shape.fillStyle {
            // Check if fill is a gradient
            if case .gradient(let gradient) = fillStyle.color {
                // For gradients, we need to clip first then draw
                context.addPath(cgPath)
                context.saveGState()
                context.clip()

                // Draw the gradient
                drawPDFGradient(gradient, in: context, bounds: cgPath.boundingBox, opacity: fillStyle.opacity)

                context.restoreGState()
            } else {
                // Regular color fill
                context.addPath(cgPath)
                setFillStyle(fillStyle, context: context)
                context.fillPath()
            }
        }

        // Handle stroke - NEVER export stroke if color is .clear (checkerboard/none)
        if let strokeStyle = shape.strokeStyle {
            // DO NOT EXPORT STROKE IF COLOR IS CLEAR!
            if case .clear = strokeStyle.color {
                // Skip stroke completely - this is the "none" stroke (checkerboard)
                Log.fileOperation("PDF EXPORT: SKIPPING stroke for \(shape.name) - stroke is NONE/CLEAR", level: .debug)
            } else if strokeStyle.width > 0 && strokeStyle.opacity > 0 {
                // Only export stroke if it has a real color, width, and opacity
                Log.fileOperation("PDF EXPORT: Drawing stroke for \(shape.name)", level: .debug)
                context.addPath(cgPath)
                setStrokeStyle(strokeStyle, context: context)
                context.strokePath()
            }
        }

        // Restore graphics state
        context.restoreGState()
    }

    /// Render image to PDF context
    static func renderImageToPDF(shape: VectorShape, imageData: Data, context: CGContext) throws {
        Log.fileOperation("🖼️ Rendering image shape: \(shape.name)", level: .debug)

        // Create NSImage from data
        guard let nsImage = NSImage(data: imageData) else {
            Log.error("Failed to create NSImage from embedded data", category: .error)
            return
        }

        // Get CGImage from NSImage
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            Log.error("Failed to get CGImage from NSImage", category: .error)
            return
        }

        // Save graphics state
        context.saveGState()

        // Apply shape transform
        context.concatenate(shape.transform)

        // Apply shape opacity if needed
        if shape.opacity < 1.0 {
            context.setAlpha(CGFloat(shape.opacity))
        }

        // Draw the image within the shape bounds
        let bounds = shape.bounds

        // Translate to the image position
        context.saveGState()
        context.translateBy(x: bounds.minX, y: bounds.minY)

        // Flip the image vertically since we already flipped the context
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)

        // Draw the image at origin with correct size
        context.draw(cgImage, in: CGRect(origin: .zero, size: bounds.size))

        context.restoreGState()

        // Restore graphics state
        context.restoreGState()

        Log.fileOperation("   ✅ Image rendered at: \(bounds.origin) size: \(bounds.size)", level: .debug)
    }
}
