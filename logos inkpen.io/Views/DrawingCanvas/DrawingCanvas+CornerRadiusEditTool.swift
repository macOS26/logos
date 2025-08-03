//
//  DrawingCanvas+CornerRadiusEditTool.swift
//  logos inkpen.io
//
//  Live corner radius editing tool (Adobe Illustrator style)
//

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Corner Radius Edit Tool
    
    /// Shows corner radius edit controls when a rounded rectangle is selected
    @ViewBuilder
    func cornerRadiusEditTool(geometry: GeometryProxy) -> some View {
        if let selectedShape = getSelectedRoundedRectangle() {
            
            // Get corner positions in screen coordinates
            if let originalBounds = selectedShape.originalBounds {
                let corners = getCornerScreenPositions(bounds: originalBounds, shape: selectedShape, geometry: geometry)
                
                ForEach(Array(corners.enumerated()), id: \.offset) { index, screenPosition in
                    cornerRadiusHandle(
                        cornerIndex: index,
                        position: (isDraggingCorner && draggedCornerIndex == index) 
                            ? currentMousePosition
                            : screenPosition,
                        radius: selectedShape.cornerRadii[safe: index] ?? 0.0,
                        shape: selectedShape,
                        geometry: geometry
                    )
                }
            }
        }
    }
    
    /// Individual corner radius handle
    @ViewBuilder
    private func cornerRadiusHandle(
        cornerIndex: Int,
        position: CGPoint,
        radius: Double,
        shape: VectorShape,
        geometry: GeometryProxy
    ) -> some View {
        ZStack {
            // Outer circle
            Circle()
                .fill(Color.orange.opacity(0.8))
                .stroke(Color.white, lineWidth: 2.0)
                .frame(width: 12, height: 12)
            
            // Inner dot
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
        .position(position)
        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    handleCornerRadiusDrag(
                        cornerIndex: cornerIndex,
                        value: value,
                        shape: shape,
                        geometry: geometry
                    )
                }
                .onEnded { _ in
                    finishCornerRadiusDrag()
                }
        )
    }
    
    // MARK: - Helper Functions
    
    /// Get the currently selected rounded rectangle
    private func getSelectedRoundedRectangle() -> VectorShape? {
        guard document.selectedShapeIDs.count == 1 else { return nil }
        
        for layer in document.layers {
            for shape in layer.shapes {
                if document.selectedShapeIDs.contains(shape.id) && shape.isRoundedRectangle {
                    return shape
                }
            }
        }
        return nil
    }
    
    /// Get corner handle positions on the actual curves (not at rectangle corners)
    private func getCornerScreenPositions(bounds: CGRect, shape: VectorShape, geometry: GeometryProxy) -> [CGPoint] {
        // Apply shape transform to bounds
        let transform = shape.transform
        let transformedBounds = bounds.applying(transform)
        
        // Calculate curve handle positions (on the curve at 45-degree angle from corner)
        var curvePositions: [CGPoint] = []
        
        let cornerPositions = [
            CGPoint(x: transformedBounds.minX, y: transformedBounds.minY), // Top-left
            CGPoint(x: transformedBounds.maxX, y: transformedBounds.minY), // Top-right
            CGPoint(x: transformedBounds.maxX, y: transformedBounds.maxY), // Bottom-right
            CGPoint(x: transformedBounds.minX, y: transformedBounds.maxY)  // Bottom-left
        ]
        
        for (index, corner) in cornerPositions.enumerated() {
            let radius = shape.cornerRadii[safe: index] ?? 0.0
            
            // When radius is 0, handle should be at the corner (square)
            // When radius > 0, handle should be on the curve at 45-degree angle
            let curvePosition: CGPoint
            
            if radius <= 0.0 {
                // Square corner - handle at corner
                curvePosition = corner
            } else {
                // Rounded corner - handle on curve at 45-degree angle
                // Distance from corner to curve point = radius / sqrt(2)
                let curveDistance = radius / sqrt(2.0)
                
                // Direction vectors for each corner (45-degree inward diagonal)
                let direction: CGPoint
                switch index {
                case 0: // Top-left: move right and down
                    direction = CGPoint(x: 1, y: 1)
                case 1: // Top-right: move left and down
                    direction = CGPoint(x: -1, y: 1)
                case 2: // Bottom-right: move left and up
                    direction = CGPoint(x: -1, y: -1)
                case 3: // Bottom-left: move right and up
                    direction = CGPoint(x: 1, y: -1)
                default:
                    direction = CGPoint(x: 0, y: 0)
                }
                
                // Calculate curve handle position
                curvePosition = CGPoint(
                    x: corner.x + direction.x * curveDistance,
                    y: corner.y + direction.y * curveDistance
                )
            }
            
            curvePositions.append(curvePosition)
        }
        
        return curvePositions.map { canvasToScreen($0, geometry: geometry) }
    }
    
    /// Handle corner radius drag with professional cursor tracking
    private func handleCornerRadiusDrag(
        cornerIndex: Int,
        value: DragGesture.Value,
        shape: VectorShape,
        geometry: GeometryProxy
    ) {
        // PROFESSIONAL CORNER RADIUS DRAGGING: Perfect cursor-to-radius synchronization
        // Uses the same precision approach as object dragging and hand tool
        
        // Initialize drag state on first drag event
        if !isDraggingCorner {
            isDraggingCorner = true
            draggedCornerIndex = cornerIndex
            cornerDragStart = value.startLocation
            initialCornerRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
            
            print("🔄 CORNER DRAG: Started at cursor (\(String(format: "%.1f", cornerDragStart.x)), \(String(format: "%.1f", cornerDragStart.y)))")
            print("   Initial radius: \(String(format: "%.1f", initialCornerRadius))pt")
        }
        
        // PERFECT MOUSE TRACKING: Handle follows mouse exactly, radius is constrained
        // Like gradient tool: handle position = mouse position directly
        currentMousePosition = value.location
        
        // Convert screen coordinates to canvas coordinates for radius calculation
        let canvasLocation = screenToCanvas(value.location, geometry: geometry)
        let canvasStartLocation = screenToCanvas(cornerDragStart, geometry: geometry)
        
        // Get the direction for this corner (45-degree diagonal)
        let direction: CGPoint
        switch cornerIndex {
        case 0: // Top-left: move right and down (positive diagonal)
            direction = CGPoint(x: 1, y: 1)
        case 1: // Top-right: move left and down (negative diagonal)
            direction = CGPoint(x: -1, y: 1)
        case 2: // Bottom-right: move left and up (positive diagonal)
            direction = CGPoint(x: -1, y: -1)
        case 3: // Bottom-left: move right and up (negative diagonal)
            direction = CGPoint(x: 1, y: -1)
        default:
            direction = CGPoint(x: 1, y: 1)
        }
        
        // Project canvas movement onto the 45-degree line for radius calculation
        let canvasDelta = CGPoint(
            x: canvasLocation.x - canvasStartLocation.x,
            y: canvasLocation.y - canvasStartLocation.y
        )
        
        // Project onto 45-degree line for radius calculation only
        let projectedDistance = (canvasDelta.x * direction.x + canvasDelta.y * direction.y) / sqrt(2.0)
        
        // Calculate radius change from the projected distance (in canvas coordinates)
        let radiusChange = projectedDistance * 0.5 // Scale factor for radius sensitivity
        let tentativeRadius = initialCornerRadius + radiusChange
        
        // Calculate maximum radius based on shape dimensions
        if let originalBounds = shape.originalBounds {
            let maxRadius = min(originalBounds.width, originalBounds.height) / 2.0
            let newRadius = max(0.0, min(maxRadius, tentativeRadius))
            
            // Apply the constrained radius
            updateCornerRadiusToValue(
                shapeID: shape.id,
                cornerIndex: cornerIndex,
                newRadius: newRadius
            )
        } else {
            // Fallback: just use minimum constraint
            let newRadius = max(0.0, tentativeRadius)
            updateCornerRadiusToValue(
                shapeID: shape.id,
                cornerIndex: cornerIndex,
                newRadius: newRadius
            )
        }
        
        // Debug logging for fine-tuning
        if abs(radiusChange) > 1.0 {
            let currentRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
            print("🔄 CORNER DRAG: Radius \(String(format: "%.1f", initialCornerRadius)) → \(String(format: "%.1f", currentRadius))pt (Δ\(String(format: "%.1f", radiusChange)))")
        }
    }
    
    /// Finish corner radius drag operation
    private func finishCornerRadiusDrag() {
        if isDraggingCorner {
            // Save to undo stack when drag ends
            document.saveToUndoStack()
            
            // Reset drag state
            isDraggingCorner = false
            draggedCornerIndex = -1
            cornerDragStart = .zero
            initialCornerRadius = 0.0
            currentMousePosition = .zero
            
            print("🔄 CORNER DRAG: Finished and saved to undo stack")
        }
    }
    
    /// Update specific corner radius and regenerate path
    private func updateCornerRadius(shapeID: UUID, cornerIndex: Int, radiusChange: Double) {
        // Find and update the shape
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Update corner radius with bounds checking
                let currentRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
                let newRadius = max(0.0, currentRadius + radiusChange) // Minimum 0pt
                
                // Update the corner radii array
                var updatedRadii = shape.cornerRadii
                if cornerIndex < updatedRadii.count {
                    updatedRadii[cornerIndex] = newRadius
                } else {
                    // Extend array if needed
                    while updatedRadii.count <= cornerIndex {
                        updatedRadii.append(0.0)
                    }
                    updatedRadii[cornerIndex] = newRadius
                }
                
                shape.cornerRadii = updatedRadii
                
                // Regenerate path from original bounds + new radii
                if let originalBounds = shape.originalBounds {
                    let newPath = createRoundedRectPathWithIndividualCorners(
                        rect: originalBounds,
                        cornerRadii: updatedRadii
                    )
                    shape.path = newPath
                    shape.updateBounds()
                }
                
                // Update the shape in the document
                document.layers[layerIndex].shapes[shapeIndex] = shape
                
                print("🔄 Updated corner \(cornerIndex) radius to \(String(format: "%.1f", newRadius))pt")
                break
            }
        }
    }
    
    /// Update specific corner radius to an absolute value and regenerate path
    private func updateCornerRadiusToValue(shapeID: UUID, cornerIndex: Int, newRadius: Double) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Update the corner radii array
                var updatedRadii = shape.cornerRadii
                if cornerIndex < updatedRadii.count {
                    updatedRadii[cornerIndex] = newRadius
                } else {
                    // Extend array if needed
                    while updatedRadii.count <= cornerIndex {
                        updatedRadii.append(0.0)
                    }
                    updatedRadii[cornerIndex] = newRadius
                }
                
                shape.cornerRadii = updatedRadii
                
                // Regenerate path from original bounds + new radii
                if let originalBounds = shape.originalBounds {
                    let newPath = createRoundedRectPathWithIndividualCorners(
                        rect: originalBounds,
                        cornerRadii: updatedRadii
                    )
                    shape.path = newPath
                    shape.updateBounds()
                }
                
                // Update the shape in the document
                document.layers[layerIndex].shapes[shapeIndex] = shape
                break
            }
        }
    }
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}