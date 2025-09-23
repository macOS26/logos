//
//  DrawingCanvas+BezierTool.swift
//  logos inkpen.io
//
//  Bezier tool functionality
//

import SwiftUI

extension DrawingCanvas {
    // MARK: - Bezier Drawing Control
    
    internal func cancelBezierDrawing() {
        // CRITICAL FIX: Ensure incomplete paths get proper colors before canceling
        if let activeBezierShape = activeBezierShape {
            ensureIncompletePathHasProperColors(shape: activeBezierShape)
        }
        
        isBezierDrawing = false
        bezierPath = nil
        bezierPoints.removeAll()
        bezierHandles.removeAll()
        activeBezierPointIndex = nil
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        showClosePathHint = false
        showContinuePathHint = false
        activeBezierShape = nil // Clear the real shape reference
        currentShapeId = nil // Clear the current shape ID
    }
    
    internal func distance(_ p1: CGPoint, _ p2: CGPoint) -> Double {
        return sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2))
    }
    
    private func findNearestSnapPoint(to point: CGPoint) -> CGPoint? {
        let snapTolerance: CGFloat = 10.0 / document.zoomLevel
        var nearestPoint: CGPoint?
        var nearestDistance = snapTolerance
        
        // Check all points in all shapes
        for unifiedObject in document.unifiedObjects {
            if case .shape(let shape) = unifiedObject.objectType {
                // Skip the current shape being drawn
                if let currentId = currentShapeId, shape.id == currentId {
                    continue
                }
                
                // Check all points in the shape's path
                for element in shape.path.elements {
                    switch element {
                    case .move(to: let p), .line(to: let p):
                        let dist = distance(point, CGPoint(x: p.x, y: p.y))
                        if dist < nearestDistance {
                            nearestDistance = dist
                            nearestPoint = CGPoint(x: p.x, y: p.y)
                        }
                    case .curve(to: let p, control1: _, control2: _):
                        let dist = distance(point, CGPoint(x: p.x, y: p.y))
                        if dist < nearestDistance {
                            nearestDistance = dist
                            nearestPoint = CGPoint(x: p.x, y: p.y)
                        }
                    case .close:
                        break
                    case .quadCurve(to: let p, control: _):
                        let dist = distance(point, CGPoint(x: p.x, y: p.y))
                        if dist < nearestDistance {
                            nearestDistance = dist
                            nearestPoint = CGPoint(x: p.x, y: p.y)
                        }
                    @unknown default:
                        break
                    }
                }
            }
        }
        
        return nearestPoint
    }
}
