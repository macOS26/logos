//
//  IconGenerator.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/6/25.
//

import Foundation
import AppKit
import CoreGraphics

class DocumentIconGenerator {
    
    static let shared = DocumentIconGenerator()
    
    private init() {}
    
    // Configuration: disabled by default to avoid sandbox/permission issues when writing next to the document
    var enableSVGSidecarPreviews: Bool = false
    
    // MARK: - Document Icon Generation
    
    func generateDocumentIcon(for document: VectorDocument, size: CGSize = CGSize(width: 256, height: 256)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return NSImage(size: size)
        }
        
        // Create a professional document icon
        createDocumentIcon(context: context, size: size, document: document)
        
        image.unlockFocus()
        return image
    }
    
    private func createDocumentIcon(context: CGContext, size: CGSize, document: VectorDocument) {
        let rect = CGRect(origin: .zero, size: size)
        
        // FIXED: Remove white background and padding - use full rect for content
        // Add a preview of the document content using full space
        createDocumentPreview(context: context, rect: rect, document: document)
     
        
        // FIXED: Add ghost "Ink Pen" text using Marker Felt font near the bottom
        let brush = "🖋️" //🖊️ 🖌️
        // Use Marker Felt font which is available on macOS
        let emojiFont = NSFont(name: "Apple Color Emoji", size: 130) ?? NSFont.systemFont(ofSize: 130, weight: .regular)
        let emojiAttributes: [NSAttributedString.Key: Any] = [
            .font: emojiFont
        ]
        
        let emojiSize = brush.size(withAttributes: emojiAttributes)
        let emojiRect = CGRect(
            x: size.width - 132,
            y: -24, // Near the bottom
            width: emojiSize.width,
            height: emojiSize.height
        )
        
        brush.draw(in: emojiRect, withAttributes: emojiAttributes)

    }
    
    private func createDocumentPreview(context: CGContext, rect: CGRect, document: VectorDocument) {
        // Check if document has any art content
        let hasArtContent = documentHasArtContent(document)
        
        if hasArtContent {
            // SIMPLIFIED: Direct image rendering instead of complex SVG generation
            renderDirectImagePreview(context: context, rect: rect, document: document)
        } else {
            // Use fallback preview when no art content
            renderFallbackPreview(context: context, rect: rect)
        }
    }
    
    private func renderDirectImagePreview(context: CGContext, rect: CGRect, document: VectorDocument) {
        print("🔍 IconGenerator: Rendering direct image preview...")
        
        // Find the first image in the document
        var foundImage: NSImage? = nil
        
        for layer in document.layers where layer.isVisible {
            for shape in layer.shapes where shape.isVisible {
                if let image = ImageContentRegistry.image(for: shape.id) {
                    foundImage = image
                    print("   ✅ Found image for shape: \(shape.name)")
                    break
                } else if let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: shape) {
                    foundImage = hydrated
                    print("   ✅ Hydrated image for shape: \(shape.name)")
                    break
                }
            }
            if foundImage != nil { break }
        }
        
        if let image = foundImage {
            // Render the image directly as a low-res thumbnail
            print("   🖼️ Rendering image thumbnail...")
            
            // Save context state
            context.saveGState()
            
            // Set up context for image rendering
            context.interpolationQuality = .medium
            context.setShouldAntialias(true)
            context.setAllowsAntialiasing(true)
            
            // Calculate scale to fit image in preview rect while maintaining aspect ratio
            let imageSize = image.size
            let scaleX = rect.width / imageSize.width
            let scaleY = rect.height / imageSize.height
            let scale = min(scaleX, scaleY) * 0.8 // 80% of available space
            
            // Calculate centered position
            let scaledWidth = imageSize.width * scale
            let scaledHeight = imageSize.height * scale
            let x = rect.midX - scaledWidth / 2
            let y = rect.midY - scaledHeight / 2
            
            // Create a simple thumbnail
            let imageRect = CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
            
            // Draw the image
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: imageRect)
                print("   ✅ Image drawn successfully")
            }
            
            // Only add a subtle border to make the image stand out, not a tint
            context.setStrokeColor(NSColor.systemGray.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(1.0)
            context.stroke(imageRect)
            
            // Restore context state
            context.restoreGState()
            
        } else {
            print("   ❌ No images found, using fallback")
            renderFallbackPreview(context: context, rect: rect)
        }
    }
    
    private func documentHasArtContent(_ document: VectorDocument) -> Bool {
        // Check if document has any visible shapes or text
        let hasVisibleShapes = document.layers.contains { layer in
            layer.isVisible && layer.shapes.contains { shape in
                shape.isVisible
            }
        }
        
        let hasVisibleText = document.allTextObjects.contains { textObj in
            textObj.isVisible
        }
        
        return hasVisibleShapes || hasVisibleText
    }
    
    private func renderSVGArtPreview(context: CGContext, rect: CGRect, document: VectorDocument) {
        // Generate SVG content from the document's art
        let svgContent = generateSVGPreview(for: document)
        
        // Debug: Print SVG content for troubleshooting
        Log.info("🔍 IconGenerator: Generated SVG content length: \(svgContent.count)", category: .general)
        if svgContent.count < 100 {
            Log.info("🔍 IconGenerator: SVG content preview: \(svgContent)", category: .general)
        }
        
        // Convert SVG content to Data
        guard let svgData = svgContent.data(using: .utf8) else {
            Log.error("❌ IconGenerator: Failed to convert SVG content to Data", category: .error)
            renderFallbackPreview(context: context, rect: rect)
            return
        }
        
        Log.info("🔍 IconGenerator: SVG data size: \(svgData.count) bytes", category: .general)
        
        // Create SVG document using the existing SVG class
        // Add error handling for CoreSVG framework availability
        guard let svg = SVG(svgData) else {
            Log.error("❌ IconGenerator: Failed to create SVG object from data", category: .error)
            Log.info("   This might be due to CoreSVG framework not being available", category: .general)
            Log.info("   Falling back to fallback preview", category: .general)
            renderFallbackPreview(context: context, rect: rect)
            return
        }
        
        Log.info("✅ IconGenerator: Successfully created SVG object, size: \(svg.size)", category: .fileOperations)
        
        // Save current context state
        context.saveGState()
        
        // Set up context for SVG rendering
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)
        
        // Calculate scale to fit SVG in preview rect while maintaining aspect ratio
        let svgSize = svg.size
        let scaleX = rect.width / svgSize.width
        let scaleY = rect.height / svgSize.height
        let scale = min(scaleX, scaleY)
        
        // Calculate centered position
        let scaledWidth = svgSize.width * scale
        let scaledHeight = svgSize.height * scale
        let x = rect.midX - scaledWidth / 2
        let y = rect.midY - scaledHeight / 2
        
        Log.info("🔍 IconGenerator: SVG rendering - scale: \(scale), position: (\(x), \(y))", category: .general)
        
        // FIXED: Apply transform to center and scale the SVG without Y-inversion
        // The regular renderToVectorContext inverts Y, so we pre-compensate
        context.translateBy(x: x, y: y + scaledHeight)
        context.scaleBy(x: scale, y: -scale)
        
        // Render the SVG to the context
        svg.renderToVectorContext(context, targetSize: svgSize)
        Log.info("✅ IconGenerator: SVG rendering completed", category: .fileOperations)
        
        // Restore context state
        context.restoreGState()
    }
    
    private func renderFallbackPreview(context: CGContext, rect: CGRect) {
        // Create a fallback preview for empty documents
        let centerX = rect.midX
        let centerY = rect.midY
        
        // Background - light gray to indicate empty state
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.1).cgColor)
        context.fill(rect)
        
        // Draw a document icon to indicate this is an empty document
        let iconSize = min(rect.width, rect.height) * 0.3
        let iconRect = CGRect(
            x: centerX - iconSize / 2,
            y: centerY - iconSize / 2,
            width: iconSize,
            height: iconSize
        )
        
        // Draw a simple document icon
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.3).cgColor)
        context.setStrokeColor(NSColor.systemGray.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(1.0)
        
        // Document shape
        let documentRect = iconRect.insetBy(dx: iconSize * 0.1, dy: iconSize * 0.1)
        context.fill(documentRect)
        context.stroke(documentRect)
        
        // Document fold corner
        let foldSize = iconSize * 0.15
        let foldRect = CGRect(
            x: documentRect.maxX - foldSize,
            y: documentRect.minY,
            width: foldSize,
            height: foldSize
        )
        
        context.setFillColor(NSColor.systemGray.withAlphaComponent(0.2).cgColor)
        context.fill(foldRect)
        
        // Add "Empty" text
        let text = "Empty"
        let font = NSFont.systemFont(ofSize: iconSize * 0.2, weight: .medium)
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.systemGray.withAlphaComponent(0.6)
        ]
        
        let textSize = text.size(withAttributes: textAttributes)
        let textRect = CGRect(
            x: centerX - textSize.width / 2,
            y: centerY + iconSize * 0.4,
            width: textSize.width,
            height: textSize.height
        )
        
        text.draw(in: textRect, withAttributes: textAttributes)
    }
    
    // MARK: - SVG Preview Generation (Simplified)
    
    func generateSVGPreview(for document: VectorDocument) -> String {
        print("🔍 IconGenerator: Generating simplified SVG preview for document...")
        print("   Document has \(document.layers.count) layers")
        print("   Document has \(document.allTextObjects.count) text objects")
        
        // SIMPLIFIED: Generate basic SVG without complex image handling
        // This is just for compatibility, the actual preview uses direct rendering
        return generateSimpleSVGPreview(for: document)
    }
    
    private func generateSimpleSVGPreview(for document: VectorDocument) -> String {
        let documentSize = document.settings.sizeInPoints
        let width = documentSize.width
        let height = documentSize.height
        
        var svgContent = """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)" xmlns="http://www.w3.org/2000/svg">
        <defs>
        """
        
        // Add gradient definitions if any
        svgContent += generateGradientDefinitions(from: document)
        
        svgContent += """
        </defs>
        """
        
        // Background rectangle removed to make SVG preview transparent
        
        // Render all visible layers and shapes (excluding Canvas and Pasteboard layers)
        for layer in document.layers where layer.isVisible {
            // Skip Canvas and Pasteboard layers for SVG preview (they're UI-only layers)
            if layer.name == "Canvas" || layer.name == "Pasteboard" {
                continue
            }
            
            for shape in layer.shapes where shape.isVisible {
                svgContent += generateShapeSVG(shape)
            }
        }
        
        // Render text objects
        for textObj in document.allTextObjects where textObj.isVisible {
            svgContent += generateTextSVG(textObj)
        }
        
        svgContent += "</svg>"
        return svgContent
    }
    
    private func generateGradientDefinitions(from document: VectorDocument) -> String {
        let definitions = ""
        
        // Add any gradient definitions here if needed
        // For now, return empty string
        return definitions
    }
    
    private func generateShapeSVG(_ shape: VectorShape) -> String {
        // SPECIAL-CASE RASTER IMAGES: Export as <image> with data URI
        if ImageContentRegistry.containsImage(shape),
           let nsImage = ImageContentRegistry.image(for: shape.id) {
            return generateImageSVG(shape, image: nsImage)
        }
        
        // Try to hydrate image if not in registry
        if let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: shape) {
            return generateImageSVG(shape, image: hydrated)
        }
        
        var svg = ""
        
        // Generate path data
        let pathData = generatePathData(from: shape.path)
        
        svg += "<path d=\"\(pathData)\""
        
        // Add fill
        if let fillStyle = shape.fillStyle {
            svg += " fill=\"\(fillStyle.color.svgColor)\""
            if fillStyle.opacity != 1.0 {
                svg += " fill-opacity=\"\(fillStyle.opacity)\""
            }
        } else {
            svg += " fill=\"none\""
        }
        
        // Add stroke
        if let strokeStyle = shape.strokeStyle {
            svg += " stroke=\"\(strokeStyle.color.svgColor)\""
            svg += " stroke-width=\"\(strokeStyle.width)\""
            if strokeStyle.opacity != 1.0 {
                svg += " stroke-opacity=\"\(strokeStyle.opacity)\""
            }
        }
        
        svg += "/>"
        return svg
    }
    
    // MARK: - Image SVG Generation
    
    /// Generate an SVG <image> element for a raster-backed shape using a data URI
    private func generateImageSVG(_ shape: VectorShape, image: NSImage) -> String {
        // Apply transform to the rect corners to export baked coordinates like paths
        let transformedPath = applyTransformToPath(shape.path, transform: shape.transform)

        // Compute bounds from transformed path elements
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude
        for element in transformedPath.elements {
            switch element {
            case .move(let to):
                minX = min(minX, CGFloat(to.x)); minY = min(minY, CGFloat(to.y))
                maxX = max(maxX, CGFloat(to.x)); maxY = max(maxY, CGFloat(to.y))
            case .line(let to):
                minX = min(minX, CGFloat(to.x)); minY = min(minY, CGFloat(to.y))
                maxX = max(maxX, CGFloat(to.x)); maxY = max(maxY, CGFloat(to.y))
            case .curve(let to, let c1, let c2):
                minX = min(minX, CGFloat(to.x), CGFloat(c1.x), CGFloat(c2.x))
                minY = min(minY, CGFloat(to.y), CGFloat(c1.y), CGFloat(c2.y))
                maxX = max(maxX, CGFloat(to.x), CGFloat(c1.x), CGFloat(c2.x))
                maxY = max(maxY, CGFloat(to.y), CGFloat(c1.y), CGFloat(c2.y))
            case .quadCurve(let to, let c):
                minX = min(minX, CGFloat(to.x), CGFloat(c.x))
                minY = min(minY, CGFloat(to.y), CGFloat(c.y))
                maxX = max(maxX, CGFloat(to.x), CGFloat(c.x))
                maxY = max(maxY, CGFloat(to.y), CGFloat(c.y))
            case .close:
                break
            }
        }
        if minX == .greatestFiniteMagnitude || minY == .greatestFiniteMagnitude {
            return "" // no geometry
        }
        let x = minX
        let y = minY
        let width = max(0, maxX - minX)
        let height = max(0, maxY - minY)

        // Rasterize NSImage to PNG data (safer for data URIs and widely supported)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            // If encoding fails, fallback to transparent rect path
            return "<rect x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" fill=\"none\"/>"
        }
        
        let base64 = pngData.base64EncodedString()
        let href = "data:image/png;base64,\(base64)"

        // Compose SVG image tag with baked coordinates
        return "<image id=\"image-\(shape.id)\" x=\"\(x)\" y=\"\(y)\" width=\"\(width)\" height=\"\(height)\" xlink:href=\"\(href)\" preserveAspectRatio=\"none\"/>"
    }
    
    /// Apply transform to path elements (helper function for image generation)
    private func applyTransformToPath(_ path: VectorPath, transform: CGAffineTransform) -> VectorPath {
        var transformedElements: [PathElement] = []
        
        for element in path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = to.cgPoint.applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint.x, transformedPoint.y)))
            case .line(let to):
                let transformedPoint = to.cgPoint.applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint.x, transformedPoint.y)))
            case .curve(let to, let control1, let control2):
                let transformedTo = to.cgPoint.applying(transform)
                let transformedControl1 = control1.cgPoint.applying(transform)
                let transformedControl2 = control2.cgPoint.applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo.x, transformedTo.y),
                    control1: VectorPoint(transformedControl1.x, transformedControl1.y),
                    control2: VectorPoint(transformedControl2.x, transformedControl2.y)
                ))
            case .quadCurve(let to, let control):
                let transformedTo = to.cgPoint.applying(transform)
                let transformedControl = control.cgPoint.applying(transform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo.x, transformedTo.y),
                    control: VectorPoint(transformedControl.x, transformedControl.y)
                ))
            case .close:
                transformedElements.append(.close)
            }
        }
        
        return VectorPath(elements: transformedElements, isClosed: path.isClosed)
    }
    
    private func generatePathData(from path: VectorPath) -> String {
        var pathData = ""
        
        for element in path.elements {
            switch element {
            case .move(let to):
                pathData += "M \(to.x) \(to.y) "
            case .line(let to):
                pathData += "L \(to.x) \(to.y) "
            case .curve(let to, let control1, let control2):
                pathData += "C \(control1.x) \(control1.y) \(control2.x) \(control2.y) \(to.x) \(to.y) "
            case .quadCurve(let to, let control):
                pathData += "Q \(control.x) \(control.y) \(to.x) \(to.y) "
            case .close:
                pathData += "Z "
            }
        }
        
        return pathData.trimmingCharacters(in: .whitespaces)
    }
    
    private func generateTextSVG(_ textObj: VectorText) -> String {
        let position = textObj.position
        let content = textObj.content.isEmpty ? "Text" : textObj.content
        
        var svg = "<text x=\"\(position.x)\" y=\"\(position.y)\""
        
        // Add font properties
        let fontSize = textObj.typography.fontSize
        svg += " font-family=\"\(textObj.typography.fontFamily)\""
        svg += " font-size=\"\(fontSize)\""
        
        // Add fill color
        svg += " fill=\"\(textObj.typography.fillColor.svgColor)\""
        
        // Add stroke if present
        if textObj.typography.strokeColor != .clear {
            svg += " stroke=\"\(textObj.typography.strokeColor.svgColor)\""
            svg += " stroke-width=\"\(textObj.typography.strokeWidth)\""
        }
        
        svg += ">\(content)</text>"
        return svg
    }
    
    // MARK: - File Icon Management
    
    func setCustomIcon(for url: URL, document: VectorDocument) {
        let icon = generateDocumentIcon(for: document)
        
        // Set the custom icon for the file
        NSWorkspace.shared.setIcon(icon, forFile: url.path, options: [])

        // Optionally write SVG preview sidecar for Finder/QuickLook workflows when enabled
        // Example: MyDoc.inkpen -> MyDoc.inkpen.svg
        if enableSVGSidecarPreviews {
            let svgPreview = generateInkpenPreview(for: document)
            let previewURL = previewSidecarURL(for: url)
            do {
                try svgPreview.write(to: previewURL, atomically: true, encoding: .utf8)
                Log.info("✅ Wrote SVG preview sidecar: \(previewURL.path)", category: .fileOperations)
            } catch {
                Log.error("❌ Failed to write SVG preview sidecar: \(error.localizedDescription)", category: .error)
            }
        } else {
            Log.info("ℹ️ Skipping SVG preview sidecar write (disabled). File icon was updated.", category: .general)
        }
    }
    
    func clearCustomIcon(for url: URL) {
        // Clear the custom icon and use default
        NSWorkspace.shared.setIcon(nil, forFile: url.path, options: [])
        
        // Optionally remove sidecar SVG preview if present
        let previewURL = previewSidecarURL(for: url)
        if FileManager.default.fileExists(atPath: previewURL.path) {
            do {
                try FileManager.default.removeItem(at: previewURL)
                Log.info("🧹 Removed SVG preview sidecar: \(previewURL.path)", category: .general)
            } catch {
                Log.fileOperation("⚠️ Could not remove SVG preview sidecar: \(error.localizedDescription)", level: .info)
            }
        }
    }
    
    // MARK: - Inkpen Preview Generation
    
    /// Generate SVG preview content for Inkpen files
    /// This can be used for QuickLook, file previews, or other preview systems
    func generateInkpenPreview(for document: VectorDocument) -> String {
        // Check if document has any art content
        let hasArtContent = documentHasArtContent(document)
        
        if hasArtContent {
            // Generate full SVG content from the document's art
            return generateSVGPreview(for: document)
        } else {
            // Generate a simple placeholder SVG for empty documents
            return generateEmptyDocumentSVG(for: document)
        }
    }
    
    private func generateEmptyDocumentSVG(for document: VectorDocument) -> String {
        let documentSize = document.settings.sizeInPoints
        let width = documentSize.width
        let height = documentSize.height
        
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg width="\(width)" height="\(height)" viewBox="0 0 \(width) \(height)" xmlns="http://www.w3.org/2000/svg">
            <defs>
                <style>
                    .empty-text { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 24px; fill: #8E8E93; }
                    .empty-icon { fill: #C7C7CC; stroke: #8E8E93; stroke-width: 1; }
                </style>
            </defs>
            
            <!-- Background rectangle removed to make SVG preview transparent -->
            
            <!-- Empty document icon -->
            <g transform="translate(\(width/2 - 50), \(height/2 - 60))">
                <!-- Document shape -->
                <rect x="0" y="0" width="100" height="120" class="empty-icon" fill="rgba(199,199,204,0.3)"/>
                <!-- Document fold corner -->
                <path d="M 80 0 L 100 20 L 80 20 Z" class="empty-icon" fill="rgba(142,142,147,0.2)"/>
                <!-- Empty text -->
                <text x="50" y="160" text-anchor="middle" class="empty-text">Empty Document</text>
            </g>
        </svg>
        """
    }

    // MARK: - Helpers
    
    private func previewSidecarURL(for url: URL) -> URL {
        // Keep original filename and append .svg (results in e.g., MyDoc.inkpen.svg)
        return url.appendingPathExtension("svg")
    }
}
