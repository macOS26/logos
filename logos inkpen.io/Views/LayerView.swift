//
//  LayerView.swift
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
                    // REMOVED: All SwiftUI transforms - handle everything in NSView
                    // The NSView will handle zoom, offset, and transforms internally
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

// MARK: - Clipping Mask Views moved to LayerView+ClippingMask.swift

// MARK: - Image Views moved to LayerView+ImageNSView.swift

// MARK: - ShapeView moved to LayerView+ShapeView.swift

// MARK: - Mask Views moved to LayerView+ShapeMask.swift

// MARK: - GridView moved to LayerView+GridView.swift

// MARK: - Gradient Rendering Helper Functions

/// Helper functions to convert VectorGradient to SwiftUI gradient objects
extension ShapeView {
    
    /// Creates appropriate fill rendering based on VectorColor type
    @ViewBuilder
    private func renderFill(fillStyle: FillStyle, path: Path, shape: VectorShape) -> some View {
        switch fillStyle.color {
        case .gradient(let vectorGradient):
            // Use the new NSViewRepresentable view for correct gradient rendering
            GradientFillView(gradient: vectorGradient, path: path.cgPath)
                .opacity(fillStyle.opacity)
                .blendMode(fillStyle.blendMode.swiftUIBlendMode)
            
        default:
            path.fill(fillStyle.color.color, style: SwiftUI.FillStyle(eoFill: shape.path.fillRule == .evenOdd))
                .opacity(fillStyle.opacity)
                .blendMode(fillStyle.blendMode.swiftUIBlendMode)
        }
    }
    
    /// Creates appropriate stroke rendering based on VectorColor type
    @ViewBuilder
    private func renderStrokeColor(strokeStyle: StrokeStyle, path: Path, swiftUIStyle: SwiftUI.StrokeStyle, shape: VectorShape) -> some View {
        switch strokeStyle.color {
        case .gradient(let vectorGradient):
            // Use NSView-based gradient stroke rendering
            GradientStrokeView(gradient: vectorGradient, path: path.cgPath, strokeStyle: strokeStyle)
            
        default:
            path.stroke(strokeStyle.color.color, style: swiftUIStyle)
        }
    }

}

// MARK: - SelectionHandlesView moved to LayerView+SelectionHandlesView.swift

// MARK: - SelectionOutline moved to LayerView+SelectionOutline.swift

// MARK: - PathOutline moved to LayerView+PathOutline.swift

// MARK: - TransformBoxHandles moved to LayerView+TransformBoxHandles.swift

