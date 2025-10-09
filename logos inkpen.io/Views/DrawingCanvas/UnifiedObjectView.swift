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

    // State variables to track all layer opacities and blend modes for live updates
    @State private var layerOpacities: [Double] = []
    @State private var layerBlendModes: [BlendMode] = []

    private var objects: [VectorObject] {
        document.getObjectsInStackingOrder()
    }

    var body: some View {
        ZStack {
            // Group objects by layer and apply opacity/blend mode to each layer's ZStack
            ForEach(Array(Set(objects.map { $0.layerIndex })).sorted(), id: \.self) { layerIndex in
                ZStack {
                    ForEach(objects.filter { $0.layerIndex == layerIndex }, id: \.id) { unifiedObject in
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
                .compositingGroup()
                .opacity(layerIndex < document.layers.count ? document.layers[layerIndex].opacity : 1.0)
                .blendMode(layerIndex < document.layers.count ? document.layers[layerIndex].blendMode.swiftUIBlendMode : .normal)
            }
       
        }
        .onAppear {
            layerOpacities = document.layers.map { $0.opacity }
            layerBlendModes = document.layers.map { $0.blendMode }
        }
        .onChange(of: document.layers.map { $0.opacity }) {
            layerOpacities = document.layers.map { $0.opacity }
        }
        .onChange(of: document.layers.map { $0.blendMode }) {
            layerBlendModes = document.layers.map { $0.blendMode }
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

    // CRITICAL: Check if the layer this object is on is visible
    private var layerIsVisible: Bool {
        guard unifiedObject.layerIndex >= 0 && unifiedObject.layerIndex < document.layers.count else {
            return true
        }
        return document.layers[unifiedObject.layerIndex].isVisible
    }

    var body: some View {
        Group {
            switch unifiedObject.objectType {
            case .shape(let shape):
                // CRITICAL FIX: Handle text objects represented as VectorShape
                if shape.isTextObject {
                    // Render text using existing StableProfessionalTextCanvas
                    // Convert VectorShape back to VectorText for the text canvas
                    if shape.textContent != nil, shape.typography != nil {

                        StableProfessionalTextCanvas(
                            document: document,
                            textObjectID: shape.id, // Use shape ID
                            dragPreviewDelta: dragPreviewDelta,
                            dragPreviewTrigger: dragPreviewTrigger
                        )
                        .allowsHitTesting(true)
                    } else {
                        EmptyView()
                    }
                }
                // CRITICAL FIX: Handle clipping masks in unified object system
                else if shape.isClippingPath {
                    // Do not render clipping path shapes themselves
                    EmptyView()
                } else if let clipID = shape.clippedByShapeID {
                    // This shape is clipped by another shape - find the mask shape
                    // PERFORMANCE: Use O(1) UUID lookup instead of O(N) loop
                    if let maskUnifiedObject = document.findObject(by: clipID),
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
                    } else {
                        // Mask shape not found - render as regular shape
                        renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))
                    }
                } else {
                    // Regular shape - render normally
                    // CRITICAL FIX: For groups, also render text objects inside
                    ZStack {
                        renderRegularShape(shape: shape, isSelected: selectedObjectIDs.contains(unifiedObject.id))

                        // CRITICAL FIX: Render text objects inside groups
                        if shape.isGroupContainer {
                            ForEach(shape.groupedShapes.filter { $0.isTextObject }, id: \.id) { textShape in
                                if textShape.textContent != nil, textShape.typography != nil {
                                    StableProfessionalTextCanvas(
                                        document: document,
                                        textObjectID: textShape.id,
                                        dragPreviewDelta: dragPreviewDelta,
                                        dragPreviewTrigger: dragPreviewTrigger
                                    )
                                    .allowsHitTesting(true)
                                }
                            }
                        }
                    }
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

    @State private var layerOpacities: [Double] = []
    @State private var layerBlendModes: [BlendMode] = []

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
        .compositingGroup()
        .opacity(pasteboardBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].opacity : 1.0 } ?? 1.0)
        .blendMode(pasteboardBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].blendMode.swiftUIBlendMode : .normal } ?? .normal)
        .onAppear {
            layerOpacities = document.layers.map { $0.opacity }
            layerBlendModes = document.layers.map { $0.blendMode }
        }
        .onChange(of: document.layers.map { $0.opacity }) {
            layerOpacities = document.layers.map { $0.opacity }
        }
        .onChange(of: document.layers.map { $0.blendMode }) {
            layerBlendModes = document.layers.map { $0.blendMode }
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

    @State private var layerOpacities: [Double] = []
    @State private var layerBlendModes: [BlendMode] = []

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
        .compositingGroup()
        .opacity(canvasBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].opacity : 1.0 } ?? 1.0)
        .blendMode(canvasBackground.map { $0.layerIndex < document.layers.count ? document.layers[$0.layerIndex].blendMode.swiftUIBlendMode : .normal } ?? .normal)
        .onAppear {
            layerOpacities = document.layers.map { $0.opacity }
            layerBlendModes = document.layers.map { $0.blendMode }
        }
        .onChange(of: document.layers.map { $0.opacity }) {
            layerOpacities = document.layers.map { $0.opacity }
        }
        .onChange(of: document.layers.map { $0.blendMode }) {
            layerBlendModes = document.layers.map { $0.blendMode }
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

    @State private var layerOpacities: [Double] = []
    @State private var layerBlendModes: [BlendMode] = []

    var body: some View {
        ZStack {
            // Group objects by layer and apply opacity/blend mode to each layer's ZStack
            ForEach(Array(Set(nonBackgroundObjects.map { $0.layerIndex })).sorted(), id: \.self) { layerIndex in
                ZStack {
                    ForEach(nonBackgroundObjects.filter { $0.layerIndex == layerIndex }, id: \.id) { unifiedObject in
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
                .compositingGroup()
                .opacity(layerIndex < document.layers.count ? document.layers[layerIndex].opacity : 1.0)
                .blendMode(layerIndex < document.layers.count ? document.layers[layerIndex].blendMode.swiftUIBlendMode : .normal)

            }
        }
        .onAppear {
            layerOpacities = document.layers.map { $0.opacity }
            layerBlendModes = document.layers.map { $0.blendMode }
        }
        .onChange(of: document.layers.map { $0.opacity }) {
            layerOpacities = document.layers.map { $0.opacity }
        }
        .onChange(of: document.layers.map { $0.blendMode }) {
            layerBlendModes = document.layers.map { $0.blendMode }
        }
    }
}

// MARK: - CG Opacity Modifier
struct CGOpacityModifier: ViewModifier {
    let opacity: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { _ in
                Color.clear.preference(key: OpacityPreferenceKey.self, value: opacity)
            }
        )
        .transformEffect(.identity)
        .opacity(Double(opacity))
    }
}

struct OpacityPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 1.0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
