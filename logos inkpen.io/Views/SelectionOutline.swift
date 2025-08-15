//
//  SelectionOutline.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Simple Selection Outline (Arrow Tool)
struct SelectionOutline: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isOptionPressed: Bool  // Path-based selection when true
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        if isOptionPressed {
            // OPTION KEY HELD: Show blue path outline instead of bounding box
            ZStack {
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
                            .stroke(Color.blue, lineWidth: 2.0 / zoomLevel)
                            .transformEffect(groupedShape.transform)
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                    }
                } else {
                    // REGULAR SHAPE: Show single path outline with cached path
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
                        .stroke(Color.blue, lineWidth: 2.0 / zoomLevel)
                        .transformEffect(shape.transform)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                }
            }
        } else {
            // NORMAL SELECTION: Show bounding box outline with blue corner handles and center point
            // Compute precise bounds in canvas coordinates
            // Regular shapes: use the actual rendered path with transform baked-in
            // Group containers: transform group bounds corners
            let baseBounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
            let center = CGPoint(x: baseBounds.midX, y: baseBounds.midY)
            let transformedBounds: CGRect = {
                // Robust bounds: transform all four corners, regardless of type (works for images too)
                let t = shape.transform
                let corners = [
                    CGPoint(x: baseBounds.minX, y: baseBounds.minY).applying(t),
                    CGPoint(x: baseBounds.maxX, y: baseBounds.minY).applying(t),
                    CGPoint(x: baseBounds.maxX, y: baseBounds.maxY).applying(t),
                    CGPoint(x: baseBounds.minX, y: baseBounds.maxY).applying(t)
                ]
                let minX = corners.map { $0.x }.min() ?? baseBounds.minX
                let minY = corners.map { $0.y }.min() ?? baseBounds.minY
                let maxX = corners.map { $0.x }.max() ?? baseBounds.maxX
                let maxY = corners.map { $0.y }.max() ?? baseBounds.maxY
                return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
            }()
            
            ZStack {
                // Bounding box outline
                // Draw selection rectangle using Path to avoid layout rounding differences
                Path { path in
                    path.addRect(transformedBounds)
                }
                .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                
                // CENTER POINT: Blue square same size as corners
                let transformedCenter = CGPoint(x: center.x, y: center.y).applying(shape.transform)
                Rectangle()
                    .fill(Color.blue)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize, height: handleSize) // Fixed UI size - does not scale with artwork
                    .position(CGPoint(
                        x: transformedCenter.x * zoomLevel + canvasOffset.x,
                        y: transformedCenter.y * zoomLevel + canvasOffset.y
                    ))
                
                // 4 Corner handles - ALL BLUE
                ForEach(0..<4) { i in
                    // Use corners from transformedBounds directly for regular shapes; transform corners for groups
                    let position = cornerPosition(for: i, in: baseBounds, center: center)
                    let transformedCorner = CGPoint(x: position.x, y: position.y).applying(shape.transform)
                    
                    Rectangle()
                        .fill(Color.blue)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize) // Fixed UI size - does not scale with artwork
                        .position(CGPoint(
                            x: transformedCorner.x * zoomLevel + canvasOffset.x,
                            y: transformedCorner.y * zoomLevel + canvasOffset.y
                        ))
                }
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
