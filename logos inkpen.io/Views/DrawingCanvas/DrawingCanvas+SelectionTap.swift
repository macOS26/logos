import SwiftUI
import Combine

extension DrawingCanvas {

    internal func handleSelectionTap(at location: CGPoint) {
        let validatedLocation = validateAndCorrectLocation(location)

        if isOptionPressed && document.viewState.currentTool == .selection {
            document.viewState.currentTool = .directSelection
            handleDirectSelectionTap(at: validatedLocation)
            return
        }

        // Note: Cmd key temporary switch to direct selection is handled by AppEventMonitor

        if isControlPressed && document.viewState.currentTool == .selection {
            var clickedShape: VectorShape?

            // Iterate through layers from top to bottom (reversed)
            for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
                let layer = document.snapshot.layers[layerIndex]
                if layerIndex < document.snapshot.layers.count && document.snapshot.layers[layerIndex].isLocked {
                    continue
                }

                // Iterate through objects in layer from top to bottom (reversed)
                for objectID in layer.objectIDs.reversed() {
                    guard let object = document.snapshot.objects[objectID] else { continue }

                    switch object.objectType {
                    case .shape(let shape),
                         .image(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape):
                        if !shape.isVisible { continue }

                        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                        if isBackgroundShape { continue }

                        let isHit = performShapeHitTest(shape: shape, at: validatedLocation)

                        if isHit {
                            clickedShape = shape
                            break
                        }
                    case .text:
                        continue
                    }
                }

                if clickedShape != nil {
                    break
                }
            }

            if let shape = clickedShape, isRectangleBasedShape(shape) {
                if !shape.isRoundedRectangle {
                }

                // Track previous selection to trigger only affected layers
                let previousSelection = document.viewState.selectedObjectIDs

                document.viewState.selectedObjectIDs = [shape.id]
                isCornerRadiusEditMode = true

                // Trigger updates for affected layers only
                var affectedLayers = Set<Int>()
                // Add layers from previously selected objects
                for objectID in previousSelection {
                    if let object = document.snapshot.objects[objectID] {
                        affectedLayers.insert(object.layerIndex)
                    }
                }
                // Add layer from newly selected object
                if let object = document.snapshot.objects[shape.id] {
                    affectedLayers.insert(object.layerIndex)
                }
                document.triggerLayerUpdates(for: affectedLayers)

                selectedPoints.removeAll()
                selectedHandles.removeAll()
                selectedObjectIDs.removeAll()

                return
            } else if clickedShape != nil {
            }
        }

        // Clear direct selection state (points/handles) but DON'T sync to document yet
        // We'll handle document.viewState.selectedObjectIDs based on the tap logic below
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        selectedObjectIDs.removeAll()
        isCornerRadiusEditMode = false

        guard document.viewState.currentTool == .selection ||
              document.viewState.currentTool == .scale ||
              document.viewState.currentTool == .rotate ||
              document.viewState.currentTool == .shear ||
              document.viewState.currentTool == .warp else {
            // For non-selection tools, deselect when clicking empty space
            if !isShiftPressed && !isCommandPressed {
                document.viewState.selectedObjectIDs = []
            }
            return
        }

        // OPTIMIZED: Use direct UUID lookups instead of building array
        let hitObject = findObjectAtLocationOptimized(validatedLocation)

