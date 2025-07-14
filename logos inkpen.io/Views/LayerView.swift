//
//  LayerView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

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
            // Fill - only show in color view mode (or always for Canvas)
            if effectiveViewMode == .color,
               let fillStyle = shape.fillStyle, 
               fillStyle.color != .clear {
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .fill(fillStyle.color.color)
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
            
            // Selection outline
            if isSelected {
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                .opacity(0.7)
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
            // Show handles for selected shapes
        ForEach(document.layers.indices, id: \.self) { layerIndex in
            let layer = document.layers[layerIndex]
            ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                let shape = layer.shapes[shapeIndex]
                if document.selectedShapeIDs.contains(shape.id) {
                    SelectionHandles(
                            document: document,
                        shape: shape,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    }
                }
            }
            
            // Show handles for selected text objects (Adobe Illustrator Standards)
            ForEach(document.textObjects.indices, id: \.self) { textIndex in
                let textObject = document.textObjects[textIndex]
                if document.selectedTextIDs.contains(textObject.id) {
                    TextSelectionHandles(
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

struct SelectionHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    private let handleSize: CGFloat = 8
    private let rotationHandleOffset: CGFloat = 20
    
    // Professional scaling state management
    @State private var isScaling = false
    @State private var scalingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    
    // Professional rotation state management
    @State private var isRotating = false
    @State private var rotationStarted = false
    @State private var initialRotation: CGFloat = 0
    @State private var rotationStartLocation: CGPoint = .zero
    
    var body: some View {
        // PROFESSIONAL SCALING: Use original bounds for consistent scaling
        let bounds = shape.bounds
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
            
            // Corner resize handles (scale proportionally)
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: bounds, center: center)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel) // Scale-independent handle size
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleCornerScaling(index: i, dragValue: value, bounds: bounds, center: center)
                            }
                            .onEnded { _ in
                                finishScaling()
                            }
                    )
            }
            
            // Edge resize handles (scale in one direction)  
            ForEach(0..<4) { i in
                let position = edgePosition(for: i, in: bounds, center: center)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel) // Scale-independent handle size
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleEdgeScaling(index: i, dragValue: value, bounds: bounds, center: center)
                            }
                            .onEnded { _ in
                                finishScaling()
                            }
                    )
            }
            
            // Rotation handle (small circle above top-center)
            let rotationPosition = CGPoint(
                x: center.x,
                y: bounds.minY - rotationHandleOffset / zoomLevel
            )
            Circle()
                .fill(Color.green)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel) // Scale-independent handle size
                .position(rotationPosition)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleRotation(dragValue: value, bounds: bounds, center: center)
                        }
                        .onEnded { _ in
                            finishRotation()
                        }
                )
            
            // Rotation indicator line
            Path { path in
                let topCenter = CGPoint(x: center.x, y: bounds.minY)
                path.move(to: topCenter)
                path.addLine(to: rotationPosition)
            }
            .stroke(Color.green, lineWidth: 1.0 / zoomLevel) // Scale-independent line width
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(shape.transform)
        }
        .onAppear {
            initialBounds = shape.bounds
            initialTransform = shape.transform
        }
    }
    
    private func handleCornerScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            scalingStarted = true
            isScaling = true
            initialBounds = bounds
            initialTransform = shape.transform
            startLocation = dragValue.startLocation
            document.saveToUndoStack()
        }
        
        // Professional scaling: Calculate scale based on distance from center
        let initialCenter = CGPoint(
            x: center.x * zoomLevel + canvasOffset.x,
            y: center.y * zoomLevel + canvasOffset.y
        )
        
        let initialDistance = distance(startLocation, initialCenter)
        let currentDistance = distance(
            CGPoint(
                x: startLocation.x + dragValue.translation.width,
                y: startLocation.y + dragValue.translation.height
            ),
            initialCenter
        )
        
        let scaleFactor = max(0.1, currentDistance / max(initialDistance, 1.0))
        
        // Apply uniform scaling for corner handles (Adobe Illustrator behavior)
        applyScaling(scaleX: scaleFactor, scaleY: scaleFactor)
    }
    
    private func handleEdgeScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !scalingStarted {
            scalingStarted = true
            isScaling = true
            initialBounds = bounds
            initialTransform = shape.transform
            startLocation = dragValue.startLocation
            document.saveToUndoStack()
        }
        
        // Professional edge scaling: Scale only in the direction of the edge
        let translation = CGPoint(
            x: dragValue.translation.width / zoomLevel,
            y: dragValue.translation.height / zoomLevel
        )
        
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        
        switch index {
        case 0: // Top edge
            scaleY = max(0.1, (bounds.height - translation.y) / bounds.height)
        case 1: // Right edge
            scaleX = max(0.1, (bounds.width + translation.x) / bounds.width)
        case 2: // Bottom edge
            scaleY = max(0.1, (bounds.height + translation.y) / bounds.height)
        case 3: // Left edge
            scaleX = max(0.1, (bounds.width - translation.x) / bounds.width)
        default:
            break
        }
        
        applyScaling(scaleX: scaleX, scaleY: scaleY)
    }
    
    private func applyScaling(scaleX: CGFloat, scaleY: CGFloat) {
        // PROFESSIONAL SCALING: Apply directly to document with proper transform management
        guard let layerIndex = document.selectedLayerIndex,
              let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) else {
            return
        }
        
        // Create scaling transform from the center of the object
        let centerX = initialBounds.midX
        let centerY = initialBounds.midY
        
        // Build transform: translate to origin, scale, translate back, then apply original transform
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: centerX, y: centerY)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -centerX, y: -centerY)
        
        // Combine with initial transform
        let newTransform = initialTransform.concatenating(scaleTransform)
        
        // Apply to shape - this ensures object stays with selection bounds
        document.layers[layerIndex].shapes[shapeIndex].transform = newTransform
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishScaling() {
        scalingStarted = false
        isScaling = false
        
        // CRITICAL FIX: Apply transform to actual coordinates after scaling
        // This ensures object origin stays with object after scaling (Adobe Illustrator behavior)
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
        }
    }
    
    // MARK: - Professional Rotation Methods (Adobe Illustrator Standards)
    
    private func handleRotation(dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !rotationStarted {
            rotationStarted = true
            isRotating = true
            initialBounds = bounds
            initialTransform = shape.transform
            rotationStartLocation = dragValue.startLocation
            
            // Calculate initial rotation from transform
            initialRotation = atan2(initialTransform.b, initialTransform.a)
            
            document.saveToUndoStack()
        }
        
        // Calculate rotation center in screen coordinates
        let rotationCenter = CGPoint(
            x: center.x * zoomLevel + canvasOffset.x,
            y: center.y * zoomLevel + canvasOffset.y
        )
        
        // Calculate angles
        let startAngle = atan2(
            rotationStartLocation.y - rotationCenter.y,
            rotationStartLocation.x - rotationCenter.x
        )
        
        let currentLocation = CGPoint(
            x: rotationStartLocation.x + dragValue.translation.width,
            y: rotationStartLocation.y + dragValue.translation.height
        )
        
        let currentAngle = atan2(
            currentLocation.y - rotationCenter.y,
            currentLocation.x - rotationCenter.x
        )
        
        // Calculate rotation delta
        let rotationDelta = currentAngle - startAngle
        
        // Apply rotation
        applyRotation(delta: rotationDelta, center: center)
    }
    
    private func applyRotation(delta: CGFloat, center: CGPoint) {
        guard let layerIndex = document.selectedLayerIndex,
              let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) else {
            return
        }
        
        // Calculate rotation center
        let centerX = initialBounds.midX
        let centerY = initialBounds.midY
        
        // Create rotation transform around center
        let rotationTransform = CGAffineTransform.identity
            .translatedBy(x: centerX, y: centerY)
            .rotated(by: delta)
            .translatedBy(x: -centerX, y: -centerY)
        
        // Combine with initial transform
        let newTransform = initialTransform.concatenating(rotationTransform)
        
        // Apply to shape
        document.layers[layerIndex].shapes[shapeIndex].transform = newTransform
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishRotation() {
        rotationStarted = false
        isRotating = false
        
        // Apply rotation to actual coordinates (Adobe Illustrator behavior)
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex)
        }
    }
    
    /// PROFESSIONAL COORDINATE SYSTEM FIX: Apply transform to actual coordinates
    /// This ensures object origin moves with the object (Adobe Illustrator behavior)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int) {
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let transform = shape.transform
        
        // Don't apply identity transforms
        if transform.isIdentity {
            return
        }
        
        print("🔧 Applying scaling transform to shape coordinates: \(shape.name)")
        
        // Transform all path elements
        var transformedElements: [PathElement] = []
        
        for element in shape.path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.move(to: VectorPoint(transformedPoint)))
                
            case .line(let to):
                let transformedPoint = CGPoint(x: to.x, y: to.y).applying(transform)
                transformedElements.append(.line(to: VectorPoint(transformedPoint)))
                
            case .curve(let to, let control1, let control2):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl1 = CGPoint(x: control1.x, y: control1.y).applying(transform)
                let transformedControl2 = CGPoint(x: control2.x, y: control2.y).applying(transform)
                transformedElements.append(.curve(
                    to: VectorPoint(transformedTo),
                    control1: VectorPoint(transformedControl1),
                    control2: VectorPoint(transformedControl2)
                ))
                
            case .quadCurve(let to, let control):
                let transformedTo = CGPoint(x: to.x, y: to.y).applying(transform)
                let transformedControl = CGPoint(x: control.x, y: control.y).applying(transform)
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
    
    private func edgePosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        // PROFESSIONAL COORDINATE SYSTEM: Use logical coordinates, let SwiftUI handle screen positioning
        switch index {
        case 0: return CGPoint(x: center.x, y: bounds.minY) // Top
        case 1: return CGPoint(x: bounds.maxX, y: center.y) // Right
        case 2: return CGPoint(x: center.x, y: bounds.maxY) // Bottom
        case 3: return CGPoint(x: bounds.minX, y: center.y) // Left
        default: return center
        }
    }
    
    // Distance calculation helper
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        return sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
    }
}

