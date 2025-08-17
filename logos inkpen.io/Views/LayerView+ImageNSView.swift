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
    let transform: CGAffineTransform // Add transform parameter for rotation
    let rotationAngle: CGFloat // Add explicit rotation angle parameter
    
    func makeNSView(context: Context) -> ImageNSViewClass {
        return ImageNSViewClass(image: image, bounds: bounds, opacity: opacity, fillStyle: fillStyle, transform: transform, rotationAngle: rotationAngle)
    }
    
    func updateNSView(_ nsView: ImageNSViewClass, context: Context) {
        nsView.image = image
        nsView.imageBounds = bounds
        nsView.opacity = opacity
        nsView.fillStyle = fillStyle
        nsView.transform = transform
        nsView.rotationAngle = rotationAngle
        nsView.needsDisplay = true
    }
}

class ImageNSViewClass: NSView {
    var image: NSImage
    var imageBounds: CGRect
    var opacity: Double
    var fillStyle: FillStyle? // Add support for fill styling
    var transform: CGAffineTransform // Add transform property
    var rotationAngle: CGFloat // Add rotation angle property
    
    init(image: NSImage, bounds: CGRect, opacity: Double, fillStyle: FillStyle? = nil, transform: CGAffineTransform = .identity, rotationAngle: CGFloat = 0.0) {
        self.image = image
        self.imageBounds = bounds
        self.opacity = opacity
        self.fillStyle = fillStyle
        self.transform = transform
        self.rotationAngle = rotationAngle
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
        
        // FIXED: Use context.rotate for proper image rotation without distortion
        // Calculate the center of the image bounds for rotation
        let imageCenter = CGPoint(x: imageBounds.midX, y: imageBounds.midY)
        
        // Use the stored rotation angle instead of extracting from transform
        // The transform gets reset to identity after rotation, so we need the stored angle
        
        // Apply the transform's translation first (position the image)
        context.translateBy(x: transform.tx, y: transform.ty)
        
        // Move to center, rotate, then move back
        context.translateBy(x: imageCenter.x, y: imageCenter.y)
        context.rotate(by: rotationAngle)
        context.translateBy(x: -imageCenter.x, y: -imageCenter.y)
        
        // FIXED: Restore vertical flip to fix upside-down image
        context.translateBy(x: imageBounds.minX, y: imageBounds.maxY)
        context.scaleBy(x: 1.0, y: -1.0)
        
        // DEBUG LOGGING: Track image placement and rotation
        print("🖼️ IMAGE NSVIEW DRAW WITH ROTATION:")
        print("   📊 Image bounds: \(imageBounds)")
        print("   📍 Image center: \(imageCenter)")
        print("   🔄 Rotation angle: \(rotationAngle * 180 / .pi)°")
        print("   🎨 Fill style: \(fillStyle != nil ? "Present" : "None")")
        print("   🔍 Opacity: \(opacity)")
        
        // Draw the image at the correct position with rotation
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            // Set up context for proper transparency support
            context.setAllowsAntialiasing(true)
            context.setShouldAntialias(true)
            context.interpolationQuality = .high
            
            // Calculate image rect to center it properly
            let imageSize = imageBounds.size
            let imageRect = CGRect(
                x: 0, // Since we translated to imageBounds.minX, minY
                y: 0, // Since we translated to imageBounds.maxY
                width: imageSize.width,
                height: imageSize.height
            )
            
            // Draw the image with proper centering
            context.draw(cgImage, in: imageRect)
            print("   ✅ Image drawn at: \(imageRect) with rotation and proper centering")
        } else {
            print("   ❌ Failed to get CGImage")
        }
        
        // Apply fill tint if specified
        if let fillStyle = fillStyle {
            print("   🎨 Applying fill tint: \(fillStyle.color)")
            
            // Set blend mode for the fill
            context.setBlendMode(fillStyle.blendMode.cgBlendMode)
            
            // Apply fill color with opacity - use cgColor directly
            let fillColor = fillStyle.color.cgColor
            context.setFillColor(fillColor)
            
            // Set alpha for the fill (this will blend with the existing image)
            context.setAlpha(CGFloat(fillStyle.opacity))
            
            // Fill the image bounds with the tint color
            // This will blend with the existing image based on the blend mode
            context.fill(imageBounds)
            
            print("   ✅ Fill tint applied with blend mode: \(fillStyle.blendMode) and opacity: \(fillStyle.opacity)")
        }
        
        context.restoreGState()
    }
}
