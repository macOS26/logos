//
//  LayerView+SelectionOutline.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
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
                            var hasCurrentPoint = false
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to):
                                    let point = to.cgPoint
                                    guard !point.x.isNaN && !point.y.isNaN else { continue }
                                    path.move(to: point)
                                    hasCurrentPoint = true
                                case .line(let to):
                                    let point = to.cgPoint
                                    guard !point.x.isNaN && !point.y.isNaN else { continue }
                                    if hasCurrentPoint { path.addLine(to: point) }
                                case .curve(let to, let control1, let control2):
                                    let toPoint = to.cgPoint
                                    let cp1 = control1.cgPoint
                                    let cp2 = control2.cgPoint
                                    guard !toPoint.x.isNaN && !toPoint.y.isNaN &&
                                          !cp1.x.isNaN && !cp1.y.isNaN &&
                                          !cp2.x.isNaN && !cp2.y.isNaN else { continue }
                                    if hasCurrentPoint { path.addCurve(to: toPoint, control1: cp1, control2: cp2) }
                                case .quadCurve(let to, let control):
                                    let toPoint = to.cgPoint
                                    let cp = control.cgPoint
                                    guard !toPoint.x.isNaN && !toPoint.y.isNaN &&
                                          !cp.x.isNaN && !cp.y.isNaN else { continue }
                                    if hasCurrentPoint { path.addQuadCurve(to: toPoint, control: cp) }
                                case .close:
                                    if hasCurrentPoint {
                                        path.closeSubpath()
                                        hasCurrentPoint = false
                                    }
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
                        var hasCurrentPoint = false
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to):
                                let point = to.cgPoint
                                guard !point.x.isNaN && !point.y.isNaN else { continue }
                                path.move(to: point)
                                hasCurrentPoint = true
                            case .line(let to):
                                let point = to.cgPoint
                                guard !point.x.isNaN && !point.y.isNaN else { continue }
                                if hasCurrentPoint { path.addLine(to: point) }
                            case .curve(let to, let control1, let control2):
                                let toPoint = to.cgPoint
                                let cp1 = control1.cgPoint
                                let cp2 = control2.cgPoint
                                guard !toPoint.x.isNaN && !toPoint.y.isNaN &&
                                      !cp1.x.isNaN && !cp1.y.isNaN &&
                                      !cp2.x.isNaN && !cp2.y.isNaN else { continue }
                                if hasCurrentPoint { path.addCurve(to: toPoint, control1: cp1, control2: cp2) }
                            case .quadCurve(let to, let control):
                                let toPoint = to.cgPoint
                                let cp = control.cgPoint
                                guard !toPoint.x.isNaN && !toPoint.y.isNaN &&
                                      !cp.x.isNaN && !cp.y.isNaN else { continue }
                                if hasCurrentPoint { path.addQuadCurve(to: toPoint, control: cp) }
                            case .close:
                                if hasCurrentPoint {
                                    path.closeSubpath()
                                    hasCurrentPoint = false
                                }
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
        } else if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
            // For warped objects in selection tool, show standard transform box
            // Use the shape's bounds property which should be calculated from the warped path
            let warpedBounds = shape.bounds
            let center = CGPoint(x: warpedBounds.midX, y: warpedBounds.midY)

            ZStack {
                // Draw standard transform box with dashed lines
                Path { path in
                    path.addRect(warpedBounds)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [5.0 / zoomLevel, 5.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)

                // Center point
                Rectangle()
                    .fill(Color.blue)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize, height: handleSize)
                    .position(CGPoint(
                        x: center.x * zoomLevel + canvasOffset.x,
                        y: center.y * zoomLevel + canvasOffset.y
                    ))

                // Corner handles
                ForEach(0..<4) { i in
                    let position = cornerPosition(for: i, in: warpedBounds, center: center)

                    Rectangle()
                        .fill(Color.blue)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize)
                        .position(CGPoint(
                            x: position.x * zoomLevel + canvasOffset.x,
                            y: position.y * zoomLevel + canvasOffset.y
                        ))
                }
            }
        } else {
            // NORMAL SELECTION: Show bounding box outline with blue corner handles and center point
            // ALWAYS USE WARP ENVELOPE IF IT EXISTS ON THE SHAPE
            let baseBounds: CGRect = {
                // First check if shape itself has warp envelope (warp objects)
                if shape.isWarpObject && !shape.warpEnvelope.isEmpty && shape.warpEnvelope.count == 4 {
                    let minX = shape.warpEnvelope.map { $0.x }.min() ?? 0
                    let maxX = shape.warpEnvelope.map { $0.x }.max() ?? 0
                    let minY = shape.warpEnvelope.map { $0.y }.min() ?? 0
                    let maxY = shape.warpEnvelope.map { $0.y }.max() ?? 0
                    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                } else if let warpBounds = document.warpBounds[shape.id] {
                    // Then check stored warp bounds
                    return warpBounds
                } else {
                    // Compute precise bounds in canvas coordinates
                    // Regular shapes: use the actual rendered path with transform baked-in
                    // Group containers: transform group bounds corners
                    return shape.isGroupContainer ? shape.groupBounds : shape.bounds
                }
            }()
            
            // CRITICAL FIX: Account for stroke width in bounding box for stroke-only shapes
            let strokeExpandedBounds: CGRect = {
                let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)
                if isStrokeOnly && shape.strokeStyle != nil {
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeExpansion = strokeWidth / 2.0 // Half stroke width on each side
                    return baseBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                } else {
                    return baseBounds
                }
            }()
            
            let center = CGPoint(x: strokeExpandedBounds.midX, y: strokeExpandedBounds.midY)
            let transformedBounds: CGRect = {
                // CRITICAL: If shape is warped, DON'T transform again - envelope is already in final position
                if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                    return strokeExpandedBounds // Use bounds directly without transform
                } else {
                    // Only apply transform for non-warped shapes
                    let t = shape.transform
                    let corners = [
                        CGPoint(x: strokeExpandedBounds.minX, y: strokeExpandedBounds.minY).applying(t),
                        CGPoint(x: strokeExpandedBounds.maxX, y: strokeExpandedBounds.minY).applying(t),
                        CGPoint(x: strokeExpandedBounds.maxX, y: strokeExpandedBounds.maxY).applying(t),
                        CGPoint(x: strokeExpandedBounds.minX, y: strokeExpandedBounds.maxY).applying(t)
                    ]
                    let minX = corners.map { $0.x }.min() ?? strokeExpandedBounds.minX
                    let minY = corners.map { $0.y }.min() ?? strokeExpandedBounds.minY
                    let maxX = corners.map { $0.x }.max() ?? strokeExpandedBounds.maxX
                    let maxY = corners.map { $0.y }.max() ?? strokeExpandedBounds.maxY
                    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                }
            }()
            
            ZStack {
                // Bounding box outline - use SHARED component
                if shape.isWarpObject {
                    // Use the SAME envelope drawing code as warp tool
                    SharedEnvelopeOutline(
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        color: .blue,
                        lineWidth: 1.0,
                        isDashed: false
                    )
                } else {
                    // Draw regular rectangle for non-warped shapes
                    // CRITICAL FIX: Validate bounds before creating Path to prevent NaN errors
                    if !transformedBounds.origin.x.isNaN &&
                       !transformedBounds.origin.y.isNaN &&
                       !transformedBounds.size.width.isNaN &&
                       !transformedBounds.size.height.isNaN &&
                       transformedBounds.size.width > 0 &&
                       transformedBounds.size.height > 0 {
                        Path { path in
                            path.addRect(transformedBounds)
                        }
                        .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                    } else {
                        // CRITICAL FIX: Log invalid bounds instead of crashing
                        EmptyView()
                            .onAppear {
                                Log.error("⚠️ Invalid bounds for selection outline on shape '\(shape.name)': \(transformedBounds)", category: .error)
                            }
                    }
                }
                
                // CENTER POINT: Blue square same size as corners
                // CRITICAL: If shape is warped, don't transform center - it's already positioned
                let transformedCenter = (shape.isWarpObject && !shape.warpEnvelope.isEmpty) ?
                    center : CGPoint(x: center.x, y: center.y).applying(shape.transform)

                // CRITICAL FIX: Validate center position before rendering
                if !transformedCenter.x.isNaN && !transformedCenter.y.isNaN {
                    Rectangle()
                        .fill(Color.blue)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize) // Fixed UI size - does not scale with artwork
                        .position(CGPoint(
                            x: transformedCenter.x * zoomLevel + canvasOffset.x,
                            y: transformedCenter.y * zoomLevel + canvasOffset.y
                        ))
                }
                
                // 4 Corner handles - use SHARED component for warped shapes
                if shape.isWarpObject {
                    SharedEnvelopeCorners(
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        handleSize: handleSize,
                        handleColor: .blue
                    )
                } else {
                    ForEach(0..<4) { i in
                        let position = cornerPosition(for: i, in: baseBounds, center: center)
                        let transformedCorner = CGPoint(x: position.x, y: position.y).applying(shape.transform)

                        // CRITICAL FIX: Validate corner position before rendering
                        if !transformedCorner.x.isNaN && !transformedCorner.y.isNaN {
                            Rectangle()
                                .fill(Color.blue)
                                .stroke(Color.white, lineWidth: 1.0)
                                .frame(width: handleSize, height: handleSize)
                                .position(CGPoint(
                                    x: transformedCorner.x * zoomLevel + canvasOffset.x,
                                    y: transformedCorner.y * zoomLevel + canvasOffset.y
                                ))
                        }
                    }
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