// MARK: - Professional Text Selection Handles (Adobe Illustrator Standards)

struct TextSelectionHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    private let handleSize: CGFloat = 8
    private let rotationHandleOffset: CGFloat = 20
    
    // Professional scaling state management for text
    @State private var isScaling = false
    @State private var scalingStarted = false
    @State private var initialBounds: CGRect = .zero
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    
    // Professional text rotation state management
    @State private var isTextRotating = false
    @State private var textRotationStarted = false
    @State private var textInitialRotation: CGFloat = 0
    @State private var textRotationStartLocation: CGPoint = .zero
    
    var body: some View {
        // CRITICAL FIX: Use EXACT SAME coordinate system as shape selection
        // Position text bounds relative to text position (baseline)
        let absoluteBounds = CGRect(
            x: textObject.position.x,
            y: textObject.position.y + textObject.bounds.minY,
            width: textObject.bounds.width,
            height: textObject.bounds.height
        )
        let center = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)
        
        ZStack {
            // Text bounding box outline (blue, professional standard) 
            // FIXED: Use EXACT SAME coordinate chain as shape selection
            Rectangle()
                .stroke(Color.blue, lineWidth: 1.0 / zoomLevel) // Scale-independent line width
                .frame(width: absoluteBounds.width, height: absoluteBounds.height)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)
            
            // Corner resize handles (scale proportionally)
            // FIXED: Use EXACT SAME coordinate chain as shape selection  
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: absoluteBounds, center: center)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel) // Scale-independent handle size
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(textObject.transform)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleTextCornerScaling(index: i, dragValue: value, bounds: absoluteBounds, center: center)
                            }
                            .onEnded { _ in
                                finishTextScaling()
                            }
                    )
            }
            
            // Edge resize handles (scale in one direction)  
            // FIXED: Use EXACT SAME coordinate chain as shape selection
            ForEach(0..<4) { i in
                let position = edgePosition(for: i, in: absoluteBounds, center: center)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel) // Scale-independent handle size
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(textObject.transform)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleTextEdgeScaling(index: i, dragValue: value, bounds: absoluteBounds, center: center)
                            }
                            .onEnded { _ in
                                finishTextScaling()
                            }
                    )
            }
            
            // Rotation handle (small circle above top-center)
            // FIXED: Use EXACT SAME coordinate chain as shape selection
            let rotationPosition = CGPoint(
                x: center.x,
                y: absoluteBounds.minY - rotationHandleOffset / zoomLevel
            )
            Circle()
                .fill(Color.green)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel) // Scale-independent handle size
                .position(rotationPosition)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            handleTextRotation(dragValue: value, bounds: absoluteBounds, center: center)
                        }
                        .onEnded { _ in
                            finishTextRotation()
                        }
                )
            
            // Rotation indicator line
            // FIXED: Use EXACT SAME coordinate chain as shape selection
            Path { path in
                let topCenter = CGPoint(
                    x: center.x,
                    y: absoluteBounds.minY
                )
                path.move(to: topCenter)
                path.addLine(to: rotationPosition)
            }
            .stroke(Color.green, lineWidth: 1.0 / zoomLevel) // Scale-independent line width
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
        }
        .onAppear {
            initialBounds = absoluteBounds
            initialTransform = textObject.transform
        }
    }
    
    // MARK: - Professional Text Transformation Helper Methods
    
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
    
    private func handleTextCornerScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        // PROFESSIONAL TEXT SCALING: Maintain proportions for corner scaling
        if !scalingStarted {
            scalingStarted = true
            isScaling = true
            initialBounds = bounds
            initialTransform = textObject.transform
            startLocation = dragValue.startLocation
            document.saveToUndoStack()
        }
        
        // Calculate scale based on distance from center (proportional scaling)
        let initialCenter = CGPoint(
            x: center.x * zoomLevel + canvasOffset.x,
            y: center.y * zoomLevel + canvasOffset.y
        )
        
        let initialDistance = distance(startLocation, initialCenter)
        let currentDistance = distance(
            CGPoint(
                x: startLocation.x + dragValue.translation.width,
                y: startLocation.y + dragValue.translation.height
            ),
            initialCenter
        )
        
        let scaleFactor = max(0.1, currentDistance / max(initialDistance, 1.0))
        
        // Apply uniform scaling for text (Adobe Illustrator behavior)
        applyTextScaling(scaleX: scaleFactor, scaleY: scaleFactor)
        
        print("🔤 Text corner scaling - maintaining proportions (professional standard)")
    }
    
    private func handleTextEdgeScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        // PROFESSIONAL TEXT SCALING: Non-proportional scaling for edge handles
        if !scalingStarted {
            scalingStarted = true
            isScaling = true
            initialBounds = bounds
            initialTransform = textObject.transform
            startLocation = dragValue.startLocation
            document.saveToUndoStack()
        }
        
        // Calculate edge-based scaling (non-proportional)
        let translation = CGPoint(
            x: dragValue.translation.width / zoomLevel,
            y: dragValue.translation.height / zoomLevel
        )
        
        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0
        
        switch index {
        case 0: // Top edge
            scaleY = max(0.1, (bounds.height - translation.y) / bounds.height)
        case 1: // Right edge
            scaleX = max(0.1, (bounds.width + translation.x) / bounds.width)
        case 2: // Bottom edge
            scaleY = max(0.1, (bounds.height + translation.y) / bounds.height)
        case 3: // Left edge
            scaleX = max(0.1, (bounds.width - translation.x) / bounds.width)
        default:
            break
        }
        
        // Apply non-proportional scaling for text
        applyTextScaling(scaleX: scaleX, scaleY: scaleY)
        
        print("🔤 Text edge scaling - non-proportional (professional standard)")
    }
    
    private func applyTextScaling(scaleX: CGFloat, scaleY: CGFloat) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) else {
            return
        }
        
        // Calculate scaling center
        let centerX = initialBounds.midX
        let centerY = initialBounds.midY
        
        // Create scaling transform around center
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: centerX, y: centerY)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -centerX, y: -centerY)
        
        // Combine with initial transform
        let newTransform = initialTransform.concatenating(scaleTransform)
        
        // Apply to text object
        document.textObjects[textIndex].transform = newTransform
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishTextScaling() {
        isScaling = false
        scalingStarted = false
        
        // Update text bounds after scaling
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].updateBounds()
        }
        
        // Save to undo stack after finishing the scaling operation
        document.saveToUndoStack()
    }
    
    // Distance calculation helper for text
    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        return sqrt(pow(point2.x - point1.x, 2) + pow(point2.y - point1.y, 2))
    }
    
    // MARK: - Professional Text Rotation Methods (Adobe Illustrator Standards)
    
    private func handleTextRotation(dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        if !textRotationStarted {
            textRotationStarted = true
            isTextRotating = true
            initialBounds = bounds
            initialTransform = textObject.transform
            textRotationStartLocation = dragValue.startLocation
            
            // Calculate initial rotation from transform
            textInitialRotation = atan2(initialTransform.b, initialTransform.a)
            
            document.saveToUndoStack()
        }
        
        // Calculate rotation center in screen coordinates
        let rotationCenter = CGPoint(
            x: center.x * zoomLevel + canvasOffset.x,
            y: center.y * zoomLevel + canvasOffset.y
        )
        
        // Calculate angles
        let startAngle = atan2(
            textRotationStartLocation.y - rotationCenter.y,
            textRotationStartLocation.x - rotationCenter.x
        )
        
        let currentLocation = CGPoint(
            x: textRotationStartLocation.x + dragValue.translation.width,
            y: textRotationStartLocation.y + dragValue.translation.height
        )
        
        let currentAngle = atan2(
            currentLocation.y - rotationCenter.y,
            currentLocation.x - rotationCenter.x
        )
        
        // Calculate rotation delta
        let rotationDelta = currentAngle - startAngle
        
        // Apply rotation to text
        applyTextRotation(delta: rotationDelta, center: center)
    }
    
    private func applyTextRotation(delta: CGFloat, center: CGPoint) {
        guard let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) else {
            return
        }
        
        // Calculate rotation center
        let centerX = initialBounds.midX
        let centerY = initialBounds.midY
        
        // Create rotation transform around center
        let rotationTransform = CGAffineTransform.identity
            .translatedBy(x: centerX, y: centerY)
            .rotated(by: delta)
            .translatedBy(x: -centerX, y: -centerY)
        
        // Combine with initial transform
        let newTransform = initialTransform.concatenating(rotationTransform)
        
        // Apply to text object
        document.textObjects[textIndex].transform = newTransform
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    private func finishTextRotation() {
        textRotationStarted = false
        isTextRotating = false
        
        // Update text bounds after rotation
        if let textIndex = document.textObjects.firstIndex(where: { $0.id == textObject.id }) {
            document.textObjects[textIndex].updateBounds()
        }
        
        print("🔄 Text rotation completed")
    }
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