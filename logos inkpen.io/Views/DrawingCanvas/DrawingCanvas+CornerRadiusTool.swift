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

            ForEach(Array(corners.enumerated()), id: \.offset) { index, screenPosition in
                cornerRadiusHandle(
                    cornerIndex: index,
                    position: (isDraggingCorner && draggedCornerIndex == index)
                        ? currentMousePosition
                        : getCornerScreenPositions(bounds: boundsToUse, shape: currentShape, geometry: geometry)[index],
                    radius: isDraggingCorner && !liveCornerRadii.isEmpty
                        ? (liveCornerRadii[safe: index] ?? 0.0)
                        : (currentShape.cornerRadii[safe: index] ?? 0.0),
                    shape: currentShape,
                    geometry: geometry
                )
            }
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

    @ViewBuilder
    private func cornerRadiusHandle(
        cornerIndex: Int,
        position: CGPoint,
        radius: Double,
        shape: VectorShape,
        geometry: GeometryProxy
    ) -> some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.8))
                .stroke(Color.white, lineWidth: 2.0)
                .frame(width: 12, height: 12)

            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
        .position(position)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    handleCornerRadiusToolDrag(
                        cornerIndex: cornerIndex,
                        value: value,
                        shape: shape,
                        geometry: geometry
                    )
                }
                .onEnded { _ in
                    finishCornerRadiusToolDrag()
                }
        )
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
