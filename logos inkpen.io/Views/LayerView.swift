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
        // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
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
    
    // Professional scaling state management - FIXED IMPLEMENTATION
    @State private var isScaling = false
    @State private var scalingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var scalingAnchorPoint: CGPoint = .zero  // This is the LOCKED/PIN point (RED)
    @State private var finalMarqueeBounds: CGRect = .zero
    @State private var isShiftPressed = false
    @State private var isCapsLockPressed = false  // NEW: Track caps-lock for locking pin point
    
    // CORRECTED POINT SYSTEM: Lock point vs scale points
    @State private var lockedPinPointIndex: Int? = nil // Which point is LOCKED (RED) - set by single click
    @State private var pathPoints: [VectorPoint] = []  // All path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Center point
    @State private var pointsRefreshTrigger: Int = 0
    
    private let handleSize: CGFloat = 8

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
                    Path { path in
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
                    .stroke(Color.red, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(groupedShape.transform)
                }
            } else {
                // REGULAR SHAPE: Show single path outline
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
                    
                    Rectangle()
                        .fill(isLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = scalable
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                        .position(cornerPos)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                        .transformEffect(shape.transform)
                        .onTapGesture {
                            if !isScaling {
                                // SINGLE CLICK: Set this as the locked pin point (RED)
                                setLockedPinPoint(cornerIndex)
                            }
                        }
                        .highPriorityGesture(
                            DragGesture()
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
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isScaling {
                        // SINGLE CLICK: Set center as the locked pin point (RED)
                        setLockedPinPoint(nil) // nil = center
                    }
                }
                .highPriorityGesture(
                    DragGesture()
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
            setupScaleKeyEventMonitoring()
            extractPathPoints()
            
            // Set default locked pin point to center if none is set
            if lockedPinPointIndex == nil && scalingAnchorPoint == .zero {
                setLockedPinPoint(nil) // nil = center point
                print("🔴 SCALE TOOL: Default locked pin set to center")
            }
        }
        .onDisappear {
            teardownScaleKeyEventMonitoring()
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change (e.g., after moving), refresh the scale points
            if !isScaling && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
                print("🔄 SCALE TOOL: Shape bounds changed, refreshed points")
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
        
        print("🎯 EXTRACTED \(pathPoints.count) path points + center for scale anchor selection")
    }
    
    /// Display all path points with correct colors: GREEN = scalable, RED = locked pin
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index
            
            Rectangle()
                .fill(isLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = scalable
                .stroke(Color.white, lineWidth: 1.0)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(CGPoint(x: point.x, y: point.y))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .onTapGesture {
                    if !isScaling {
                        // SINGLE CLICK: Set this as the locked pin point (RED)
                        setLockedPinPoint(index)
                    }
                }
                .highPriorityGesture(
                    DragGesture()
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
                print("🔴 LOCKED PIN: Set to path point \(index) at (\(String(format: "%.1f", point.x)), \(String(format: "%.1f", point.y)))")
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
            print("🔒 CAPS-LOCK ACTIVE: Pin point locked, scaling away from locked point")
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
            print("🔄 SCALING START: No pin point set, defaulting to center")
        }
        
        print("🔄 SCALING START: Dragging from point \(draggedPointIndex?.description ?? "center"), scaling away from LOCKED PIN at (\(String(format: "%.1f", scalingAnchorPoint.x)), \(String(format: "%.1f", scalingAnchorPoint.y)))")
        print("   🔴 Locked pin point index: \(lockedPinPointIndex?.description ?? "center")")
        print("   🟢 Dragging from point index: \(draggedPointIndex?.description ?? "center")")
        
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
    
    // MARK: - Key Event Monitoring (same as rotate/shear tools)
    
    @State private var scaleKeyEventMonitor: Any?
    
    private func setupScaleKeyEventMonitoring() {
        scaleKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.isShiftPressed = event.modifierFlags.contains(.shift)
                self.isCapsLockPressed = event.modifierFlags.contains(.capsLock)
                
                // Debug logging for caps-lock state
                if self.isCapsLockPressed {
                    print("🔒 CAPS-LOCK ACTIVE: Pin point locking enabled")
                }
            }
            return event
        }
    }
    
    private func teardownScaleKeyEventMonitoring() {
        if let monitor = scaleKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            scaleKeyEventMonitor = nil
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
            
            print("✅ Flattened group coordinates updated - transformed \(transformedGroupedShapes.count) individual shapes")
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
        // FLATTENED SHAPE FIX: Use actual path bounds for flattened shapes, not group bounds
        let bounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
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
    
    // Professional shear state management - FIXED IMPLEMENTATION (same as scale tool)
    @State private var isShearing = false
    @State private var shearStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity
    @State private var shearAnchorPoint: CGPoint = .zero  // This is the LOCKED/PIN point (RED)
    @State private var isShiftPressed = false  // For constrained shearing
    @State private var isCapsLockPressed = false  // NEW: Track caps-lock for locking pin point
    
    // CORRECTED POINT SYSTEM: Lock point vs shear points (same as scale tool)
    @State private var lockedPinPointIndex: Int? = nil // Which point is LOCKED (RED) - set by single click
    @State private var pathPoints: [VectorPoint] = []  // All path points for display
    @State private var centerPoint: VectorPoint = VectorPoint(CGPoint.zero) // Center point
    @State private var pointsRefreshTrigger: Int = 0
    
    private let handleSize: CGFloat = 8
    
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
                    Path { path in
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
                    .stroke(Color.purple, lineWidth: 2.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(groupedShape.transform)
                }
            } else {
                // REGULAR SHAPE: Show single path outline
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
                    DragGesture()
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
            setupShearKeyEventMonitoring()
            extractPathPoints()
            
            // Set default locked pin point to center if none is set
            if lockedPinPointIndex == nil && shearAnchorPoint == .zero {
                setLockedPinPoint(nil) // nil = center point
                print("🔴 SHEAR TOOL: Default locked pin set to center")
            }
        }
        .onDisappear {
            teardownShearKeyEventMonitoring()
        }
        .onChange(of: shape.bounds) { oldBounds, newBounds in
            // MOVEMENT FIX: When shape bounds change (e.g., after moving), refresh the shear points
            if !isShearing && oldBounds != newBounds {
                extractPathPoints()
                pointsRefreshTrigger += 1
                print("🔄 SHEAR TOOL: Shape bounds changed, refreshed points")
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
        
        print("   📊 PIN-POINT SHEAR preview updated:")
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
        
        print("🎯 EXTRACTED \(pathPoints.count) path points + center for shear anchor selection")
    }
    
    /// Display all path points with correct colors: GREEN = shearable, RED = locked pin
    @ViewBuilder
    private func pathPointsView() -> some View {
        ForEach(pathPoints.indices, id: \.self) { index in
            let point = pathPoints[index]
            let isLockedPin = lockedPinPointIndex == index
            
            Rectangle()
                .fill(isLockedPin ? Color.red : Color.green)  // RED = locked pin, GREEN = shearable
                .stroke(Color.white, lineWidth: 1.0)
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
                    DragGesture()
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
                print("🔴 LOCKED PIN: Set to bounds point (fallback to center)")
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
            print("🔒 CAPS-LOCK ACTIVE: Pin point locked, shearing away from locked point")
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
        let minDistance: CGFloat = 20.0 // Minimum distance to prevent extreme shearing
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
            print("🔄 SHEAR START: No pin point set, defaulting to center")
        }
        
        print("🔄 SHEAR START: Dragging from point \(draggedPointIndex?.description ?? "center"), shearing away from LOCKED PIN at (\(String(format: "%.1f", shearAnchorPoint.x)), \(String(format: "%.1f", shearAnchorPoint.y)))")
        print("   🔴 Locked pin point index: \(lockedPinPointIndex?.description ?? "center")")
        print("   🟢 Dragging from point index: \(draggedPointIndex?.description ?? "center")")
        
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
        
        // Update center point based on NEW bounds after shear
        let newBounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        centerPoint = VectorPoint(CGPoint(x: newBounds.midX, y: newBounds.midY))
        
        // FORCE VIEW REFRESH: Trigger state change to rebuild UI with new points
        pointsRefreshTrigger += 1
        
        print("🔄 FORCE UPDATED shear points - \(pathPoints.count) path points + center at (\(String(format: "%.1f", centerPoint.x)), \(String(format: "%.1f", centerPoint.y)))")
        print("   📐 New bounds: (\(String(format: "%.1f", newBounds.minX)), \(String(format: "%.1f", newBounds.minY))) → (\(String(format: "%.1f", newBounds.maxX)), \(String(format: "%.1f", newBounds.maxY)))")
    }
    
    // MARK: - Key Event Monitoring (same as scale tool)
    
    @State private var shearKeyEventMonitor: Any?
    
    private func setupShearKeyEventMonitoring() {
        shearKeyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
            DispatchQueue.main.async {
                self.isShiftPressed = event.modifierFlags.contains(.shift)
                self.isCapsLockPressed = event.modifierFlags.contains(.capsLock)
                
                // Debug logging for caps-lock state
                if self.isCapsLockPressed {
                    print("🔒 CAPS-LOCK ACTIVE: Pin point locking enabled")
                }
            }
            return event
        }
    }
    
    private func teardownShearKeyEventMonitoring() {
        if let monitor = shearKeyEventMonitor {
            NSEvent.removeMonitor(monitor)
            shearKeyEventMonitor = nil
        }
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

