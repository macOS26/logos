//
//  LayerView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

struct LayerView: View {
    let layer: VectorLayer
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedShapeIDs: Set<UUID>
    let viewMode: ViewMode
    
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
                ShapeView(
                    shape: layer.shapes[shapeIndex],
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    isSelected: selectedShapeIDs.contains(layer.shapes[shapeIndex].id),
                    viewMode: viewMode,
                    isCanvasLayer: isCanvasLayer,  // Pass Canvas layer info
                    isPasteboardLayer: isPasteboardLayer  // Pass Pasteboard layer info
                )
            }
        }
        .opacity(layer.opacity)
    }
}

struct ShapeView: View {
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isSelected: Bool
    let viewMode: ViewMode
    let isCanvasLayer: Bool  // NEW: Canvas layer protection
    let isPasteboardLayer: Bool  // NEW: Pasteboard layer recognition
    
    // CANVAS AND PASTEBOARD LAYER PROTECTION: Canvas and Pasteboard objects never go to keyline view
    private var effectiveViewMode: ViewMode {
        return (isCanvasLayer || isPasteboardLayer) ? .color : viewMode
    }
    
    var body: some View {
        ZStack {
            // GROUPED SHAPES RENDERING: If this is a group container, render all grouped shapes
            if shape.isGroupContainer {
                // CRITICAL FIX: Render grouped shapes WITHOUT zoom/offset (prevent double application)
                ZStack {
                    ForEach(shape.groupedShapes, id: \.id) { groupedShape in
                        // Render shapes directly - NO coordinate system nesting
                        ZStack {
                            // Fill - only show in color view mode (or always for Canvas)
                            if effectiveViewMode == .color,
                               let fillStyle = groupedShape.fillStyle, 
                               fillStyle.color != .clear {
                                Path { path in
                                    addPathElements(groupedShape.path.elements, to: &path)
                                }
                                .fill(fillStyle.color.color, style: SwiftUI.FillStyle(eoFill: groupedShape.path.fillRule == .evenOdd))
                                .opacity(fillStyle.opacity)
                                .blendMode(fillStyle.blendMode.swiftUIBlendMode)
                            }
                            
                            // Stroke rendering - improved for keyline mode and placement  
                            if effectiveViewMode == .keyline {
                                Path { path in
                                    addPathElements(groupedShape.path.elements, to: &path)
                                }
                                .stroke(Color.black, lineWidth: 1.0)
                            } else if let strokeStyle = groupedShape.strokeStyle, strokeStyle.color != .clear {
                                renderStrokeWithPlacement(shape: groupedShape, strokeStyle: strokeStyle, viewMode: effectiveViewMode)
                                    .opacity(strokeStyle.placement == .outside ? 1.0 : strokeStyle.opacity)
                                    .blendMode(strokeStyle.blendMode.swiftUIBlendMode)
                            }
                        }
                        // CRITICAL: Only apply individual shape transform - NO zoom/offset here
                        .transformEffect(groupedShape.transform)
                        .opacity(groupedShape.opacity)
                    }
                }
                // CRITICAL FIX: Let ShapeView handle zoom/offset - only apply group transform here
                .transformEffect(shape.transform) // PREVIEW SCALING: Use preview transform during scaling
                .onAppear {
                    print("🏗️ GROUP FIXED: Rendering group container \(shape.name)")
                    print("   📊 Group bounds: \(shape.bounds)")
                    print("   🔄 Group transform: \(shape.transform)")
                    print("   🔍 Zoom level: \(zoomLevel)")
                    print("   📍 Canvas offset: \(canvasOffset)")
                    print("   👥 Contains \(shape.groupedShapes.count) grouped shapes")
                    print("   ✅ COORDINATE FIX: Zoom/offset applied ONCE at group level")
                    
                    for (index, groupedShape) in shape.groupedShapes.enumerated() {
                        print("   🔥 Grouped shape \(index): \(groupedShape.name)")
                        print("      📊 Bounds: \(groupedShape.bounds)")
                        print("      🔄 Transform: \(groupedShape.transform)")
                        print("      ✅ NO double zoom/offset application")
                    }
                }
            } else {
                // REGULAR SHAPE RENDERING: Render individual shape path
                
                // Fill - only show in color view mode (or always for Canvas)
                if effectiveViewMode == .color,
                   let fillStyle = shape.fillStyle, 
                   fillStyle.color != .clear {
                    Path { path in
                        addPathElements(shape.path.elements, to: &path)
                    }
                    .fill(fillStyle.color.color, style: SwiftUI.FillStyle(eoFill: shape.path.fillRule == .evenOdd))
                    .opacity(fillStyle.opacity)
                    .blendMode(fillStyle.blendMode.swiftUIBlendMode)
                }
                
                // Stroke rendering - improved for keyline mode and placement
                if effectiveViewMode == .keyline {
                    // In keyline mode, always show a stroke regardless of original stroke style
                    // (Canvas and Pasteboard objects will never reach this branch)
                    Path { path in
                        addPathElements(shape.path.elements, to: &path)
                    }
                    .stroke(Color.black, lineWidth: 1.0)
                } else if let strokeStyle = shape.strokeStyle, strokeStyle.color != .clear {
                    // In color mode, show the actual stroke with proper placement and transparency
                    renderStrokeWithPlacement(shape: shape, strokeStyle: strokeStyle, viewMode: effectiveViewMode)
                        // CRITICAL FIX: Don't apply opacity here for outside strokes - handled internally
                        .opacity(strokeStyle.placement == .outside ? 1.0 : strokeStyle.opacity)
                        .blendMode(strokeStyle.blendMode.swiftUIBlendMode) // PROFESSIONAL STROKE BLEND MODES
                }
            }
            
            // GROUP SELECTION OUTLINE: Show selection outline for the entire group bounds
            if isSelected {
                if shape.isGroupContainer {
                    // For groups, show selection outline around group bounds
                    let groupBounds = shape.groupBounds
                    Rectangle()
                        .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                        .frame(width: groupBounds.width, height: groupBounds.height)
                        .position(x: groupBounds.midX, y: groupBounds.midY)
                        .opacity(0.7)
                } else {
                    // For individual shapes, show selection outline around shape path
                    Path { path in
                        addPathElements(shape.path.elements, to: &path)
                    }
                    .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                    .opacity(0.7)
                }
            }
        }
        // CRITICAL FIX: Apply transforms in CORRECT order - zoom and offset first, then shape transform
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        .transformEffect(shape.transform)
        .opacity(shape.opacity)
    }
    
