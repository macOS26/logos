//
//  UnifiedObjectView.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

struct UnifiedObjectView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let isShiftPressed: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    
    private var objects: [VectorObject] {
        document.getObjectsInStackingOrder()
    }
    
    var body: some View {
        ZStack {
            // Render all objects in proper layer stacking order
            ForEach(objects, id: \.id) { unifiedObject in
                UnifiedObjectContentView(
                    unifiedObject: unifiedObject,
                    document: document,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    selectedObjectIDs: selectedObjectIDs,
                    viewMode: viewMode,
                    dragPreviewDelta: dragPreviewDelta,
                    dragPreviewTrigger: dragPreviewTrigger
                )
            }
        }
    }
}

// MARK: - Unified Object Content View
struct UnifiedObjectContentView: View {
    let unifiedObject: VectorObject
    let document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool
    
    var body: some View {
        switch unifiedObject.objectType {
        case .shape(let shape):
            // CRITICAL FIX: Handle text objects represented as VectorShape
            if shape.isTextObject {
                // Render text using existing StableProfessionalTextCanvas
                // Convert VectorShape back to VectorText for the text canvas
                if let textContent = shape.textContent, let typography = shape.typography {
                    let position = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                    let vectorText = VectorText(
                        content: textContent,
                        typography: typography,
                        position: position,
                        transform: .identity,
                        isVisible: shape.isVisible,
                        isLocked: shape.isLocked,
                        isEditing: shape.isEditing ?? false,
                        layerIndex: nil, // Will be handled by unified object
                        isPointText: shape.isPointText ?? true,
                        cursorPosition: shape.cursorPosition ?? 0,
                        areaSize: shape.areaSize
                    )
                    
                    StableProfessionalTextCanvas(
                        document: document,
                        textObjectID: shape.id, // Use shape ID
                        dragPreviewDelta: dragPreviewDelta,
                        dragPreviewTrigger: dragPreviewTrigger
                    )
                    .id("\(shape.id)-\(position.x)-\(position.y)")  // CRITICAL FIX: Include position in ID to trigger view refresh
                    .allowsHitTesting(true)
                } else {
                    EmptyView()
                }
            }
            // CRITICAL FIX: Handle clipping masks in unified object system
            else if shape.isClippingPath {
                // Do not render clipping path shapes themselves
                EmptyView()
                    .onAppear {
                        print("🎭 UNIFIED OBJECT: Skipping clipping path shape '\(shape.name)' - should be invisible")
                    }
            } else if let clipID = shape.clippedByShapeID {
                // This shape is clipped by another shape - find the mask shape
                if let maskUnifiedObject = document.unifiedObjects.first(where: { 
                    if case .shape(let maskShape) = $0.objectType {
                        return maskShape.id == clipID
                    }
                    return false
                }),
                case .shape(let maskShape) = maskUnifiedObject.objectType {
                    // Create pre-transformed paths for the clipping mask
                    let clippedPath = createPreTransformedPath(for: shape)
                    let maskPath = createPreTransformedPath(for: maskShape)
                    
                    // Determine selection state for both clipped shape and mask
                    let isClippedShapeSelected = selectedObjectIDs.contains(unifiedObject.id)
                    let isMaskShapeSelected = selectedObjectIDs.contains(maskUnifiedObject.id)
                    let isSelected = isClippedShapeSelected || isMaskShapeSelected
                    
                    // Render the clipped shape using NSView-based clipping mask
                    ClippingMaskShapeView(
                        clippedShape: shape,
                        maskShape: maskShape,
                        clippedPath: clippedPath,
                        maskPath: maskPath,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isSelected: isSelected,
                        dragPreviewDelta: isSelected ? dragPreviewDelta : .zero,
                        dragPreviewTrigger: dragPreviewTrigger
                    )
                    .id("\(shape.id)-\(shape.path.isClosed)-\(maskShape.id)-\(maskShape.path.isClosed)")  // CRITICAL FIX: Include both shapes' path state
                    .onAppear {
                        print("🎭 UNIFIED OBJECT: Rendering clipped shape '\(shape.name)' clipped by '\(maskShape.name)'")
                        print("   🎯 Selection state: clipped=\(isClippedShapeSelected), mask=\(isMaskShapeSelected)")
                    }
                } else {
                    // Mask shape not found - render as regular shape
                    renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))
                        .onAppear {
                            print("🎭 UNIFIED OBJECT: Mask shape not found for '\(shape.name)' - rendering as regular shape")
                        }
                }
            } else {
                // Regular shape - render normally
                renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))
                    .onAppear {
                        print("🎭 UNIFIED OBJECT: Rendering regular shape '\(shape.name)'")
                        print("🎭 UNIFIED OBJECT DEBUG: Shape '\(shape.name)' - isClippingPath: \(shape.isClippingPath), clippedByShapeID: \(shape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")")
                    }
            }
            
        }
    }
    
    // Helper function to render regular shapes
    @ViewBuilder
    private func renderRegularShape(shape: VectorShape, isSelected: Bool) -> some View {
        ShapeView(
            shape: shape,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset,
            isSelected: isSelected,
            viewMode: viewMode,
            isCanvasLayer: unifiedObject.layerIndex == 1, // Canvas layer is index 1
            isPasteboardLayer: unifiedObject.layerIndex == 0, // Pasteboard layer is index 0
            dragPreviewDelta: dragPreviewDelta,
            dragPreviewTrigger: dragPreviewTrigger
        )
        .id("\(shape.id)-\(shape.path.isClosed)-\(shape.bounds.hashValue)")  // CRITICAL FIX: Include path state in ID to trigger view refresh when closed
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
        
        // Apply shape transform for proper positioning
        if !shape.transform.isIdentity {
            let transformedPath = CGMutablePath()
            transformedPath.addPath(path, transform: shape.transform)
            return transformedPath
        }
        
        return path
    }
}
