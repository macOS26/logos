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

        // Check if guides are locked
        let guidesLocked = document.gridSettings.guidesLocked

        // Use Metal spatial index for GPU-accelerated candidate lookup
        return metalHitTest(at: validatedLocation) { object, point in
            // ARROW TOOL: Skip children that are inside groups - only select the group
            if groupedChildIDs.contains(object.id) {
                return false
            }

            // If Guides layer is selected, only allow selecting guides
            if isGuidesLayerSelected {
                if case .guide = object.objectType {
                    // Allow guide selection (unless locked)
                    if guidesLocked {
                        return false
                    }
                } else {
                    return false
                }
            }

            // Allow guide selection from any layer (unless guides are locked)
            if case .guide = object.objectType {
                if guidesLocked {
                    return false
                }
                // Guides can be selected - continue to hit test
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

    /// Find guide at location for hover detection (returns guide orientation if hovering over a guide)
    internal func findGuideAtLocation(_ location: CGPoint) -> Guide.Orientation? {
        let validatedLocation = validateAndCorrectLocation(location)

        // Check if guides are visible and not locked
        guard document.snapshot.layers.count > 2,
              document.snapshot.layers[2].isVisible,
              !document.gridSettings.guidesLocked else {
            return nil
        }

        let guidesLayer = document.snapshot.layers[2]
        let guideTolerance: CGFloat = 5.0

        // Check all guides in the Guides layer
        for objectID in guidesLayer.objectIDs {
            guard let object = document.snapshot.objects[objectID],
                  case .guide(let shape) = object.objectType,
                  let orientation = shape.guideOrientation else {
                continue
            }

            // Get guide position from path
            guard let firstElement = shape.path.elements.first,
                  case .move(let point) = firstElement else {
                continue
            }

            switch orientation {
            case .horizontal:
                let guideY = CGFloat(point.y)
                if abs(validatedLocation.y - guideY) <= guideTolerance {
                    return .horizontal
                }
            case .vertical:
                let guideX = CGFloat(point.x)
                if abs(validatedLocation.x - guideX) <= guideTolerance {
                    return .vertical
                }
            }
        }

        return nil
    }
}