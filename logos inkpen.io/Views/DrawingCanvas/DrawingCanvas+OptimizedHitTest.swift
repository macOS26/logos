import SwiftUI

extension DrawingCanvas {

    /// Path-only hit testing for direct selection (no bounding box)
    internal func findObjectWithPathHitTest(_ location: CGPoint) -> VectorObject? {
        let validatedLocation = validateAndCorrectLocation(location)

        // Use Metal spatial index for GPU-accelerated candidate lookup, fallback to CPU
        if let metalIndex = metalSpatialIndex {
            return metalHitTest(at: validatedLocation, metalIndex: metalIndex) { object, point in
            // Skip background shapes
            let shape = object.shape
            if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                return false
            }

            // Check if layer is locked using O(1) index lookup
            let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
            if layer?.isLocked == true {
                return false
            }

            // Perform path-only hit test (no bounding box)
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

            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape):
                // Shape hit test - path only
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performPathOnlyHitTest(shape: shape, at: point)
                }
            }
            }
        } else {
            return spatialIndex.hitTest(at: validatedLocation, in: document.snapshot) { object, point in
            // Skip background shapes
            let shape = object.shape
            if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                return false
            }

            // Check if layer is locked using O(1) index lookup
            let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
            if layer?.isLocked == true {
                return false
            }

            // Perform path-only hit test (no bounding box)
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

            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape):
                // Shape hit test - path only
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performPathOnlyHitTest(shape: shape, at: point)
                }
            }
            }
        }
    }

    /// Optimized hit testing using spatial index for O(1) performance
    internal func findObjectAtLocationOptimized(_ location: CGPoint) -> VectorObject? {
        let validatedLocation = validateAndCorrectLocation(location)

        // Build set of child IDs that are inside groups - arrow tool should skip these
        var groupedChildIDs = Set<UUID>()
        for obj in document.snapshot.objects.values {
            switch obj.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }

        // Use Metal spatial index for GPU-accelerated candidate lookup, fallback to CPU
        if let metalIndex = metalSpatialIndex {
            return metalHitTest(at: validatedLocation, metalIndex: metalIndex) { object, point in
            // ARROW TOOL: Skip children that are inside groups - only select the group
            if groupedChildIDs.contains(object.id) {
                return false
            }

            // Skip background shapes
            let shape = object.shape
            if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                return false
            }

            // Check if layer is locked using O(1) index lookup
            let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
            if layer?.isLocked == true {
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

            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape):
                // Shape hit test
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performShapeHitTest(shape: shape, at: point)
                }
            }
            }
        } else {
            return spatialIndex.hitTest(at: validatedLocation, in: document.snapshot) { object, point in
            // ARROW TOOL: Skip children that are inside groups - only select the group
            if groupedChildIDs.contains(object.id) {
                return false
            }

            // Skip background shapes
            let shape = object.shape
            if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                return false
            }

            // Check if layer is locked using O(1) index lookup
            let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
            if layer?.isLocked == true {
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

            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
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

    /// Metal-accelerated hit test helper
    private func metalHitTest(at point: CGPoint, metalIndex: MetalSpatialIndex, testFunction: (VectorObject, CGPoint) -> Bool) -> VectorObject? {
        // Get candidates from GPU spatial index
        let candidates = metalIndex.candidateObjectIDs(at: point)

        // Iterate layers from top to bottom (reversed)
        for layer in document.snapshot.layers.reversed() {
            guard layer.isVisible else { continue }

            // Test objects in reverse order (top to bottom within layer)
            for objectID in layer.objectIDs.reversed() {
                // Check if this object is a candidate
                guard candidates.contains(objectID) else { continue }

                guard let object = document.snapshot.objects[objectID] else { continue }

                if testFunction(object, point) {
                    return object
                }
            }
        }

        return nil
    }
}