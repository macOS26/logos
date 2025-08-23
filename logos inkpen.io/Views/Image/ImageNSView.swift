//
//  LayerView+ImageNSView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics

// MARK: - NSView-Based Image View

struct ImageNSView: NSViewRepresentable {
    let image: NSImage
    let bounds: CGRect
    let opacity: Double
    let fillStyle: FillStyle? // Add support for fill styling
    
    func makeNSView(context: Context) -> ImageNSViewClass {
        return ImageNSViewClass(image: image, bounds: bounds, opacity: opacity, fillStyle: fillStyle)
    }
    
    func updateNSView(_ nsView: ImageNSViewClass, context: Context) {
        nsView.image = image
        nsView.imageBounds = bounds
        nsView.opacity = opacity
        nsView.fillStyle = fillStyle
        nsView.needsDisplay = true
    }
}

class ImageNSViewClass: NSView {
    var image: NSImage
    var imageBounds: CGRect
    var opacity: Double
    var fillStyle: FillStyle? // Add support for fill styling
    
    init(image: NSImage, bounds: CGRect, opacity: Double, fillStyle: FillStyle? = nil) {
        self.image = image
        self.imageBounds = bounds
        self.opacity = opacity
        self.fillStyle = fillStyle
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool {
        return true  // FIXED: Match GradientNSView coordinate system
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        // Apply opacity
        context.setAlpha(CGFloat(opacity))
        
        // FIXED: Flip image vertically without changing coordinate system
        // This keeps the bounds correct while fixing the image orientation
        context.translateBy(x: imageBounds.minX, y: imageBounds.maxY)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the image at origin (0,0) since we've translated the context
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            // Set up context for proper transparency support
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.interpolationQuality = .high
            
            // Draw the image with transparency support
            context.draw(cgImage, in: CGRect(origin: .zero, size: imageBounds.size))
        }
        
        // Apply fill colorization if specified (simplified approach)
        if let fillStyle = fillStyle, fillStyle.color != .clear {
            // Use a simple blend mode approach instead of complex pixel manipulation
            context.setBlendMode(.lighten)
            context.setFillColor(fillStyle.color.cgColor)
            context.setAlpha(CGFloat(fillStyle.opacity))
            
            // Fill the image bounds with the color
            context.fill(CGRect(origin: .zero, size: imageBounds.size))
        }
        
        context.restoreGState()
    }
}
