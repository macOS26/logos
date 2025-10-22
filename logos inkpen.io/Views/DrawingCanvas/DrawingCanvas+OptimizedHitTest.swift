import SwiftUI

extension DrawingCanvas {

    /// Optimized hit testing using spatial index for O(1) performance
    internal func findObjectAtLocationOptimized(_ location: CGPoint) -> VectorObject? {
        let validatedLocation = validateAndCorrectLocation(location)

        // Use spatial index for O(1) candidate lookup
        return spatialIndex.hitTest(at: validatedLocation, in: document.snapshot) { object, point in
            // Skip background shapes
            let shape = object.shape
            if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                return false
            }

            // Check if layer is locked
            if let layer = document.snapshot.layers.first(where: { $0.objectIDs.contains(object.id) }),
               layer.isLocked {
                return false
            }

            // Perform hit test based on object type
            switch object.objectType {
            case .text(let textShape):
                // Text hit test using transform position
                let textPos = CGPoint(x: textShape.transform.tx, y: textShape.transform.ty)
                let textBounds = CGRect(
                    x: textPos.x,
                    y: textPos.y,
                    width: textShape.bounds.width,
                    height: textShape.bounds.height
                )
                return textBounds.contains(point)

            case .shape(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape):
                // Shape hit test
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performShapeHitTest(shape: shape, at: point)
                }
            }
        }
    }
}