// MARK: - Scale Tool Handles
struct ScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool  // Passed from DrawingCanvas for shift constraints
    
    // Professional scaling state management - FIXED IMPLEMENTATION
    @State private var isScaling = false
    @State private var scalingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var scalingAnchorPoint: CGPoint = .zero  // This is the LOCKED/PIN point (RED)
    @State private var finalMarqueeBounds: CGRect = .zero
    @State private var isCapsLockPressed = false  // NEW: Track caps-lock for locking pin point
    
    // CORRECTED POINT SYSTEM: Lock point vs scale points
    @State private var lockedPinPointIndex: Int? = nil // Which point is LOCKED (RED) - set by single click
    @State private var pathPoints: [VectorPoint] = []  // All path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Center point
    @State private var pointsRefreshTrigger: Int = 0
    
    private let handleSize: CGFloat = 10

    var body: some View {
        // SCALE TOOL: Show all path points + center point with correct colors
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        ZStack {
            // ACTUAL OBJECT OUTLINE: Show the real shape paths
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                // GROUP/FLATTENED SHAPE: Show outline of each individual shape
                ForEach(shape.groupedShapes.indices, id: \.self) { index in
                    let groupedShape = shape.groupedShapes[index]
                    // PERFORMANCE OPTIMIZATION: Use cached path creation
                    let cachedPath = Path { path in
                        for element in groupedShape.path.elements {
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
                    }
                    cachedPath
                        .stroke(Color.red, lineWidth: 2.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(groupedShape.transform)
                }
            } else {
                // REGULAR SHAPE: Show single path outline with cached path
                // PERFORMANCE OPTIMIZATION: Use cached path creation
                let cachedPath = Path { path in
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
                }
                cachedPath
                    .stroke(Color.red, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
            
            // SHOW ALL PATH POINTS + CENTER POINT with correct colors
            pathPointsView()
            
            // GROUP BOUNDS FEATURES: For groups/flattened objects, also show bounds points
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                // GREEN BOUNDS MARQUEE: Show the overall bounding box
                Rectangle()
                    .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [3.0 / zoomLevel, 3.0 / zoomLevel]))
                    .frame(width: bounds.width, height: bounds.height)
                    .position(center)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
                
                // BOUNDS CORNER POINTS: Show the 4 corner points of the bounding box
                ForEach(0..<4) { i in
                    let cornerPos = cornerPosition(for: i, in: bounds, center: center)
                    let cornerIndex = pathPoints.count + i // Offset to avoid conflicts with path points
                    let isLockedPin = lockedPinPointIndex == cornerIndex
                    
                    Circle()
                        .fill(isLockedPin ? Color.red : Color.green)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize)
                        .offset(
                            x: cornerPos.x * zoomLevel + canvasOffset.x - (handleSize) / 2,
                            y: cornerPos.y * zoomLevel + canvasOffset.y - (handleSize) / 2
                        )
                        .onTapGesture {
                            if !isScaling {
                                // SINGLE CLICK: Set this as the locked pin point (RED)
                                setLockedPinPoint(cornerIndex)
                            }
                        }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 3)
                                .onChanged { value in
                                    // DRAG: Scale away from the locked pin point
                                    handleScalingFromPoint(draggedPointIndex: cornerIndex, dragValue: value, bounds: bounds, center: center)
                                }
                                .onEnded { _ in
                                    finishScaling()
                                }
                        )
                }
            }
            
            // CENTER POINT: Always available (GREEN if not locked, RED if locked)
            let isCenterLockedPin = (lockedPinPointIndex == nil) // nil represents center as locked pin
            Rectangle()
                .fill(isCenterLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = scalable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize) // Fixed UI size - does not scale with artwork
                .position(CGPoint(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: center.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isScaling {
                        // SINGLE CLICK: Set center as the locked pin point (RED)
                        setLockedPinPoint(nil) // nil = center
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Scale away from the locked pin point
                            handleScalingFromPoint(draggedPointIndex: nil, dragValue: value, bounds: bounds, center: center)
                        }
                        .onEnded { _ in
                            finishScaling()
                        }
                )

            // MARQUEE PREVIEW: Show ACTUAL SCALED SHAPE OUTLINE (EXACTLY like the final object will be)
            if isScaling && !previewTransform.isIdentity {
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    // GROUP/FLATTENED SHAPE: Show marquee preview for each individual shape
                    ForEach(shape.groupedShapes.indices, id: \.self) { index in
                        let groupedShape = shape.groupedShapes[index]
                        Path { path in
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.move(to: transformedPoint)
                                case .line(let to):
                                    let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    path.addLine(to: transformedPoint)
                                case .curve(let to, let control1, let control2):
                                    let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                                    let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                                    path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                                case .quadCurve(let to, let control):
                                    let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                    let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                                    path.addQuadCurve(to: transformedTo, control: transformedControl)
                                case .close:
                                    path.closeSubpath()
                                }
                            }
                        }
                        .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        // NO .transformEffect! Coordinates already transformed above (same as actual object)
                        .opacity(0.8)
                    }
                } else {
                    // REGULAR SHAPE: Show single marquee preview
                    Path { path in
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.move(to: transformedPoint)
                            case .line(let to):
                                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                path.addLine(to: transformedPoint)
                            case .curve(let to, let control1, let control2):
                                let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                                path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                            case .quadCurve(let to, let control):
                                let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                                let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                                path.addQuadCurve(to: transformedTo, control: transformedControl)
                            case .close:
                                path.closeSubpath()
                            }
                        }
                    }
                    .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    // NO .transformEffect! Coordinates already transformed above (same as actual object)
                    .opacity(0.8)
                }
                
                // GREEN BOUNDS MARQUEE PREVIEW: Show live scaling bounds for groups/flattened objects
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    // Calculate transformed bounds for the green marquee preview
                    let transformedBounds = bounds.applying(previewTransform)
                    let transformedCenter = CGPoint(x: transformedBounds.midX, y: transformedBounds.midY)
                    
                    Rectangle()
                        .stroke(Color.green, style: SwiftUI.StrokeStyle(lineWidth: 1.5 / zoomLevel, dash: [3.0 / zoomLevel, 3.0 / zoomLevel]))
                        .frame(width: transformedBounds.width, height: transformedBounds.height)
                        .position(transformedCenter)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        // NO .transformEffect! Bounds already transformed above
                        .opacity(0.6)
                }
                
                // Marquee shows scaling preview without additional handles (handled by point system below)
            }
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            extractPathPoints()
            
            // Set default locked pin point to center if none is set
            if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
                setLockedPinPoint(nil) // nil = center point
                Log.info("🔴 SCALE TOOL: Default locked pin set to center", category: .general)
            }
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change (e.g., after moving), refresh the scale points
            if !isScaling && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
                Log.fileOperation("🔄 SCALE TOOL: Shape bounds changed, refreshed points", level: .info)
            }
        }
        .id("scale-handles-\(pointsRefreshTrigger)") // Force view rebuild when points update
    }
    
    private func handleCornerScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            scalingStarted = true
            isScaling = true
            document.isHandleScalingActive = true // CRITICAL: Prevent canvas drag conflicts
            initialBounds = bounds
            initialTransform = shape.transform
            startLocation = dragValue.startLocation
            document.saveToUndoStack()
            
            // NEW: Use selected scaling anchor mode from toolbar
            scalingAnchorPoint = getAnchorPoint(for: document.scalingAnchor, in: bounds, cornerIndex: index)
            print("🔄 SCALING START: Corner \(index) → Anchor mode: \(document.scalingAnchor.displayName) at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))")
            print("   📐 Initial bounds: (\(String(format: "%.1f", bounds.minX)), \(String(format: "%.1f", bounds.minY))) → (\(String(format: "%.1f", bounds.maxX)), \(String(format: "%.1f", bounds.maxY)))")
            print("   🖱️ Start cursor: screen(\(String(format: "%.1f", startLocation.x)), \(String(format: "%.1f", startLocation.y)))")
        }
        
        // PROFESSIONAL SCALING: Calculate scale from anchor point to current cursor position
        // Use direct cursor tracking instead of DragGesture.translation for perfect accuracy
        let currentLocation = dragValue.location
        
        // Convert anchor point to screen coordinates using manual calculation
        let anchorScreenX = scalingAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = scalingAnchorPoint.y * zoomLevel + canvasOffset.y
        
        // Calculate distances from anchor to start and current positions
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )
        
        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )
        
        // Calculate scale factors with reasonable bounds to prevent extreme values
        // ADAPTIVE MINIMUM DISTANCE: Base threshold on object size to handle thin/narrow objects
        let baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let adaptiveMinDistanceX = min(20.0, max(2.0, abs(baseBounds.width) * 0.05))  // 5% of width, min 2pt, max 20pt
        let adaptiveMinDistanceY = min(20.0, max(2.0, abs(baseBounds.height) * 0.05)) // 5% of height, min 2pt, max 20pt
        let maxScale: CGFloat = 10.0    // Maximum scale factor to prevent extreme scaling
        let minScale: CGFloat = 0.1     // Minimum scale factor to prevent inversion
        
        var scaleX = abs(startDistance.x) > adaptiveMinDistanceX ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
        var scaleY = abs(startDistance.y) > adaptiveMinDistanceY ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
        
        // Clamp scale factors to reasonable bounds
        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)
        
        // PROPORTIONAL SCALING: When shift is held, use uniform scaling
        if isShiftPressed {
            let uniformScale = max(scaleX, scaleY) // Use the larger scale factor
            scaleX = uniformScale
            scaleY = uniformScale
            print("🔀 PROPORTIONAL SCALING: Shift held - uniform scale \(String(format: "%.3f", uniformScale))")
        }
        
        // Professional logging for tracking
        print("🔢 SCALING: scaleX=\(String(format: "%.3f", scaleX)), scaleY=\(String(format: "%.3f", scaleY))\(isShiftPressed ? " (PROPORTIONAL)" : "")")
        print("   🖱️ Cursor: (\(String(format: "%.1f", currentLocation.x)), \(String(format: "%.1f", currentLocation.y))) → Distance: (\(String(format: "%.1f", currentDistance.x)), \(String(format: "%.1f", currentDistance.y)))")
        print("   ⚓ Anchor screen: (\(String(format: "%.1f", anchorScreenX)), \(String(format: "%.1f", anchorScreenY)))")
        print("   🎯 Adaptive thresholds: X=\(String(format: "%.1f", adaptiveMinDistanceX))pt, Y=\(String(format: "%.1f", adaptiveMinDistanceY))pt (based on bounds: \(String(format: "%.1f", baseBounds.width))×\(String(format: "%.1f", baseBounds.height)))")
        
        // Apply preview scaling
        calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: scalingAnchorPoint)
    }
    

    
    private func finishScaling() {
        scalingStarted = false
        isScaling = false
        document.isHandleScalingActive = false // CRITICAL: Re-enable canvas drag gestures
        
        Log.info("🏁 SCALING FINISH: Applying final transform to coordinates", category: .general)
        print("   📊 Preview transform: [\(String(format: "%.3f", previewTransform.a)), \(String(format: "%.3f", previewTransform.b)), \(String(format: "%.3f", previewTransform.c)), \(String(format: "%.3f", previewTransform.d)), \(String(format: "%.1f", previewTransform.tx)), \(String(format: "%.1f", previewTransform.ty))]")
        print("   🎯 FINAL MARQUEE: Bounds (\(String(format: "%.1f", finalMarqueeBounds.minX)), \(String(format: "%.1f", finalMarqueeBounds.minY))) → (\(String(format: "%.1f", finalMarqueeBounds.maxX)), \(String(format: "%.1f", finalMarqueeBounds.maxY)))")
        
        // PROFESSIONAL SCALING FIX: Apply the final preview transform to coordinates
        // This ensures object origin stays with object after scaling (Professional behavior)
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            
            let oldBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   📐 Old bounds: (\(String(format: "%.1f", oldBounds.minX)), \(String(format: "%.1f", oldBounds.minY))) → (\(String(format: "%.1f", oldBounds.maxX)), \(String(format: "%.1f", oldBounds.maxY)))")
            
            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            document.layers[layerIndex].shapes[shapeIndex].transform = initialTransform
            
            // Apply the final transform to coordinates and reset transform to identity
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            let newBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
            
            // Reset preview transform and marquee bounds
            previewTransform = .identity
            finalMarqueeBounds = .zero // Hide marquee
            
            Log.info("✅ SCALING FINISHED: Applied final transform to coordinates and reset transform to identity", category: .fileOperations)
            
            // CRITICAL FIX: Force refresh of point selection system (same as rotate/shear tools)
            // This updates the points to match the scaled object positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterScaling()
            }
        }
    }
    
    // MARK: - Point-Based Scale System (same as rotate/shear tools)
    
    /// Extract all path points for selection display
    private func extractPathPoints() {
        pathPoints.removeAll()
        
        // FLATTENED SHAPE FIX: Extract points from individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // For flattened shapes, extract points from all grouped shapes
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue // Skip close elements
                    }
                }
            }
        } else {
            // Regular shape: Extract from main path
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue // Skip close elements
                }
            }
        }
        
        // Update center point based on current bounds
        // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        centerPoint = VectorPoint(CGPoint(x: bounds.midX, y: bounds.midY))
        
        Log.fileOperation("🎯 EXTRACTED \(pathPoints.count) path points + center for scale anchor selection", level: .info)
    }
    
    /// Display all path points with correct colors: GREEN = scalable, RED = locked pin
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index
            
            let transformedPoint = CGPoint(x: point.x, y: point.y).applying(shape.transform)
            Circle()
                .fill(isLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = scalable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize, height: handleSize)
                .position(CGPoint(
                    x: transformedPoint.x * zoomLevel + canvasOffset.x,
                    y: transformedPoint.y * zoomLevel + canvasOffset.y
                ))
                .onTapGesture {
                    if !isScaling {
                        // SINGLE CLICK: Set this as the locked pin point (RED)
                        setLockedPinPoint(index)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Scale away from the locked pin point
                            handleScalingFromPoint(draggedPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishScaling()
                        }
                )
        }
    }
    
    // MARK: - Lock Pin Point Management
    
    /// Set which point is the locked pin point (RED) - stays stationary during scaling
    private func setLockedPinPoint(_ pointIndex: Int?) {
        lockedPinPointIndex = pointIndex
        
        // Update the scaling anchor point to the locked pin location
        if let index = pointIndex {
            if index < pathPoints.count {
                // Path point
                let point = pathPoints[index]
                scalingAnchorPoint = CGPoint(x: point.x, y: point.y)
                print("�� LOCKED PIN: Set to path point \(index) at (\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))")
            } else {
                // Bounds corner point
                let cornerIndex = index - pathPoints.count
                let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                scalingAnchorPoint = cornerPosition(for: cornerIndex, in: bounds, center: center)
                print("🔴 LOCKED PIN: Set to bounds corner \(cornerIndex) at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))")
            }
        } else {
            // Center point
            scalingAnchorPoint = CGPoint(x: centerPoint.x, y: centerPoint.y)
            print("🔴 LOCKED PIN: Set to center point at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))")
        }
    }
    
    // CORRECTED: Handle scaling away from the locked pin point
    private func handleScalingFromPoint(draggedPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            startScalingFromPoint(draggedPointIndex: draggedPointIndex, bounds: bounds, dragValue: dragValue)
        }
        
        // CRITICAL: Check if caps-lock is pressed to prevent changing the locked pin point
        if isCapsLockPressed && draggedPointIndex != lockedPinPointIndex {
            // Caps-lock is active: locked pin point cannot be changed, only scale away from it
            Log.info("🔒 CAPS-LOCK ACTIVE: Pin point locked, scaling away from locked point", category: .general)
        }
        
        // PROFESSIONAL SCALING: Scale away from the LOCKED PIN POINT (not the dragged point)
        // The locked pin point (RED) stays stationary, we scale away from it toward the drag location
        
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        
        // Convert locked pin point (anchor) to screen coordinates
        let anchorScreenX = scalingAnchorPoint.x * preciseZoom + canvasOffset.x
        let anchorScreenY = scalingAnchorPoint.y * preciseZoom + canvasOffset.y
        
        // Calculate distance from locked pin to start drag location
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )
        
        // Calculate distance from locked pin to current drag location
        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )
        
        // Calculate scale factors: how much bigger/smaller relative to the locked pin point
        let minDistance: CGFloat = 10.0 // Minimum distance to prevent extreme scaling
        let maxScale: CGFloat = 10.0
        let minScale: CGFloat = 0.1
        
        var scaleX = abs(startDistance.x) > minDistance ? abs(currentDistance.x) / abs(startDistance.x) : 1.0
        var scaleY = abs(startDistance.y) > minDistance ? abs(currentDistance.y) / abs(startDistance.y) : 1.0
        
        // Clamp scale factors
        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)
        
        // PROPORTIONAL SCALING: When shift is held, use uniform scaling
        if isShiftPressed {
            let uniformScale = max(scaleX, scaleY) // Use the larger scale factor
            scaleX = uniformScale
            scaleY = uniformScale
            print("🔢 SCALING AWAY FROM PIN: Uniform scale \(String(format: "%.3f", uniformScale)) (shift pressed)")
        } else {
            print("🔢 SCALING AWAY FROM PIN: scaleX=\(String(format: "%.3f", scaleX)), scaleY=\(String(format: "%.3f", scaleY))")
        }
        
        // Apply preview scaling with the LOCKED PIN POINT as anchor (it stays stationary)
        calculatePreviewTransform(scaleX: scaleX, scaleY: scaleY, anchor: scalingAnchorPoint)
    }
    
    private func startScalingFromPoint(draggedPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        scalingStarted = true
        isScaling = true
        document.isHandleScalingActive = true
        initialBounds = bounds
        initialTransform = shape.transform
        startLocation = dragValue.startLocation
        document.saveToUndoStack()
        
        // CORRECTED LOGIC: Don't change the locked pin point when starting to drag
        // The locked pin point should already be set by a previous single click
        // If no locked pin point is set, default to center
        if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
            // Default to center if no pin point was explicitly set
            setLockedPinPoint(nil) // nil = center
            Log.fileOperation("🔄 SCALING START: No pin point set, defaulting to center", level: .info)
        }
        
        // SCALING START: Minimal logging for performance
        
        let originalBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        print("   📐 Original bounds: (\(String(format: "%.1f", originalBounds.minX)), \(String(format: "%.1f", originalBounds.minY))) → (\(String(format: "%.1f", originalBounds.maxX)), \(String(format: "%.1f", originalBounds.maxY)))")
    }
    
    private func updatePathPointsAfterScaling() {
        // FORCE REFRESH: Clear current points and re-extract from transformed object
        pathPoints.removeAll()
        
        // FLATTENED SHAPE FIX: Extract points from individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // For flattened shapes, extract points from all grouped shapes
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue
                    }
                }
            }
        } else {
            // Regular shape: Re-extract all path points from the NOW-TRANSFORMED shape
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue
                }
            }
        }
        
        // Update center point based on NEW bounds after scaling
        // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds
        let newBounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))
        
        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1
        
        print("🔄 FORCE UPDATED scale points - \(pathPoints.count) path points + center at (\(String(format: "%.1f", centerPoint.x)), \(String(format: "%.1f", centerPoint.y)))")
        print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
    }
    
    // MARK: - Key Event Monitoring
    // NOTE: Shift key monitoring is now handled by the centralized keyEventMonitor in DrawingCanvas
    // to avoid multiple NSEvent monitors and ensure consistent behavior across all transform tools
    
    // MARK: - Scaling Anchor Point Calculation
    
    /// Get anchor point based on selected scaling mode
    private func getAnchorPoint(for anchor: ScalingAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }

    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying scaling transform to shape coordinates: \(shape.name)", level: .info)
        
        // FLATTENED SHAPE FIX: Apply transform to individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // Transform each individual shape within the flattened group
            var transformedGroupedShapes: [VectorShape] = []
            
            for var groupedShape in shape.groupedShapes {
                // Transform all path elements of this grouped shape
                var transformedElements: [PathElement] = []
                
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to):
                        let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                        
                    case .line(let to):
                        let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                        
                    case .curve(let to, let control1, let control2):
                        let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                        let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                        transformedElements.append(.curve(
                            to: VectorPoint(transformedTo),
                            control1: VectorPoint(transformedControl1),
                            control2: VectorPoint(transformedControl2)
                        ))
                        
                    case .quadCurve(let to, let control):
                        let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                        let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                        transformedElements.append(.quadCurve(
                            to: VectorPoint(transformedTo),
                            control: VectorPoint(transformedControl)
                        ))
                        
                    case .close:
                        transformedElements.append(.close)
                    }
                }
                
                // Update this grouped shape with transformed coordinates
                groupedShape.path = VectorPath(elements: transformedElements, isClosed: groupedShape.path.isClosed)
                groupedShape.transform = .identity
                groupedShape.updateBounds()
                
                transformedGroupedShapes.append(groupedShape)
            }
            
            // Update the flattened group with the transformed individual shapes
            document.layers[layerIndex].shapes[shapeIndex].groupedShapes = transformedGroupedShapes
            document.layers[layerIndex].shapes[shapeIndex].transform = .identity
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            Log.info("✅ Flattened group coordinates updated - transformed \(transformedGroupedShapes.count) individual shapes", category: .fileOperations)
            return
        }
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        // CORNER RADIUS SCALING: Apply transform to corner radii if this shape has them
        var updatedShape = document.layers[layerIndex].shapes[shapeIndex]
        if !updatedShape.cornerRadii.isEmpty && updatedShape.isRoundedRectangle {
            applyTransformToCornerRadiiLocal(shape: &updatedShape, transform: currentTransform)
            document.layers[layerIndex].shapes[shapeIndex] = updatedShape
        }
        
        Log.info("✅ Shape coordinates updated after scaling - object origin stays with object", category: .fileOperations)
    }
    

    
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates, let SwiftUI handle screen positioning
        // This prevents off-screen handle positioning issues
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY) // Top-left
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY) // Top-right
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY) // Bottom-right
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY) // Bottom-left
        default: return center
        }
    }
    

    
    // FIXED: Calculate preview transform from anchor point (corner pinning)
    private func calculatePreviewTransform(scaleX: CGFloat, scaleY: CGFloat, anchor: CGPoint) {
        // Create scaling transform around the anchor point (opposite corner)
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        
        // CRITICAL FIX: Always calculate from initial transform to prevent drift
        previewTransform = initialTransform.concatenating(scaleTransform)
        
        // MARQUEE FIX: Calculate exact final bounds position (PINNED CORRECTLY!)
        let currentBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        finalMarqueeBounds = currentBounds.applying(scaleTransform)
        
        // MARQUEE PREVIEW: Ensure isScaling is true for marquee visibility
        isScaling = true
        
        // MARQUEE LOGGING: Track marquee position vs anchor
        Log.info("   🎯 MARQUEE PREVIEW:", category: .general)
        print("      Original bounds: (\(String(format: "%.1f", currentBounds.minX)), \(String(format: "%.1f", currentBounds.minY))) → (\(String(format: "%.1f", currentBounds.maxX)), \(String(format: "%.1f", currentBounds.maxY)))")
        print("      Final marquee bounds: (\(String(format: "%.1f", finalMarqueeBounds.minX)), \(String(format: "%.1f", finalMarqueeBounds.minY))) → (\(String(format: "%.1f", finalMarqueeBounds.maxX)), \(String(format: "%.1f", finalMarqueeBounds.maxY)))")
        print("      Anchor point: (\(String(format: "%.1f", anchor.x)), \(String(format: "%.1f", anchor.y))) - \(document.scalingAnchor.displayName)")
        print("      Scale factors: X=\(String(format: "%.3f", scaleX)), Y=\(String(format: "%.3f", scaleY))")
        
        // CRITICAL FIX: DON'T apply preview to actual shape during dragging (like rectangle tool)
        // This prevents the transformation box from scaling and eliminates drift
        // The preview will be applied only at the end in finishScaling
        
        print("   📊 Preview transform: [\(String(format: "%.3f", previewTransform.a)), \(String(format: "%.3f", previewTransform.b)), \(String(format: "%.3f", previewTransform.c)), \(String(format: "%.3f", previewTransform.d)), \(String(format: "%.1f", previewTransform.tx)), \(String(format: "%.1f", previewTransform.ty))]")
        
        // Force UI update for preview rendering (without applying to shape)
        document.objectWillChange.send()
    }
    
    /// Check if a corner is the pinned anchor point
    private func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.scalingAnchor {
        case .center:
            return false // No corner is pinned when scaling from center
        case .topLeft:
            return cornerIndex == 0 // Top-left corner (index 0)
        case .topRight:
            return cornerIndex == 1 // Top-right corner (index 1)
        case .bottomRight:
            return cornerIndex == 2 // Bottom-right corner (index 2)
        case .bottomLeft:
            return cornerIndex == 3 // Bottom-left corner (index 3)
        }
    }
    
    /// Get scaling anchor for a corner index
    private func getAnchorForCorner(index: Int) -> ScalingAnchor {
        switch index {
        case 0: return .topLeft      // Top-left corner
        case 1: return .topRight     // Top-right corner
        case 2: return .bottomRight  // Bottom-right corner
        case 3: return .bottomLeft   // Bottom-left corner
        default: return .center      // Fallback
        }
    }
    
    // MARK: - Shift Key Monitoring for Proportional Scaling
    @State private var keyEventMonitor: Any?
    
    private func setupKeyEventMonitoring() {
        // DISABLED: NSEvent monitoring to fix text input interference
        // keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
        //     DispatchQueue.main.async {
        //         self.isShiftPressed = event.modifierFlags.contains(.shift)
        //     }
        //     return event
        // }
    }
    
    private func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
    
    // MARK: - Helper Functions for Transform Operations
    
    /// Apply transform to corner radii (local implementation to avoid import issues)
    private func applyTransformToCornerRadiiLocal(shape: inout VectorShape, transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }
        
        // Extract scale factors from transform
        let scaleX = sqrt(transform.a * transform.a + transform.c * transform.c)
        let scaleY = sqrt(transform.b * transform.b + transform.d * transform.d)
        
        // Check for uneven scaling that's too extreme
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0 // Threshold for "reasonable" scaling
        
        if scaleRatio > maxReasonableRatio {
            // BREAK/EXPAND: Transform is too uneven - disable corner radius tools
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            return
        }
        
        // SCALE RADII: Apply proportional scaling to corner radii
        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0 // Use average scale for corner radii
            
            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius) // Ensure non-negative
            }
        }
    }
}