    @ViewBuilder
    private func renderStrokeWithPlacement(shape: VectorShape, strokeStyle: StrokeStyle, viewMode: ViewMode) -> some View {
        let swiftUIStrokeStyle = SwiftUI.StrokeStyle(
            lineWidth: strokeStyle.width,
            lineCap: strokeStyle.lineCap.swiftUILineCap,
            lineJoin: strokeStyle.lineJoin.swiftUILineJoin,
            miterLimit: strokeStyle.miterLimit,
            dash: strokeStyle.dashPattern.map { CGFloat($0) }
        )
        
        switch strokeStyle.placement {
        case .center:
            // Default behavior - stroke is centered on the path
            Path { path in
                addPathElements(shape.path.elements, to: &path)
            }
            .stroke(strokeStyle.color.color, style: swiftUIStrokeStyle)
            
        case .inside:
            // PROFESSIONAL INSIDE STROKE (Adobe Illustrator Standard)
            // Draw a normal stroke but mask it to only show inside the shape
            Path { path in
                addPathElements(shape.path.elements, to: &path)
            }
            .stroke(
                strokeStyle.color.color,
                style: SwiftUI.StrokeStyle(
                    lineWidth: strokeStyle.width * 2, // Double width since we're masking to inside
                    lineCap: swiftUIStrokeStyle.lineCap,
                    lineJoin: swiftUIStrokeStyle.lineJoin,
                    miterLimit: swiftUIStrokeStyle.miterLimit,
                    dash: swiftUIStrokeStyle.dash.map { $0 * 2 } // Scale dash pattern accordingly
                )
            )
            .mask(
                // Mask to shape interior only
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .fill(Color.black) // Black reveals, transparent hides
            )
            
        case .outside:
            // OUTSIDE STROKE - CRITICAL FIX: Handle opacity internally to prevent bleed-through
            ZStack {
                // 1. Draw stroke at double width with correct opacity (extends both inside and outside)
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .stroke(
                    strokeStyle.color.color.opacity(strokeStyle.opacity), // Apply opacity here internally
                    style: SwiftUI.StrokeStyle(
                        lineWidth: strokeStyle.width * 2, // Double width
                        lineCap: swiftUIStrokeStyle.lineCap,
                        lineJoin: swiftUIStrokeStyle.lineJoin,
                        miterLimit: swiftUIStrokeStyle.miterLimit,
                        dash: swiftUIStrokeStyle.dash.map { $0 * 2 } // Scale dash pattern
                    )
                )
                
                // 2. Cover the inside stroke completely with opaque background
                // This ensures NO stroke color bleeds through, regardless of fill opacity
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .fill(Color.white.opacity(1.0)) // Ensure completely opaque white background
                
                // 3. Draw the actual fill at correct opacity on top
                if let fillStyle = shape.fillStyle, fillStyle.color != .clear {
                    Path { path in
                        addPathElements(shape.path.elements, to: &path)
                    }
                    .fill(fillStyle.color.color.opacity(fillStyle.opacity))
                }
            }
        }
    }
    
