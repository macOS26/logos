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
    
    func makeNSView(context: Context) -> ImageNSViewClass {
        return ImageNSViewClass(image: image, bounds: bounds, opacity: opacity)
    }
    
    func updateNSView(_ nsView: ImageNSViewClass, context: Context) {
        nsView.image = image
        nsView.imageBounds = bounds
        nsView.opacity = opacity
        nsView.needsDisplay = true
    }
}

class ImageNSViewClass: NSView {
    var image: NSImage
    var imageBounds: CGRect
    var opacity: Double
    
    init(image: NSImage, bounds: CGRect, opacity: Double) {
        self.image = image
        self.imageBounds = bounds
        self.opacity = opacity
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool {
        return true  // Match coordinate system with other views
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        // Apply opacity
        context.setAlpha(CGFloat(opacity))
        
        // FIXED: Restore coordinate flipping for proper image orientation
        // The coordinate flipping is necessary because of the app's coordinate system
        // SwiftUI will handle all transformations (rotation, skewing, warping) via .transformEffect()
        
        // Draw the image with proper coordinate flipping
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            // FIXED: Apply coordinate flipping to match the app's coordinate system
            // This keeps the image oriented correctly while allowing transforms to work
            context.translateBy(x: imageBounds.minX, y: imageBounds.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            
            // Draw the image at origin (0,0) since we've translated the context
            context.draw(cgImage, in: CGRect(origin: .zero, size: imageBounds.size))
        }
        
        context.restoreGState()
    }
}