        if let hitObject = hitObject {

            let objectToSelect = hitObject

            // Track previous selection to trigger only affected layers
            let previousSelection = document.viewState.selectedObjectIDs

            if isShiftPressed {
                document.viewState.selectedObjectIDs.insert(objectToSelect.id)
            } else if isCommandPressed {
                if document.viewState.selectedObjectIDs.contains(objectToSelect.id) {
                    document.viewState.selectedObjectIDs.remove(objectToSelect.id)
                } else {
                    document.viewState.selectedObjectIDs.insert(objectToSelect.id)
                }
            } else {
                document.viewState.selectedObjectIDs = [objectToSelect.id]
            }

            // Trigger updates for affected layers only
            var affectedLayers = Set<Int>()
            // Add layers from previously selected objects
            for objectID in previousSelection {
                if let object = document.snapshot.objects[objectID] {
                    affectedLayers.insert(object.layerIndex)
                }
            }
            // Add layers from newly selected objects
            for objectID in document.viewState.selectedObjectIDs {
                if let object = document.snapshot.objects[objectID] {
                    affectedLayers.insert(object.layerIndex)
                }
            }
            document.triggerLayerUpdates(for: affectedLayers)

            if case .text = objectToSelect.objectType {
                document.viewState.transformOrigin = .topLeft
            }

            document.selectedLayerIndex = objectToSelect.layerIndex

            if let selectedColor = document.getSelectedObjectColor() {
                if document.viewState.activeColorTarget == .stroke {
                    document.defaultStrokeColor = selectedColor
                } else {
                    document.defaultFillColor = selectedColor
                }
            }
        } else {
            // Nothing was hit - deselect unless modifier keys pressed
            if !isShiftPressed && !isCommandPressed {
                // Track previous selection to trigger only affected layers
                let previousSelection = document.viewState.selectedObjectIDs

                document.viewState.selectedObjectIDs = []

                // Trigger updates for previously selected layers only
                var affectedLayers = Set<Int>()
                for objectID in previousSelection {
                    if let object = document.snapshot.objects[objectID] {
                        affectedLayers.insert(object.layerIndex)
                    }
                }
                document.triggerLayerUpdates(for: affectedLayers)

                // Clear local selection state
                selectedPoints.removeAll()
                selectedHandles.removeAll()
                selectedObjectIDs.removeAll()

                // Sync with document to ensure UI updates
                syncDirectSelectionWithDocument()
                isCornerRadiusEditMode = false
            }
        }
    }

    /// Path-only hit test for direct selection (no bounding box)
    internal func performPathOnlyHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        if shape.typography != nil {
            let textBounds = CGRect(
                x: shape.transform.tx,
                y: shape.transform.ty,
                width: shape.bounds.width,
                height: shape.bounds.height
            )
            return textBounds.contains(location)
        }

        // Direct selection always uses path hit test
        let baseTolerance: CGFloat = 8.0
        let tolerance = max(2.0, baseTolerance / zoomLevel)
        return PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
    }

    internal func performShapeHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        // Bounds-only hit testing - no tolerance

        if shape.typography != nil {
            let textBounds: CGRect
            if let position = shape.textPosition, let size = shape.areaSize {
                textBounds = CGRect(origin: position, size: size)
            } else {
                textBounds = CGRect(
                    x: shape.transform.tx,
                    y: shape.transform.ty,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )
            }
            return textBounds.contains(location)
        }

        // Groups use groupBounds
        if shape.isGroupContainer {
            return shape.groupBounds.contains(location)
        }

        // Get transformed bounds
        var hitBounds = shape.bounds.applying(shape.transform)

        // For stroked shapes, expand bounds by half stroke width
        if let strokeStyle = shape.strokeStyle {
            let halfStroke = strokeStyle.width / 2.0
            hitBounds = hitBounds.insetBy(dx: -halfStroke, dy: -halfStroke)
        }

        return hitBounds.contains(location)
    }

     internal func validateAndCorrectLocation(_ location: CGPoint) -> CGPoint {
         if location.x.isNaN || location.y.isNaN || location.x.isInfinite || location.y.isInfinite {
             Log.error("❌ INVALID COORDINATES: \(location) - using zero point", category: .error)
             return .zero
         }

         let maxReasonableValue: CGFloat = 1000000.0
         if abs(location.x) > maxReasonableValue || abs(location.y) > maxReasonableValue {
             Log.error("❌ EXTREME COORDINATES: \(location) - using zero point", category: .error)
             return .zero
         }

         return location
     }

    private func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }

    private func isLocationWithinSelectionBox(_ location: CGPoint) -> Bool {
        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }

            switch object.objectType {
            case .text(let shape):
                let textContentArea = CGRect(
                    x: CGPoint(x: shape.transform.tx, y: shape.transform.ty).x,
                    y: CGPoint(x: shape.transform.tx, y: shape.transform.ty).y,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )
                let contains = textContentArea.contains(location)

                if contains {
                    return true
                }
            case .shape(let shape),
                 .image(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                let transformedBounds = shape.bounds.applying(shape.transform)
                let selectionBoxBounds = transformedBounds.insetBy(dx: 0, dy: 0)
                let contains = selectionBoxBounds.contains(location)

                if contains {
                    return true
                }
            }
        }

        return false
    }

    private func findShapeByID(_ shapeID: UUID) -> VectorShape? {
        guard let object = document.snapshot.objects[shapeID] else { return nil }

        switch object.objectType {
        case .shape(let shape),
             .image(let shape),
             .warp(let shape),
             .group(let shape),
             .clipGroup(let shape),
             .clipMask(let shape):
            return shape
        case .text:
            return nil
        }
    }
}
