//
//  VectorShape+Centroid.swift
//  logos inkpen.io
//
//  Helper extension for calculating the true geometric centroid of shapes
//

import Foundation
import CoreGraphics

extension VectorShape {
    /// Calculate the true geometric centroid (center of mass) of the shape
    /// For polygons, this uses the proper centroid formula, not just the bounding box center
    func calculateCentroid() -> CGPoint {
        var vertices: [CGPoint] = []

        // Extract vertices from path elements
        for element in path.elements {
            switch element {
            case .move(let to):
                vertices.append(CGPoint(x: to.x, y: to.y))
            case .line(let to):
                vertices.append(CGPoint(x: to.x, y: to.y))
            case .curve(let to, _, _):
                // For curves, use the end point (approximation)
                vertices.append(CGPoint(x: to.x, y: to.y))
            case .quadCurve(let to, _):
                // For quad curves, use the end point (approximation)
                vertices.append(CGPoint(x: to.x, y: to.y))
            case .close:
                break // Don't add duplicate of first point
            }
        }

        // If we have less than 3 vertices, fall back to bounds center
        if vertices.count < 3 {
            let shapeBounds = isGroupContainer ? groupBounds : bounds
            return CGPoint(x: shapeBounds.midX, y: shapeBounds.midY)
        }

        // Calculate the signed area and centroid using the polygon centroid formula
        // Cx = (1/6A) * Σ(xi + xi+1)(xi*yi+1 - xi+1*yi)
        // Cy = (1/6A) * Σ(yi + yi+1)(xi*yi+1 - xi+1*yi)

        var signedArea: CGFloat = 0.0
        var cx: CGFloat = 0.0
        var cy: CGFloat = 0.0

        for i in 0..<vertices.count {
            let j = (i + 1) % vertices.count
            let xi = vertices[i].x
            let yi = vertices[i].y
            let xj = vertices[j].x
            let yj = vertices[j].y

            let a = xi * yj - xj * yi
            signedArea += a
            cx += (xi + xj) * a
            cy += (yi + yj) * a
        }

        signedArea *= 0.5

        // Avoid division by zero
        if abs(signedArea) < 0.001 {
            // Degenerate polygon, fall back to average of vertices
            let sumX = vertices.reduce(0.0) { $0 + $1.x }
            let sumY = vertices.reduce(0.0) { $0 + $1.y }
            return CGPoint(x: sumX / CGFloat(vertices.count), y: sumY / CGFloat(vertices.count))
        }

        let factor = 1.0 / (6.0 * signedArea)
        cx *= factor
        cy *= factor

        return CGPoint(x: cx, y: cy)
    }
}