// MARK: - Rotate Tool Handles  
struct RotateHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool  // Passed from DrawingCanvas for 15-degree increment snapping
    
    // Professional rotation state management
    @State private var isRotating = false
    @State private var rotationStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var rotationAnchorPoint: CGPoint = .zero
    @State private var startAngle: CGFloat = 0.0
    @State private var finalMarqueeBounds: CGRect = .zero  // MARQUEE FIX: Track final destination bounds like scale tool
    
    // POINT-BASED SELECTION SYSTEM: Select actual path points + center for rotation anchor
    @State private var selectedAnchorPointIndex: Int? = nil // Which point is selected as anchor (nil = center)
    @State private var pathPoints: [VectorPoint] = []  // Extracted path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Always include center
    @State private var pointsRefreshTrigger: Int = 0 // Force view refresh after transformation
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // ROTATE TOOL: Show actual path points + center point for precise anchor selection
        // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        ZStack {
            // ACTUAL OBJECT OUTLINE: Show the real shape path, not bounding box
            Path { path in
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
            }
            .stroke(Color.orange, lineWidth: 2.0 / zoomLevel) // Orange outline for rotate tool selection
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(shape.transform)
            
            // MARQUEE PREVIEW: Show ACTUAL ROTATED SHAPE OUTLINE (EXACTLY like the final object will be)
            if isRotating && !previewTransform.isIdentity {
                // CRITICAL FIX: Apply the SAME transformation that will be applied to the actual object
                // Transform the path coordinates directly (same as finishRotation does)
                Path { path in
                    for element in shape.path.elements {
                        switch element {
                        case .move(let to):
                            let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            path.move(to: transformedPoint)
                        case .line(let to):
                            let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            path.addLine(to: transformedPoint)
                        case .curve(let to, let control1, let control2):
                            let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                            let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                            path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                        case .quadCurve(let to, let control):
                            let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                            path.addQuadCurve(to: transformedTo, control: transformedControl)
                        case .close:
                            path.closeSubpath()
                        }
                    }
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                // NO .transformEffect! Coordinates already transformed above (same as actual object)
                .opacity(0.8)
                
                // Marquee shows rotation preview without additional handles (handled by point system below)
            }
            
            // SHOW ALL PATH POINTS + CENTER POINT for anchor selection
            pathPointsView()
            
            // CENTER POINT: Always available as rotation anchor
            let isCenterSelected = selectedAnchorPointIndex == nil
            Rectangle()
                .fill(isCenterSelected ? Color.green : Color.orange)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = nil // Select center
                        Log.fileOperation("🎯 ANCHOR SELECTED: Center point", level: .info)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: nil, dragValue: value, bounds: bounds, center: center)
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            setupRotationKeyEventMonitoring()
            extractPathPoints()
        }
        .onDisappear {
            teardownRotationKeyEventMonitoring()
        }
        .id("rotation-handles-\(pointsRefreshTrigger)") // Force view rebuild when points update
    }
    
    // MARK: - Point-Based Rotation System
    
    /// Extract all path points for selection display
    private func extractPathPoints() {
        pathPoints.removeAll()
        
        for element in shape.path.elements {
            switch element {
            case .move(let to), .line(let to):
                pathPoints.append(to)
            case .curve(let to, _, _), .quadCurve(let to, _):
                pathPoints.append(to)
            case .close:
                continue // Skip close elements
            }
        }
        
        // Update center point based on current bounds
        // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        centerPoint = VectorPoint(CGPoint(x: bounds.midX, y: bounds.midY))
        
        Log.fileOperation("🎯 EXTRACTED \(pathPoints.count) path points + center for rotation anchor selection", level: .info)
    }
    
    /// Display all path points as selectable anchors
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isSelected = selectedAnchorPointIndex == index
            
            Rectangle()
                .fill(isSelected ? Color.green : Color.orange)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(CGPoint(x: point.x, y: point.y))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isRotating {
                        selectedAnchorPointIndex = index
                        print("🎯 ANCHOR SELECTED: Path point \(index) at (\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))")
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            handlePointRotation(anchorPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
        }
    }
    
    // Handle rotation from selected point
    private func handlePointRotation(anchorPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !rotationStarted {
            startPointRotation(anchorPointIndex: anchorPointIndex, bounds: bounds, dragValue: dragValue)
        }
        
        // ROTATION FIX: Convert anchor point to screen coordinates like scale tool
        let currentLocation = dragValue.location
        
        // Convert anchor point to screen coordinates using manual calculation (same as scale tool)
        let anchorScreenX = rotationAnchorPoint.x * zoomLevel + canvasOffset.x
        let anchorScreenY = rotationAnchorPoint.y * zoomLevel + canvasOffset.y
        let rotationCenter = CGPoint(x: anchorScreenX, y: anchorScreenY)
        
        // Calculate angle from anchor point to current position
        let currentVector = CGPoint(x: currentLocation.x - rotationCenter.x, y: currentLocation.y - rotationCenter.y)
        let startVector = CGPoint(x: startLocation.x - rotationCenter.x, y: startLocation.y - rotationCenter.y)
        
        let currentAngle = atan2(currentVector.y, currentVector.x)
        let initialAngle = atan2(startVector.y, startVector.x)
        var rotationAngle = currentAngle - initialAngle
        
        // Shift key for 15-degree increments
        if isShiftPressed {
            let increment: CGFloat = .pi / 12  // 15 degrees
            rotationAngle = round(rotationAngle / increment) * increment
        }
        
        print("🔄 ROTATING: angle=\(String(format: "%.1f", rotationAngle * 180 / .pi))°, shift=\(isShiftPressed)")
        print("   ⚓ Anchor screen: (\(String(format: "%.1f", anchorScreenX)), \(String(format: "%.1f", anchorScreenY)))")
        
        calculatePreviewRotation(angle: rotationAngle, anchor: rotationAnchorPoint)
    }
    
    private func startPointRotation(anchorPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        document.saveToUndoStack()
        
        // AUTO-SELECT: Make the dragged point green (selected) automatically
        selectedAnchorPointIndex = anchorPointIndex
        
        // POINT-BASED ANCHOR: Use selected point or center
        if let pointIndex = anchorPointIndex {
            let point = pathPoints[pointIndex]
            rotationAnchorPoint = CGPoint(x: point.x, y: point.y)
            print("🔄 ROTATION START: Anchored to path point \(pointIndex) at (\(String(format: "%.1f", rotationAnchorPoint.x)), \(String(format: "%.1f", rotationAnchorPoint.y))) - AUTO-SELECTED GREEN")
        } else {
            rotationAnchorPoint = CGPoint(x: centerPoint.x, y: centerPoint.y)
            print("🔄 ROTATION START: Anchored to center point at (\(String(format: "%.1f", rotationAnchorPoint.x)), \(String(format: "%.1f", rotationAnchorPoint.y))) - AUTO-SELECTED GREEN")
        }
        
        print("   📐 Using ORIGINAL bounds: (\(String(format: "%.1f", bounds.minX)), \(String(format: "%.1f", bounds.minY))) → (\(String(format: "%.1f", bounds.maxX)), \(String(format: "%.1f", bounds.maxY)))")
    }
    
    private func updatePathPointsAfterRotation() {
        // FORCE REFRESH: Clear current points and re-extract from transformed object
        pathPoints.removeAll()
        
        // Re-extract all path points from the NOW-TRANSFORMED shape
        for element in shape.path.elements {
            switch element {
            case .move(let to), .line(let to):
                pathPoints.append(to)
            case .curve(let to, _, _), .quadCurve(let to, _):
                pathPoints.append(to)
            case .close:
                continue
            }
        }
        
        // Update center point based on NEW bounds after rotation
        let newBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))
        
        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1
        
        print("🔄 FORCE UPDATED rotation points - \(pathPoints.count) path points + center at (\(String(format: "%.1f", centerPoint.x)), \(String(format: "%.1f", centerPoint.y)))")
        print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
        Log.info("   🔄 View refresh trigger: \(pointsRefreshTrigger)", category: .general)
    }
    
    // MARK: - Rotation Anchor Point Calculation (Rotation-specific versions)
    
    /// Get anchor point based on selected rotation mode
    private func getRotationAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center:
            return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft:
            return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight:
            return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft:
            return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight:
            return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }
    
    /// Check if a corner is the pinned anchor point for rotation
    private func isRotationPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.rotationAnchor {
        case .center:
            return false // No corner is pinned when rotating from center
        case .topLeft:
            return cornerIndex == 0 // Top-left corner (index 0)
        case .topRight:
            return cornerIndex == 1 // Top-right corner (index 1)
        case .bottomRight:
            return cornerIndex == 2 // Bottom-right corner (index 2)
        case .bottomLeft:
            return cornerIndex == 3 // Bottom-left corner (index 3)
        }
    }
    
    /// Get rotation anchor for a corner index
    private func getRotationAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft      // Top-left corner
        case 1: return .topRight     // Top-right corner
        case 2: return .bottomRight  // Bottom-right corner
        case 3: return .bottomLeft   // Bottom-left corner
        default: return .center      // Fallback
        }
    }
    
    private func rotationCornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates, let SwiftUI handle screen positioning
        // This prevents off-screen handle positioning issues
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY) // Top-left
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY) // Top-right
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY) // Bottom-right
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY) // Bottom-left
        default: return center
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates (Rotation version)
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyRotationTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying rotation transform to shape coordinates: \(shape.name)", level: .info)
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        // CORNER RADIUS SCALING: Apply transform to corner radii if this shape has them
        var updatedShape = document.layers[layerIndex].shapes[shapeIndex]
        if !updatedShape.cornerRadii.isEmpty && updatedShape.isRoundedRectangle {
            applyTransformToCornerRadiiLocal(shape: &updatedShape, transform: currentTransform)
            document.layers[layerIndex].shapes[shapeIndex] = updatedShape
        }
        
        Log.info("✅ Shape coordinates updated after rotation - object origin stays with object", category: .fileOperations)
    }
    
    // MARK: - Rotation Key Event Monitoring
    @State private var rotationKeyEventMonitor: Any?
    
    private func setupRotationKeyEventMonitoring() {
        // DISABLED: NSEvent monitoring to fix text input interference
        // rotationKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
        //     DispatchQueue.main.async {
        //         self.isShiftPressed = event.modifierFlags.contains(.shift)
        //     }
        //     return event
        // }
    }
    
    private func teardownRotationKeyEventMonitoring() {
        if let monitor = rotationKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            rotationKeyEventMonitor = nil
        }
    }
    
    private func startRotation(cornerIndex: Int, bounds: CGRect, dragValue: DragGesture.Value) {
        rotationStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        document.saveToUndoStack()
        
        // CRITICAL FIX: Use ORIGINAL bounds (no transform applied) for anchor calculation  
        // This prevents anchor drift after multiple transformations
        let originalBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        rotationAnchorPoint = getRotationAnchorPoint(for: document.rotationAnchor, in: originalBounds, cornerIndex: cornerIndex)
        print("🔄 ROTATION START: Corner \(cornerIndex) → Anchor mode: \(document.rotationAnchor.displayName) at (\(String(format: "%.1f", rotationAnchorPoint.x)), \(String(format: "%.1f", rotationAnchorPoint.y)))")
        print("   📐 Using ORIGINAL bounds: (\(String(format: "%.1f", originalBounds.minX)), \(String(format: "%.1f", originalBounds.minY))) → (\(String(format: "%.1f", originalBounds.maxX)), \(String(format: "%.1f", originalBounds.maxY)))")
    }
    
    private func calculatePreviewRotation(angle: CGFloat, anchor: CGPoint) {
        // Create rotation transform around the anchor point
        let rotationTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .rotated(by: angle)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        
        // CRITICAL FIX: Always calculate from initial transform to prevent drift
        previewTransform = initialTransform.concatenating(rotationTransform)
        
        // MARQUEE PREVIEW: Ensure isRotating is true for marquee visibility
        isRotating = true
        
        // ROTATION LOGGING: Track rotation details
        Log.info("   🔄 ROTATION PREVIEW:", category: .general)
        print("      Anchor point: (\(String(format: "%.1f", anchor.x)), \(String(format: "%.1f", anchor.y))) - \(document.rotationAnchor.displayName)")
        print("      Rotation angle: \(String(format: "%.1f", angle * 180 / .pi))°")
        
        print("   📊 Rotation preview updated: angle=\(String(format: "%.1f", angle * 180 / .pi))° - showing ROTATED SHAPE outline")
        
        // Force UI update for preview rendering (without applying to shape)
        document.objectWillChange.send()
    }
    
    private func finishRotation() {
        rotationStarted = false
        document.isHandleScalingActive = false
        
        // CRITICAL FIX: Store the rotation angle before applying transform to coordinates
        let finalRotationAngle = atan2(previewTransform.b, previewTransform.a)
        
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            
            let oldBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   📐 Old bounds: (\(String(format: "%.1f", oldBounds.minX)), \(String(format: "%.1f", oldBounds.minY))) → (\(String(format: "%.1f", oldBounds.maxX)), \(String(format: "%.1f", oldBounds.maxY)))")
            
            // FIXED: Store rotation angle AND apply transform to make orange marquee rotate
            // But prevent bounds expansion by using a different approach
            document.layers[layerIndex].shapes[shapeIndex].rotationAngle = finalRotationAngle
            
            // CRITICAL: Apply transform to make orange marquee rotate
            // Use the existing helper function that properly handles VectorPath
            applyRotationTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            // Reset transform to identity since we're handling rotation separately
            document.layers[layerIndex].shapes[shapeIndex].transform = .identity
            
            let newBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   🔄 Stored rotation angle: \(String(format: "%.1f", finalRotationAngle * 180 / .pi))°")
            print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
            
            // Trigger view refresh
            document.objectWillChange.send()
        }
        
        // Reset rotation state
        previewTransform = .identity
    }
    
    // Helper functions (similar to ScaleHandles)
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }
    
    private func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.rotationAnchor {
        case .center: return false
        case .topLeft: return cornerIndex == 0
        case .topRight: return cornerIndex == 1
        case .bottomRight: return cornerIndex == 2
        case .bottomLeft: return cornerIndex == 3
        }
    }
    
    private func getAnchorForCorner(index: Int) -> RotationAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }
    
    private func getAnchorPoint(for anchor: RotationAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center: return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft: return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft: return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying rotation transform to shape coordinates: \(shape.name)", level: .info)
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        Log.info("✅ Shape coordinates updated after rotation - object origin stays with object", category: .fileOperations)
    }
    
    // MARK: - Key Event Monitoring
    // NOTE: Shift key monitoring is now handled by the centralized keyEventMonitor in DrawingCanvas
    // to avoid multiple NSEvent monitors and ensure consistent behavior across all transform tools
    
    // MARK: - Helper Functions for Transform Operations
    
    /// Apply transform to corner radii (local implementation to avoid import issues)
    private func applyTransformToCornerRadiiLocal(shape: inout VectorShape, transform: CGAffineTransform) {
        guard !transform.isIdentity else { return }
        
        // Extract scale factors from transform
        let scaleX = sqrt(transform.a * transform.a + transform.c * transform.c)
        let scaleY = sqrt(transform.b * transform.b + transform.d * transform.d)
        
        // Check for uneven scaling that's too extreme
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0 // Threshold for "reasonable" scaling
        
        if scaleRatio > maxReasonableRatio {
            // BREAK/EXPAND: Transform is too uneven - disable corner radius tools
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            return
        }
        
        // SCALE RADII: Apply proportional scaling to corner radii
        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0 // Use average scale for corner radii
            
            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius) // Ensure non-negative
            }
        }
    }
}

