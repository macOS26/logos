//
//  GeometryValidation.swift
//  logos inkpen.io
//
//  Geometry validation and detection utilities
//

import CoreGraphics

/// Check if a path's bounds are finite
func isPathBoundsFinite(_ rect: CGRect) -> Bool {
    return rect.width.isFinite && rect.height.isFinite &&
           rect.origin.x.isFinite && rect.origin.y.isFinite &&
           rect.width > 0 && rect.height > 0
}

/// Check if a point is near a line segment within a tolerance
func isPointNearLineSegment(point: CGPoint, start: CGPoint, end: CGPoint, tolerance: Double) -> Bool {
    // Calculate distance from point to line segment
    let lineVec = CGPoint(x: end.x - start.x, y: end.y - start.y)
    let pointVec = CGPoint(x: point.x - start.x, y: point.y - start.y)
    let lineLength = sqrt(lineVec.x * lineVec.x + lineVec.y * lineVec.y)

    if lineLength < 0.001 {
        // Start and end are the same point
        let dist = sqrt(pointVec.x * pointVec.x + pointVec.y * pointVec.y)
        return dist < tolerance
    }

    let t = max(0, min(1, (pointVec.x * lineVec.x + pointVec.y * lineVec.y) / (lineLength * lineLength)))
    let projection = CGPoint(x: start.x + t * lineVec.x, y: start.y + t * lineVec.y)
    let dist = sqrt(pow(point.x - projection.x, 2) + pow(point.y - projection.y, 2))

    return dist < tolerance
}

/// Check if a point is near a Bezier curve within a tolerance
func isPointNearBezierCurve(point: CGPoint, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tolerance: Double) -> Bool {
    // Sample the curve at several t values
    let steps = 20
    for i in 0...steps {
        let t = Double(i) / Double(steps)
        let curvePoint = bezierPoint(t: t, p0: p0, p1: p1, p2: p2, p3: p3)
        let dist = sqrt(pow(point.x - curvePoint.x, 2) + pow(point.y - curvePoint.y, 2))
        if dist < tolerance {
            return true
        }
    }
    return false
}

/// Calculate a point on a cubic Bezier curve at parameter t
private func bezierPoint(t: Double, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
    let mt = 1.0 - t
    let mt2 = mt * mt
    let mt3 = mt2 * mt
    let t2 = t * t
    let t3 = t2 * t

    let x = mt3 * p0.x + 3 * mt2 * t * p1.x + 3 * mt * t2 * p2.x + t3 * p3.x
    let y = mt3 * p0.y + 3 * mt2 * t * p1.y + 3 * mt * t2 * p2.y + t3 * p3.y

    return CGPoint(x: x, y: y)
}

/// Detect if a series of points forms a straight line
func detectStraightLine(points: [CGPoint]) -> Bool {
    guard points.count >= 3 else { return true }

    let first = points.first!
    let last = points.last!

    // Calculate the expected line
    let dx = last.x - first.x
    let dy = last.y - first.y
    let length = sqrt(dx * dx + dy * dy)

    // If start and end are too close, it's effectively a point
    if length < 5 {
        return false
    }

    // Check all intermediate points
    let tolerance: Double = 3.0 // pixels
    for i in 1..<(points.count - 1) {
        let point = points[i]

        // Distance from point to line
        let t = ((point.x - first.x) * dx + (point.y - first.y) * dy) / (length * length)
        let projection = CGPoint(x: first.x + t * dx, y: first.y + t * dy)
        let distance = sqrt(pow(point.x - projection.x, 2) + pow(point.y - projection.y, 2))

        if distance > tolerance {
            return false
        }
    }

    return true
}

/// Check if a rectangle-based shape (by checking if it has 4 curve elements forming a rectangle)
func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
    // Rectangle-based shapes have exactly 5 elements: move + 4 lines/curves + close
    // Or 4 elements without close
    let elementCount = shape.path.elements.count
    return elementCount == 4 || elementCount == 5 || elementCount == 6
}