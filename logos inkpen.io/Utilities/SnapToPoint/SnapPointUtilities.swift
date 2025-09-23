//
//  SnapPointUtilities.swift
//  logos inkpen.io
//
//  Snap to point utilities for bezier pen tool
//

import Foundation
import CoreGraphics

/// Structure to hold information about a potential snap point
struct SnapPoint {
    let point: CGPoint
    let objectID: UUID
    let isAnchor: Bool // true for anchor points, false for control points
    let description: String // For debugging
}

/// Extract all snap points from a shape
func extractSnapPoints(from shape: VectorShape) -> [SnapPoint] {
    var snapPoints: [SnapPoint] = []

    // Handle text objects
    if shape.isTextObject {
        // For text objects, snap to the corners of the text bounds
        let bounds = shape.bounds
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Text top-left"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Text top-right"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Text bottom-left"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Text bottom-right"))
        snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Text center"))
        return snapPoints
    }

    // Handle regular shapes
    // Add all anchor points and control points from the path
    for element in shape.path.elements {
        switch element {
        case .move(to: let point):
            snapPoints.append(SnapPoint(point: point.cgPoint, objectID: shape.id, isAnchor: true, description: "Move to"))

        case .line(to: let point):
            snapPoints.append(SnapPoint(point: point.cgPoint, objectID: shape.id, isAnchor: true, description: "Line to"))

        case .curve(to: let endPoint, control1: let control1, control2: let control2):
            snapPoints.append(SnapPoint(point: endPoint.cgPoint, objectID: shape.id, isAnchor: true, description: "Curve end"))
            snapPoints.append(SnapPoint(point: control1.cgPoint, objectID: shape.id, isAnchor: false, description: "Control 1"))
            snapPoints.append(SnapPoint(point: control2.cgPoint, objectID: shape.id, isAnchor: false, description: "Control 2"))

        case .quadCurve(to: let endPoint, control: let control):
            snapPoints.append(SnapPoint(point: endPoint.cgPoint, objectID: shape.id, isAnchor: true, description: "Quad curve end"))
            snapPoints.append(SnapPoint(point: control.cgPoint, objectID: shape.id, isAnchor: false, description: "Quad control"))

        case .close:
            break // No point to add
        }
    }

    // Add bounding box corners and center for all shapes
    let bounds = shape.bounds
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Top-left"))
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Top-right"))
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Bottom-left"))
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Bottom-right"))
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Center"))

    // Add midpoints of edges
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.minY), objectID: shape.id, isAnchor: true, description: "Top-center"))
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.midX, y: bounds.maxY), objectID: shape.id, isAnchor: true, description: "Bottom-center"))
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.minX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Left-center"))
    snapPoints.append(SnapPoint(point: CGPoint(x: bounds.maxX, y: bounds.midY), objectID: shape.id, isAnchor: true, description: "Right-center"))

    // Apply the shape's transform to all points
    let transformedSnapPoints = snapPoints.map { snapPoint in
        let transformedPoint = snapPoint.point.applying(shape.transform)
        return SnapPoint(point: transformedPoint, objectID: snapPoint.objectID, isAnchor: snapPoint.isAnchor, description: snapPoint.description)
    }

    return transformedSnapPoints
}
