import SwiftUI

// MARK: - Path Building Helpers

@inline(__always)
func addPathElements(_ elements: [PathElement], to path: inout Path) {
    for element in elements {
        switch element {
        case .move(let to, _):
            path.move(to: to.cgPoint)
        case .line(let to, _):
            path.addLine(to: to.cgPoint)
        case .curve(let to, let control1, let control2, _):
            path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
        case .quadCurve(let to, let control, _):
            path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
        case .close:
            path.closeSubpath()
        }
    }
}

// MARK: - Point Type Detection

/// Auto-detects the anchor point type based on handle geometry
/// - Parameters:
///   - element: The current path element (destination point)
///   - prevElement: The previous path element (for incoming handle)
///   - nextElement: The next path element (for outgoing handle)
/// - Returns: Detected point type (corner, cusp, or smooth)
func detectPointType(element: PathElement, prevElement: PathElement?, nextElement: PathElement?) -> AnchorPointType {
    // Extract handles
    var incomingHandle: VectorPoint?
    var outgoingHandle: VectorPoint?
    var anchorPoint: VectorPoint?

    // Get anchor point
    anchorPoint = element.destinationPoint

    // Get incoming handle (control2 from current element if curve)
    switch element {
    case .curve(_, _, let control2, _):
        incomingHandle = control2
    case .quadCurve(_, let control, _):
        incomingHandle = control
    default:
        break
    }

    // Get outgoing handle (control1 from next element if curve)
    if let next = nextElement {
        switch next {
        case .curve(_, let control1, _, _):
            outgoingHandle = control1
        case .quadCurve(_, let control, _):
            outgoingHandle = control
        default:
            break
        }
    }

    guard let anchor = anchorPoint else { return .corner }

    // No handles = corner
    guard let inHandle = incomingHandle, let outHandle = outgoingHandle else {
        return .corner
    }

    // Calculate vectors from anchor to each handle
    let vec1 = CGPoint(x: inHandle.x - anchor.x, y: inHandle.y - anchor.y)
    let vec2 = CGPoint(x: outHandle.x - anchor.x, y: outHandle.y - anchor.y)

    let len1 = sqrt(vec1.x * vec1.x + vec1.y * vec1.y)
    let len2 = sqrt(vec2.x * vec2.x + vec2.y * vec2.y)

    // If either handle is at the anchor, it's a corner
    if len1 < 0.1 || len2 < 0.1 { return .corner }

    // Normalize vectors
    let norm1 = CGPoint(x: vec1.x / len1, y: vec1.y / len1)
    let norm2 = CGPoint(x: vec2.x / len2, y: vec2.y / len2)

    // Calculate dot product (should be -1 for 180 degrees)
    let dot = norm1.x * norm2.x + norm1.y * norm2.y

    // Check if 180° (smooth) - within 2 degrees tolerance
    if dot < -0.9994 {  // cos(178°) ≈ -0.9994
        return .smooth
    }

    // Has handles but not 180° = cusp
    return .cusp
}

/// Auto-detects and sets point types for all elements in a path
func autoDetectPointTypes(elements: inout [PathElement]) {
    guard !elements.isEmpty else { return }

    // Check if path is closed
    let isClosed = elements.last == .close

    for i in 0..<elements.count {
        // Skip .close element
        if case .close = elements[i] {
            continue
        }

        let prevIndex = i - 1
        let nextIndex = i + 1

        var prevElement: PathElement?
        var nextElement: PathElement?

        // Handle wraparound for closed paths
        if isClosed {
            // For first point (index 0), look at last real point (before .close)
            if i == 0 {
                let lastRealIndex = elements.count - 2 // -2 because last is .close
                if lastRealIndex >= 0 && lastRealIndex < elements.count {
                    prevElement = elements[lastRealIndex]
                }
            } else {
                prevElement = prevIndex >= 0 ? elements[prevIndex] : nil
            }

            // For last real point, look at first point
            if i == elements.count - 2 { // Last point before .close
                nextElement = elements[0]
            } else {
                nextElement = nextIndex < elements.count ? elements[nextIndex] : nil
            }
        } else {
            prevElement = prevIndex >= 0 ? elements[prevIndex] : nil
            nextElement = nextIndex < elements.count ? elements[nextIndex] : nil
        }

        let detectedType = detectPointType(
            element: elements[i],
            prevElement: prevElement,
            nextElement: nextElement
        )

        elements[i].setPointType(detectedType)
    }
}
