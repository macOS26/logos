//
//  ImageNSView.swift
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
        return true  // FIXED: Match GradientNSView coordinate system
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        context.saveGState()
        
        // Apply opacity
        context.setAlpha(CGFloat(opacity))
        
        // FIXED: Match GradientNSView approach - draw image directly in bounds
        // The path we receive is already pre-transformed into the document's coordinate space.
        // SwiftUI will handle scaling/offsetting this NSView. We just draw the image as-is.
        
        // DEBUG LOGGING: Track image placement and movement
        print("🖼️ IMAGE NSVIEW DRAW:")
        print("   📊 Image bounds: \(imageBounds)")
        print("   📍 Image origin: \(imageBounds.origin)")
        print("   📏 Image size: \(imageBounds.size)")
        
        // FIXED: Flip image vertically without changing coordinate system
        // This keeps the bounds correct while fixing the image orientation
        context.translateBy(x: imageBounds.minX, y: imageBounds.maxY)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // Draw the image at origin (0,0) since we've translated the context
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: CGRect(origin: .zero, size: imageBounds.size))
            print("   ✅ Image drawn at: \(imageBounds) with vertical flip")
        } else {
            print("   ❌ Failed to get CGImage")
        }
        
        context.restoreGState()
    }
}
