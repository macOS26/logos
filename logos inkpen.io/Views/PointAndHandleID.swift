//
//  PointAndHandleID.swift
//  logos inkpen.io
//
//  Created by Assistant on 1/20/25.
//

import Foundation

// MARK: - Point and Handle Identification Types

/// Identifies a specific anchor point in a vector path
struct PointID: Hashable {
    let shapeID: UUID
    let pathIndex: Int
    let elementIndex: Int
}

/// Identifies a specific control handle for a bezier curve
struct HandleID: Hashable {
    let shapeID: UUID
    let pathIndex: Int
    let elementIndex: Int
    let handleType: HandleType
}

/// Type of control handle for bezier curves
enum HandleType {
    case control1, control2
}

// MARK: - Utility Functions for Coincident Point Detection

/// Static utility to find coincident points for use in views
func findCoincidentPointsStatic(to targetPointID: PointID, in document: VectorDocument, tolerance: Double = 1.0) -> Set<PointID> {
    guard let targetPosition = getPointPosition(targetPointID, in: document) else { return [] }
    
    var coincidentPoints: Set<PointID> = []
    let targetPoint = CGPoint(x: targetPosition.x, y: targetPosition.y)
    
    // Search through all layers and shapes for points at the same location
    for layerIndex in document.layers.indices {
        let layer = document.layers[layerIndex]
        if !layer.isVisible { continue }
        
        for shape in layer.shapes {
            if !shape.isVisible { continue }
            
            // Check each path element for coincident points
            for (elementIndex, element) in shape.path.elements.enumerated() {
                let pointID = PointID(
                    shapeID: shape.id,
                    pathIndex: 0,
                    elementIndex: elementIndex
                )
                
                // Skip the original point itself
                if pointID == targetPointID { continue }
                
                // Extract point location from element
                let elementPoint: CGPoint?
                switch element {
                case .move(let to), .line(let to):
                    elementPoint = CGPoint(x: to.x, y: to.y)
                case .curve(let to, _, _), .quadCurve(let to, _):
                    elementPoint = CGPoint(x: to.x, y: to.y)
                case .close:
                    elementPoint = nil
                }
                
                // Check if this point is coincident with the target
                if let checkPoint = elementPoint {
                    let distance = sqrt(pow(targetPoint.x - checkPoint.x, 2) + pow(targetPoint.y - checkPoint.y, 2))
                    if distance <= tolerance {
                        coincidentPoints.insert(pointID)
                    }
                }
            }
        }
    }
    
    return coincidentPoints
} 