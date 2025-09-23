//
//  LayerView+ClippingMask.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct ClippingMaskShapeView: View {
    let clippedShape: VectorShape
    let maskShape: VectorShape
    let clippedPath: CGPath
    let maskPath: CGPath
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode
    
    var body: some View {
        // Render the clipped shape using NSView-based clipping mask
        ClippingMaskNSViewRepresentable(
            clippedShape: clippedShape,
            maskShape: maskShape,
            clippedPath: clippedPath,
            maskPath: maskPath,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset,
            isSelected: isSelected,
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger,
            viewMode: viewMode
        )
        // REMOVED: All SwiftUI transforms - handle everything in NSView
        // The NSView will handle zoom, offset, and transforms internally
        .onAppear {
            // Debug clipping mask rendering
            print("🎭 RENDERING CLIPPED SHAPE: '\(clippedShape.name)' clipped by '\(maskShape.name)'")
            print("   📊 Clipped shape bounds: \(clippedShape.bounds)")
            print("   📊 Mask shape bounds: \(maskShape.bounds)")
            print("   🔄 Clipped shape transform: \(clippedShape.transform)")
            print("   🔄 Mask shape transform: \(maskShape.transform)")
            print("   🔍 Zoom level: \(zoomLevel)")
            print("   📍 Canvas offset: \(canvasOffset)")
        }
    }
}

// MARK: - NSView-Based Clipping Mask Shape View
struct ClippingMaskNSViewRepresentable: NSViewRepresentable {
    let clippedShape: VectorShape
    let maskShape: VectorShape
    let clippedPath: CGPath
    let maskPath: CGPath
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    let viewMode: ViewMode
    
    func makeNSView(context: Context) -> ClippingMaskNSView {
        return ClippingMaskNSView(clippedShape: clippedShape, maskShape: maskShape, clippedPath: clippedPath, maskPath: maskPath, viewMode: viewMode)
    }
    
    func updateNSView(_ nsView: ClippingMaskNSView, context: Context) {
        nsView.clippedShape = clippedShape
        nsView.maskShape = maskShape
        nsView.clippedPath = clippedPath
        nsView.maskPath = maskPath
        nsView.zoomLevel = zoomLevel
        nsView.canvasOffset = canvasOffset
        nsView.isSelected = isSelected
        nsView.dragPreviewDelta = dragPreviewDelta
        nsView.dragPreviewTrigger = dragPreviewTrigger
        nsView.viewMode = viewMode
        nsView.needsDisplay = true
    }
}

class ClippingMaskNSView: NSView {
    var clippedShape: VectorShape
    var maskShape: VectorShape
    var clippedPath: CGPath
    var maskPath: CGPath
    var zoomLevel: Double = 1.0
    var canvasOffset: CGPoint = .zero
    var isSelected: Bool = false
    var dragPreviewDelta: CGPoint = .zero
    var dragPreviewTrigger: Bool = false
    var viewMode: ViewMode = .color
    
    init(clippedShape: VectorShape, maskShape: VectorShape, clippedPath: CGPath, maskPath: CGPath, viewMode: ViewMode = .color) {
        self.clippedShape = clippedShape
        self.maskShape = maskShape
        self.clippedPath = clippedPath
        self.maskPath = maskPath
        self.viewMode = viewMode
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
        
        // CRITICAL FIX: Handle ALL transforms in NSView like working image code
        // Apply zoom and offset first, then shape transforms
        context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
        context.scaleBy(x: zoomLevel, y: zoomLevel)
        
        // Apply drag preview offset if selected
        if isSelected {
            context.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
        }
        
        // CRITICAL FIX: Apply clipping mask using the mask path
        // The mask path should already be in the correct coordinate system
        context.addPath(maskPath)
        context.clip()
        
        // Draw the clipped content (image or shape)
        print("CLIPPING MASK: 🔍 Checking for image with ID: \(clippedShape.id)")
        print("CLIPPING MASK: Shape name: '\(clippedShape.name)'")
        print("CLIPPING MASK: Has embedded data: \(clippedShape.embeddedImageData != nil)")

        if ImageContentRegistry.containsImage(clippedShape) {
            print("CLIPPING MASK: ✅ Found image in registry for shape '\(clippedShape.name)'")
        } else {
            print("CLIPPING MASK: ❌ No image in registry for shape '\(clippedShape.name)'")
        }

        if ImageContentRegistry.containsImage(clippedShape),
           let image = ImageContentRegistry.image(for: clippedShape.id) {
            // FIXED: Use actual shape bounds and transform like regular ShapeView
            let pathBounds = clippedShape.path.cgPath.boundingBoxOfPath
            let transformedBounds = pathBounds.applying(clippedShape.transform)
            // Apply 20% opacity in keyline mode to ghost the image
            let effectiveOpacity = viewMode == .keyline ? min(clippedShape.opacity * 0.2, 0.2) : clippedShape.opacity
            context.setAlpha(CGFloat(effectiveOpacity))
            
            // Draw image at its actual transformed position with proper flip
            context.translateBy(x: transformedBounds.minX, y: transformedBounds.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: CGRect(origin: .zero, size: transformedBounds.size))
            }
        } else if clippedShape.linkedImagePath != nil || clippedShape.embeddedImageData != nil,
                  let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: clippedShape) {
            // FIXED: Same approach for linked/embedded images
            let pathBounds = clippedShape.path.cgPath.boundingBoxOfPath
            let transformedBounds = pathBounds.applying(clippedShape.transform)
            // Apply 20% opacity in keyline mode to ghost the image
            let effectiveOpacity = viewMode == .keyline ? min(clippedShape.opacity * 0.2, 0.2) : clippedShape.opacity
            context.setAlpha(CGFloat(effectiveOpacity))
            
            // Draw image at its actual transformed position with proper flip
            context.translateBy(x: transformedBounds.minX, y: transformedBounds.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            
            if let cgImage = hydrated.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: CGRect(origin: .zero, size: transformedBounds.size))
            }
        } else {
            // Draw shape with fill and stroke
            context.addPath(clippedPath)
            
            // Apply fill
            if let fillStyle = clippedShape.fillStyle, fillStyle.color != .clear {
                context.setFillColor(fillStyle.color.cgColor)
                context.fillPath()
            }
            
            // Apply stroke
            if let strokeStyle = clippedShape.strokeStyle, strokeStyle.color != .clear {
                context.setStrokeColor(strokeStyle.color.cgColor)
                context.setLineWidth(strokeStyle.width)
                context.strokePath()
            }
        }
        
        context.restoreGState()
        
        // In keyline mode, draw the clipping path outline
        if viewMode == .keyline {
            context.saveGState()
            
            // Apply transforms again for the outline
            context.translateBy(x: canvasOffset.x, y: canvasOffset.y)
            context.scaleBy(x: zoomLevel, y: zoomLevel)
            
            if isSelected {
                context.translateBy(x: dragPreviewDelta.x, y: dragPreviewDelta.y)
            }
            
            // Draw the mask path outline
            context.addPath(maskPath)
            context.setStrokeColor(NSColor.systemOrange.cgColor) // Orange color for clip path in keyline
            context.setLineWidth(1.0 / zoomLevel) // Consistent line width
            context.setLineDash(phase: 0, lengths: [4.0 / zoomLevel, 2.0 / zoomLevel]) // Dashed line
            context.strokePath()
            
            context.restoreGState()
        }
    }
}
