//
//  LayerView+LayerView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

struct LayerView: View {
    let layer: VectorLayer
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedShapeIDs: Set<UUID>
    let viewMode: ViewMode
    let isShiftPressed: Bool  // Passed from DrawingCanvas for transform tool constraints
    let dragPreviewDelta: CGPoint  // Passed for 60fps drag preview
    let dragPreviewTrigger: Bool  // Trigger for efficient preview updates
    
    // CANVAS LAYER PROTECTION: Check if this is the Canvas layer
    private var isCanvasLayer: Bool {
        return layer.name == "Canvas"
    }
    
    // PASTEBOARD LAYER RECOGNITION: Check if this is the Pasteboard layer
    private var isPasteboardLayer: Bool {
        return layer.name == "Pasteboard"
    }
    
    var body: some View {
        ZStack {
            ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                let currentShape = layer.shapes[shapeIndex]
                // Do not render clipping path shapes themselves
                if currentShape.isClippingPath {
                    EmptyView()
                } else if let clipID = currentShape.clippedByShapeID, let maskShape = layer.shapes.first(where: { $0.id == clipID }) {
                    // FIXED CLIPPING MASK: Use NSView approach like gradient fills
                    // Create pre-transformed paths for the clipping mask
                    let clippedPath = createPreTransformedPath(for: currentShape)
                    let maskPath = createPreTransformedPath(for: maskShape)
                    
                    // Render the clipped shape using NSView-based clipping mask
                    ClippingMaskShapeView(
                        clippedShape: currentShape,
                        maskShape: maskShape,
                        clippedPath: clippedPath,
                        maskPath: maskPath,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isSelected: selectedShapeIDs.contains(currentShape.id) || selectedShapeIDs.contains(maskShape.id),
                        dragPreviewDelta: (selectedShapeIDs.contains(currentShape.id) || selectedShapeIDs.contains(maskShape.id)) ? dragPreviewDelta : .zero,
                        dragPreviewTrigger: dragPreviewTrigger
                    )
                    // CRITICAL FIX: Apply transforms in CORRECT order - zoom and offset first
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    // ULTRA FAST 60FPS: Apply drag preview offset - trigger ensures efficient updates
                    .offset(x: (selectedShapeIDs.contains(currentShape.id) || selectedShapeIDs.contains(maskShape.id)) ? dragPreviewDelta.x * zoomLevel : 0, 
                            y: (selectedShapeIDs.contains(currentShape.id) || selectedShapeIDs.contains(maskShape.id)) ? dragPreviewDelta.y * zoomLevel : 0)
                    .id(dragPreviewTrigger) // Force update when drag preview trigger changes
                    .onAppear {
                        // Debug clipping mask rendering
                        print("🎭 RENDERING CLIPPED SHAPE: '\(currentShape.name)' clipped by '\(maskShape.name)'")
                        print("   📊 Clipped shape bounds: \(currentShape.bounds)")
                        print("   📊 Mask shape bounds: \(maskShape.bounds)")
                        print("   🔄 Clipped shape transform: \(currentShape.transform)")
                        print("   🔄 Mask shape transform: \(maskShape.transform)")
                        print("   🔍 Zoom level: \(zoomLevel)")
                        print("   📍 Canvas offset: \(canvasOffset)")
                    }
                } else {
                    ShapeView(
                        shape: currentShape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isSelected: selectedShapeIDs.contains(currentShape.id),
                        viewMode: viewMode,
                        isCanvasLayer: isCanvasLayer,  // Pass Canvas layer info
                        isPasteboardLayer: isPasteboardLayer,  // Pass Pasteboard layer info
                        dragPreviewDelta: dragPreviewDelta,
                        dragPreviewTrigger: dragPreviewTrigger
                    )
                }
            }
        }
        .opacity(layer.opacity)
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
