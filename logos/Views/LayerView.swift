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
    
    var body: some View {
        ZStack {
            ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                ShapeView(
                    shape: layer.shapes[shapeIndex],
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    isSelected: selectedShapeIDs.contains(layer.shapes[shapeIndex].id),
                    viewMode: viewMode
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
    
    var body: some View {
        ZStack {
            // Fill - only show in color view mode
            if viewMode == .color,
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
            if viewMode == .keyline {
                // In keyline mode, always show a stroke regardless of original stroke style
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .stroke(Color.black, lineWidth: 1.0)
            } else if let strokeStyle = shape.strokeStyle, strokeStyle.color != .clear {
                // In color mode, show the actual stroke with proper placement and transparency
                renderStrokeWithPlacement(shape: shape, strokeStyle: strokeStyle, viewMode: viewMode)
                    .opacity(strokeStyle.opacity) // PROFESSIONAL STROKE TRANSPARENCY
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
        // Apply same transforms as ShapeView in same order
        .transformEffect(shape.transform)
        .scaleEffect(zoomLevel)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
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
            // OUTSIDE STROKE - SIMPLE & CORRECT: Just cover the inside with the shape's fill
            ZStack {
                // 1. Draw stroke at double width (extends both inside and outside)
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .stroke(
                    strokeStyle.color.color.opacity(strokeStyle.opacity),
                    style: SwiftUI.StrokeStyle(
                        lineWidth: strokeStyle.width * 2, // Double width
                        lineCap: swiftUIStrokeStyle.lineCap,
                        lineJoin: swiftUIStrokeStyle.lineJoin,
                        miterLimit: swiftUIStrokeStyle.miterLimit,
                        dash: swiftUIStrokeStyle.dash.map { $0 * 2 } // Scale dash pattern
                    )
                )
                
                // 2. Cover the inside stroke completely with white background
                // This ensures NO stroke color bleeds through, regardless of fill opacity
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .fill(Color.white)
                
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
        let gridSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit * document.zoomLevel
        let canvasSize = document.settings.sizeInPoints
        
        // Prevent infinite loop when grid spacing is 0
        if gridSpacing > 0 {
        Path { path in
            // Vertical lines
            var x = document.canvasOffset.x
            while x < document.canvasOffset.x + canvasSize.width * document.zoomLevel {
                path.move(to: CGPoint(x: x, y: document.canvasOffset.y))
                path.addLine(to: CGPoint(x: x, y: document.canvasOffset.y + canvasSize.height * document.zoomLevel))
                x += gridSpacing
            }
            
            // Horizontal lines
            var y = document.canvasOffset.y
            while y < document.canvasOffset.y + canvasSize.height * document.zoomLevel {
                path.move(to: CGPoint(x: document.canvasOffset.x, y: y))
                path.addLine(to: CGPoint(x: document.canvasOffset.x + canvasSize.width * document.zoomLevel, y: y))
                y += gridSpacing
            }
        }
        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
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
                .transformEffect(shape.transform)
                .scaleEffect(zoomLevel)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
            
            // Corner resize handles (scale proportionally)
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: bounds, center: center)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel) // Scale-independent handle size
                    .position(position)
                    .transformEffect(shape.transform)
                    .scaleEffect(zoomLevel)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
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
                    .transformEffect(shape.transform)
                    .scaleEffect(zoomLevel)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
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
                .transformEffect(shape.transform)
                .scaleEffect(zoomLevel)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // TODO: Implement rotation
                        }
                )
            
            // Rotation indicator line
            Path { path in
                let topCenter = CGPoint(x: center.x, y: bounds.minY)
                path.move(to: topCenter)
                path.addLine(to: rotationPosition)
            }
            .stroke(Color.green, lineWidth: 1.0 / zoomLevel) // Scale-independent line width
            .transformEffect(shape.transform)
            .scaleEffect(zoomLevel)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
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
        // Transform has already been applied during dragging
        // Undo stack was saved at the start of scaling
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
    
    var body: some View {
        // PROFESSIONAL TEXT SCALING: Use text bounds for transformation
        let bounds = textObject.bounds
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        
        ZStack {
            // Text bounding box outline (blue, professional standard)
            Rectangle()
                .stroke(Color.blue, lineWidth: 1.0)
                .frame(width: bounds.width * zoomLevel, height: bounds.height * zoomLevel)
                .position(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: center.y * zoomLevel + canvasOffset.y
                )
                .transformEffect(textObject.transform)
            
            // Corner resize handles (scale proportionally)
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: bounds, center: center)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize, height: handleSize)
                    .position(position)
                    .transformEffect(textObject.transform)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleTextCornerScaling(index: i, dragValue: value, bounds: bounds, center: center)
                            }
                            .onEnded { _ in
                                finishTextScaling()
                            }
                    )
            }
            
            // Edge resize handles (scale in one direction)  
            ForEach(0..<4) { i in
                let position = edgePosition(for: i, in: bounds, center: center)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize, height: handleSize)
                    .position(position)
                    .transformEffect(textObject.transform)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                handleTextEdgeScaling(index: i, dragValue: value, bounds: bounds, center: center)
                            }
                            .onEnded { _ in
                                finishTextScaling()
                            }
                    )
            }
            
            // Rotation handle (small circle above top-center)
            let rotationPosition = CGPoint(
                x: center.x * zoomLevel + canvasOffset.x,
                y: (bounds.minY - rotationHandleOffset / zoomLevel) * zoomLevel + canvasOffset.y
            )
            Circle()
                .fill(Color.green)
                .frame(width: handleSize, height: handleSize)
                .position(rotationPosition)
                .transformEffect(textObject.transform)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // TODO: Implement text rotation
                        }
                )
            
            // Rotation indicator line
            Path { path in
                let topCenter = CGPoint(
                    x: center.x * zoomLevel + canvasOffset.x,
                    y: bounds.minY * zoomLevel + canvasOffset.y
                )
                path.move(to: topCenter)
                path.addLine(to: rotationPosition)
            }
            .stroke(Color.green, lineWidth: 1.0)
            .transformEffect(textObject.transform)
        }
        .onAppear {
            initialBounds = textObject.bounds
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
        // TODO: Implement proportional text scaling like Adobe Illustrator
        print("🔤 Text corner scaling - maintaining proportions (professional standard)")
    }
    
    private func handleTextEdgeScaling(index: Int, dragValue: DragGesture.Value, bounds: CGRect, center: CGPoint) {
        // PROFESSIONAL TEXT SCALING: Non-proportional scaling for edge handles
        // TODO: Implement edge-based text scaling
        print("🔤 Text edge scaling - non-proportional (professional standard)")
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