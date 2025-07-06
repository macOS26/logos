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
                // In color mode, show the actual stroke with proper placement
                renderStrokeWithPlacement(shape: shape, strokeStyle: strokeStyle, viewMode: viewMode)
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
            // Stroke is clipped to the inside of the shape
            ZStack {
                // Draw the stroke at double width
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .stroke(
                    strokeStyle.color.color,
                    style: SwiftUI.StrokeStyle(
                        lineWidth: strokeStyle.width * 2,
                        lineCap: swiftUIStrokeStyle.lineCap,
                        lineJoin: swiftUIStrokeStyle.lineJoin,
                        miterLimit: swiftUIStrokeStyle.miterLimit,
                        dash: swiftUIStrokeStyle.dash
                    )
                )
                .clipShape(
                    Path { path in
                        addPathElements(shape.path.elements, to: &path)
                    }
                )
            }
            
        case .outside:
            // Stroke is drawn outside the shape bounds
            ZStack {
                // Draw the stroke at double width
                Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                .stroke(
                    strokeStyle.color.color,
                    style: SwiftUI.StrokeStyle(
                        lineWidth: strokeStyle.width * 2,
                        lineCap: swiftUIStrokeStyle.lineCap,
                        lineJoin: swiftUIStrokeStyle.lineJoin,
                        miterLimit: swiftUIStrokeStyle.miterLimit,
                        dash: swiftUIStrokeStyle.dash
                    )
                )
                .mask(
                    // Invert the shape to keep only the outside stroke
                    Rectangle()
                        .fill(Color.black)
                        .overlay(
                            Path { path in
                                addPathElements(shape.path.elements, to: &path)
                            }
                            .fill(Color.black)
                            .blendMode(.destinationOut)
                        )
                )
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
    }
}

struct SelectionHandlesView: View {
    let document: VectorDocument
    let geometry: GeometryProxy
    
    var body: some View {
        ForEach(document.layers.indices, id: \.self) { layerIndex in
            let layer = document.layers[layerIndex]
            ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                let shape = layer.shapes[shapeIndex]
                if document.selectedShapeIDs.contains(shape.id) {
                    SelectionHandles(
                        shape: shape,
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset
                    )
                }
            }
        }
    }
}

struct SelectionHandles: View {
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    private let handleSize: CGFloat = 8
    private let rotationHandleOffset: CGFloat = 20
    
    var body: some View {
        // Use original bounds - transform will be applied via SwiftUI modifiers
        let bounds = shape.bounds
        
        ZStack {
            // Bounding box
            Rectangle()
                .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                .frame(width: bounds.width, height: bounds.height)
                .position(x: bounds.midX, y: bounds.midY)
            
            // Corner resize handles (scale proportionally)
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: bounds)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // TODO: Implement corner scaling
                            }
                    )
            }
            
            // Edge resize handles (scale in one direction)
            ForEach(0..<4) { i in
                let position = edgePosition(for: i, in: bounds)
                Rectangle()
                    .fill(Color.blue)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // TODO: Implement edge scaling
                            }
                    )
            }
            
            // Rotation handle (small circle above top-center)
            let rotationPosition = CGPoint(
                x: bounds.midX,
                y: bounds.minY - rotationHandleOffset / zoomLevel
            )
            Circle()
                .fill(Color.green)
                .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                .position(rotationPosition)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // TODO: Implement rotation
                        }
                )
            
            // Rotation indicator line
            Path { path in
                path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
                path.addLine(to: rotationPosition)
            }
            .stroke(Color.green, lineWidth: 1.0 / zoomLevel)
        }
        // Apply same transforms as ShapeView in same order
        .transformEffect(shape.transform)
        .scaleEffect(zoomLevel)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
    }
    
    private func cornerPosition(for index: Int, in bounds: CGRect) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY) // Top-left
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY) // Top-right
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY) // Bottom-right
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY) // Bottom-left
        default: return CGPoint(x: bounds.midX, y: bounds.midY)
        }
    }
    
    private func edgePosition(for index: Int, in bounds: CGRect) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.midX, y: bounds.minY) // Top
        case 1: return CGPoint(x: bounds.maxX, y: bounds.midY) // Right
        case 2: return CGPoint(x: bounds.midX, y: bounds.maxY) // Bottom
        case 3: return CGPoint(x: bounds.minX, y: bounds.midY) // Left
        default: return CGPoint(x: bounds.midX, y: bounds.midY)
        }
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