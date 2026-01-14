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
                         .clipMask(let shape),
                         .guide(let shape):
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

                document.setSelectionWithUndo([shape.id], ordered: [shape.id])
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
                document.clearSelectionWithUndo()
            }
            return
        }

        // Cmd+Click = Select Behind (cycle through stacked objects like Illustrator)
        if isCommandPressed {
            let objectsAtLocation = findAllObjectsAtLocation(validatedLocation)
            if !objectsAtLocation.isEmpty {
                // Check if we're clicking at the same location (within tolerance)
                let tolerance: CGFloat = 5.0
                let isSameLocation = abs(validatedLocation.x - selectBehindLocation.x) < tolerance &&
                                     abs(validatedLocation.y - selectBehindLocation.y) < tolerance

                if isSameLocation {
                    // Cycle to next object behind
                    selectBehindIndex = (selectBehindIndex + 1) % objectsAtLocation.count
                } else {
                    // New location - start from top
                    selectBehindIndex = 0
                    selectBehindLocation = validatedLocation
                }

                let objectToSelect = objectsAtLocation[selectBehindIndex]
                let previousSelection = document.viewState.selectedObjectIDs
                document.setSelectionWithUndo([objectToSelect.id], ordered: [objectToSelect.id])

                // Trigger updates for affected layers
                var affectedLayers = Set<Int>()
                for objectID in previousSelection {
                    if let object = document.snapshot.objects[objectID] {
                        affectedLayers.insert(object.layerIndex)
                    }
                }
                affectedLayers.insert(objectToSelect.layerIndex)
                document.triggerLayerUpdates(for: affectedLayers)

                document.selectedLayerIndex = objectToSelect.layerIndex
                return
            }
        }

        // OPTIMIZED: Use direct UUID lookups instead of building array
        let hitObject = findObjectAtLocationOptimized(validatedLocation)

        // Reset select behind state on normal click
        if !isCommandPressed {
            selectBehindIndex = 0
            selectBehindLocation = .zero
        }

        if let hitObject = hitObject {

            let objectToSelect = hitObject

            // Track previous selection to trigger only affected layers
            let previousSelection = document.viewState.selectedObjectIDs

            if isShiftPressed {
                // Add to selection
                document.addToSelectionWithUndo(objectToSelect.id)
            } else {
                // Single selection
                document.setSelectionWithUndo([objectToSelect.id], ordered: [objectToSelect.id])
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

                document.clearSelectionWithUndo()

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

    /// Hit test for direct selection - click anywhere on shape to select it
    internal func performPathOnlyHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        // Direct selection uses same hit test as arrow tool
        return performShapeHitTest(shape: shape, at: location)
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

        // Special handling for guides - use tolerance-based hit testing
        if shape.isGuide, let orientation = shape.guideOrientation {
            let guideTolerance: CGFloat = 5.0  // 5px tolerance for guide selection

            // Extract guide position from path
            guard let firstElement = shape.path.elements.first,
                  case .move(let point) = firstElement else {
                return false
            }

            switch orientation {
            case .horizontal:
                let guideY = CGFloat(point.y)
                return abs(location.y - guideY) <= guideTolerance
            case .vertical:
                let guideX = CGFloat(point.x)
                return abs(location.x - guideX) <= guideTolerance
            }
        }

        // Get transformed bounds - exact bounding box only
        let hitBounds = shape.bounds.applying(shape.transform)
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
                 .clipMask(let shape),
                 .guide(let shape):
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
             .clipMask(let shape),
             .guide(let shape):
            return shape
        case .text:
            return nil
        }
    }

    /// Find all objects at a location, ordered from top to bottom (for select behind)
    internal func findAllObjectsAtLocation(_ location: CGPoint) -> [VectorObject] {
        var results: [VectorObject] = []

        // Iterate from top layer to bottom
        for layerIndex in stride(from: document.snapshot.layers.count - 1, through: 0, by: -1) {
            let layer = document.snapshot.layers[layerIndex]
            if layer.isLocked { continue }

            // Iterate from top object to bottom within layer
            for objectID in layer.objectIDs.reversed() {
                guard let object = document.snapshot.objects[objectID] else { continue }
                let shape = object.shape

                // Skip backgrounds
                if shape.name == "Canvas Background" || shape.name == "Pasteboard Background" {
                    continue
                }
                if !shape.isVisible { continue }

                // Hit test
                if performShapeHitTest(shape: shape, at: location) {
                    results.append(object)
                }
            }
        }

        return results
    }
}
