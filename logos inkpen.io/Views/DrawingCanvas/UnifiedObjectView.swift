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
//                    let _ = VectorText(
//                        content: textContent,
//                        typography: typography,
//                        position: position,
//                        transform: .identity,
//                        isVisible: shape.isVisible,
//                        isLocked: shape.isLocked,
//                        isEditing: shape.isEditing ?? false,
//                        layerIndex: nil, // Will be handled by unified object
//                        cursorPosition: shape.cursorPosition ?? 0,
//                        areaSize: shape.areaSize
//                    )
                    
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
                        Log.info("🎭 UNIFIED OBJECT: Skipping clipping path shape '\(shape.name)' - should be invisible", category: .general)
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
                        dragPreviewTrigger: dragPreviewTrigger,
                        viewMode: viewMode
                    )
                    .id("\(shape.id)-\(shape.path.isClosed)-\(maskShape.id)-\(maskShape.path.isClosed)-\(shape.clippedByShapeID?.uuidString ?? "none")")  // CRITICAL FIX: Include clipping mask ID
                    .onAppear {
                        Log.info("🎭 UNIFIED OBJECT: Rendering clipped shape '\(shape.name)' clipped by '\(maskShape.name)'", category: .general)
                        Log.info("   🎯 Selection state: clipped=\(isClippedShapeSelected), mask=\(isMaskShapeSelected)", category: .general)
                    }
                } else {
                    // Mask shape not found - render as regular shape
                    renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))
                        .onAppear {
                            Log.info("🎭 UNIFIED OBJECT: Mask shape not found for '\(shape.name)' - rendering as regular shape", category: .general)
                        }
                }
            } else {
                // Regular shape - render normally
                renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))
                    .onAppear {
                        Log.info("🎭 UNIFIED OBJECT: Rendering regular shape '\(shape.name)'", category: .general)
                        Log.info("🎭 UNIFIED OBJECT DEBUG: Shape '\(shape.name)' - isClippingPath: \(shape.isClippingPath), clippedByShapeID: \(shape.clippedByShapeID?.uuidString.prefix(8) ?? "nil")", category: .debug)
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
        .id("\(shape.id)-\(shape.path.isClosed)-\(shape.bounds.hashValue)-\(shape.isClippingPath)-\(shape.clippedByShapeID?.uuidString ?? "none")")  // CRITICAL FIX: Include clipping mask properties to trigger refresh
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

// MARK: - Pasteboard Background View
struct PasteboardBackgroundView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    private var pasteboardBackground: VectorObject? {
        document.getObjectsInStackingOrder().first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.name == "Pasteboard Background"
            }
            return false
        }
    }

    var body: some View {
        ZStack {
            // Render only the Pasteboard Background
            if let pasteboardBackground = pasteboardBackground {
                UnifiedObjectContentView(
                    unifiedObject: pasteboardBackground,
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

// MARK: - Canvas Background View
struct CanvasBackgroundView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    private var canvasBackground: VectorObject? {
        document.getObjectsInStackingOrder().first { obj in
            if case .shape(let shape) = obj.objectType {
                return shape.name == "Canvas Background"
            }
            return false
        }
    }

    var body: some View {
        ZStack {
            // Render only the Canvas Background
            if let canvasBackground = canvasBackground {
                UnifiedObjectContentView(
                    unifiedObject: canvasBackground,
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

// MARK: - Non-Background Objects View
struct NonBackgroundObjectsView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedObjectIDs: Set<UUID>
    let viewMode: ViewMode
    let isShiftPressed: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    private var nonBackgroundObjects: [VectorObject] {
        document.getObjectsInStackingOrder().filter { obj in
            if case .shape(let shape) = obj.objectType {
                // Exclude both Canvas Background and Pasteboard Background
                return shape.name != "Canvas Background" && shape.name != "Pasteboard Background"
            }
            return true
        }
    }

    var body: some View {
        ZStack {
            // Render all objects except Canvas Background
            ForEach(nonBackgroundObjects, id: \.id) { unifiedObject in
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
