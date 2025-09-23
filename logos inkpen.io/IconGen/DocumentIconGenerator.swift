//
//  DocumentIconGenerator.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/28/25.
//

import SwiftUI

/// Generates document icons from saved SVG files for macOS file display
class DocumentIconGenerator {
    static let shared = DocumentIconGenerator()
    
    private init() {}
    
    /// Generate an icon from a document's SVG data
    func generateIcon(from document: VectorDocument, size: NSSize = NSSize(width: 512, height: 512)) -> NSImage? {
        do {
            // Export document to SVG string
            let svgString = try SVGExporter.shared.exportToSVG(document)
            // Convert string to data
            guard let svgData = svgString.data(using: .utf8) else {
                Log.error("❌ Failed to convert SVG string to data", category: .error)
                return createFallbackIcon(size: size)
            }
            return generateIcon(from: svgData, size: size)
        } catch {
            Log.error("❌ Failed to export document to SVG for icon: \(error)", category: .error)
            return createFallbackIcon(size: size)
        }
    }
    
    /// Generate an icon from SVG data (used for both saved files and new documents)
    func generateIcon(from svgData: Data, size: NSSize = NSSize(width: 512, height: 512)) -> NSImage? {
        // macOS document icons should be 512x512 for best quality
        let iconDim = 512
        
        // Icon is always 512x512
        let iconSize = CGSize(width: iconDim, height: iconDim)
        
        // Create bitmap representation explicitly at 512x512
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: iconDim,
            pixelsHigh: iconDim,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else {
            Log.error("❌ Failed to create bitmap representation for icon", category: .error)
            return createFallbackIcon(size: size)
        }
        
        // Create context for drawing
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        
        guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else {
            Log.error("❌ Failed to create graphics context for icon", category: .error)
            return createFallbackIcon(size: size)
        }
        
        NSGraphicsContext.current = context
        
        // Fill with white background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: iconSize).fill()
        
        // Try to draw SVG using WebKit's SVG rendering
        if let svgImage = NSImage(data: svgData) {
            // SVG loaded as NSImage - draw it centered and scaled
            let drawRect = NSRect(origin: .zero, size: iconSize)
            svgImage.draw(in: drawRect, from: NSRect(origin: .zero, size: svgImage.size), operation: .sourceOver, fraction: 1.0)
        } else {
            // Fallback: Try to parse as XML and extract basic shapes
            Log.info("⚠️ Could not load SVG as NSImage, using fallback", category: .fileOperations)
            // For now, just use the fallback icon
            return createFallbackIcon(size: size)
        }
        
        // Create NSImage from bitmap
        let icon = NSImage(size: iconSize)
        icon.addRepresentation(bitmapRep)
        
        Log.info("✅ Generated 512x512 icon from SVG", category: .fileOperations)
        return icon
    }
    
    /// Set a custom icon for a saved document file
    func setCustomIcon(for url: URL, document: VectorDocument) {
        guard let icon = generateIcon(from: document) else {
            Log.error("❌ Failed to generate icon for document", category: .error)
            return
        }
        
        // Set the custom icon for the file
        NSWorkspace.shared.setIcon(icon, forFile: url.path, options: [])
        Log.info("✅ Set custom icon for file: \(url.lastPathComponent)", category: .fileOperations)
    }
    
    /// Create a fallback icon when SVG rendering fails
    private func createFallbackIcon(size: NSSize) -> NSImage {
        let icon = NSImage(size: size)
        
        icon.lockFocus()
        defer { icon.unlockFocus() }
        
        // White background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        
        // Draw a simple document icon shape
        let margin: CGFloat = size.width * 0.1
        let docRect = NSRect(
            x: margin,
            y: margin,
            width: size.width - (margin * 2),
            height: size.height - (margin * 2)
        )
        
        // Document outline
        NSColor.systemGray.setStroke()
        let path = NSBezierPath(roundedRect: docRect, xRadius: 8, yRadius: 8)
        path.lineWidth = 2
        path.stroke()
        
        // "inkpen" text in center
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: size.width * 0.1),
            .foregroundColor: NSColor.systemGray
        ]
        
        let text = "inkpen"
        let textSize = text.size(withAttributes: attributes)
        let textPoint = NSPoint(
            x: (size.width - textSize.width) / 2,
            y: (size.height - textSize.height) / 2
        )
        
        text.draw(at: textPoint, withAttributes: attributes)
        
        Log.info("📄 Created fallback icon", category: .fileOperations)
        return icon
    }
}
