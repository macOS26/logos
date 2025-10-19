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

        if isCommandPressed && document.viewState.currentTool == .selection {
            var hitShape: VectorShape?
            var hitLayerIndex: Int?
            outerHit: for unifiedObject in document.unifiedObjects.reversed() {
                if unifiedObject.layerIndex < document.layers.count {
                    let layer = document.layers[unifiedObject.layerIndex]
                    if layer.isLocked { continue }
                }

                switch unifiedObject.objectType {
                case .text(let shape):
                    if !shape.isVisible { continue }
                    // Get text position from transform and create hit area
                    let textPos = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                    let textArea = CGRect(x: textPos.x, y: textPos.y, width: shape.bounds.width, height: shape.bounds.height)
                    if textArea.contains(validatedLocation) {
                        hitShape = shape
                        hitLayerIndex = unifiedObject.layerIndex
                        break outerHit
                    }
                case .shape(let shape),
                     .warp(let shape),
                     .group(let shape),
                     .clipGroup(let shape),
                     .clipMask(let shape):
                    if !shape.isVisible { continue }
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    if isBackgroundShape { continue }

                    let baseTolerance: CGFloat = 8.0
                    let tolerance = max(2.0, baseTolerance / document.viewState.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: validatedLocation, tolerance: tolerance)

                    if isHit {
                        hitShape = shape
                        hitLayerIndex = unifiedObject.layerIndex
                        break outerHit
                    }
                }
            }
            if let shape = hitShape, let layerIndex = hitLayerIndex {
                let isAlreadySelected = document.selectedShapeIDs.contains(shape.id)
                if isAlreadySelected {
                    document.viewState.currentTool = .directSelection
                    directSelectedShapeIDs = [shape.id]
                    selectedPoints.removeAll()
                    selectedHandles.removeAll()
                    syncDirectSelectionWithDocument()
                    document.selectedLayerIndex = layerIndex
                } else {
                    document.selectedTextIDs.removeAll()
                    if isShiftPressed {
                        document.selectedShapeIDs.insert(shape.id)
                    } else {
                        document.selectedShapeIDs = [shape.id]
                    }
                    document.selectedLayerIndex = layerIndex
                }
            }
            return
        }

        if isControlPressed && document.viewState.currentTool == .selection {
            var clickedShape: VectorShape?

            for unifiedObject in document.unifiedObjects.reversed() {
                if unifiedObject.layerIndex < document.layers.count {
                    let layer = document.layers[unifiedObject.layerIndex]
                    if layer.isLocked { continue }
                }

                switch unifiedObject.objectType {
                case .shape(let shape),
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

            if let shape = clickedShape, isRectangleBasedShape(shape) {
                if !shape.isRoundedRectangle {
                }

                document.selectedShapeIDs = [shape.id]
                isCornerRadiusEditMode = true

                selectedPoints.removeAll()
                selectedHandles.removeAll()
                directSelectedShapeIDs.removeAll()

                return
            } else if clickedShape != nil {
            }
        }

        selectedPoints.removeAll()
        selectedHandles.removeAll()
        directSelectedShapeIDs.removeAll()
        syncDirectSelectionWithDocument()
        isCornerRadiusEditMode = false

        guard document.viewState.currentTool == .selection ||
              document.viewState.currentTool == .scale ||
              document.viewState.currentTool == .rotate ||
              document.viewState.currentTool == .shear ||
              document.viewState.currentTool == .warp else {
            // For non-selection tools, deselect when clicking empty space
            if !isShiftPressed && !isCommandPressed {
                document.selectedObjectIDs = []
                document.syncSelectionArrays()
            }
            return
        }

        var hitObject: VectorObject?
        let objectsInOrder = document.getObjectsInStackingOrder()

        for unifiedObject in objectsInOrder.reversed() {
            if unifiedObject.layerIndex < document.layers.count {
                let layer = document.layers[unifiedObject.layerIndex]
                if !layer.isVisible {
                    continue
                }
                if layer.isLocked {
                    continue
                }
            }

            var isHit = false

            switch unifiedObject.objectType {
            case .text(let shape):
                if !shape.isVisible || shape.isLocked { continue }

                // Get position from transform (tx, ty are the translation components)
                let textPos = CGPoint(x: shape.transform.tx, y: shape.transform.ty)
                let textContentArea = CGRect(
                    x: textPos.x,
                    y: textPos.y,
                    width: shape.bounds.width,
                    height: shape.bounds.height
                )

                let contentHit = textContentArea.contains(validatedLocation)
                isHit = contentHit
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if !shape.isVisible { continue }

                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                if isBackgroundShape {
                    continue
                }

                if shape.clippedByShapeID != nil {
                    isHit = false
                } else if shape.isClippingPath {
                    let baseTolerance: CGFloat = 8.0
                    let tolerance = max(2.0, baseTolerance / document.viewState.zoomLevel)
                    isHit = PathOperations.hitTest(shape.transformedPath, point: validatedLocation, tolerance: tolerance)
                } else {
                    isHit = performShapeHitTest(shape: shape, at: validatedLocation)
                }
            }

            if isHit {
                hitObject = unifiedObject
                break
            }
        }

        if let hitObject = hitObject {

            let objectToSelect = hitObject

            if isShiftPressed {
                document.selectedObjectIDs.insert(objectToSelect.id)
            } else if isCommandPressed {
                if document.selectedObjectIDs.contains(objectToSelect.id) {
                    document.selectedObjectIDs.remove(objectToSelect.id)
                } else {
                    document.selectedObjectIDs.insert(objectToSelect.id)
                }
            } else {
                document.selectedObjectIDs = [objectToSelect.id]
            }

            if case .text = objectToSelect.objectType {
                document.transformOrigin = .topLeft
            }

            document.selectedLayerIndex = objectToSelect.layerIndex

            document.syncSelectionArrays()

            if let selectedColor = document.getSelectedObjectColor() {
                if document.activeColorTarget == .stroke {
                    document.defaultStrokeColor = selectedColor
                } else {
                    document.defaultFillColor = selectedColor
                }
            }
        } else {
            // Nothing was hit - deselect unless modifier keys pressed
            if !isShiftPressed && !isCommandPressed {
                document.selectedObjectIDs = []
                document.syncSelectionArrays()

                selectedPoints.removeAll()
                selectedHandles.removeAll()
                directSelectedShapeIDs.removeAll()
                syncDirectSelectionWithDocument()
                isCornerRadiusEditMode = false
            }
        }
    }

    private func performShapeHitTest(shape: VectorShape, at location: CGPoint) -> Bool {
        if shape.typography != nil {
            let textBounds = CGRect(
                x: shape.transform.tx,
                y: shape.transform.ty,
                width: shape.bounds.width,
                height: shape.bounds.height
            )
            let isHit = textBounds.contains(location)
            return isHit
        }

        if isOptionPressed {
            let baseTolerance: CGFloat = 8.0
            let tolerance = max(2.0, baseTolerance / document.viewState.zoomLevel)
            let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
            return isHit
        } else {
            let isImageShape = ImageContentRegistry.containsImage(shape)
            let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)

            if isImageShape {
                let transformedBounds = shape.bounds.applying(shape.transform)
                if transformedBounds.contains(location) {
                    return true
                } else {
                    let baseTolerance: CGFloat = 4.0
                    let tolerance = max(1.0, baseTolerance / document.viewState.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                    return isHit
                }
            } else if isStrokeOnly && shape.strokeStyle != nil {
                let strokeWidth = shape.strokeStyle?.width ?? 1.0
                let strokeTolerance = max(12.0, strokeWidth + 8.0)
                let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: strokeTolerance)
                return isHit
            } else {
                let transformedBounds = shape.bounds.applying(shape.transform)

                if transformedBounds.contains(location) {
                    return true
                } else {
                    let baseTolerance: CGFloat = 4.0
                    let tolerance = max(1.0, baseTolerance / document.viewState.zoomLevel)
                    let isHit = PathOperations.hitTest(shape.transformedPath, point: location, tolerance: tolerance)
                    return isHit
                }
            }
        }
    }

     private func validateAndCorrectLocation(_ location: CGPoint) -> CGPoint {
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
        for objectID in document.selectedObjectIDs {
            if let unifiedObject = document.findObject(by: objectID) {
                switch unifiedObject.objectType {
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
        }

        return false
    }

    private func findShapeByID(_ shapeID: UUID) -> VectorShape? {
        for unifiedObject in document.unifiedObjects {
            switch unifiedObject.objectType {
            case .shape(let shape),
                 .warp(let shape),
                 .group(let shape),
                 .clipGroup(let shape),
                 .clipMask(let shape):
                if shape.id == shapeID {
                    return shape
                }
            case .text:
                continue
            }
        }
        return nil
    }
}
