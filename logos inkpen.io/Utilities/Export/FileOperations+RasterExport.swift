//
//  FileOperations+RasterExport.swift
//  logos inkpen.io
//
//  Raster (PNG/JPEG) export functionality extracted from FileOperations.swift
//

import Foundation
import AppKit
import UniformTypeIdentifiers

extension FileOperations {
    
    // MARK: - PNG Export
    
    static func exportToPNG(_ document: VectorDocument, url: URL, scale: CGFloat) throws {
        Log.fileOperation("🖼️ Exporting document to PNG: \(url.path) at \(scale)x scale", level: .info)
        
        // Calculate output size
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        
        // CRITICAL FIX: Add size validation to prevent Core Image crashes
        guard outputSize.width > 0 && outputSize.height > 0 && 
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
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
        
        // Set coordinate system to match our canvas (flip Y axis)
        context.translateBy(x: 0, y: outputSize.height)
        context.scaleBy(x: scale, y: -scale)
        
        // Draw background
        context.setFillColor(document.settings.backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))
        
        // Draw each layer
        for layer in document.layers {
            if !layer.isVisible { continue }
            
            // Apply layer opacity
            context.saveGState()
            context.setAlpha(layer.opacity)
            
            // Draw shapes in layer
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
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
        
        // CRITICAL FIX: Add timeout and error handling for Core Image operations
        let image: CGImage
        do {
            // Create image from context with timeout protection
            guard let createdImage = context.makeImage() else {
                throw VectorImportError.parsingError("Failed to create image from context", line: nil)
            }
            image = createdImage
        } catch {
            throw VectorImportError.parsingError("Core Image operation failed: \(error.localizedDescription)", line: nil)
        }
        
        // Save PNG with error handling
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        guard let dest = destination else {
            throw VectorImportError.parsingError("Failed to create PNG destination", line: nil)
        }
        
        CGImageDestinationAddImage(dest, image, nil)
        
        if !CGImageDestinationFinalize(dest) {
            throw VectorImportError.parsingError("Failed to finalize PNG export", line: nil)
        }
        
        Log.info("✅ Successfully exported PNG document", category: .fileOperations)
    }
    
    // MARK: - JPEG Export
    
    static func exportToJPEG(_ document: VectorDocument, url: URL, scale: CGFloat, quality: Double) throws {
        Log.info("📷 Exporting document to JPEG: \(url.path) at \(scale)x scale, \(Int(quality * 100))% quality", category: .general)
        
        // Calculate output size
        let pageSize = document.settings.sizeInPoints
        let outputSize = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        
        // CRITICAL FIX: Add size validation to prevent Core Image crashes
        guard outputSize.width > 0 && outputSize.height > 0 && 
              outputSize.width <= 16384 && outputSize.height <= 16384 else {
            throw VectorImportError.parsingError("Invalid output size: \(outputSize)", line: nil)
        }
        
        // Create bitmap context
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.noneSkipLast.rawValue // JPEG doesn't support alpha
        
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
        
        // Set coordinate system to match our canvas (flip Y axis)
        context.translateBy(x: 0, y: outputSize.height)
        context.scaleBy(x: scale, y: -scale)
        
        // Draw background (important for JPEG since it doesn't support transparency)
        context.setFillColor(document.settings.backgroundColor.cgColor)
        context.fill(CGRect(origin: .zero, size: pageSize))
        
        // Draw each layer
        for layer in document.layers {
            if !layer.isVisible { continue }
            
            // Apply layer opacity
            context.saveGState()
            context.setAlpha(layer.opacity)
            
            // Draw shapes in layer
            let layerIndex = document.layers.firstIndex(where: { $0.id == layer.id }) ?? 0
            let shapesInLayer = document.getShapesForLayer(layerIndex)
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
        
        // CRITICAL FIX: Add timeout and error handling for Core Image operations
        let image: CGImage
        do {
            // Create image from context with timeout protection
            guard let createdImage = context.makeImage() else {
                throw VectorImportError.parsingError("Failed to create image from context", line: nil)
            }
            image = createdImage
        } catch {
            throw VectorImportError.parsingError("Core Image operation failed: \(error.localizedDescription)", line: nil)
        }
        
        // Save JPEG with quality setting and error handling
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        guard let dest = destination else {
            throw VectorImportError.parsingError("Failed to create JPEG destination", line: nil)
        }
        
        // Set JPEG compression quality
        let options = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        
        if !CGImageDestinationFinalize(dest) {
            throw VectorImportError.parsingError("Failed to finalize JPEG export", line: nil)
        }
        
        Log.info("✅ Successfully exported JPEG document", category: .fileOperations)
    }
    
    // MARK: - Helper Functions for Drawing
    
    internal static func drawShapeInPDF(_ shape: VectorShape, context: CGContext) {
        context.saveGState()
        
        // Apply shape opacity
        context.setAlpha(shape.opacity)
        
        // Apply transform
        if !shape.transform.isIdentity {
            context.concatenate(shape.transform)
        }
        
        // Create path from shape
        let path = shape.path.cgPath
        context.addPath(path)
        
        // Apply fill
        if let fillStyle = shape.fillStyle {
            context.setFillColor(fillStyle.color.cgColor)
            context.setAlpha(fillStyle.opacity)
            
            if shape.strokeStyle != nil {
                context.drawPath(using: .fillStroke)
            } else {
                context.fillPath()
            }
        } else if let strokeStyle = shape.strokeStyle {
            // Only stroke, no fill
            context.setStrokeColor(strokeStyle.color.cgColor)
            context.setLineWidth(strokeStyle.width)
            context.setAlpha(strokeStyle.opacity)
            context.setLineCap(strokeStyle.lineCap)
            context.setLineJoin(strokeStyle.lineJoin)
            
            if !strokeStyle.dashPattern.isEmpty {
                let dashPatternCGFloat = strokeStyle.dashPattern.map { CGFloat($0) }
                context.setLineDash(phase: 0, lengths: dashPatternCGFloat)
            }
            
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