    private func addPathElements(_ elements: [PathElement], to path: inout Path) {
        for element in elements {
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
}

struct GridView: View {
    let document: VectorDocument
    let geometry: GeometryProxy
    
    var body: some View {
        let gridSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit
        let canvasSize = document.settings.sizeInPoints
        
        // Prevent infinite loop when grid spacing is 0
        if gridSpacing > 0 {
        Path { path in
            // UNIFIED COORDINATE SYSTEM: Draw grid in canvas space then transform
            let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1
            
            // Vertical lines
            for i in 0...gridSteps {
                let x = CGFloat(i) * gridSpacing
                if x <= canvasSize.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                }
            }
            
            // Horizontal lines
            for i in 0...gridSteps {
                let y = CGFloat(i) * gridSpacing
                if y <= canvasSize.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
            }
        }
        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5 / document.zoomLevel)
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        } else {
            // Return empty view when grid spacing is 0
            EmptyView()
        }
    }
}

struct SelectionHandlesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Show different handles based on current tool
            ForEach(document.layers.indices, id: \.self) { layerIndex in
                let layer = document.layers[layerIndex]
                ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                    let shape = layer.shapes[shapeIndex]
                    if document.selectedShapeIDs.contains(shape.id) {
                        // Show different handles based on tool
                        if document.currentTool == .selection {
                            // Arrow tool: Only selection outline (no transform handles)
                            SelectionOutline(
                                document: document,
                                shape: shape,
                                zoomLevel: document.zoomLevel,
                                canvasOffset: document.canvasOffset
                            )
                        } else if document.currentTool == .scale {
                            // Scale tool: Only corner scaling handles
                            ScaleHandles(
                                document: document,
                                shape: shape,
                                zoomLevel: document.zoomLevel,
                                canvasOffset: document.canvasOffset
                            )
                        } else if document.currentTool == .rotate {
                            // Rotate tool: Rotation handles with anchor point
                            RotateHandles(
                                document: document,
                                shape: shape,
                                zoomLevel: document.zoomLevel,
                                canvasOffset: document.canvasOffset
                            )
                        } else if document.currentTool == .shear {
                            // Shear tool: Shear handles with anchor point
                            ShearHandles(
                                document: document,
                                shape: shape,
                                zoomLevel: document.zoomLevel,
                                canvasOffset: document.canvasOffset
                            )
                        }
                    }
                }
            }
            
            // Show handles for selected text objects (Adobe Illustrator Standards)
            ForEach(document.textObjects.indices, id: \.self) { textIndex in
                let textObject = document.textObjects[textIndex]
                if document.selectedTextIDs.contains(textObject.id) {
                    if document.currentTool == .selection {
                        // Arrow tool: Only text outline (no transform handles)
                        TextSelectionOutline(
                            document: document,
                            textObject: textObject,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    } else if document.currentTool == .scale {
                        // Scale tool: Text scaling handles
                        TextScaleHandles(
                            document: document,
                            textObject: textObject,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    } else if document.currentTool == .rotate {
                        // Rotate tool: Text rotation handles
                        TextRotateHandles(
                            document: document,
                            textObject: textObject,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    } else if document.currentTool == .shear {
                        // Shear tool: Text shear handles
                        TextShearHandles(
                            document: document,
                            textObject: textObject,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Simple Selection Outline (Arrow Tool)
struct SelectionOutline: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // SELECTION TOOL: Show bounding box outline with blue corner handles and center point
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        ZStack {
            // Bounding box outline
            Rectangle()
                .stroke(Color.blue, lineWidth: 1.0 / zoomLevel) // Scale-independent line width
                .frame(width: bounds.width, height: bounds.height)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
            
            // CENTER POINT: Blue square same size as corners
            Rectangle()
                .fill(Color.blue)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
            
            // 4 Corner handles - ALL BLUE
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: bounds, center: center)
                
                Rectangle()
                    .fill(Color.blue)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
        }
    }
    
    /// Calculate corner positions for handles
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

// MARK: - Scale Tool Handles
struct ScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    // Professional scaling state management - NEW CLEAN IMPLEMENTATION
    @State private var isScaling = false
    @State private var scalingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var scalingAnchorPoint: CGPoint = .zero
    @State private var finalMarqueeBounds: CGRect = .zero  // MARQUEE FIX: Track final destination bounds
    @State private var isShiftPressed = false  // PROPORTIONAL SCALING: Track shift key state
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // SCALE TOOL: Show bounding box outline with 4 corner scaling handles only
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        ZStack {
            // Bounding box outline
            Rectangle()
                .stroke(Color.red, lineWidth: 1.0 / zoomLevel) // Red outline for scale tool
                .frame(width: bounds.width, height: bounds.height)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
            
            // CENTER POINT: Square same size as corners - Green if live, red if pinned anchor
            let isCenterPinned = document.scalingAnchor == .center
            Rectangle()
                .fill(isCenterPinned ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    // Allow clicking center to set center anchor
                    if !isScaling {
                        document.scalingAnchor = .center
                        print("🎯 ANCHOR CHANGED: Center scaling selected")
                    }
                }
            
            // MARQUEE PREVIEW: Show EXACT final destination (PINNED CORRECTLY!)
            if isScaling && !finalMarqueeBounds.isEmpty {
                let marqueeCenter = CGPoint(x: finalMarqueeBounds.midX, y: finalMarqueeBounds.midY)
                
                // Marquee outline
                Rectangle()
                    .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                    .frame(width: finalMarqueeBounds.width, height: finalMarqueeBounds.height)
                    .position(marqueeCenter)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    // NO transformEffect! Show exact final position
                    .opacity(0.8) // Semi-transparent for clarity
                
                // MARQUEE CENTER POINT: Square same size as corners - Green if live, red if pinned
                let isCenterPinned = document.scalingAnchor == .center
                Rectangle()
                    .fill(isCenterPinned ? Color.red : Color.green)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(marqueeCenter)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .onTapGesture {
                        // Allow clicking center to set center anchor
                        if !isScaling {
                            document.scalingAnchor = .center
                            print("🎯 ANCHOR CHANGED: Center scaling selected")
                        }
                    }
            }
            
            // 4 Corner scaling handles - GREEN for live, RED for pinned anchor
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: bounds, center: center)
                let isPinnedCorner = isPinnedAnchorCorner(cornerIndex: i)
                let handleColor = isPinnedCorner ? Color.red : Color.green
                
                Rectangle()
                    .fill(handleColor)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
                    .onTapGesture {
                        // Allow clicking corner to set anchor point
                        if !isScaling {
                            let newAnchor = getAnchorForCorner(index: i)
                            document.scalingAnchor = newAnchor
                            print("🎯 ANCHOR CHANGED: \(newAnchor.displayName) selected via corner \(i)")
                        }
                    }
                    .highPriorityGesture(
                        // Don't allow scaling from pinned corners
                        isPinnedCorner ? nil : DragGesture()
                            .onChanged { value in
                                handleCornerScaling(index: i, dragValue: value, bounds: bounds, center: center)
                            }
                            .onEnded { _ in
                                finishScaling()
                            }
                    )
            }
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            setupKeyEventMonitoring()
        }
        .onDisappear {
            teardownKeyEventMonitoring()
        }
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
        
        print("🏁 SCALING FINISH: Applying final transform to coordinates")
        print("   📊 Preview transform: [\(String(format: "%.3f", previewTransform.a)), \(String(format: "%.3f", previewTransform.b)), \(String(format: "%.3f", previewTransform.c)), \(String(format: "%.3f", previewTransform.d)), \(String(format: "%.1f", previewTransform.tx)), \(String(format: "%.1f", previewTransform.ty))]")
        print("   🎯 FINAL MARQUEE: Bounds (\(String(format: "%.1f", finalMarqueeBounds.minX)), \(String(format: "%.1f", finalMarqueeBounds.minY))) → (\(String(format: "%.1f", finalMarqueeBounds.maxX)), \(String(format: "%.1f", finalMarqueeBounds.maxY)))")
        
        // PROFESSIONAL SCALING FIX: Apply the final preview transform to coordinates
        // This ensures object origin stays with object after scaling (Adobe Illustrator behavior)
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
            
            print("✅ SCALING FINISHED: Applied final transform to coordinates and reset transform to identity")
        }
    }
    
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
    /// This ensures object origin moves with the object (Adobe Illustrator behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        print("🔧 Applying scaling transform to shape coordinates: \(shape.name)")
        
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
        
        print("✅ Shape coordinates updated after scaling - object origin stays with object")
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
        print("   🎯 MARQUEE PREVIEW:")
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
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.isShiftPressed = event.modifierFlags.contains(.shift)
            }
            return event
        }
    }
    
    private func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
}

