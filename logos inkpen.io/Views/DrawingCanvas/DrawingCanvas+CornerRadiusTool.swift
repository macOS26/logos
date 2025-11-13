import SwiftUI

extension DrawingCanvas {

    @ViewBuilder
    func cornerRadiusTool(geometry: GeometryProxy) -> some View {
        if document.viewState.currentTool == .cornerRadius,
           let currentShape = getSelectedRectangleShape() {
            let boundsToUse = getProperShapeBounds(for: currentShape)
            let corners = getCornerScreenPositions(bounds: boundsToUse, shape: currentShape, geometry: geometry)

            // Show live preview during drag using CURRENT shape position
            if isDraggingCorner && !liveCornerRadii.isEmpty {
                cornerRadiusLivePreview(shape: currentShape, geometry: geometry)
            }

            // Use Canvas for all handles - single view, single gesture
            Canvas { context, size in
                for (index, position) in corners.enumerated() {
                    let handlePosition = (isDraggingCorner && draggedCornerIndex == index)
                        ? currentMousePosition
                        : position

                    // Outer circle (orange with white stroke)
                    let outerRect = CGRect(x: handlePosition.x - 6, y: handlePosition.y - 6, width: 12, height: 12)
                    context.fill(Path(ellipseIn: outerRect), with: .color(.orange.opacity(0.8)))
                    context.stroke(Path(ellipseIn: outerRect), with: .color(.white), lineWidth: 2.0)

                    // Inner circle (white)
                    let innerRect = CGRect(x: handlePosition.x - 2, y: handlePosition.y - 2, width: 4, height: 4)
                    context.fill(Path(ellipseIn: innerRect), with: .color(.white))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleCornerRadiusCanvasDrag(
                            value: value,
                            shape: currentShape,
                            corners: corners,
                            geometry: geometry
                        )
                    }
                    .onEnded { _ in
                        finishCornerRadiusToolDrag()
                    }
            )
        }
    }

    @ViewBuilder
    private func cornerRadiusLivePreview(shape: VectorShape, geometry: GeometryProxy) -> some View {
        // Use the transformed path bounds, not originalBounds
        let currentBounds = shape.path.cgPath.boundingBox
        let previewPath = createRoundedRectPathWithIndividualCorners(
            rect: currentBounds,
            cornerRadii: liveCornerRadii
        )

        Path { path in
            addPathElements(previewPath.elements, to: &path)
        }
        .stroke(Color.blue.opacity(0.8), lineWidth: 2.0 / zoomLevel)
        .transformEffect(shape.transform)
        // .scaleEffect(zoomLevel, anchor: UnitPoint.topLeading)
        // .offset(x: canvasOffset.x, y: canvasOffset.y)
    }

    private func handleCornerRadiusCanvasDrag(
        value: DragGesture.Value,
        shape: VectorShape,
        corners: [CGPoint],
        geometry: GeometryProxy
    ) {
        // Determine which corner was clicked (only on first drag event)
        if !isDraggingCorner {
            let hitRadius: CGFloat = 15.0 // Slightly larger hit area
            var nearestIndex: Int?
            var nearestDistance = CGFloat.infinity

            for (index, cornerPosition) in corners.enumerated() {
                let distance = hypot(value.startLocation.x - cornerPosition.x, value.startLocation.y - cornerPosition.y)
                if distance < hitRadius && distance < nearestDistance {
                    nearestDistance = distance
                    nearestIndex = index
                }
            }

            guard let cornerIndex = nearestIndex else { return }

            // Start dragging this corner
            handleCornerRadiusToolDrag(
                cornerIndex: cornerIndex,
                value: value,
                shape: shape,
                geometry: geometry
            )
        } else {
            // Continue dragging
            if let cornerIndex = draggedCornerIndex {
                handleCornerRadiusToolDrag(
                    cornerIndex: cornerIndex,
                    value: value,
                    shape: shape,
                    geometry: geometry
                )
            }
        }
    }

