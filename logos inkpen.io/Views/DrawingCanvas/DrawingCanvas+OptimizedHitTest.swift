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

    /// Direct selection hit test - finds individual paths/text inside groups
    /// Returns (shapeID, isGroupChild) tuple
    internal func findShapeForDirectSelection(_ location: CGPoint) -> (UUID, Bool)? {
        let validatedLocation = validateAndCorrectLocation(location)

        // First check inside groups for child paths and text
        for object in document.snapshot.objects.values {
            // Check if layer is locked
            let layer = object.layerIndex < document.snapshot.layers.count ? document.snapshot.layers[object.layerIndex] : nil
            if layer?.isLocked == true || !layer!.isVisible { continue }

            switch object.objectType {
            case .group(let groupShape), .clipGroup(let groupShape):
                // Check each child shape in the group
                for childShape in groupShape.groupedShapes.reversed() {
                    if !childShape.isVisible || childShape.isLocked { continue }

                    // Check if it's text
                    if childShape.typography != nil {
                        let textBounds: CGRect
                        if let position = childShape.textPosition, let size = childShape.areaSize {
                            textBounds = CGRect(origin: position, size: size)
                        } else {
                            textBounds = CGRect(
                                x: childShape.transform.tx,
                                y: childShape.transform.ty,
                                width: childShape.bounds.width,
                                height: childShape.bounds.height
                            )
                        }
                        if textBounds.contains(validatedLocation) {
                            return (childShape.id, true)
                        }
                    } else if performPathOnlyHitTest(shape: childShape, at: validatedLocation) {
                        return (childShape.id, true)
                    }
                }
            default:
                continue
            }
        }

        // Then check top-level objects
        if let hitObject = findObjectWithPathHitTest(location) {
            return (hitObject.id, false)
        }

        return nil
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

        // Use Metal spatial index for GPU-accelerated candidate lookup
        return metalHitTest(at: validatedLocation) { object, point in
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

    /// Metal-accelerated hit test helper
    private func metalHitTest(at point: CGPoint, testFunction: (VectorObject, CGPoint) -> Bool) -> VectorObject? {
        // Get candidates from GPU spatial index
        let candidates = spatialIndex.candidateObjectIDs(at: point)
        print("🔍 Hit test at \(point) found \(candidates.count) candidates")

        // Iterate layers from top to bottom (reversed)
        for layer in document.snapshot.layers.reversed() {
            guard layer.isVisible else { continue }

            // Test objects in reverse order (top to bottom within layer)
            for objectID in layer.objectIDs.reversed() {
                // Check if this object is a candidate
                guard candidates.contains(objectID) else { continue }

                guard let object = document.snapshot.objects[objectID] else {
                    print("  ❌ Object not found for ID: \(objectID)")
                    continue
                }

                let testResult = testFunction(object, point)
                print("  🎯 Testing object \(objectID): testResult=\(testResult)")
                if testResult {
                    return object
                }
            }
        }

        return nil
    }
}