// MARK: - Rotate Tool Handles  
struct RotateHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    // Professional rotation state management
    @State private var isRotating = false
    @State private var rotationStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var rotationAnchorPoint: CGPoint = .zero
    @State private var startAngle: CGFloat = 0.0
    @State private var isShiftPressed = false  // For 15-degree increment snapping
    @State private var finalMarqueeBounds: CGRect = .zero  // MARQUEE FIX: Track final destination bounds like scale tool
    
    // POINT-BASED SELECTION SYSTEM: Select actual path points + center for rotation anchor
    @State private var selectedAnchorPointIndex: Int? = nil // Which point is selected as anchor (nil = center)
    @State private var pathPoints: [VectorPoint] = []  // Extracted path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Always include center
    @State private var pointsRefreshTrigger: Int = 0 // Force view refresh after transformation
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // ROTATE TOOL: Show actual path points + center point for precise anchor selection
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
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
                        print("🎯 ANCHOR SELECTED: Center point")
                    }
                }
                .highPriorityGesture(
                    DragGesture()
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
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        centerPoint = VectorPoint(CGPoint(x: bounds.midX, y: bounds.midY))
        
        print("🎯 EXTRACTED \(pathPoints.count) path points + center for rotation anchor selection")
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
                    DragGesture()
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
        print("   🔄 View refresh trigger: \(pointsRefreshTrigger)")
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
    /// This ensures object origin moves with the object (Adobe Illustrator behavior)
    private func applyRotationTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        print("🔧 Applying rotation transform to shape coordinates: \(shape.name)")
        
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
        
        print("✅ Shape coordinates updated after rotation - object origin stays with object")
    }
    
    // MARK: - Rotation Key Event Monitoring
    @State private var rotationKeyEventMonitor: Any?
    
    private func setupRotationKeyEventMonitoring() {
        rotationKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.isShiftPressed = event.modifierFlags.contains(.shift)
            }
            return event
        }
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
        print("   🔄 ROTATION PREVIEW:")
        print("      Anchor point: (\(String(format: "%.1f", anchor.x)), \(String(format: "%.1f", anchor.y))) - \(document.rotationAnchor.displayName)")
        print("      Rotation angle: \(String(format: "%.1f", angle * 180 / .pi))°")
        
        print("   📊 Rotation preview updated: angle=\(String(format: "%.1f", angle * 180 / .pi))° - showing ROTATED SHAPE outline")
        
        // Force UI update for preview rendering (without applying to shape)
        document.objectWillChange.send()
    }
    
    private func finishRotation() {
        rotationStarted = false
        isRotating = false
        document.isHandleScalingActive = false
        
        print("🏁 ROTATION FINISH: Applying final transform to coordinates")
        print("   📊 Preview transform: [\(String(format: "%.3f", previewTransform.a)), \(String(format: "%.3f", previewTransform.b)), \(String(format: "%.3f", previewTransform.c)), \(String(format: "%.3f", previewTransform.d)), \(String(format: "%.1f", previewTransform.tx)), \(String(format: "%.1f", previewTransform.ty))]")
        
        // CRITICAL FIX: Apply rotation to actual coordinates, not just transform
        // This ensures object origin stays with object after rotation (Adobe Illustrator behavior)
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            
            let oldBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   📐 Old bounds: (\(String(format: "%.1f", oldBounds.minX)), \(String(format: "%.1f", oldBounds.minY))) → (\(String(format: "%.1f", oldBounds.maxX)), \(String(format: "%.1f", oldBounds.maxY)))")
            
            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            document.layers[layerIndex].shapes[shapeIndex].transform = initialTransform
            
            // Apply the final transform to coordinates and reset transform to identity
            applyRotationTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            let newBounds = document.layers[layerIndex].shapes[shapeIndex].bounds
            print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
            
            // Reset preview transform
            previewTransform = .identity
            
            print("✅ ROTATION FINISHED: Applied final transform to coordinates and reset transform to identity")
            
            // CRITICAL FIX: Force refresh of point selection system (same as switching tools)
            // This updates the points to match the rotated object positions
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updatePathPointsAfterRotation()
            }
        }
        
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
    /// This ensures object origin moves with the object (Adobe Illustrator behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        print("🔧 Applying rotation transform to shape coordinates: \(shape.name)")
        
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
        
        print("✅ Shape coordinates updated after rotation - object origin stays with object")
    }
    
    // Shift Key Monitoring
    @State private var keyEventMonitor: Any?
    
    private func setupKeyEventMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.isShiftPressed = event.modifierFlags.contains(.shift)
            }
            return event
        }
    }
    
    private func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
}

