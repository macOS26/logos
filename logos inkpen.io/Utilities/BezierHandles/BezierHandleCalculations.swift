//
//  BezierHandleCalculations.swift
//  logos inkpen.io
//
//  Bezier handle calculation utilities
//

import CoreGraphics
import Foundation

/// Calculates the linked handle position for smooth curve behavior
/// 🚀 GPU-ACCELERATED: Uses Metal compute shaders when available
func calculateLinkedHandle(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
    // 🚀 PHASE 7: Try GPU acceleration first
    let metalEngine = MetalComputeEngine.shared
    let results = metalEngine.calculateLinkedHandlesGPU(
        anchorPoints: [anchorPoint],
        draggedHandles: [draggedHandle],
        originalOppositeHandles: [originalOppositeHandle]
    )
    switch results {
    case .success(let linkedHandles):
        if let result = linkedHandles.first {
            return result
        }
    case .failure:
        // Fallback to CPU calculation
        break
    }

    // CPU fallback
    return calculateLinkedHandleCPU(anchorPoint: anchorPoint, draggedHandle: draggedHandle, originalOppositeHandle: originalOppositeHandle)
}

private func calculateLinkedHandleCPU(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
    // Vector from anchor to dragged handle
    let draggedVector = CGPoint(
        x: draggedHandle.x - anchorPoint.x,
        y: draggedHandle.y - anchorPoint.y
    )

    // Keep the original opposite handle length
    let originalVector = CGPoint(
        x: originalOppositeHandle.x - anchorPoint.x,
        y: originalOppositeHandle.y - anchorPoint.y
    )
    let originalLength = sqrt(originalVector.x * originalVector.x + originalVector.y * originalVector.y)

    // Create opposite vector (180° from dragged handle) with original length
    let draggedLength = sqrt(draggedVector.x * draggedVector.x + draggedVector.y * draggedVector.y)
    guard draggedLength > 0.1 else { return originalOppositeHandle } // Avoid division by zero

    let normalizedDragged = CGPoint(
        x: draggedVector.x / draggedLength,
        y: draggedVector.y / draggedLength
    )

    // Opposite direction with original length
    let linkedHandle = CGPoint(
        x: anchorPoint.x - normalizedDragged.x * originalLength,
        y: anchorPoint.y - normalizedDragged.y * originalLength
    )

    return linkedHandle
}
