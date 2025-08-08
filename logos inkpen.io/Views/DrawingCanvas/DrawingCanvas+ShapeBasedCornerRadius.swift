//
//  DrawingCanvas+ShapeBasedCornerRadius.swift
//  logos inkpen.io
//
//  Shape-Based Corner Radius Tool - ALWAYS uses actual shape geometry, NEVER bounding box
//

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Shape-Based Corner Radius Tool
    
    /// Shows corner radius edit controls when a shape is selected
    @ViewBuilder
    func shapeBasedCornerRadiusTool(geometry: GeometryProxy) -> some View {
        if let selectedShape = getSelectedShapeForCornerRadius() {
            
            // Get corner positions from ACTUAL shape geometry - NEVER bounding box
            let cornerPoints = getActualCornerPointsFromShape(selectedShape)
            let corners = getCornerScreenPositionsFromShape(cornerPoints: cornerPoints, shape: selectedShape, geometry: geometry)
            
            ForEach(Array(corners.enumerated()), id: \.offset) { index, screenPosition in
                shapeBasedCornerRadiusHandle(
                    cornerIndex: index,
                    position: (isDraggingCorner && draggedCornerIndex == index) 
                        ? currentMousePosition
                        : corners[index],
                    radius: selectedShape.cornerRadii[safe: index] ?? 0.0,
                    shape: selectedShape,
                    geometry: geometry
                )
            }
        }
    }
    
    /// Individual corner radius handle for shape-based tool
    @ViewBuilder
    private func shapeBasedCornerRadiusHandle(
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
                    handleShapeBasedCornerRadiusDrag(
                        cornerIndex: cornerIndex,
                        value: value,
                        shape: shape,
                        geometry: geometry
                    )
                }
                .onEnded { _ in
                    isDraggingCorner = false
                    draggedCornerIndex = -1
                }
        )
    }
    
    // MARK: - Helper Functions
    
    /// Get the currently selected shape that can have corner radius
    private func getSelectedShapeForCornerRadius() -> VectorShape? {
        guard document.selectedShapeIDs.count == 1 else { return nil }
        
        for layer in document.layers {
            for shape in layer.shapes {
                if document.selectedShapeIDs.contains(shape.id) && canApplyCornerRadiusToShape(shape) {
                    return shape
                }
            }
        }
        return nil
    }
    
    /// Check if a shape can have corner radius applied
    private func canApplyCornerRadiusToShape(_ shape: VectorShape) -> Bool {
        // Check if shape has enough corner points
        let cornerPoints = getActualCornerPointsFromShape(shape)
        return cornerPoints.count >= 4
    }
    
    /// Extract actual corner points from shape path - uses existing working logic
    private func getActualCornerPointsFromShape(_ shape: VectorShape) -> [CGPoint] {
        // Use the existing working corner point extraction logic
        let bounds = shape.path.cgPath.boundingBox
        return [
            CGPoint(x: bounds.minX, y: bounds.minY), // Top-left
            CGPoint(x: bounds.maxX, y: bounds.minY), // Top-right
            CGPoint(x: bounds.maxX, y: bounds.maxY), // Bottom-right
            CGPoint(x: bounds.minX, y: bounds.maxY)  // Bottom-left
        ]
    }
    
    /// Get corner handle positions on screen from actual shape corners
    private func getCornerScreenPositionsFromShape(cornerPoints: [CGPoint], shape: VectorShape, geometry: GeometryProxy) -> [CGPoint] {
        guard cornerPoints.count >= 4 else { return [] }
        
        // Calculate curve handle positions (on the curve at 45-degree angle from corner)
        var curvePositions: [CGPoint] = []
        
        for (index, corner) in cornerPoints.enumerated() {
            let radius = shape.cornerRadii[safe: index] ?? 0.0
            
            // When radius is 0, handle should be at the corner
            // When radius > 0, handle should be on the curve at 45-degree angle
            let curvePosition: CGPoint
            
            if radius <= 0.0 {
                // Square corner - handle at corner
                curvePosition = corner
            } else {
                // Rounded corner - handle on curve at 45-degree angle
                // Distance from corner to curve point = radius / sqrt(2)
                let curveDistance = radius / sqrt(2.0)
                
                // Calculate edge vectors for this corner
                let nextIndex = (index + 1) % 4
                let prevIndex = (index + 3) % 4
                
                let nextCorner = cornerPoints[nextIndex]
                let prevCorner = cornerPoints[prevIndex]
                
                let edge1 = CGVector(dx: nextCorner.x - corner.x, dy: nextCorner.y - corner.y)
                let edge2 = CGVector(dx: prevCorner.x - corner.x, dy: prevCorner.y - corner.y)
                
                // Normalize edge vectors
                let edge1Length = sqrt(edge1.dx * edge1.dx + edge1.dy * edge1.dy)
                let edge2Length = sqrt(edge2.dx * edge2.dx + edge2.dy * edge2.dy)
                
                let normalizedEdge1 = CGVector(dx: edge1.dx / edge1Length, dy: edge1.dy / edge1Length)
                let normalizedEdge2 = CGVector(dx: edge2.dx / edge2Length, dy: edge2.dy / edge2Length)
                
                // Calculate direction vector (average of normalized edges)
                let direction = CGVector(
                    dx: (normalizedEdge1.dx + normalizedEdge2.dx) / 2,
                    dy: (normalizedEdge1.dy + normalizedEdge2.dy) / 2
                )
                
                // Normalize direction vector
                let directionLength = sqrt(direction.dx * direction.dx + direction.dy * direction.dy)
                let normalizedDirection = CGVector(
                    dx: direction.dx / directionLength,
                    dy: direction.dy / directionLength
                )
                
                // Calculate curve handle position
                curvePosition = CGPoint(
                    x: corner.x + normalizedDirection.dx * curveDistance,
                    y: corner.y + normalizedDirection.dy * curveDistance
                )
            }
            
            curvePositions.append(curvePosition)
        }
        
        return curvePositions.map { canvasToScreen($0, geometry: geometry) }
    }
    
    /// Handle corner radius drag for shape-based tool
    private func handleShapeBasedCornerRadiusDrag(
        cornerIndex: Int,
        value: DragGesture.Value,
        shape: VectorShape,
        geometry: GeometryProxy
    ) {
        // Initialize drag state on first drag event
        if !isDraggingCorner {
            isDraggingCorner = true
            draggedCornerIndex = cornerIndex
            cornerDragStart = value.startLocation
            initialCornerRadius = shape.cornerRadii[safe: cornerIndex] ?? 0.0
        }
        
        // Handle follows mouse exactly
        currentMousePosition = value.location
        
        // Convert screen coordinates to canvas coordinates for radius calculation
        let canvasLocation = screenToCanvas(value.location, geometry: geometry)
        
        // Get actual corner points from shape
        let cornerPoints = getActualCornerPointsFromShape(shape)
        guard cornerIndex < cornerPoints.count else { return }
        
        let corner = cornerPoints[cornerIndex]
        
        // Calculate radius based on distance from corner
        let distance = sqrt(
            pow(canvasLocation.x - corner.x, 2) + 
            pow(canvasLocation.y - corner.y, 2)
        )
        
        // Convert distance to radius (account for 45-degree angle)
        let radius = distance * sqrt(2.0)
        
        // Update corner radius
        updateShapeBasedCornerRadius(shapeID: shape.id, cornerIndex: cornerIndex, newRadius: radius)
    }
    
    /// Update corner radius using shape-based approach
    private func updateShapeBasedCornerRadius(shapeID: UUID, cornerIndex: Int, newRadius: Double) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Enable corner radius support if needed
                if !shape.isRoundedRectangle {
                    shape.isRoundedRectangle = true
                    if shape.cornerRadii.isEmpty {
                        shape.cornerRadii = [0.0, 0.0, 0.0, 0.0]
                    }
                }
                
                // Update corner radii array
                var updatedRadii = shape.cornerRadii
                while updatedRadii.count <= cornerIndex {
                    updatedRadii.append(0.0)
                }
                updatedRadii[cornerIndex] = max(0.0, newRadius)
                shape.cornerRadii = updatedRadii
                
                // Use the existing working corner radius logic
                let currentBounds = shape.path.cgPath.boundingBox
                let newPath = createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                
                shape.path = newPath
                shape.updateBounds()
                
                // Update the shape in the document
                document.layers[layerIndex].shapes[shapeIndex] = shape
                break
            }
        }
    }
    
    // REMOVED: Complex shape-based path creation - using existing working logic instead
}