// MARK: - Shear Tool Handles
struct ShearHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    // Professional shear state management
    @State private var isShearing = false
    @State private var shearStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var shearAnchorPoint: CGPoint = .zero
    @State private var isShiftPressed = false  // For constrained shearing
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // SHEAR TOOL: Show bounding box with shear handles
        let bounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        ZStack {
            // Bounding box outline
            Rectangle()
                .stroke(Color.purple, lineWidth: 1.0 / zoomLevel) // Purple outline for shear tool
                .frame(width: bounds.width, height: bounds.height)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
            
            // MARQUEE PREVIEW: Show ACTUAL SHEARED SHAPE OUTLINE
            if isShearing && !previewTransform.isIdentity {
                // Show the actual sheared shape path, not just bounds
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
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(previewTransform) // FIXED: Use exact same transform order as actual shapes
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
            
            // CENTER POINT: Green if live, red if pinned anchor
            let isCenterPinned = document.shearAnchor == .center
            Rectangle()
                .fill(isCenterPinned ? Color.red : Color.green)
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isShearing {
                        document.shearAnchor = .center
                        print("🎯 ANCHOR CHANGED: Center shear selected")
                    }
                }
            
            // 4 Corner handles with color coding
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: bounds, center: center)
                let isPinnedCorner = isPinnedAnchorCorner(cornerIndex: i)
                let handleColor = isPinnedCorner ? Color.red : Color.green
                
                Rectangle()
                    .fill(handleColor)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
                    .highPriorityGesture(
                        isPinnedCorner ? nil : DragGesture()
                            .onChanged { value in
                                handleCornerShear(index: i, dragValue: value, bounds: bounds, center: center)
                            }
                            .onEnded { _ in
                                finishShear()
                            }
                    )
                    .onTapGesture {
                        if !isShearing {
                            document.shearAnchor = getAnchorForCorner(index: i)
                            print("🎯 ANCHOR CHANGED: \(getAnchorForCorner(index: i).displayName) shear selected")
                        }
                    }
            }
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
            setupKeyEventMonitoring()
        }
        .onDisappear {
            teardownKeyEventMonitoring()
        }
    }
    
    private func handleCornerShear(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !shearStarted {
            startShear(cornerIndex: index, bounds: bounds, dragValue: dragValue)
        }
        
        // CRITICAL FIX: Convert screen coordinates to canvas coordinates (like DrawingCanvas precision fixes)
        // The drag coordinates are in screen space but we need shape-local coordinates for accurate shear
        let screenDelta = CGPoint(
            x: dragValue.location.x - startLocation.x,
            y: dragValue.location.y - startLocation.y
        )
        
        // Convert screen delta to canvas delta (accounting for zoom - same precision as DrawingCanvas)
        let preciseZoom = Double(zoomLevel)
        let canvasDelta = CGPoint(
            x: screenDelta.x / preciseZoom,
            y: screenDelta.y / preciseZoom
        )
        
        // Calculate shear factors based on canvas movement (not screen movement)
        let shearFactorX = bounds.height > 0 ? canvasDelta.x / bounds.height : 0
        let shearFactorY = bounds.width > 0 ? canvasDelta.y / bounds.width : 0
        
        // Apply shift key constraint for horizontal/vertical only shearing
        var finalShearX = shearFactorX
        var finalShearY = shearFactorY
        
        if isShiftPressed {
            // Constrain to dominant direction
            if abs(shearFactorX) > abs(shearFactorY) {
                finalShearY = 0
            } else {
                finalShearX = 0
            }
        }
        
        print("🔄 SHEARING: X=\(String(format: "%.3f", finalShearX)), Y=\(String(format: "%.3f", finalShearY)), shift=\(isShiftPressed)")
        
        calculatePreviewShear(shearX: finalShearX, shearY: finalShearY, anchor: shearAnchorPoint)
    }
    
    private func startShear(cornerIndex: Int, bounds: CGRect, dragValue: DragGesture.Value) {
        shearStarted = true
        document.isHandleScalingActive = true
        startLocation = dragValue.location
        initialBounds = bounds
        initialTransform = shape.transform
        document.saveToUndoStack()
        
        // CRITICAL FIX: Use ORIGINAL bounds (no transform applied) for anchor calculation
        // This prevents anchor drift after multiple transformations
        let originalBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds
        shearAnchorPoint = getAnchorPoint(for: document.shearAnchor, in: originalBounds, cornerIndex: cornerIndex)
        print("🔄 SHEAR START: Corner \(cornerIndex) → Anchor mode: \(document.shearAnchor.displayName) at (\(String(format: "%.1f", shearAnchorPoint.x)), \(String(format: "%.1f", shearAnchorPoint.y)))")
        print("   📐 Using ORIGINAL bounds: (\(String(format: "%.1f", originalBounds.minX)), \(String(format: "%.1f", originalBounds.minY))) → (\(String(format: "%.1f", originalBounds.maxX)), \(String(format: "%.1f", originalBounds.maxY)))")
    }
    
    private func calculatePreviewShear(shearX: CGFloat, shearY: CGFloat, anchor: CGPoint) {
        // Create shear transform around the anchor point
        let shearTransform = CGAffineTransform(a: 1, b: shearY, c: shearX, d: 1, tx: 0, ty: 0)
        let anchorTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .concatenating(shearTransform)
            .translatedBy(x: -anchor.x, y: -anchor.y)
        
        previewTransform = initialTransform.concatenating(anchorTransform)
        isShearing = true
        
        print("   📊 Shear preview updated: X=\(String(format: "%.3f", shearX)), Y=\(String(format: "%.3f", shearY)) - showing SHEARED SHAPE outline")
    }
    
    private func finishShear() {
        shearStarted = false
        isShearing = false
        document.isHandleScalingActive = false
        
        print("🏁 SHEAR FINISH: Applying final transform to coordinates")
        
        // CRITICAL FIX: Apply shear to actual coordinates, not just transform
        // This ensures object origin stays with object after shearing (Adobe Illustrator behavior)
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            
            // CRITICAL FIX: Reset to initial transform first to prevent drift accumulation
            document.layers[layerIndex].shapes[shapeIndex].transform = initialTransform
            
            // Apply the final transform to coordinates and reset transform to identity
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            
            print("✅ SHEAR FINISHED: Applied shear to coordinates and reset transform to identity")
        }
        
        previewTransform = .identity
    }
    
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
    
    private func isPinnedAnchorCorner(cornerIndex: Int) -> Bool {
        switch document.shearAnchor {
        case .center: return false
        case .topLeft: return cornerIndex == 0
        case .topRight: return cornerIndex == 1
        case .bottomRight: return cornerIndex == 2
        case .bottomLeft: return cornerIndex == 3
        }
    }
    
    private func getAnchorForCorner(index: Int) -> ShearAnchor {
        switch index {
        case 0: return .topLeft
        case 1: return .topRight
        case 2: return .bottomRight
        case 3: return .bottomLeft
        default: return .center
        }
    }
    
    private func getAnchorPoint(for anchor: ShearAnchor, in bounds: CGRect, cornerIndex: Int) -> CGPoint {
        switch anchor {
        case .center: return CGPoint(x: bounds.midX, y: bounds.midY)
        case .topLeft: return CGPoint(x: bounds.minX, y: bounds.minY)
        case .topRight: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case .bottomLeft: return CGPoint(x: bounds.minX, y: bounds.maxY)
        case .bottomRight: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Adobe Illustrator behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform? = nil) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let currentTransform = transform ?? shape.transform
        
        // Don't apply identity transforms
        if currentTransform.isIdentity {
            return
        }
        
        print("🔧 Applying shear transform to shape coordinates: \(shape.name)")
        
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
        
        print("✅ Shape coordinates updated after shear - object origin stays with object")
    }
    
    // Shift Key Monitoring
    @State private var keyEventMonitor: Any?
    
    private func setupKeyEventMonitoring() {
        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.isShiftPressed = event.modifierFlags.contains(.shift)
            }
            return event
        }
    }
    
    private func teardownKeyEventMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
            keyEventMonitor = nil
        }
    }
}