// MARK: - Shear Tool Handles
struct ShearHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool  // Passed from DrawingCanvas for constrained shearing
    
    // Professional shear state management - FIXED IMPLEMENTATION (same as scale tool)
    @State private var isShearing = false
    @State private var shearStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var shearAnchorPoint: CGPoint = .zero  // This is the LOCKED/PIN point (RED)
    @State private var isCapsLockPressed = false  // NEW: Track caps-lock for locking pin point
    
    // CORRECTED POINT SYSTEM: Lock point vs shear points (same as scale tool)
    @State private var lockedPinPointIndex: Int? = nil // Which point is LOCKED (RED) - set by single click
    @State private var pathPoints: [VectorPoint] = []  // All path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Center point
    @State private var pointsRefreshTrigger: Int = 0
    
    private let handleSize: CGFloat = 10
    
    var body: some View {
        // SHEAR TOOL: Show all path points + center point with correct colors (same as scale tool)
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        ZStack {
            // ACTUAL OBJECT OUTLINE: Show the real shape paths
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                // GROUP/FLATTENED SHAPE: Show outline of each individual shape
                ForEach(shape.groupedShapes.indices, id: \.self) { index in
                    let groupedShape = shape.groupedShapes[index]
                    // PERFORMANCE OPTIMIZATION: Use cached path creation
                    let cachedPath = Path { path in
                        for element in groupedShape.path.elements {
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
                    }
                    cachedPath
                        .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(groupedShape.transform)
                }
            } else {
                // REGULAR SHAPE: Show single path outline with cached path
                // PERFORMANCE OPTIMIZATION: Use cached path creation
                let cachedPath = Path { path in
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
                }
                cachedPath
                    .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
            
            // SHOW ALL PATH POINTS + CENTER POINT with correct colors
            pathPointsView()
            
            // CENTER POINT: Always available (GREEN if not locked, RED if locked)
            let isCenterLockedPin = (lockedPinPointIndex == nil) // nil represents center as locked pin
            Rectangle()
                .fill(isCenterLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = shearable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isShearing {
                        // SINGLE CLICK: Set center as the locked pin point (RED)
                        setLockedPinPoint(nil) // nil = center
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Shear away from the locked pin point
                            handleShearingFromPoint(draggedPointIndex: nil, dragValue: value, bounds: bounds, center: center)
                        }
                        .onEnded { _ in
                            finishShear()
                        }
                )
            
            // MARQUEE PREVIEW: Show ACTUAL SHEARED SHAPE OUTLINE (EXACTLY like the final object will be)
            if isShearing && !previewTransform.isIdentity {
                // CRITICAL FIX: Apply the SAME transformation that will be applied to the actual object
                // Transform the path coordinates directly (same as finishShear does)
                Path { path in
                    for element in shape.path.elements {
                        switch element {
                        case .move(let to):
                            let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            path.move(to: transformedPoint)
                        case .line(let to):
                            let transformedPoint = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            path.addLine(to: transformedPoint)
                        case .curve(let to, let control1, let control2):
                            let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(previewTransform)
                            let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(previewTransform)
                            path.addCurve(to: transformedTo, control1: transformedControl1, control2: transformedControl2)
                        case .quadCurve(let to, let control):
                            let transformedTo = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            let transformedControl = CGPoint(x: control.x, y: control.y).applying(previewTransform)
                            path.addQuadCurve(to: transformedTo, control: transformedControl)
                        case .close:
                            path.closeSubpath()
                        }
                    }
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                // NO .transformEffect! Coordinates already transformed above (same as actual object)
                .opacity(0.8)
                
                // MARQUEE CENTER POINT: Show the shear anchor point (stays fixed during shearing)
                let anchorScreenX = shearAnchorPoint.x * zoomLevel + canvasOffset.x
                let anchorScreenY = shearAnchorPoint.y * zoomLevel + canvasOffset.y
                let isCenterPinned = document.shearAnchor == .center
                Rectangle()
                    .fill(isCenterPinned ? Color.red : Color.green)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(x: anchorScreenX, y: anchorScreenY)
            }
            

        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            extractPathPoints()
            
            // Set default locked pin point to center if none is set
            if lockedPinPointIndex == nil && shearAnchorPoint == .zero {
                setLockedPinPoint(nil) // nil = center point
                Log.info("🔴 SHEAR TOOL: Default locked pin set to center", category: .general)
            }
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change (e.g., after moving), refresh the shear points
            if !isShearing && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
                Log.fileOperation("🔄 SHEAR TOOL: Shape bounds changed, refreshed points", level: .info)
            }
        }
        .id("shear-handles-\(pointsRefreshTrigger)") // Force view rebuild when points update
    }
    

    
    // FIXED: Calculate shear transform with TRUE pin point (different from scale tool approach)
    private func calculatePreviewShear(shearX: CGFloat, shearY: CGFloat, anchor: CGPoint) {
        // SHEAR-SPECIFIC PIN POINT CALCULATION:
        // Unlike scaling, shear transforms move ALL points including the intended anchor
        // We need to calculate the shear, then compensate to keep the pin point stationary
        
        // Step 1: Create the base shear transformation
        let baseShearTransform = CGAffineTransform(a: 1, b: shearY, c: shearX, d: 1, tx: 0, ty: 0)
        
        // Step 2: Calculate where the anchor point would move to with this shear
        let sheared_anchor = anchor.applying(baseShearTransform)
        
        // Step 3: Calculate the translation needed to move it back to original position
        let compensationTranslation = CGAffineTransform(translationX: anchor.x - sheared_anchor.x, y: anchor.y - sheared_anchor.y)
        
        // Step 4: Combine shear + compensation translation to pin the anchor point
        let pinPointShearTransform = baseShearTransform.concatenating(compensationTranslation)
        
        // Step 5: Apply to initial transform to prevent drift
        previewTransform = initialTransform.concatenating(pinPointShearTransform)
        
        // Ensure isShearing is true for preview visibility
        isShearing = true
        
        Log.info("   📊 PIN-POINT SHEAR preview updated:", category: .general)
        print("      Shear factors: X=\(String(format: "%.3f", shearX)), Y=\(String(format: "%.3f", shearY))")
        print("      📍 Original anchor: (\(String(format: "%.1f", anchor.x)), \(String(format: "%.1f", anchor.y)))")
        print("      📐 Would move to: (\(String(format: "%.1f", sheared_anchor.x)), \(String(format: "%.1f", sheared_anchor.y)))")
        print("      🔧 Compensation: (\(String(format: "%.1f", anchor.x - sheared_anchor.x)), \(String(format: "%.1f", anchor.y - sheared_anchor.y)))")
        print("      🔒 RESULT: Pin point stays at (\(String(format: "%.1f", anchor.x)), \(String(format: "%.1f", anchor.y)))")
    }
    
    private func finishShear() {
        shearStarted = false
        isShearing = false
        document.isHandleScalingActive = false
        
        Log.info("🏁 SHEAR FINISH: Applying final transform to coordinates", category: .general)
        
        // CRITICAL FIX: Apply shear to actual coordinates, not just transform
        // This ensures object origin stays with object after shearing (Professional behavior)
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            
            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            document.layers[layerIndex].shapes[shapeIndex].transform = initialTransform
            
            // Apply the final transform to coordinates and reset transform to identity
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            Log.info("✅ SHEAR FINISHED: Applied shear to coordinates and reset transform to identity", category: .fileOperations)
            
            // CRITICAL FIX: Force refresh of point selection system (same as rotation tool)
            // This updates the points to match the sheared object positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterShear()
            }
        }
        
        previewTransform = .identity
    }
    
    // MARK: - Point-Based Shear System (same as rotate tool)
    
    /// Extract all path points for selection display
    private func extractPathPoints() {
        pathPoints.removeAll()
        
        // FLATTENED SHAPE FIX: Extract points from individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // For flattened shapes, extract points from all grouped shapes
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue // Skip close elements
                    }
                }
            }
        } else {
            // Regular shape: Extract from main path
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue // Skip close elements
                }
            }
        }
        
        // Update center point based on current bounds
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        centerPoint = VectorPoint(CGPoint(x: bounds.midX, y: bounds.midY))
        
        Log.fileOperation("🎯 EXTRACTED \(pathPoints.count) path points + center for shear anchor selection", level: .info)
    }
    
    /// Display all path points with correct colors: GREEN = shearable, RED = locked pin
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index
            
            Circle()
                .fill(isLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = shearable
                .stroke(Color.white, lineWidth: 1.0 / zoomLevel)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(CGPoint(x: point.x, y: point.y))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isShearing {
                        // SINGLE CLICK: Set this as the locked pin point (RED)
                        setLockedPinPoint(index)
                    }
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Shear away from the locked pin point
                            handleShearingFromPoint(draggedPointIndex: index, dragValue: value, bounds: shape.bounds, center: CGPoint(x: centerPoint.x, y: centerPoint.y))
                        }
                        .onEnded { _ in
                            finishShear()
                        }
                )
        }
    }
    
    // MARK: - Lock Pin Point Management (same as scale tool)
    
    /// Set which point is the locked pin point (RED) - stays stationary during shearing
    private func setLockedPinPoint(_ pointIndex: Int?) {
        lockedPinPointIndex = pointIndex
        
        // Update the shearing anchor point to the locked pin location
        if let index = pointIndex {
            if index < pathPoints.count {
                // Path point
                let point = pathPoints[index]
                shearAnchorPoint = CGPoint(x: point.x, y: point.y)
                print("🔴 LOCKED PIN: Set to path point \(index) at (\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))")
            } else {
                // Bounds corner point (if we add them later)
                let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
                let center = CGPoint(x: bounds.midX, y: bounds.midY)
                shearAnchorPoint = center // Fallback to center
                Log.info("🔴 LOCKED PIN: Set to bounds point (fallback to center)", category: .general)
            }
        } else {
            // Center point
            shearAnchorPoint = CGPoint(x: centerPoint.x, y: centerPoint.y)
            print("🔴 LOCKED PIN: Set to center point at (\(String(format: "%.1f", shearAnchorPoint.x)), \(String(format: "%.1f", shearAnchorPoint.y)))")
        }
    }
    
    // CORRECTED: Handle shearing away from the locked pin point (same as scale tool)
    private func handleShearingFromPoint(draggedPointIndex: Int?, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !shearStarted {
            startShearingFromPoint(draggedPointIndex: draggedPointIndex, bounds: bounds, dragValue: dragValue)
        }
        
        // CRITICAL: Check if caps-lock is pressed to prevent changing the locked pin point
        if isCapsLockPressed && draggedPointIndex != lockedPinPointIndex {
            // Caps-lock is active: locked pin point cannot be changed, only shear away from it
            Log.info("🔒 CAPS-LOCK ACTIVE: Pin point locked, shearing away from locked point", category: .general)
        }
        
        // PROFESSIONAL SHEARING: Shear relative to the LOCKED PIN POINT (similar to scale tool)
        // The locked pin point (RED) stays stationary, we calculate shear based on movement relative to it
        
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        
        // Convert locked pin point (anchor) to screen coordinates
        let anchorScreenX = shearAnchorPoint.x * preciseZoom + canvasOffset.x
        let anchorScreenY = shearAnchorPoint.y * preciseZoom + canvasOffset.y
        
        // Calculate distance from locked pin to start drag location
        let startDistance = CGPoint(
            x: startLocation.x - anchorScreenX,
            y: startLocation.y - anchorScreenY
        )
        
        // Calculate distance from locked pin to current drag location
        let currentDistance = CGPoint(
            x: currentLocation.x - anchorScreenX,
            y: currentLocation.y - anchorScreenY
        )
        
        // Calculate shear factors based on movement relative to pin point
        // Using the same sensitivity approach as the scale tool
        let sensitivity: CGFloat = 0.002 // Shear sensitivity factor
        
        let deltaX = currentDistance.x - startDistance.x
        let deltaY = currentDistance.y - startDistance.y
        
        // Calculate shear factors: how much to shear based on pin-relative movement
        let shearFactorX = deltaY * sensitivity  // Horizontal shear based on vertical movement
        let shearFactorY = deltaX * sensitivity  // Vertical shear based on horizontal movement
        
        var finalShearX = shearFactorX
        var finalShearY = shearFactorY
        
        // CONSTRAINED SHEARING: When shift is held, constrain to dominant direction
        if isShiftPressed {
            if abs(shearFactorX) > abs(shearFactorY) {
                finalShearY = 0
                print("🔄 SHEARING AWAY FROM PIN: X=\(String(format: "%.3f", finalShearX)), Y=0 (shift constrained - horizontal)")
            } else {
                finalShearX = 0
                print("🔄 SHEARING AWAY FROM PIN: X=0, Y=\(String(format: "%.3f", finalShearY)) (shift constrained - vertical)")
            }
        } else {
            print("🔄 SHEARING AWAY FROM PIN: X=\(String(format: "%.3f", finalShearX)), Y=\(String(format: "%.3f", finalShearY))")
        }
        
        // Apply preview shearing with the LOCKED PIN POINT as anchor (it stays stationary)
        calculatePreviewShear(shearX: finalShearX, shearY: finalShearY, anchor: shearAnchorPoint)
    }
    
    private func startShearingFromPoint(draggedPointIndex: Int?, bounds: CGRect, dragValue: DragGesture.Value) {
        shearStarted = true
        isShearing = true
        document.isHandleScalingActive = true
        initialBounds = bounds
        initialTransform = shape.transform
        startLocation = dragValue.location
        document.saveToUndoStack()
        
        // CORRECTED LOGIC: Don't change the locked pin point when starting to drag
        // The locked pin point should already be set by a previous single click
        // If no locked pin point is set, default to center
        if lockedPinPointIndex == nil && shearAnchorPoint == .zero {
            // Default to center if no pin point was explicitly set
            setLockedPinPoint(nil) // nil = center
            Log.fileOperation("🔄 SHEAR START: No pin point set, defaulting to center", level: .info)
        }
        
        // SHEAR START: Minimal logging for performance
        
        let originalBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        print("   📐 Original bounds: (\(String(format: "%.1f", originalBounds.minX)), \(String(format: "%.1f", originalBounds.minY))) → (\(String(format: "%.1f", originalBounds.maxX)), \(String(format: "%.1f", originalBounds.maxY)))")
    }
    
    private func updatePathPointsAfterShear() {
        // FORCE REFRESH: Clear current points and re-extract from transformed object
        pathPoints.removeAll()
        
        // FLATTENED SHAPE FIX: Extract points from individual grouped shapes, not container
        if shape.isGroup && !shape.groupedShapes.isEmpty {
            // For flattened shapes, extract points from all grouped shapes
            for groupedShape in shape.groupedShapes {
                for element in groupedShape.path.elements {
                    switch element {
                    case .move(let to), .line(let to):
                        pathPoints.append(to)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        pathPoints.append(to)
                    case .close:
                        continue // Skip close elements
                    }
                }
            }
        } else {
            // Regular shape: Re-extract all path points from the NOW-TRANSFORMED shape
            for element in shape.path.elements {
                switch element {
                case .move(let to), .line(let to):
                    pathPoints.append(to)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    pathPoints.append(to)
                case .close:
                    continue // Skip close elements
                }
            }
        }
        
        // Update center point based on NEW bounds after shear
        let newBounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))
        
        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1
        
        print("🔄 FORCE UPDATED shear points - \(pathPoints.count) path points + center at (\(String(format: "%.1f", centerPoint.x)), \(String(format: "%.1f", centerPoint.y)))")
        print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
    }
    
    // MARK: - Key Event Monitoring
    // NOTE: Shift key monitoring is now handled by the centralized keyEventMonitor in DrawingCanvas
    // to avoid multiple NSEvent monitors and ensure consistent behavior across all transform tools
    
    // Helper functions (similar to RotateHandles)
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }
    

    

    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Professional behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        Log.fileOperation("🔧 Applying shear transform to shape coordinates: \(shape.name)", level: .info)
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(currentTransform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(currentTransform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(currentTransform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(currentTransform)
                transformedElements.append(.quadCurve(
                    to: VectorPoint(transformedTo),
                    control: VectorPoint(transformedControl)
                ))
                
            case .close:
                transformedElements.append(.close)
            }
        }
        
        // Create new path with transformed coordinates
        let transformedPath = VectorPath(elements: transformedElements, isClosed: shape.path.isClosed)
        
        // Update the shape with transformed path and reset transform to identity
        document.layers[layerIndex].shapes[shapeIndex].path = transformedPath
        document.layers[layerIndex].shapes[shapeIndex].transform = .identity
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        Log.info("✅ Shape coordinates updated after shear - object origin stays with object", category: .fileOperations)
    }
    

}

