//
//  LayerView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LayerView: View {
    @ObservedObject var document: VectorDocument
    let layerIndex: Int
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedShapeIDs: Set<UUID>
    let viewMode: ViewMode
    let isShiftPressed: Bool  // Passed from DrawingCanvas for transform tool constraints
    let dragPreviewDelta: CGPoint  // Passed for 60fps drag preview
    let dragPreviewTrigger: Bool  // Trigger for efficient preview updates
    
    private var layer: VectorLayer {
        document.layers[layerIndex]
    }
    
    // CANVAS LAYER PROTECTION: Check if this is the Canvas layer
    private var isCanvasLayer: Bool {
        return layer.name == "Canvas"
    }
    
    // PASTEBOARD LAYER RECOGNITION: Check if this is the Pasteboard layer
    private var isPasteboardLayer: Bool {
        return layer.name == "Pasteboard"
    }
    
    var body: some View {
        let shapes = document.getShapesForLayer(layerIndex)
        return ZStack {
            ForEach(shapes.indices, id: \.self) { shapeIndex in
                let currentShape = shapes[shapeIndex]
                // Do not render clipping path shapes themselves
                if currentShape.isClippingPath {
                    EmptyView()
                } else if let clipID = currentShape.clippedByShapeID, let maskShape = shapes.first(where: { $0.id == clipID }) {
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
                        dragPreviewTrigger: dragPreviewTrigger,
                        viewMode: viewMode
                    )
                    // REMOVED: All SwiftUI transforms - handle everything in NSView
                    // The NSView will handle zoom, offset, and transforms internally
                    .onAppear {
                        // Debug clipping mask rendering
                        // print("🎭 RENDERING CLIPPED SHAPE: '\(currentShape.name)' clipped by '\(maskShape.name)'")
                        // print("   📊 Clipped shape bounds: \(currentShape.bounds)")
                        // print("   📊 Mask shape bounds: \(maskShape.bounds)")
                        // print("   🔄 Clipped shape transform: \(currentShape.transform)")
                        // print("   🔄 Mask shape transform: \(maskShape.transform)")
                        // print("   🔍 Zoom level: \(zoomLevel)")
                        // print("   📍 Canvas offset: \(canvasOffset)")
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
        
        // RESTORE: Apply shape transform for proper positioning
        // The paths need to include transforms to align with the image
        if !shape.transform.isIdentity {
            let transformedPath = CGMutablePath()
            transformedPath.addPath(path, transform: shape.transform)
            return transformedPath
        }
        
        return path
    }
    
}

