//
//  LayerView+TransformBoxHandles.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics

// MARK: - Transform Box for Arrow Tool (Illustrator-style)
struct TransformBoxHandles: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool

    // State for interactive scaling
    @State private var isScaling: Bool = false
    @State private var initialTransform: CGAffineTransform = .identity
    @State private var startLocation: CGPoint = .zero
    @State private var previewTransform: CGAffineTransform = .identity

    private let handleSize: CGFloat = 10

    var body: some View {
        let transformedBounds: CGRect = computeTransformedBounds()

        ZStack {
            // Bounding rectangle (dashed)
            Path { path in
                path.addRect(transformedBounds)
            }
            .stroke(Color.black.opacity(0.5), style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [4.0 / zoomLevel, 4.0 / zoomLevel]))
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .allowsHitTesting(false)

            // Red preview outline when scaling
            if isScaling && !previewTransform.isIdentity {
                Path { path in
                    for element in shape.path.elements {
                        switch element {
                        case .move(let to):
                            let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            path.move(to: p)
                        case .line(let to):
                            let p = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            path.addLine(to: p)
                        case .curve(let to, let c1, let c2):
                            let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            let tc1 = CGPoint(x: c1.x, y: c1.y).applying(previewTransform)
                            let tc2 = CGPoint(x: c2.x, y: c2.y).applying(previewTransform)
                            path.addCurve(to: tp, control1: tc1, control2: tc2)
                        case .quadCurve(let to, let c):
                            let tp = CGPoint(x: to.x, y: to.y).applying(previewTransform)
                            let tc = CGPoint(x: c.x, y: c.y).applying(previewTransform)
                            path.addQuadCurve(to: tp, control: tc)
                        case .close:
                            path.closeSubpath()
                        }
                    }
                }
                .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .allowsHitTesting(false)
            }

            // Handles: 4 corners + 4 mids + center
            ForEach(0..<9) { index in
                let pt = handlePosition(index: index, in: transformedBounds)
                Circle()
                    .fill(Color.blue)
                    .overlay(Circle().stroke(Color.white, lineWidth: 1.0))
                    .frame(width: handleSize, height: handleSize)
                    .position(CGPoint(x: pt.x * zoomLevel + canvasOffset.x,
                                      y: pt.y * zoomLevel + canvasOffset.y))
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isScaling {
                                    beginScaling(startValue: value)
                                }
                                updateScaling(forHandle: index, dragValue: value, bounds: transformedBounds)
                            }
                            .onEnded { _ in
                                endScaling()
                            }
                    )
            }
        }
        .onAppear { initialTransform = shape.transform }
    }

    // Compute transformed bounds in canvas coordinates (after shape.transform)
    private func computeTransformedBounds() -> CGRect {
        let baseBounds = shape.isGroup ? shape.bounds : (shape.isGroupContainer ? shape.groupBounds : shape.bounds)
        
        // CRITICAL FIX: Account for stroke width in bounding box for stroke-only shapes
        var strokeExpandedBounds = baseBounds
        let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)
        if isStrokeOnly && shape.strokeStyle != nil {
            let strokeWidth = shape.strokeStyle?.width ?? 1.0
            let strokeExpansion = strokeWidth / 2.0 // Half stroke width on each side
            strokeExpandedBounds = baseBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
        }
        
        // Use corner transformation for ALL shape types (consistent with image rendering)
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

    private func handlePosition(index: Int, in rect: CGRect) -> CGPoint {
        // 0 TL, 1 Top, 2 TR, 3 Right, 4 BR, 5 Bottom, 6 BL, 7 Left, 8 Center
        switch index {
        case 0: return CGPoint(x: rect.minX, y: rect.minY)
        case 1: return CGPoint(x: rect.midX, y: rect.minY)
        case 2: return CGPoint(x: rect.maxX, y: rect.minY)
        case 3: return CGPoint(x: rect.maxX, y: rect.midY)
        case 4: return CGPoint(x: rect.maxX, y: rect.maxY)
        case 5: return CGPoint(x: rect.midX, y: rect.maxY)
        case 6: return CGPoint(x: rect.minX, y: rect.maxY)
        case 7: return CGPoint(x: rect.minX, y: rect.midY)
        default: return CGPoint(x: rect.midX, y: rect.midY)
        }
    }

    private func oppositeHandle(index: Int, in rect: CGRect) -> CGPoint {
        // Anchor at the opposite corner or mid; center returns center
        switch index {
        case 0: return handlePosition(index: 4, in: rect)
        case 1: return handlePosition(index: 5, in: rect)
        case 2: return handlePosition(index: 6, in: rect)
        case 3: return handlePosition(index: 7, in: rect)
        case 4: return handlePosition(index: 0, in: rect)
        case 5: return handlePosition(index: 1, in: rect)
        case 6: return handlePosition(index: 2, in: rect)
        case 7: return handlePosition(index: 3, in: rect)
        default: return handlePosition(index: 8, in: rect)
        }
    }

    private func beginScaling(startValue: DragGesture.Value) {
        isScaling = true
        startLocation = startValue.startLocation
        initialTransform = shape.transform
        document.isHandleScalingActive = true
        document.saveToUndoStack()
    }

    private func updateScaling(forHandle index: Int, dragValue: DragGesture.Value, bounds: CGRect) {
        // Handle 8 (center) uses a special, stable mapping from mouse delta to scale
        if index == 8 {
            let anchor = CGPoint(x: bounds.midX, y: bounds.midY)
            // Convert mouse delta to canvas space
            let preciseZoom = CGFloat(zoomLevel)
            let dxCanvas = (dragValue.location.x - startLocation.x) / preciseZoom
            let dyCanvas = (dragValue.location.y - startLocation.y) / preciseZoom

            // Sensitivity: moving by full width/height -> ~2x
            let denomX = max(20.0, bounds.width)
            let denomY = max(20.0, bounds.height)

            var sx = 1.0 + (dxCanvas / denomX)
            var sy = 1.0 + (dyCanvas / denomY)

            // Uniform with shift: take dominant axis sign/magnitude
            if isShiftPressed {
                let ux = dxCanvas / denomX
                let uy = dyCanvas / denomY
                let useX = abs(ux) >= abs(uy)
                let u = useX ? ux : uy
                sx = 1.0 + u
                sy = 1.0 + u
            }

            let maxScale: CGFloat = 10.0
            let minScale: CGFloat = 0.1
            sx = min(max(sx, minScale), maxScale)
            sy = min(max(sy, minScale), maxScale)

            // Build scale transform about center
            let scaleTransform = CGAffineTransform.identity
                .translatedBy(x: anchor.x, y: anchor.y)
                .scaledBy(x: sx, y: sy)
                .translatedBy(x: -anchor.x, y: -anchor.y)

            previewTransform = initialTransform.concatenating(scaleTransform)
            document.isHandleScalingActive = true
            document.objectWillChange.send()
            return
        }

        let anchor = oppositeHandle(index: index, in: bounds) // canvas coordinates

        // Convert anchor to screen coordinates
        let anchorScreenX = anchor.x * zoomLevel + canvasOffset.x
        let anchorScreenY = anchor.y * zoomLevel + canvasOffset.y

        let startDX = startLocation.x - anchorScreenX
        let startDY = startLocation.y - anchorScreenY
        let curDX = dragValue.location.x - anchorScreenX
        let curDY = dragValue.location.y - anchorScreenY

        // Avoid division by near-zero
        let minDist: CGFloat = 2.0
        let maxScale: CGFloat = 10.0
        let minScale: CGFloat = 0.1

        var scaleX: CGFloat = 1.0
        var scaleY: CGFloat = 1.0

        let isCorner = [0,2,4,6].contains(index)
        let isTopBottom = [1,5].contains(index)
        let isLeftRight = [3,7].contains(index)
        if isCorner {
            let sx = abs(startDX) > minDist ? abs(curDX) / abs(startDX) : 1.0
            let sy = abs(startDY) > minDist ? abs(curDY) / abs(startDY) : 1.0
            if isShiftPressed {
                let u = max(sx, sy)
                scaleX = u
                scaleY = u
            } else {
                scaleX = sx
                scaleY = sy
            }
        } else if isTopBottom {
            // Vertical only
            let sy = abs(startDY) > minDist ? abs(curDY) / abs(startDY) : 1.0
            scaleX = 1.0
            scaleY = sy
        } else if isLeftRight {
            // Horizontal only
            let sx = abs(startDX) > minDist ? abs(curDX) / abs(startDX) : 1.0
            scaleX = sx
            scaleY = 1.0
        }

        scaleX = min(max(scaleX, minScale), maxScale)
        scaleY = min(max(scaleY, minScale), maxScale)

        // Build scale transform about anchor (canvas space)
        let scaleTransform = CGAffineTransform.identity
            .translatedBy(x: anchor.x, y: anchor.y)
            .scaledBy(x: scaleX, y: scaleY)
            .translatedBy(x: -anchor.x, y: -anchor.y)

        previewTransform = initialTransform.concatenating(scaleTransform)
        // Keep transform active so next small drags immediately continue
        document.isHandleScalingActive = true
        document.objectWillChange.send()
    }

    private func endScaling() {
        isScaling = false
        document.isHandleScalingActive = false
        if let layerIndex = document.selectedLayerIndex,
           let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            // SPECIAL-CASE RASTER IMAGES: Keep transforms on transform property instead of baking into path
            if ImageContentRegistry.containsImage(document.layers[layerIndex].shapes[shapeIndex]) {
                // Commit the preview transform as the shape.transform
                document.layers[layerIndex].shapes[shapeIndex].transform = previewTransform
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            } else {
                // Reset to initial transform to avoid drift and apply final preview to path coordinates
                document.layers[layerIndex].shapes[shapeIndex].transform = initialTransform
                applyTransformToShapeCoordinates(layerIndex: layerIndex, shapeIndex: shapeIndex, transform: previewTransform)
            }
            previewTransform = .identity
            // Force UI refresh to reflect committed transform
            document.objectWillChange.send()
        }
    }

    // Apply preview transform to actual coordinates then reset transform (local implementation)
    private func applyTransformToShapeCoordinates(layerIndex: Int, shapeIndex: Int, transform: CGAffineTransform) {
        var targetShape = document.layers[layerIndex].shapes[shapeIndex]
        let t = transform
        if t.isIdentity { return }

        // Transform all path elements
        var transformedElements: [PathElement] = []
        for element in targetShape.path.elements {
            switch element {
            case .move(let to):
                transformedElements.append(.move(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
            case .line(let to):
                transformedElements.append(.line(to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t))))
            case .curve(let to, let c1, let c2):
                transformedElements.append(.curve(
                    to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                    control1: VectorPoint(CGPoint(x: c1.x, y: c1.y).applying(t)),
                    control2: VectorPoint(CGPoint(x: c2.x, y: c2.y).applying(t))
                ))
            case .quadCurve(let to, let c):
                transformedElements.append(.quadCurve(
                    to: VectorPoint(CGPoint(x: to.x, y: to.y).applying(t)),
                    control: VectorPoint(CGPoint(x: c.x, y: c.y).applying(t))
                ))
            case .close:
                transformedElements.append(.close)
            }
        }

        targetShape.path = VectorPath(elements: transformedElements, isClosed: targetShape.path.isClosed)
        targetShape.transform = .identity
        targetShape.updateBounds()
        document.layers[layerIndex].shapes[shapeIndex] = targetShape
    }
}
