import SwiftUI

extension DrawingCanvas {

    @ViewBuilder
    func cornerRadiusTool(geometry: GeometryProxy) -> some View {
        if document.currentTool == .cornerRadius,
           let selectedShape = getSelectedRectangleShape() {
            let boundsToUse = getProperShapeBounds(for: selectedShape)
            let corners = getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)

            ForEach(Array(corners.enumerated()), id: \.offset) { index, screenPosition in
                cornerRadiusHandle(
                    cornerIndex: index,
                    position: (isDraggingCorner && draggedCornerIndex == index)
                        ? currentMousePosition
                        : getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)[index],
                    radius: selectedShape.cornerRadii[safe: index] ?? 0.0,
                    shape: selectedShape,
                    geometry: geometry
                )
            }
        }
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
        if !isDraggingCorner {
            isDraggingCorner = true
            draggedCornerIndex = cornerIndex
            cornerDragStart = value.startLocation
            initialCornerRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0

            sharedOriginalShape = shape
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

        if let originalBounds = shape.originalBounds {
            let maxRadius = min(originalBounds.width, originalBounds.height) / 2.0
            let newRadius = max(0.0, min(maxRadius, tentativeRadius))
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {

                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }

                let originalRadius = allRadii[cornerIndex]

                if originalRadius > 0 {
                    let ratio = newRadius / originalRadius

                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        let proportionalRadius = originalCornerRadius * ratio
                        let constrainedRadius = max(0.0, min(maxRadius, proportionalRadius))
                        allRadii[i] = constrainedRadius
                    }

                } else {
                    for i in 0..<4 {
                        let constrainedRadius = max(0.0, min(maxRadius, newRadius))
                        allRadii[i] = constrainedRadius
                    }

                }

                updateAllCornerRadiiToValues(
                    shapeID: shape.id,
                    cornerRadii: allRadii
                )
            } else {
                updateCornerRadiusToValue(
                    shapeID: shape.id,
                    cornerIndex: cornerIndex,
                    newRadius: newRadius
                )
            }
        }
    }

    private func finishCornerRadiusToolDrag() {
        if isDraggingCorner {
            if let selectedShape = getSelectedRectangleShape() {
                let currentRadius = selectedShape.cornerRadii[safe: draggedCornerIndex ?? -1] ?? 0.0
                let roundedRadius = round(currentRadius)

                if abs(currentRadius - roundedRadius) > 0.01 {
                    let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
                    if isShiftCurrentlyPressed {
                        var allRadii = selectedShape.cornerRadii
                        while allRadii.count < 4 {
                            allRadii.append(0.0)
                        }

                        let originalRadius = allRadii[draggedCornerIndex ?? 0]

                        if originalRadius > 0 {
                            let ratio = roundedRadius / originalRadius

                            for i in 0..<4 {
                                let originalCornerRadius = allRadii[i]
                                allRadii[i] = round(originalCornerRadius * ratio)
                            }

                        } else {
                            for i in 0..<4 {
                                allRadii[i] = round(max(0.0, roundedRadius))
                            }

                        }

                        updateAllCornerRadiiToValues(
                            shapeID: selectedShape.id,
                            cornerRadii: allRadii
                        )
                    } else {
                        updateCornerRadiusToValue(
                            shapeID: selectedShape.id,
                            cornerIndex: draggedCornerIndex ?? 0,
                            newRadius: roundedRadius
                        )
                    }
                }
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

            isDraggingCorner = false
            draggedCornerIndex = nil
            cornerDragStart = .zero
            initialCornerRadius = 0.0
            currentMousePosition = .zero

        }
    }
}
