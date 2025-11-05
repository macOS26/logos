import SwiftUI

extension DrawingCanvas {

    internal func updateLinkedHandle(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) {

        // Check if user explicitly set anchor type to cusp or corner
        if let object = document.snapshot.objects[draggedHandleID.shapeID],
           case .shape(let shape) = object.objectType {

            // Determine anchor element index
            let anchorElementIndex: Int
            if draggedHandleID.handleType == .control2 {
                anchorElementIndex = draggedHandleID.elementIndex
            } else {
                anchorElementIndex = draggedHandleID.elementIndex - 1
            }

            // Check for explicit anchor type
            if let explicitType = shape.anchorTypes[anchorElementIndex] {
                switch explicitType {
                case .cusp, .corner:
                    // User explicitly set cusp or corner - don't link handles
                    return
                case .smooth, .auto:
                    break  // Continue with linking
                }
            }

            // Check coincident point (element 0)
            if let explicitType = shape.anchorTypes[0] {
                // Check if this is a coincident point handle
                let isCoincidentHandle = (draggedHandleID.handleType == .control1 && draggedHandleID.elementIndex == 1) ||
                                        (draggedHandleID.handleType == .control2 && draggedHandleID.elementIndex == elements.count - 1)

                if isCoincidentHandle {
                    switch explicitType {
                    case .cusp, .corner:
                        // User explicitly set cusp or corner for coincident point - don't link
                        return
                    case .smooth, .auto:
                        break  // Continue with linking
                    }
                }
            }
        }

        if handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: draggedHandleID, newDraggedPosition: newDraggedPosition) {
            return
        }

        if draggedHandleID.handleType == .control2 {
            guard case .curve(let anchorTo, let control1, _) = elements[draggedHandleID.elementIndex] else { return }

            let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
            let nextIndex = draggedHandleID.elementIndex + 1
            if nextIndex < elements.count, case .curve(let nextTo, let currentOutgoing, let nextControl2) = elements[nextIndex] {

                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentOutgoing.x, y: currentOutgoing.y)
                )

                elements[draggedHandleID.elementIndex] = .curve(to: anchorTo, control1: control1, control2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[nextIndex] = .curve(to: nextTo, control1: VectorPoint(oppositeHandle.x, oppositeHandle.y), control2: nextControl2)
            }

        } else if draggedHandleID.handleType == .control1 {

            let prevIndex = draggedHandleID.elementIndex - 1
            if prevIndex >= 0, case .curve(let anchorTo, let prevControl1, let currentIncoming) = elements[prevIndex] {

                let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentIncoming.x, y: currentIncoming.y)
                )

                if case .curve(let currentTo, _, let currentControl2) = elements[draggedHandleID.elementIndex] {
                    elements[prevIndex] = .curve(to: anchorTo, control1: prevControl1, control2: VectorPoint(oppositeHandle.x, oppositeHandle.y))
                    elements[draggedHandleID.elementIndex] = .curve(to: currentTo, control1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y), control2: currentControl2)
                }
            }
        }
    }

    internal func optionPressed() -> Bool {
        return isOptionPressed
    }
}
