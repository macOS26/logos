//
//  LayerView+ShapeMask.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics

// Extracted mask view to simplify type-checking of the main body
struct ShapeMaskView: View {
    let maskShape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let dragPreviewDelta: CGPoint
    let isSelected: Bool

    var body: some View {
        Group {
            if maskShape.isGroupContainer {
                GroupMaskContainer(maskShape: maskShape, zoomLevel: zoomLevel, canvasOffset: canvasOffset, dragPreviewDelta: dragPreviewDelta, isSelected: isSelected)
            } else {
                SingleMaskShape(shape: maskShape, zoomLevel: zoomLevel, canvasOffset: canvasOffset, dragPreviewDelta: dragPreviewDelta, isSelected: isSelected)
            }
        }
    }
}

// MARK: - Mask Subviews
struct SingleMaskShape: View {
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let dragPreviewDelta: CGPoint
    let isSelected: Bool

    var body: some View {
        let useEvenOdd = (shape.path.fillRule == .evenOdd)
        return Path { path in
            addPathElements(shape.path.elements, to: &path)
        }
        .fill(Color.black, style: SwiftUI.FillStyle(eoFill: useEvenOdd, antialiased: true))
        // CRITICAL FIX: Apply transformations in EXACTLY the same order as the main ShapeView
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
        // Only apply transform for groups, just like the main ShapeView
        .transformEffect(shape.isGroupContainer ? shape.transform : .identity)
        // CLIPPING MASK LIVE PREVIEW: Apply drag preview for live movement
        .offset(x: isSelected ? dragPreviewDelta.x * zoomLevel : 0,
                y: isSelected ? dragPreviewDelta.y * zoomLevel : 0)
    }
}

struct GroupMaskContainer: View {
    let maskShape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let dragPreviewDelta: CGPoint
    let isSelected: Bool

    var body: some View {
        ZStack {
            ForEach(maskShape.groupedShapes, id: \.id) { grouped in
                SingleMaskShape(shape: grouped, zoomLevel: zoomLevel, canvasOffset: canvasOffset, dragPreviewDelta: dragPreviewDelta, isSelected: isSelected)
            }
        }
        // CRITICAL FIX: Only apply group transform, not zoom/offset (already applied to individual shapes)
        .transformEffect(maskShape.transform)
        // CLIPPING MASK LIVE PREVIEW: Apply drag preview for live movement
        .offset(x: isSelected ? dragPreviewDelta.x * zoomLevel : 0,
                y: isSelected ? dragPreviewDelta.y * zoomLevel : 0)
    }
}