// MARK: - Envelope Warping Tool Handles
struct EnvelopeHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    // Professional envelope warping state management
    @State private var isWarping = false
    @State private var warpingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewPath: VectorPath? = nil
    @State private var isShiftPressed = false  // For proportional warping
    
    // ENVELOPE BOUNDING BOX SYSTEM: 4 corner points that define the warp envelope
    @State private var originalCorners: [CGPoint] = []  // Original bounding box corners
    @State private var warpedCorners: [CGPoint] = []    // Current warped positions
    @State private var draggingCornerIndex: Int? = nil  // Which corner is being dragged
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // ENVELOPE TOOL: Show bounding box corners with correct colors
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        
        ZStack {
            // ACTUAL OBJECT OUTLINE: Show the real shape paths
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                // GROUP/FLATTENED SHAPE: Show outline of each individual shape
                ForEach(shape.groupedShapes.indices, id: \.self) { index in
                    let groupedShape = shape.groupedShapes[index]
                    // PERFORMANCE OPTIMIZATION: Use cached path creation
                    let cachedPath = Path { path in
                        for element in groupedShape.path.elements {
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
                    }
                    cachedPath
                        .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(groupedShape.transform)
                }
            } else {
                // REGULAR SHAPE: Show single path outline with cached path
                // PERFORMANCE OPTIMIZATION: Use cached path creation
                let cachedPath = Path { path in
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
                }
                cachedPath
                    .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
            
            // ENVELOPE BOUNDING BOX: Show the 4 corner handles
            envelopeCornerHandles()
            
            // ENVELOPE GRID: Show the warp grid when envelope tool is active
            if document.currentTool == .warp && warpedCorners.count == 4 {
                envelopeGridPreview()
            }
            
            // WARPED PREVIEW: Show the warped shape when there's a preview (continuous editing)
            if let _ = previewPath {
                warpedShapePreview()
            }
        }
        .onAppear {
            initialBounds = bounds
            initialTransform = shape.transform
            setupEnvelopeKeyEventMonitoring()
            initializeEnvelopeCorners()
        }
        .onDisappear {
            teardownEnvelopeKeyEventMonitoring()
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change, refresh the envelope corners
            // CRITICAL FIX: Don't recalculate axis during active warping or when warp handles are already established
            if !isWarping && !warpingStarted && warpedCorners.isEmpty && oldBounds != newBounds {
                initializeEnvelopeCorners()
                Log.fileOperation("🔄 ENVELOPE TOOL: Shape bounds changed, refreshed corners", level: .info)
            }
        }
        .onChange(of: document.currentTool) { oldTool, newTool in
            // ENVELOPE COMMIT: When switching away from envelope tool, commit any pending warp
            if oldTool == .warp && newTool != .warp {
                // First commit any pending warp transformation
                if previewPath != nil {
                    commitEnvelopeWarp()
                }
                
                // CRITICAL FIX: DON'T clear envelope state - preserve warp memory
                // This allows continuous editing when switching back to envelope tool
                Log.fileOperation("🔄 ENVELOPE TOOL: Switched away - committed warp and PRESERVED state", level: .info)
            }
            
            // ENVELOPE REACTIVATION: When switching back to envelope tool, reinitialize for current shape
            if oldTool != .warp && newTool == .warp {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }
                Log.fileOperation("🔄 ENVELOPE TOOL: Reactivated - initializing for current shape", level: .info)
            }
        }
        .onChange(of: document.selectedShapeIDs) { oldSelection, newSelection in
            // ENVELOPE COMMIT: When shape selection changes, commit current warp and reset for new shape
            if document.currentTool == .warp && oldSelection != newSelection {
                // First commit any pending warp transformation on the old shape
                if previewPath != nil {
                    commitEnvelopeWarp()
                }
                
                // CLEAR PREVIEW: When switching to different shape, clear old preview
                previewPath = nil
                
                // Then reset the envelope state for the new shape
                originalCorners.removeAll()
                warpedCorners.removeAll()
                
                // Initialize envelope for the new shape
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.initializeEnvelopeCorners()
                }
                
                Log.fileOperation("🔄 ENVELOPE TOOL: Shape selection changed - committed warp and reset for new shape", level: .info)
            }
        }
    }
    
    // MARK: - Envelope Corner Handles
    
    @ViewBuilder
    private func envelopeCornerHandles() -> some View {
        ForEach(0..<4) { cornerIndex in
            let cornerPos = warpedCorners.indices.contains(cornerIndex) ? warpedCorners[cornerIndex] : CGPoint.zero
            
            Rectangle()
                .fill(Color.green)  // All corners GREEN - no locking
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(cornerPos)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                // ACTUAL PATH CORNERS FIX: Never apply transform since we use actual path points
                // (Path points already contain the object's geometry and rotation)
                .gesture(
                    DragGesture(minimumDistance: 3)
                        .onChanged { value in
                            // DRAG: Warp envelope from this corner
                            handleEnvelopeWarp(cornerIndex: cornerIndex, dragValue: value)
                        }
                        .onEnded { _ in
                            finishEnvelopeWarp()
                        }
                )
        }
    }
    
    @ViewBuilder
    private func envelopeGridPreview() -> some View {
        // Show a 3x3 or 4x4 grid overlay showing the warp distortion
        let gridLines = 4
        
        // Horizontal grid lines
        ForEach(0..<4) { row in
            let t = CGFloat(row) / CGFloat(gridLines - 1)
            Path { path in
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1], 
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: 0.0, v: t
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3], 
                    bottomRight: warpedCorners[2],
                    u: 1.0, v: t
                )
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            // ACTUAL PATH CORNERS FIX: Never apply transform since we use actual path points
            .opacity(0.6)
        }
        
        // Vertical grid lines
        ForEach(0..<4) { col in
            let u = CGFloat(col) / CGFloat(gridLines - 1)
            Path { path in
                let startPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 0.0
                )
                let endPoint = bilinearInterpolation(
                    topLeft: warpedCorners[0],
                    topRight: warpedCorners[1],
                    bottomLeft: warpedCorners[3],
                    bottomRight: warpedCorners[2],
                    u: u, v: 1.0
                )
                path.move(to: startPoint)
                path.addLine(to: endPoint)
            }
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            // ACTUAL PATH CORNERS FIX: Never apply transform since we use actual path points
            .opacity(0.6)
        }
    }
    
    @ViewBuilder
    private func warpedShapePreview() -> some View {
        if let warpedPath = previewPath {
            Path { path in
                for element in warpedPath.elements {
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
            }
            .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .opacity(0.8)
        }
    }
    
    // MARK: - Envelope Warping Logic
    
    private func initializeEnvelopeCorners() {
        // WARP OBJECT HANDLING: Use stored original envelope for continuous warping
        if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
            // CRITICAL FIX: Use stored original envelope as reference, current envelope as starting point
            if !shape.originalEnvelope.isEmpty {
                originalCorners = shape.originalEnvelope  // TRUE original envelope (never changes)
                warpedCorners = shape.warpEnvelope        // Current envelope (can be warped further)
                Log.fileOperation("🔧 WARP MEMORY PRESERVED: Using stored original envelope for reference", level: .info)
                print("   Original Envelope: [\(shape.originalEnvelope.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]")
                print("   Current Envelope: [\(shape.warpEnvelope.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]")
            } else {
                // Fallback for older warp objects without originalEnvelope
                originalCorners = shape.warpEnvelope
                warpedCorners = shape.warpEnvelope
                Log.fileOperation("🔧 LEGACY WARP OBJECT: Missing original envelope, using current as reference", level: .info)
            }
            
            Log.info("   🎯 Continuous warping enabled - can warp from current state", category: .general)
            
            // REACTIVATION: Set preview to current warped shape for immediate visual feedback
            previewPath = shape.path  // Show current warped state immediately
            Log.info("   🔄 REACTIVATION: Set preview to current warped shape (\(shape.path.elements.count) elements)", category: .general)
            
            return
        }
        
        // Use axis plane dtection for four pounted shapes or four ointed gorups and flattened objects
        // otherwise use the bounding box
        if shape.path.elements.count <= 4 || shape.isGroup {
            let newOriginalCorners = calculateOrientedBoundingBox(for: shape)
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners
        } else {
            let bounds = shape.bounds
            let newOriginalCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.minY),
                CGPoint(x: bounds.maxX, y: bounds.maxY),
                CGPoint(x: bounds.minX, y: bounds.maxY)
            ]
            originalCorners = newOriginalCorners
            warpedCorners = newOriginalCorners
        }

        Log.fileOperation("🔧 ENVELOPE INITIALIZED: Using \(originalCorners.count) corners", level: .info)
    }
    
    private func cornersHaveChangedSignificantly(from oldCorners: [CGPoint], to newCorners: [CGPoint]) -> Bool {
        guard oldCorners.count == 4 && newCorners.count == 4 else { return true }
        
        let threshold: CGFloat = 1.0 // 1 pixel tolerance
        for i in 0..<4 {
            let oldCorner = oldCorners[i]
            let newCorner = newCorners[i]
            if abs(oldCorner.x - newCorner.x) > threshold || abs(oldCorner.y - newCorner.y) > threshold {
                return true
            }
        }
        return false
    }
    

    
    private func handleEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        if !warpingStarted {
            startEnvelopeWarp(cornerIndex: cornerIndex, dragValue: dragValue)
        }
        
        // Convert drag location to canvas coordinates
        let currentLocation = dragValue.location
        let preciseZoom = Double(zoomLevel)
        let canvasLocation = CGPoint(
            x: (currentLocation.x - canvasOffset.x) / preciseZoom,
            y: (currentLocation.y - canvasOffset.y) / preciseZoom
        )
        
        // Update the warped corner position
        warpedCorners[cornerIndex] = canvasLocation
        
        // Calculate the warped shape preview
        calculateEnvelopeWarpPreview()
    }
    
    private func startEnvelopeWarp(cornerIndex: Int, dragValue: DragGesture.Value) {
        warpingStarted = true
        isWarping = true
        document.isHandleScalingActive = true // Prevent canvas dragging
        
        // CRITICAL FIX: Use correct reference bounds for warp objects
        if shape.isWarpObject && originalCorners.count == 4 {
            // For warp objects, use the original corners to calculate reference bounds
            let minX = min(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let maxX = max(originalCorners[0].x, originalCorners[1].x, originalCorners[2].x, originalCorners[3].x)
            let minY = min(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            let maxY = max(originalCorners[0].y, originalCorners[1].y, originalCorners[2].y, originalCorners[3].y)
            initialBounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            print("🔧 WARP OBJECT: Using original bounds for reference: (\(String(format: "%.1f", minX)), \(String(format: "%.1f", minY))) → (\(String(format: "%.1f", maxX)), \(String(format: "%.1f", maxY)))")
        } else if shape.isWarpObject, let originalPath = shape.originalPath {
            // Fallback: Use original path bounds if corners aren't available
            initialBounds = originalPath.cgPath.boundingBoxOfPath
            Log.fileOperation("🔧 WARP OBJECT: Using original path bounds for reference", level: .info)
        } else {
            // For regular shapes, use current bounds
            initialBounds = shape.bounds
            Log.fileOperation("🔧 REGULAR SHAPE: Using current bounds for reference", level: .info)
        }
        
        initialTransform = shape.transform
        startLocation = dragValue.startLocation
        draggingCornerIndex = cornerIndex
        document.saveToUndoStack()
        
        Log.fileOperation("🔧 ENVELOPE WARP STARTED: Corner \(cornerIndex)", level: .info)
    }
    
    private func calculateEnvelopeWarpPreview() {
        // Apply bilinear transformation to create warped shape
        guard originalCorners.count == 4 && warpedCorners.count == 4 else { return }
        
        // CRITICAL FIX: Handle different object types properly
        if shape.isWarpObject, let originalPath = shape.originalPath {
            // WARP OBJECT: Use the original unwrapped path for clean transformations
            let warpedElements = warpPathElements(originalPath.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: originalPath.isClosed)
            // Using original path for warp object transformation
        } else if shape.isGroup && !shape.groupedShapes.isEmpty {
            // GROUP/FLATTENED OBJECT: Warp all individual shapes within the group
            var allWarpedElements: [PathElement] = []
            
            for groupedShape in shape.groupedShapes {
                let warpedElements = warpPathElements(groupedShape.path.elements)
                allWarpedElements.append(contentsOf: warpedElements)
                
                // Add a move to separate shapes if needed
                if !allWarpedElements.isEmpty && groupedShape != shape.groupedShapes.last {
                    // Separation is handled naturally by individual shape paths
                }
            }
            
            previewPath = VectorPath(elements: allWarpedElements, isClosed: false)
            Log.info("   🔧 Warping \(shape.groupedShapes.count) grouped shapes (flattened/group object)", category: .general)
        } else {
            // REGULAR SHAPE: Use current path
            let warpedElements = warpPathElements(shape.path.elements)
            previewPath = VectorPath(elements: warpedElements, isClosed: shape.path.isClosed)
            // Using current path for regular shape transformation
        }
        
        // Envelope warp preview updated
    }
    
    private func warpPathElements(_ elements: [PathElement]) -> [PathElement] {
        var warpedElements: [PathElement] = []
        
        for element in elements {
            switch element {
            case .move(let to):
                let warpedPoint = warpPoint(CGPoint(x: to.x, y: to.y))
                warpedElements.append(.move(to: VectorPoint(warpedPoint)))
                
            case .line(let to):
                let warpedPoint = warpPoint(CGPoint(x: to.x, y: to.y))
                warpedElements.append(.line(to: VectorPoint(warpedPoint)))
                
            case .curve(let to, let control1, let control2):
                let warpedTo = warpPoint(CGPoint(x: to.x, y: to.y))
                let warpedControl1 = warpPoint(CGPoint(x: control1.x, y: control1.y))
                let warpedControl2 = warpPoint(CGPoint(x: control2.x, y: control2.y))
                warpedElements.append(.curve(
                    to: VectorPoint(warpedTo),
                    control1: VectorPoint(warpedControl1),
                    control2: VectorPoint(warpedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let warpedTo = warpPoint(CGPoint(x: to.x, y: to.y))
                let warpedControl = warpPoint(CGPoint(x: control.x, y: control.y))
                warpedElements.append(.quadCurve(
                    to: VectorPoint(warpedTo),
                    control: VectorPoint(warpedControl)
                ))
                
            case .close:
                warpedElements.append(.close)
            }
        }
        
        return warpedElements
    }
    
    private func warpPoint(_ point: CGPoint) -> CGPoint {
        // ORIENTED BOUNDING BOX FIX: Use actual original corners for coordinate transformation
        guard originalCorners.count == 4 else {
            // Fallback to axis-aligned approach
            let bounds = initialBounds
            let u = (point.x - bounds.minX) / bounds.width
            let v = (point.y - bounds.minY) / bounds.height
            
            return bilinearInterpolation(
                topLeft: warpedCorners[0],
                topRight: warpedCorners[1],
                bottomLeft: warpedCorners[3],
                bottomRight: warpedCorners[2],
                u: u, v: v
            )
        }
        
        // Convert point from oriented bounding box to normalized coordinates (0-1)
        // Use inverse bilinear interpolation to find (u,v) coordinates in the original oriented quad
        let (u, v) = inverseBilinearInterpolation(
            point: point,
            topLeft: originalCorners[0],     // Top-left
            topRight: originalCorners[1],    // Top-right
            bottomLeft: originalCorners[3],  // Bottom-left
            bottomRight: originalCorners[2]  // Bottom-right
        )
        
        // Use bilinear interpolation to map to warped quadrilateral
        return bilinearInterpolation(
            topLeft: warpedCorners[0],     // Top-left
            topRight: warpedCorners[1],    // Top-right
            bottomLeft: warpedCorners[3],  // Bottom-left
            bottomRight: warpedCorners[2], // Bottom-right
            u: u, v: v
        )
    }
    
    // MARK: - Bilinear Interpolation Math
    
    private func bilinearInterpolation(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        // Standard bilinear interpolation formula
        let top = CGPoint(
            x: topLeft.x * (1 - u) + topRight.x * u,
            y: topLeft.y * (1 - u) + topRight.y * u
        )
        let bottom = CGPoint(
            x: bottomLeft.x * (1 - u) + bottomRight.x * u,
            y: bottomLeft.y * (1 - u) + bottomRight.y * u
        )
        
        return CGPoint(
            x: top.x * (1 - v) + bottom.x * v,
            y: top.y * (1 - v) + bottom.y * v
        )
    }
    
    private func inverseBilinearInterpolation(point: CGPoint, topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) -> (u: CGFloat, v: CGFloat) {
        // Find (u,v) coordinates where point lies within the quadrilateral
        // This is more complex for arbitrary quadrilaterals, so we'll use an iterative approach
        
        // For simple axis-aligned rectangles, this would be:
        // u = (point.x - topLeft.x) / (topRight.x - topLeft.x)
        // v = (point.y - topLeft.y) / (bottomLeft.y - topLeft.y)
        
        // For oriented rectangles, we need to solve the bilinear system
        // We'll use Newton's method or a simplified approach for rectangular shapes
        
        // Calculate vectors for the oriented rectangle
        let rightVector = CGPoint(x: topRight.x - topLeft.x, y: topRight.y - topLeft.y)
        let downVector = CGPoint(x: bottomLeft.x - topLeft.x, y: bottomLeft.y - topLeft.y)
        let pointVector = CGPoint(x: point.x - topLeft.x, y: point.y - topLeft.y)
        
        // For rectangles, we can solve this as a 2x2 linear system
        // pointVector = u * rightVector + v * downVector
        
        let det = rightVector.x * downVector.y - rightVector.y * downVector.x
        
        if abs(det) < 1e-10 {
            // Degenerate case - fallback to simple projection
            let rightLength = sqrt(rightVector.x * rightVector.x + rightVector.y * rightVector.y)
            let downLength = sqrt(downVector.x * downVector.x + downVector.y * downVector.y)
            
            let u: CGFloat = rightLength > 0 ? 
                (pointVector.x * rightVector.x + pointVector.y * rightVector.y) / (rightLength * rightLength) : 0
            let v: CGFloat = downLength > 0 ? 
                (pointVector.x * downVector.x + pointVector.y * downVector.y) / (downLength * downLength) : 0
            
            return (u: max(0, min(1, u)), v: max(0, min(1, v)))
        }
        
        // Solve the 2x2 system using Cramer's rule
        let u = (pointVector.x * downVector.y - pointVector.y * downVector.x) / det
        let v = (rightVector.x * pointVector.y - rightVector.y * pointVector.x) / det
        
        // Clamp to [0,1] range
        return (u: max(0, min(1, u)), v: max(0, min(1, v)))
    }
    
    private func finishEnvelopeWarp() {
        // CONTINUOUS EDITING: Update the shape coordinates but keep envelope active
        warpingStarted = false
        isWarping = false
        document.isHandleScalingActive = false
        draggingCornerIndex = nil
        
        // ENVELOPE DRAG FINISHED: Minimal logging for performance
        
        // REAL-TIME UPDATE: Apply the current warp to the shape immediately
        updateShapeWithCurrentWarp()
        
        // BOUNDS UPDATE: Now that warping is finished, update bounds properly
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            if document.layers[layerIndex].shapes[shapeIndex].isGroup {
                for i in 0..<document.layers[layerIndex].shapes[shapeIndex].groupedShapes.count {
                    document.layers[layerIndex].shapes[shapeIndex].groupedShapes[i].updateBounds()
                }
            }
        }
        
        print("   Current envelope: TL(\(String(format: "%.1f", warpedCorners[0].x)), \(String(format: "%.1f", warpedCorners[0].y))), TR(\(String(format: "%.1f", warpedCorners[1].x)), \(String(format: "%.1f", warpedCorners[1].y))), BR(\(String(format: "%.1f", warpedCorners[2].x)), \(String(format: "%.1f", warpedCorners[2].y))), BL(\(String(format: "%.1f", warpedCorners[3].x)), \(String(format: "%.1f", warpedCorners[3].y)))")
        
        // Keep preview for visual feedback but refresh it for next transformation
        calculateEnvelopeWarpPreview()
    }
    
    private func updateShapeWithCurrentWarp() {
        guard let layerIndex = document.selectedLayerIndex,
              let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) else { return }
        
        let currentShape = document.layers[layerIndex].shapes[shapeIndex]
        
        if currentShape.isWarpObject {
            // Update existing warp object with new warped coordinates
            var updatedWarpObject = currentShape
            
            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                // WARP OBJECT + GROUP: Warp each individual shape in the group
                var warpedGroupedShapes: [VectorShape] = []
                
                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)
                    
                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    // CRITICAL FIX: Don't update bounds during active warping to prevent axis recalculation
                    if !isWarping {
                        warpedGrouped.updateBounds()
                    }
                    warpedGroupedShapes.append(warpedGrouped)
                }
                
                updatedWarpObject.groupedShapes = warpedGroupedShapes
                Log.info("   🔄 Updated warp object with \(warpedGroupedShapes.count) warped grouped shapes", category: .general)
            } else if let finalWarpedPath = previewPath {
                // WARP OBJECT + SINGLE SHAPE: Update the main path
                updatedWarpObject.path = finalWarpedPath
                Log.info("   🔄 Updated warp object with single warped path", category: .general)
            }
            
            updatedWarpObject.warpEnvelope = warpedCorners
            // CRITICAL FIX: Don't update bounds during active warping to prevent axis recalculation
            if !isWarping {
                updatedWarpObject.updateBounds()
            }
            
            document.layers[layerIndex].shapes[shapeIndex] = updatedWarpObject
            Log.info("   ✅ Updated existing warp object coordinates in real-time", category: .general)
        } else {
            // First-time warp: create warp object
            var warpObject = currentShape
            warpObject.id = UUID() // New ID for the warp object
            warpObject.name = "Warped " + currentShape.name
            warpObject.isWarpObject = true
            warpObject.warpEnvelope = warpedCorners
            warpObject.originalEnvelope = originalCorners // CRITICAL: Store original envelope for continuous warping
            warpObject.transform = .identity
            
            if currentShape.isGroup && !currentShape.groupedShapes.isEmpty {
                // GROUP/FLATTENED OBJECT: Store original grouped shapes and create warped versions
                warpObject.originalPath = nil // Groups don't have a single original path
                
                // Warp each individual shape in the group
                var warpedGroupedShapes: [VectorShape] = []
                
                for groupedShape in currentShape.groupedShapes {
                    let warpedElements = warpPathElements(groupedShape.path.elements)
                    let warpedPath = VectorPath(elements: warpedElements, isClosed: groupedShape.path.isClosed)
                    
                    var warpedGrouped = groupedShape
                    warpedGrouped.path = warpedPath
                    // CRITICAL FIX: Don't update bounds during active warping to prevent axis recalculation
                    if !isWarping {
                        warpedGrouped.updateBounds()
                    }
                    warpedGroupedShapes.append(warpedGrouped)
                }
                
                warpObject.groupedShapes = warpedGroupedShapes
                Log.info("   ✅ Created warp object from group with \(warpedGroupedShapes.count) warped shapes", category: .general)
            } else if let finalWarpedPath = previewPath {
                // SINGLE SHAPE: Store original path and use warped path
                warpObject.originalPath = currentShape.path
                warpObject.path = finalWarpedPath
                Log.info("   ✅ Created warp object from single shape", category: .general)
            }
            
            // CRITICAL FIX: Don't update bounds during active warping to prevent axis recalculation
            if !isWarping {
                warpObject.updateBounds()
            }
            
            document.layers[layerIndex].shapes[shapeIndex] = warpObject
            document.selectedShapeIDs.remove(currentShape.id)
            document.selectedShapeIDs.insert(warpObject.id)
            
            Log.info("   🎯 First-time warp completed - created new warp object", category: .general)
        }
        
        // Log final warp state
        print("🏁 WARP COMPLETED: Final envelope TL(\(String(format: "%.1f", warpedCorners[0].x)), \(String(format: "%.1f", warpedCorners[0].y))), TR(\(String(format: "%.1f", warpedCorners[1].x)), \(String(format: "%.1f", warpedCorners[1].y))), BR(\(String(format: "%.1f", warpedCorners[2].x)), \(String(format: "%.1f", warpedCorners[2].y))), BL(\(String(format: "%.1f", warpedCorners[3].x)), \(String(format: "%.1f", warpedCorners[3].y)))")
        
        document.objectWillChange.send()
    }
    
    private func commitEnvelopeWarp() {
        Log.info("🏁 ENVELOPE WARP COMMIT: Finalizing envelope editing session", category: .general)
        
        // The shape has already been updated in real-time during editing
        // PRESERVE PREVIEW: Keep the preview when switching away so it shows correctly when returning
        // Don't clear previewPath - this maintains the warped shape preview for reactivation
        
        Log.info("📍 ENVELOPE SESSION COMPLETE: Warp object finalized", category: .general)
        Log.fileOperation("🔄 REACTIVATABLE: Select envelope tool again to continue editing", level: .info)
        Log.fileOperation("📋 UNWRAP VIA MENU: Use Object menu to unwrap back to original", level: .info)
        Log.info("   🎯 PREVIEW PRESERVED: Will show correct state when reactivating", category: .general)
    }
    
    // MARK: - Key Event Monitoring
    
    @State private var envelopeKeyEventMonitor: Any?
    
    private func setupEnvelopeKeyEventMonitoring() {
        // DISABLED: NSEvent monitoring to fix text input interference
        // envelopeKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
        //     DispatchQueue.main.async {
        //         self.isShiftPressed = event.modifierFlags.contains(.shift)
        //     }
        //     return event
        // }
    }
    
    private func teardownEnvelopeKeyEventMonitoring() {
        if let monitor = envelopeKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            envelopeKeyEventMonitor = nil
        }
    }
}

