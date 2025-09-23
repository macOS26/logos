//
//  DrawingCanvas+SnapToPoint.swift
//  logos inkpen.io
//
//  Snap to point functionality for bezier pen tool
//

import SwiftUI

extension DrawingCanvas {

    // MARK: - Point Snap Detection

    /// Structure to hold information about a potential snap point
    struct SnapPoint {
        let point: CGPoint
        let objectID: UUID
        let isAnchor: Bool // true for anchor points, false for control points
        let description: String // For debugging
    }

    /// Find the nearest snap point within a threshold distance
    func findNearestSnapPoint(to point: CGPoint, threshold: CGFloat = 10.0) -> SnapPoint? {
        guard document.snapToPoint else { return nil }

        var nearestSnapPoint: SnapPoint?
        var nearestDistance = threshold

        // Iterate through all objects to find snap points
        for unifiedObject in document.unifiedObjects {
            // Skip hidden or locked objects
            if case .shape(let shape) = unifiedObject.objectType {
                if !shape.isVisible || shape.isLocked {
                    continue
                }

                // Skip the current object being drawn (if applicable)
                if let currentShapeId = currentShapeId, shape.id == currentShapeId {
                    continue
                }

                // Get all points from the shape
                let snapPoints = extractSnapPoints(from: shape)

                // Find the nearest point from this shape
                for snapPoint in snapPoints {
                    let distance = hypot(point.x - snapPoint.point.x, point.y - snapPoint.point.y)
                    if distance < nearestDistance {
                        nearestDistance = distance
                        nearestSnapPoint = snapPoint
                    }
                }
            }
        }

        return nearestSnapPoint
    }

    /// Extract all snap points from a shape
    private func extractSnapPoints(from shape: VectorShape) -> [SnapPoint] {
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

    /// Apply snap to point or grid based on settings
    func applySnapping(to point: CGPoint) -> CGPoint {
        // First check snap to point (has higher priority)
        if document.snapToPoint {
            if let snapPoint = findNearestSnapPoint(to: point) {
                // Store the current snap point for visual feedback
                currentSnapPoint = snapPoint.point
                return snapPoint.point
            } else {
                currentSnapPoint = nil
            }
        }

        // Fall back to snap to grid if enabled
        if document.snapToGrid {
            return snapToGrid(point)
        }

        // No snapping
        currentSnapPoint = nil
        return point
    }

    /// Draw visual feedback for snap to point in view coordinates
    func drawSnapPointFeedback(in context: CGContext, at mousePoint: CGPoint, snapPointView: CGPoint) {
        guard document.snapToPoint else { return }

        // Save the current context state
        context.saveGState()

        // Draw a highlight circle at the snap point
        context.setStrokeColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.8))
        context.setLineWidth(2.0)
        context.setLineDash(phase: 0, lengths: [])

        // Draw outer circle
        context.addEllipse(in: CGRect(x: snapPointView.x - 8, y: snapPointView.y - 8, width: 16, height: 16))
        context.strokePath()

        // Draw inner filled circle
        context.setFillColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.3))
        context.addEllipse(in: CGRect(x: snapPointView.x - 4, y: snapPointView.y - 4, width: 8, height: 8))
        context.fillPath()

        // Draw connection line from cursor to snap point (if not already snapped)
        let distance = hypot(mousePoint.x - snapPointView.x, mousePoint.y - snapPointView.y)
        if distance > 1.0 {
            context.setStrokeColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.4))
            context.setLineWidth(1.0)
            context.setLineDash(phase: 0, lengths: [4, 4])
            context.move(to: mousePoint)
            context.addLine(to: snapPointView)
            context.strokePath()
        }

        // Restore the context state
        context.restoreGState()
    }

    /// Draw visual feedback for snap to point (alternative version that receives canvas point)
    func drawSnapPointFeedback(in context: CGContext, at mousePoint: CGPoint) {
        guard document.snapToPoint, let snapPoint = currentSnapPoint else { return }

        // Transform snap point to view coordinates (this should be done by caller)
        // For now, just draw at the raw snap point since we expect the caller to transform it
        drawSnapPointFeedback(in: context, at: mousePoint, snapPointView: snapPoint)
    }
}
