
import CoreGraphics
import Foundation

func calculateLinkedHandle(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
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
        break
    }

    return calculateLinkedHandleCPU(anchorPoint: anchorPoint, draggedHandle: draggedHandle, originalOppositeHandle: originalOppositeHandle)
}

private func calculateLinkedHandleCPU(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
    let draggedVector = CGPoint(
        x: draggedHandle.x - anchorPoint.x,
        y: draggedHandle.y - anchorPoint.y
    )

    let originalVector = CGPoint(
        x: originalOppositeHandle.x - anchorPoint.x,
        y: originalOppositeHandle.y - anchorPoint.y
    )
    let originalLength = sqrt(originalVector.x * originalVector.x + originalVector.y * originalVector.y)

    let draggedLength = sqrt(draggedVector.x * draggedVector.x + draggedVector.y * draggedVector.y)
    guard draggedLength > 0.1 else { return originalOppositeHandle }

    let normalizedDragged = CGPoint(
        x: draggedVector.x / draggedLength,
        y: draggedVector.y / draggedLength
    )

    let linkedHandle = CGPoint(
        x: anchorPoint.x - normalizedDragged.x * originalLength,
        y: anchorPoint.y - normalizedDragged.y * originalLength
    )

    return linkedHandle
}