// MARK: - Persistent Warp Marquee (Always Visible for Warp Objects)
struct PersistentWarpMarquee: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isEnvelopeTool: Bool
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        ZStack {
            // BLUE WARP MARQUEE: Always visible for warp objects
            if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                // Draw the blue envelope marquee lines
                warpEnvelopeOutline()
                
                // Show corner handles only when envelope tool is active
                if isEnvelopeTool {
                    warpCornerHandles()
                } else {
                    // Show small blue dots when not using envelope tool
                    warpCornerDots()
                    
                    // ARROW TOOL: Show warp grid in darker blue
                    if document.currentTool == .selection {
                        warpGridOverlay()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func warpEnvelopeOutline() -> some View {
        // Draw the blue dashed envelope outline connecting the 4 corners
        if shape.warpEnvelope.count >= 4 {
            let corners = shape.warpEnvelope
            
            Path { path in
                // Connect all 4 corners to form the envelope quadrilateral
                path.move(to: corners[0])        // Top-left
                path.addLine(to: corners[1])     // Top-right
                path.addLine(to: corners[2])     // Bottom-right
                path.addLine(to: corners[3])     // Bottom-left
                path.closeSubpath()              // Back to top-left
            }
            .stroke(
                Color.blue,
                style: SwiftUI.StrokeStyle(
                    lineWidth: 2.0 / zoomLevel,
                    dash: [6.0 / zoomLevel, 4.0 / zoomLevel]
                )
            )
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(shape.transform)
        }
    }
    
    @ViewBuilder
    private func warpCornerHandles() -> some View {
        // Full envelope handles when using envelope tool
        if shape.warpEnvelope.count >= 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = shape.warpEnvelope[cornerIndex]
                
                Rectangle()
                    .fill(Color.green)  // GREEN = warpable
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(cornerPos)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
        }
    }
    
    @ViewBuilder
    private func warpCornerDots() -> some View {
        // Small blue dots when not using envelope tool
        if shape.warpEnvelope.count >= 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = shape.warpEnvelope[cornerIndex]
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4.0 / zoomLevel, height: 4.0 / zoomLevel)
                    .position(cornerPos)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
        }
    }
    
    @ViewBuilder
    private func warpGridOverlay() -> some View {
        // Show darker blue warp grid for arrow tool selection
        if shape.warpEnvelope.count >= 4 {
            let gridLines = 4
            let corners = shape.warpEnvelope
            
            // Horizontal grid lines
            ForEach(0..<4) { row in
                let t = CGFloat(row) / CGFloat(gridLines - 1)
                Path { path in
                    let startPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1], 
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: 0.0, v: t
                    )
                    let endPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3], 
                        bottomRight: corners[2],
                        u: 1.0, v: t
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .opacity(0.8) // Darker blue for completed warp
            }
            
            // Vertical grid lines
            ForEach(0..<4) { col in
                let u = CGFloat(col) / CGFloat(gridLines - 1)
                Path { path in
                    let startPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: u, v: 0.0
                    )
                    let endPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: u, v: 1.0
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .opacity(0.8) // Darker blue for completed warp
            }
        }
    }
    
    // MARK: - Bilinear Interpolation Helper
    
    private func bilinearInterpolation(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        // Standard bilinear interpolation formula
        let top = CGPoint(
            x: topLeft.x * (1 - u) + topRight.x * u,
            y: topLeft.y * (1 - u) + topRight.y * u
        )
        let bottom = CGPoint(
            x: bottomLeft.x * (1 - u) + bottomRight.x * u,
            y: bottomLeft.y * (1 - u) + bottomRight.y * u
        )
        
        return CGPoint(
            x: top.x * (1 - v) + bottom.x * v,
            y: top.y * (1 - v) + bottom.y * v
        )
    }
}

