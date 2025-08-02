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
                        position: screenPosition,
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
                    // Save to undo stack when drag ends
                    document.saveToUndoStack()
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
    
    /// Get corner positions in screen coordinates
    private func getCornerScreenPositions(bounds: CGRect, shape: VectorShape, geometry: GeometryProxy) -> [CGPoint] {
        // Apply shape transform to bounds
        let transform = shape.transform
        let transformedBounds = bounds.applying(transform)
        
        let corners = [
            CGPoint(x: transformedBounds.minX, y: transformedBounds.minY), // Top-left
            CGPoint(x: transformedBounds.maxX, y: transformedBounds.minY), // Top-right
            CGPoint(x: transformedBounds.maxX, y: transformedBounds.maxY), // Bottom-right
            CGPoint(x: transformedBounds.minX, y: transformedBounds.maxY)  // Bottom-left
        ]
        
        return corners.map { canvasToScreen($0, geometry: geometry) }
    }
    
    /// Handle corner radius drag
    private func handleCornerRadiusDrag(
        cornerIndex: Int,
        value: DragGesture.Value,
        shape: VectorShape,
        geometry: GeometryProxy
    ) {
        // Calculate radius change based on drag distance
        let dragDistance = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
        let direction = value.translation.width + value.translation.height > 0 ? 1.0 : -1.0
        let radiusChange = dragDistance * direction * 0.5 // Sensitivity adjustment
        
        // Update the corner radius for this corner
        updateCornerRadius(
            shapeID: shape.id,
            cornerIndex: cornerIndex,
            radiusChange: radiusChange
        )
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
}

// MARK: - Array Safe Access Extension
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}