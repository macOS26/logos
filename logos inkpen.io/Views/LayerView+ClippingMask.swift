//
//  LayerView+ClippingMask.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics

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
            dragPreviewTrigger: dragPreviewTrigger
        )
        // CRITICAL FIX: Apply transforms in CORRECT order - zoom and offset first
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        // ULTRA FAST 60FPS: Apply drag preview offset - trigger ensures efficient updates
        .offset(x: isSelected ? dragPreviewDelta.x * zoomLevel : 0, 
                y: isSelected ? dragPreviewDelta.y * zoomLevel : 0)
        .id(dragPreviewTrigger) // Force update when drag preview trigger changes
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
    
    // Helper function to create pre-transformed paths for clipping masks
    private func createPreTransformedPath(for shape: VectorShape) -> CGPath {
        let path = CGMutablePath()
        
        // Add path elements
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                path.move(to: to.cgPoint)
            case .line(let to):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                path.closeSubpath()
            }
        }
        
        // Apply shape transform
        if !shape.transform.isIdentity {
            let transformedPath = CGMutablePath()
            transformedPath.addPath(path, transform: shape.transform)
            return transformedPath
        }
        
        return path
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
    
    func makeNSView(context: Context) -> ClippingMaskNSView {
        return ClippingMaskNSView(clippedShape: clippedShape, maskShape: maskShape, clippedPath: clippedPath, maskPath: maskPath)
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
    
    init(clippedShape: VectorShape, maskShape: VectorShape, clippedPath: CGPath, maskPath: CGPath) {
        self.clippedShape = clippedShape
        self.maskShape = maskShape
        self.clippedPath = clippedPath
        self.maskPath = maskPath
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
        
        // Apply clipping mask using the mask path
        context.addPath(maskPath)
        context.clip()
        
        // Draw the clipped content (image or shape)
        if ImageContentRegistry.containsImage(clippedShape),
           let image = ImageContentRegistry.image(for: clippedShape.id) {
            // FIXED: Use same approach as ImageNSViewClass - no double transforms
            let imageRect = clippedPath.boundingBoxOfPath
            context.setAlpha(CGFloat(clippedShape.opacity))
            
            // FIXED: Apply same image flip logic as ImageNSViewClass
            context.translateBy(x: imageRect.minX, y: imageRect.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: CGRect(origin: .zero, size: imageRect.size))
            }
        } else if clippedShape.linkedImagePath != nil || clippedShape.embeddedImageData != nil,
                  let hydrated = ImageContentRegistry.hydrateImageIfAvailable(for: clippedShape) {
            // FIXED: Use same approach for linked/embedded images
            let imageRect = clippedPath.boundingBoxOfPath
            context.setAlpha(CGFloat(clippedShape.opacity))
            
            // FIXED: Apply same image flip logic
            context.translateBy(x: imageRect.minX, y: imageRect.maxY)
            context.scaleBy(x: 1.0, y: -1.0)
            
            if let cgImage = hydrated.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                context.draw(cgImage, in: CGRect(origin: .zero, size: imageRect.size))
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
    }
}