// MARK: - Text Rotation and Shear Handles
struct TextRotateHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    var body: some View {
        // SIMPLIFIED: Use text object position and bounds directly (no legacy calculation)
        let bounds = textObject.bounds
        let absoluteBounds = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: bounds.width,
            height: bounds.height
        )
        let center = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)
        
        Rectangle()
            .stroke(Color.orange, lineWidth: 1.0 / zoomLevel)
            .frame(width: absoluteBounds.width, height: absoluteBounds.height)
            .position(center)
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
    }
}

struct TextShearHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    var body: some View {
        // SIMPLIFIED: Use text object position and bounds directly (no legacy calculation)
        let bounds = textObject.bounds
        let absoluteBounds = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: bounds.width,
            height: bounds.height
        )
        let center = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)
        
        Rectangle()
            .stroke(Color.purple, lineWidth: 1.0 / zoomLevel)
            .frame(width: absoluteBounds.width, height: absoluteBounds.height)
            .position(center)
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
    }
}

// MARK: - Text Selection Views

// REMOVED: Legacy TextSelectionOutline view that was causing wrong blue boxes
// This view used old bounds calculations that didn't handle multi-line text properly
// ProfessionalTextCanvas now handles all text selection visualization correctly

// Scale handles for text objects with Scale tool
struct TextScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // SIMPLIFIED: Use text object position and bounds directly (no legacy calculation)
        let bounds = textObject.bounds
        let absoluteBounds = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: bounds.width,
            height: bounds.height
        )
        let center = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)
        
        ZStack {
            // Text bounding box outline (red for scale tool)
            Rectangle()
                .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                .frame(width: absoluteBounds.width, height: absoluteBounds.height)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)
            
            // 4 Corner scaling handles ONLY (simplified for now)
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: absoluteBounds, center: center)
                Rectangle()
                    .fill(Color.red)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(textObject.transform)
                                         // TODO: Add text scaling gesture handling
            }
        }
    }
    
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY) // Top-left
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY) // Top-right
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY) // Bottom-right
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY) // Bottom-left
        default: return center
        }
    }
}

// MARK: - Professional Text Transformation Helper Methods (old implementation, TODO: clean up)
    
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates for text selection handles
        let positions = [
            CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
            CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
            CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
            CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
        ]
        
        return positions[index]
    }
    
    private func edgePosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates for text edge handles
        let positions = [
            CGPoint(x: center.x, y: bounds.minY), // Top
            CGPoint(x: bounds.maxX, y: center.y), // Right
            CGPoint(x: center.x, y: bounds.maxY), // Bottom
            CGPoint(x: bounds.minX, y: center.y)  // Left
        ]
        
        return positions[index]
    }


// Extensions for SwiftUI compatibility
extension BlendMode {
    var swiftUIBlendMode: SwiftUI.BlendMode {
        switch self {
        case .normal: return .normal
        case .multiply: return .multiply
        case .screen: return .screen
        case .overlay: return .overlay
        case .softLight: return .softLight
        case .hardLight: return .hardLight
        case .colorDodge: return .colorDodge
        case .colorBurn: return .colorBurn
        case .darken: return .darken
        case .lighten: return .lighten
        case .difference: return .difference
        case .exclusion: return .exclusion
        case .hue: return .hue
        case .saturation: return .saturation
        case .color: return .color
        case .luminosity: return .luminosity
        }
    }
}

extension CGLineCap {
    var swiftUILineCap: SwiftUI.CGLineCap {
        switch self {
        case .butt: return .butt
        case .round: return .round
        case .square: return .square
        @unknown default: return .butt
        }
    }
}

extension CGLineJoin {
    var swiftUILineJoin: SwiftUI.CGLineJoin {
        switch self {
        case .miter: return .miter
        case .round: return .round
        case .bevel: return .bevel
        @unknown default: return .miter
        }
    }
}

