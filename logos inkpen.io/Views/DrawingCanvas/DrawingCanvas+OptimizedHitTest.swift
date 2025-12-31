import SwiftUI

extension DrawingCanvas {

    /// Path-only hit testing for direct selection (no bounding box)
    internal func findObjectWithPathHitTest(_ location: CGPoint) -> VectorObject? {
        let validatedLocation = validateAndCorrectLocation(location)

        // Use Metal spatial index for GPU-accelerated candidate lookup
        return metalHitTest(at: validatedLocation) { object, point in
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
                // Text hit test using textPosition and areaSize
                // textPosition is the world position - do NOT apply transform
                let textBounds: CGRect
                if let position = textShape.textPosition, let size = textShape.areaSize {
                    textBounds = CGRect(origin: position, size: size)
                } else {
                    textBounds = CGRect(
                        x: textShape.transform.tx,
                        y: textShape.transform.ty,
                        width: textShape.bounds.width,
                        height: textShape.bounds.height
                    )
                }
                return textBounds.contains(point)

            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                // Shape hit test - path only
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performPathOnlyHitTest(shape: shape, at: point)
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
                // Modern groups use memberIDs
                for memberID in groupShape.memberIDs {
                    groupedChildIDs.insert(memberID)
                }
                // Legacy groups use groupedShapes (deprecated)
                for childShape in groupShape.groupedShapes {
                    groupedChildIDs.insert(childShape.id)
                }
            default:
                break
            }
        }

        // Check if Guides layer (index 2) is the selected layer
        let guidesLayerID = document.snapshot.layers.count > 2 ? document.snapshot.layers[2].id : nil
        let isGuidesLayerSelected = guidesLayerID != nil && document.settings.selectedLayerId == guidesLayerID

        // Use Metal spatial index for GPU-accelerated candidate lookup
        return metalHitTest(at: validatedLocation) { object, point in
            // ARROW TOOL: Skip children that are inside groups - only select the group
            if groupedChildIDs.contains(object.id) {
                return false
            }

            // If Guides layer is selected, only allow selecting guides
            if isGuidesLayerSelected {
                if case .guide = object.objectType {
                    // Allow guide selection
                } else {
                    return false
                }
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
                // Text hit test using textPosition and areaSize
                // textPosition is the world position - do NOT apply transform
                let textBounds: CGRect
                if let position = textShape.textPosition, let size = textShape.areaSize {
                    textBounds = CGRect(origin: position, size: size)
                } else {
                    textBounds = CGRect(
                        x: textShape.transform.tx,
                        y: textShape.transform.ty,
                        width: textShape.bounds.width,
                        height: textShape.bounds.height
                    )
                }
                return textBounds.contains(point)

            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape),
                 .clipGroup(let shape), .clipMask(let shape), .guide(let shape):
                // Shape hit test
                if shape.clippedByShapeID != nil {
                    return false
                } else {
                    return performShapeHitTest(shape: shape, at: point)
                }
            }
        }
    }

    /// Metal-accelerated hit test helper
    private func metalHitTest(at point: CGPoint, testFunction: (VectorObject, CGPoint) -> Bool) -> VectorObject? {
        // Get candidates from GPU spatial index
        let candidates = spatialIndex.candidateObjectIDs(at: point)

        // Iterate layers from top to bottom (reversed)
        for layer in document.snapshot.layers.reversed() {
            guard layer.isVisible else { continue }

            // Test objects in reverse order (top to bottom within layer)
            for objectID in layer.objectIDs.reversed() {
                // Check if this object is a candidate
                guard candidates.contains(objectID) else { continue }

                guard let object = document.snapshot.objects[objectID] else {
                    continue
                }

                if testFunction(object, point) {
                    return object
                }
            }
        }

        return nil
    }
}