// MARK: - Text Rotation and Shear Handles
struct TextRotateHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    var body: some View {
        // Simplified text rotation handles - just show outline for now
        let absoluteBounds = CGRect(
            x: textObject.position.x + textObject.bounds.minX,
            y: textObject.position.y + textObject.bounds.minY,
            width: textObject.bounds.width,
            height: textObject.bounds.height
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
        // Simplified text shear handles - just show outline for now
        let absoluteBounds = CGRect(
            x: textObject.position.x + textObject.bounds.minX,
            y: textObject.position.y + textObject.bounds.minY,
            width: textObject.bounds.width,
            height: textObject.bounds.height
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

// Simple text outline for Selection tool
struct TextSelectionOutline: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    var body: some View {
        // SELECTION TOOL: Just show text bounding box outline (no transform handles)
        let absoluteBounds = CGRect(
            x: textObject.position.x + textObject.bounds.minX,
            y: textObject.position.y + textObject.bounds.minY,
            width: textObject.bounds.width,
            height: textObject.bounds.height
        )
        let center = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)
        
        Rectangle()
            .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
            .frame(width: absoluteBounds.width, height: absoluteBounds.height)
            .position(center)
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
    }
}

// Scale handles for text objects with Scale tool
struct TextScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // SCALE TOOL: Show text bounding box outline with 4 corner scaling handles only
        let absoluteBounds = CGRect(
            x: textObject.position.x + textObject.bounds.minX,
            y: textObject.position.y + textObject.bounds.minY,
            width: textObject.bounds.width,
            height: textObject.bounds.height
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
