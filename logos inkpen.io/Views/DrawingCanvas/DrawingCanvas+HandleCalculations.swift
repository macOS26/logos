import SwiftUI

extension DrawingCanvas {

    internal func updateLinkedHandle(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) {

        if handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: draggedHandleID, newDraggedPosition: newDraggedPosition) {
            return
        }

        if draggedHandleID.handleType == .control2 {
            guard case .curve(let anchorTo, let control1, _, let pointType) = elements[draggedHandleID.elementIndex] else { return }

            let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
            let nextIndex = draggedHandleID.elementIndex + 1
            if nextIndex < elements.count, case .curve(let nextTo, let currentOutgoing, let nextControl2, let nextPointType) = elements[nextIndex] {

                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentOutgoing.x, y: currentOutgoing.y)
                )

                elements[draggedHandleID.elementIndex] = .curve(to: anchorTo, control1: control1, control2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y), pointType: pointType)
                elements[nextIndex] = .curve(to: nextTo, control1: VectorPoint(oppositeHandle.x, oppositeHandle.y), control2: nextControl2, pointType: nextPointType)
            }

        } else if draggedHandleID.handleType == .control1 {

            let prevIndex = draggedHandleID.elementIndex - 1
            if prevIndex >= 0, case .curve(let anchorTo, let prevControl1, let currentIncoming, let prevPointType) = elements[prevIndex] {

                let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentIncoming.x, y: currentIncoming.y)
                )

                if case .curve(let currentTo, _, let currentControl2, let currentPointType) = elements[draggedHandleID.elementIndex] {
                    elements[prevIndex] = .curve(to: anchorTo, control1: prevControl1, control2: VectorPoint(oppositeHandle.x, oppositeHandle.y), pointType: prevPointType)
                    elements[draggedHandleID.elementIndex] = .curve(to: currentTo, control1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y), control2: currentControl2, pointType: currentPointType)
                }
            }
        }
    }

    internal func optionPressed() -> Bool {
        return isOptionPressed
    }
}
