//
//  PointHandlePositionUtilities.swift
//  logos inkpen.io
//
//  Utilities for getting and manipulating point and handle positions
//

import Foundation

/// Get the position of a point from a path element
func getPointPosition(_ pointID: PointID, in unifiedObjects: [VectorObject]) -> VectorPoint? {
    // Find the shape and get the point position using unified objects
    for unifiedObject in unifiedObjects {
        if case .shape(let shape) = unifiedObject.objectType,
           shape.id == pointID.shapeID {
            guard pointID.elementIndex < shape.path.elements.count else { return nil }
            let element = shape.path.elements[pointID.elementIndex]

            switch element {
            case .move(let to), .line(let to):
                return to
            case .curve(let to, _, _), .quadCurve(let to, _):
                return to
            case .close:
                return nil
            }
        }
    }
    return nil
}

/// Get the position of a handle from a path element
func getHandlePosition(_ handleID: HandleID, in unifiedObjects: [VectorObject]) -> VectorPoint? {
    // Find the shape and get the handle position using unified objects
    for unifiedObject in unifiedObjects {
        if case .shape(let shape) = unifiedObject.objectType,
           shape.id == handleID.shapeID {
            guard handleID.elementIndex < shape.path.elements.count else { return nil }
            let element = shape.path.elements[handleID.elementIndex]

            switch element {
            case .curve(_, let control1, let control2):
                return handleID.handleType == .control1 ? control1 : control2
            case .quadCurve(_, let control):
                return handleID.handleType == .control1 ? control : nil
            default:
                return nil
            }
        }
    }
    return nil
}

/// Detects if a point is a smooth curve point (has handles that are not collapsed to the anchor)
func isSmoothCurvePoint(elements: [PathElement], elementIndex: Int) -> Bool {
    guard elementIndex < elements.count else { return false }

    switch elements[elementIndex] {
    case .curve(let to, _, let control2):
        // Check if incoming handle (control2) is not collapsed to anchor point
        let incomingHandleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)

        // Check if outgoing handle (control1 of NEXT element) is not collapsed to anchor point
        var outgoingHandleCollapsed = true // Default to true if no next element
        if elementIndex + 1 < elements.count {
            let nextElement = elements[elementIndex + 1]
            if case .curve(_, let nextControl1, _) = nextElement {
                outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
            }
        }

        // Point is smooth if BOTH handles are NOT collapsed (opposite of corner point logic)
        return !incomingHandleCollapsed && !outgoingHandleCollapsed

    default:
        return false
    }
}

/// Moves handles with an anchor point, maintaining their relative positions
/// This properly handles both smooth curve handles and collapsed handles (corner points)
func moveHandlesWithAnchorPoint(elements: inout [PathElement], elementIndex: Int, delta: CGPoint) {
    guard elementIndex < elements.count else { return }

    switch elements[elementIndex] {
    case .curve(let to, let control1, let control2):
        // Move incoming handle (control2) by the same delta
        // This maintains the handle's position relative to the anchor point
        // If the handle is collapsed to the anchor, it stays collapsed
        let newControl2 = VectorPoint(control2.x + delta.x, control2.y + delta.y)
        elements[elementIndex] = .curve(to: to, control1: control1, control2: newControl2)

        // Move outgoing handle (control1 of NEXT element) if it exists
        if elementIndex + 1 < elements.count {
            let nextElement = elements[elementIndex + 1]
            if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                // Move the outgoing handle by the same delta
                // This maintains its position relative to the anchor point
                let newNextControl1 = VectorPoint(nextControl1.x + delta.x, nextControl1.y + delta.y)
                elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
            }
        }

    case .move(_), .line(_):
        // For move/line elements, check if the NEXT element has an outgoing handle
        if elementIndex + 1 < elements.count {
            let nextElement = elements[elementIndex + 1]
            if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                // Move the outgoing handle by the same delta
                let newNextControl1 = VectorPoint(nextControl1.x + delta.x, nextControl1.y + delta.y)
                elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
            }
        }

    default:
        break
    }
}