// MARK: - NSViewRepresentable Gradient Renderer

struct GradientFillView: NSViewRepresentable {
    let gradient: VectorGradient
    let path: CGPath

    func makeNSView(context: Context) -> GradientNSView {
        return GradientNSView(gradient: gradient, path: path)
    }

    func updateNSView(_ nsView: GradientNSView, context: Context) {
        nsView.gradient = gradient
        nsView.path = path
        nsView.needsDisplay = true
    }
}

struct GradientStrokeView: NSViewRepresentable {
    let gradient: VectorGradient
    let path: CGPath
    let strokeStyle: StrokeStyle

    func makeNSView(context: Context) -> GradientStrokeNSView {
        return GradientStrokeNSView(gradient: gradient, path: path, strokeStyle: strokeStyle)
    }

    func updateNSView(_ nsView: GradientStrokeNSView, context: Context) {
        nsView.gradient = gradient
        nsView.path = path
        nsView.strokeStyle = strokeStyle
        nsView.needsDisplay = true
    }
}

class GradientNSView: NSView {
    var gradient: VectorGradient
    var path: CGPath

    init(gradient: VectorGradient, path: CGPath) {
        self.gradient = gradient
        self.path = path
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        
        // The path we receive is already pre-transformed into the document's coordinate space.
        // SwiftUI will handle scaling/offsetting this NSView. We just draw the path as-is.
        let pathBounds = path.boundingBoxOfPath

        // Create CGGradient with proper clear color handling
        let colors = gradient.stops.map { stop -> CGColor in
            if case .clear = stop.color {
                // For clear colors, use the clear color's cgColor directly (don't apply opacity)
                return stop.color.cgColor
            } else {
                // For non-clear colors, apply the stop opacity
                return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
            }
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }
        guard let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }
        
        // Add path for clipping
        context.addPath(path)
        context.clip()

        // Draw gradient
        switch gradient {
        case .linear(let linear):
            // FIXED: Use the same coordinate system as the preview and gradient edit tool
            // The origin point represents the center of the gradient, just like radial gradients
            let originX = linear.originPoint.x
            let originY = linear.originPoint.y
            
            // Apply scale factor to match the coordinate system
            let scale = CGFloat(linear.scaleX)
            let scaledOriginX = originX * scale
            let scaledOriginY = originY * scale
            
            // Calculate the center of the gradient in path coordinates
            let centerX = pathBounds.minX + pathBounds.width * scaledOriginX
            let centerY = pathBounds.minY + pathBounds.height * scaledOriginY
            
            // Calculate gradient direction based on startPoint and endPoint
            let gradientVector = CGPoint(x: linear.endPoint.x - linear.startPoint.x, y: linear.endPoint.y - linear.startPoint.y)
            let gradientLength = sqrt(gradientVector.x * gradientVector.x + gradientVector.y * gradientVector.y)
            let gradientAngle = atan2(gradientVector.y, gradientVector.x)
            
            // Apply scale to gradient length
            let scaledLength = gradientLength * CGFloat(scale) * max(pathBounds.width, pathBounds.height)
            
            // Calculate start and end points
            let startX = centerX - cos(gradientAngle) * scaledLength / 2
            let startY = centerY - sin(gradientAngle) * scaledLength / 2
            let endX = centerX + cos(gradientAngle) * scaledLength / 2
            let endY = centerY + sin(gradientAngle) * scaledLength / 2
            
            let startPoint = CGPoint(x: startX, y: startY)
            let endPoint = CGPoint(x: endX, y: endY)
            
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        case .radial(let radial):
            // FIXED: Radial gradient coordinate system - centerPoint is already in 0-1 range
            
            // FIXED: Origin point should NOT be scaled - it defines the center position
            let originX = radial.originPoint.x
            let originY = radial.originPoint.y
            
            // Calculate the center position in path coordinates (no scaling applied to position)
            let center = CGPoint(x: pathBounds.minX + pathBounds.width * originX,
                                 y: pathBounds.minY + pathBounds.height * originY)
            
            // Apply transforms for angle and aspect ratio support
            context.saveGState()
            
            // Translate to gradient center for transformation
            context.translateBy(x: center.x, y: center.y)
            
            // Apply rotation (convert degrees to radians)
            let angleRadians = CGFloat(radial.angle * .pi / 180.0)
            context.rotate(by: angleRadians)
            
            // Apply independent X/Y scaling (elliptical gradient) - this affects the shape, not the position
            let scaleX = CGFloat(radial.scaleX)
            let scaleY = CGFloat(radial.scaleY)
            context.scaleBy(x: scaleX, y: scaleY)
            
            // FIXED: Focal point should NOT be scaled - it's already in the correct coordinate space
            let focalPoint: CGPoint
            if let focal = radial.focalPoint {
                // Focal point is already in the correct coordinate space relative to center
                focalPoint = CGPoint(x: focal.x, y: focal.y)
            } else {
                // No focal point specified, use center
                focalPoint = CGPoint.zero
            }
            
            // Calculate radius - use the original calculation that was working before
            let radius = max(pathBounds.width, pathBounds.height) * CGFloat(radial.radius)
            
            // Draw gradient with focal point in original coordinate space
            context.drawRadialGradient(cgGradient, startCenter: focalPoint, startRadius: 0, endCenter: CGPoint.zero, endRadius: radius, options: [.drawsAfterEndLocation])
            
            context.restoreGState()
        }
        
        context.restoreGState()
    }
}

class GradientStrokeNSView: NSView {
    var gradient: VectorGradient
    var path: CGPath
    var strokeStyle: StrokeStyle

    init(gradient: VectorGradient, path: CGPath, strokeStyle: StrokeStyle) {
        self.gradient = gradient
        self.path = path
        self.strokeStyle = strokeStyle
        super.init(frame: .zero)
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        context.saveGState()
        
        // The path we receive is already pre-transformed into the document's coordinate space.
        // SwiftUI will handle scaling/offsetting this NSView. We just draw the path as-is.
        _ = path.boundingBoxOfPath

        // Create CGGradient with proper clear color handling
        let colors = gradient.stops.map { stop -> CGColor in
            if case .clear = stop.color {
                // For clear colors, use the clear color's cgColor directly (don't apply opacity)
                return stop.color.cgColor
            } else {
                // For non-clear colors, apply the stop opacity
                return stop.color.color.opacity(stop.opacity).cgColor ?? stop.color.cgColor
            }
        }
        let locations: [CGFloat] = gradient.stops.map { CGFloat($0.position) }
        guard let cgGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations) else {
            context.restoreGState()
            return
        }
        
        // Set stroke properties
        context.setLineWidth(strokeStyle.width)
        context.setLineCap(strokeStyle.lineCap)
        context.setLineJoin(strokeStyle.lineJoin)
        context.setMiterLimit(strokeStyle.miterLimit)
        
        // Use CoreGraphics native gradient stroke support
        // Set the gradient as the stroke color
        context.setStrokeColorSpace(CGColorSpaceCreateDeviceRGB())
        
        // Draw gradient stroke using native CoreGraphics support
        switch gradient {
        case .linear(let linear):
            // Use CoreGraphics native gradient stroke
            context.addPath(path)
            context.replacePathWithStrokedPath()
            
            // Get the actual stroke outline bounds for proper gradient positioning
            let strokeBounds = context.boundingBoxOfPath
            
            // Calculate gradient coordinates based on the actual stroke outline bounds
            let startPoint = CGPoint(x: strokeBounds.minX, y: strokeBounds.minY + strokeBounds.height * CGFloat(linear.originPoint.y))
            let endPoint = CGPoint(x: strokeBounds.maxX, y: strokeBounds.minY + strokeBounds.height * CGFloat(linear.originPoint.y))
            
            context.clip()
            context.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [])
            
        case .radial(let radial):
            // Use CoreGraphics native gradient stroke
            context.addPath(path)
            context.replacePathWithStrokedPath()
            
            // Get the actual stroke outline bounds for proper gradient positioning
            let strokeBounds = context.boundingBoxOfPath
            
            // Calculate gradient coordinates based on the actual stroke outline bounds
            let center = CGPoint(x: strokeBounds.minX + strokeBounds.width * CGFloat(radial.originPoint.x),
                                y: strokeBounds.minY + strokeBounds.height * CGFloat(radial.originPoint.y))
            let radius = max(strokeBounds.width, strokeBounds.height) * CGFloat(radial.radius)
            
            context.clip()
            context.drawRadialGradient(cgGradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
        }
        
        context.restoreGState()
    }
}

    // MARK: - Oriented Bounding Box Calculation
    
    /// Calculate TRUE AXIS DETECTION for ANY shape on ANY axis/plane
    private func calculateOrientedBoundingBox(for shape: VectorShape) -> [CGPoint] {
        print("📐 TRUE AXIS DETECTION for \(shape.geometricType?.rawValue ?? "unknown")")
        
        // NOTE: Warp objects are handled in initializeEnvelopeCorners() 
        // This function only handles fresh objects for TRUE AXIS DETECTION
        
        // Special handling for groups and compound shapes
        if shape.isGroup || shape.isGroupContainer {
            Log.info("   👥 GROUP/COMPOUND SHAPE: Using composite bounds", category: .general)
            let bounds = shape.isGroup ? shape.bounds : shape.groupBounds
            
            // For groups, use the overall bounds (already computed across all grouped shapes)
            let objectSpaceCorners = [
                CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
                CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
                CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
                CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
            ]
            
            // Apply group transform
            let worldSpaceCorners = objectSpaceCorners.map { corner in
                corner.applying(shape.transform)
            }
            
            print("   📍 Group Bounds: (\(String(format: "%.1f", bounds.origin.x)), \(String(format: "%.1f", bounds.origin.y))) size (\(String(format: "%.1f", bounds.width)) × \(String(format: "%.1f", bounds.height)))")
            print("   📐 World Corners: [\(worldSpaceCorners.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]")
            
            return worldSpaceCorners
        }
        
        // TRUE AXIS DETECTION: Extract actual path corners for rotated objects
        let pathElements = shape.path.elements
        var actualCorners: [CGPoint] = []
        
        Log.info("   🔍 EXTRACTING ACTUAL PATH CORNERS from \(pathElements.count) elements", category: .general)
        
        // Try to extract the actual corner points from the path
        for element in pathElements {
            switch element {
            case .move(let to):
                actualCorners.append(to.cgPoint)
                print("     ➤ Move to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))")
            case .line(let to):
                actualCorners.append(to.cgPoint)
                print("     ➤ Line to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))")
            case .curve(let to, _, _):
                actualCorners.append(to.cgPoint)
                print("     ➤ Curve to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))")
            case .quadCurve(let to, _):
                actualCorners.append(to.cgPoint)
                print("     ➤ Quad curve to: (\(String(format: "%.1f", to.cgPoint.x)), \(String(format: "%.1f", to.cgPoint.y)))")
            case .close:
                Log.info("     ➤ Close path", category: .general)
                break
            }
            
            // For rectangles and simple shapes, we expect 4 corners
            if actualCorners.count >= 4 && (shape.geometricType == .rectangle || pathElements.count <= 6) {
                break
            }
        }
        
        // TRUE AXIS DETECTION: Use actual path corners if we found them
        if actualCorners.count >= 4 && (shape.geometricType == .rectangle || shape.geometricType == .star || pathElements.count <= 8) {
            let detectedCorners = Array(actualCorners.prefix(4))
            Log.info("   ✅ TRUE AXIS DETECTION: Using ACTUAL PATH CORNERS", category: .general)
            print("   📐 Detected Corners: [\(detectedCorners.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]")
            return detectedCorners
        }
        
        // FALLBACK: Use transformed bounds for complex shapes
        Log.info("   ⚠️ FALLBACK: Using transformed bounds for complex shape", category: .general)
        let objectSpaceBounds = shape.path.cgPath.boundingBoxOfPath
        
        // Create the 4 corners of the bounding box in object space
        let objectSpaceCorners = [
            CGPoint(x: objectSpaceBounds.minX, y: objectSpaceBounds.minY), // Top-left
            CGPoint(x: objectSpaceBounds.maxX, y: objectSpaceBounds.minY), // Top-right
            CGPoint(x: objectSpaceBounds.maxX, y: objectSpaceBounds.maxY), // Bottom-right
            CGPoint(x: objectSpaceBounds.minX, y: objectSpaceBounds.maxY)  // Bottom-left
        ]
        
        // Apply the shape's transform to get world space coordinates
        let worldSpaceCorners = objectSpaceCorners.map { corner in
            corner.applying(shape.transform)
        }
        
        print("   📍 Object Bounds: (\(String(format: "%.1f", objectSpaceBounds.origin.x)), \(String(format: "%.1f", objectSpaceBounds.origin.y))) size (\(String(format: "%.1f", objectSpaceBounds.width)) × \(String(format: "%.1f", objectSpaceBounds.height)))")
        print("   🔄 Transform: [\(String(format: "%.3f", shape.transform.a)), \(String(format: "%.3f", shape.transform.b)), \(String(format: "%.3f", shape.transform.c)), \(String(format: "%.3f", shape.transform.d)), \(String(format: "%.1f", shape.transform.tx)), \(String(format: "%.1f", shape.transform.ty))]")
        print("   📐 World Corners: [\(worldSpaceCorners.map { "(\(String(format: "%.1f", $0.x)),\(String(format: "%.1f", $0.y)))" }.joined(separator: ", "))]")
        return worldSpaceCorners
    }

// MARK: - View Extensions

// MARK: - SVG Shape Renderer moved to LayerView+SVGRenderer.swift