    private func handleCornerRadiusToolDrag(
        cornerIndex: Int,
        value: DragGesture.Value,
        shape: VectorShape,
        geometry: GeometryProxy
    ) {
        // Always get the CURRENT shape from document
        guard let currentShape = getSelectedRectangleShape() else { return }

        if !isDraggingCorner {
            isDraggingCorner = true
            draggedCornerIndex = cornerIndex
            cornerDragStart = value.startLocation
            initialCornerRadius = currentShape.cornerRadii[safe: cornerIndex] ?? 0.0

            sharedOriginalShape = currentShape

            // Capture original corner radii for live state
            originalCornerRadii = currentShape.cornerRadii
            liveCornerRadii = currentShape.cornerRadii
            while liveCornerRadii.count < 4 {
                liveCornerRadii.append(0.0)
            }
        }

        currentMousePosition = value.location

        let canvasLocation = screenToCanvas(value.location, geometry: geometry)
        let canvasStartLocation = screenToCanvas(cornerDragStart, geometry: geometry)
        let direction: CGPoint
        switch cornerIndex {
        case 0:
            direction = CGPoint(x: 1, y: 1)
        case 1:
            direction = CGPoint(x: -1, y: 1)
        case 2:
            direction = CGPoint(x: -1, y: -1)
        case 3:
            direction = CGPoint(x: 1, y: -1)
        default:
            direction = CGPoint(x: 1, y: 1)
        }

        let deltaX = canvasLocation.x - canvasStartLocation.x
        let deltaY = canvasLocation.y - canvasStartLocation.y
        let diagonalMovement = (deltaX * direction.x + deltaY * direction.y) / sqrt(2.0)

        let tentativeRadius = initialCornerRadius + diagonalMovement

        if let originalBounds = currentShape.originalBounds {
            let maxRadius = min(originalBounds.width, originalBounds.height) / 2.0
            let newRadius = max(0.0, min(maxRadius, tentativeRadius))
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)

            // Update live state instead of actual shape during drag
            if isShiftCurrentlyPressed {
                let originalRadius = originalCornerRadii[safe: cornerIndex] ?? 0.0

                if originalRadius > 0 {
                    let ratio = newRadius / originalRadius

                    for i in 0..<4 {
                        let originalCornerRadius = originalCornerRadii[safe: i] ?? 0.0
                        let proportionalRadius = originalCornerRadius * ratio
                        let constrainedRadius = max(0.0, min(maxRadius, proportionalRadius))
                        liveCornerRadii[i] = constrainedRadius
                    }
                } else {
                    for i in 0..<4 {
                        let constrainedRadius = max(0.0, min(maxRadius, newRadius))
                        liveCornerRadii[i] = constrainedRadius
                    }
                }
            } else {
                liveCornerRadii[cornerIndex] = newRadius
            }
        }
    }

    private func finishCornerRadiusToolDrag() {
        if isDraggingCorner {
            // Commit live radii to actual shape
            if let selectedShape = getSelectedRectangleShape() {
                // Round the live radii
                let finalRadii = liveCornerRadii.map { round($0) }

                // Apply final rounded radii to shape
                updateAllCornerRadiiToValues(
                    shapeID: selectedShape.id,
                    cornerRadii: finalRadii
                )
            }

            if let originalShape = sharedOriginalShape,
               let finalShape = getSelectedRectangleShape() {
                var oldShapes: [UUID: VectorShape] = [:]
                var newShapes: [UUID: VectorShape] = [:]
                let objectIDs = [originalShape.id]

                oldShapes[originalShape.id] = originalShape
                newShapes[finalShape.id] = finalShape

                let command = ShapeModificationCommand(objectIDs: objectIDs, oldShapes: oldShapes, newShapes: newShapes)
                document.commandManager.execute(command)
            }

            sharedOriginalShape = nil

            // Clear live state
            liveCornerRadii.removeAll()
            originalCornerRadii.removeAll()

            isDraggingCorner = false
            draggedCornerIndex = nil
            cornerDragStart = .zero
            initialCornerRadius = 0.0
            currentMousePosition = .zero
        }
    }
}
