//
//  DrawingCanvas+CornerRadiusTool.swift
//  logos inkpen.io
//
//  Corner Radius Tool Implementation
//

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Corner Radius Tool
    
    /// Shows corner radius edit controls when corner radius tool is active
    @ViewBuilder
    func cornerRadiusTool(geometry: GeometryProxy) -> some View {
        if document.currentTool == .cornerRadius,
           let selectedShape = getSelectedRectangleShape() {
            
            // Get corner positions in screen coordinates
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
    
    /// Individual corner radius handle for the corner radius tool
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
    
    // MARK: - Corner Radius Tool Drag Handling
    
    /// Handle corner radius dragging when using the corner radius tool
    private func handleCornerRadiusToolDrag(
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
            Log.fileOperation("🔧 CORNER RADIUS TOOL: Started dragging corner \(cornerIndex)", level: .info)
        }
        
        // Perfect mouse tracking: Handle follows mouse exactly
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
        let deltaX = canvasLocation.x - canvasStartLocation.x
        let deltaY = canvasLocation.y - canvasStartLocation.y
        
        // Calculate movement along the diagonal direction
        let diagonalMovement = (deltaX * direction.x + deltaY * direction.y) / sqrt(2.0)
        
        // Calculate tentative radius based on movement
        let tentativeRadius = initialCornerRadius + diagonalMovement
        
        // Constrain radius to reasonable bounds
        if let originalBounds = shape.originalBounds {
            let maxRadius = min(originalBounds.width, originalBounds.height) / 2.0
            let newRadius = max(0.0, min(maxRadius, tentativeRadius))
            
            // Proportional corner radius: When shift is held, make all corners proportional
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                Log.fileOperation("🔄 CORNER RADIUS TOOL PROPORTIONAL: Shift detected", level: .info)
                
                // Get all current corner radii
                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }
                
                let originalRadius = allRadii[cornerIndex]
                
                if originalRadius > 0 {
                    // Ratio mode: When corners have existing radius, scale proportionally
                    let ratio = newRadius / originalRadius
                    
                    // Apply the same ratio to all corners
                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        let proportionalRadius = originalCornerRadius * ratio
                        let constrainedRadius = max(0.0, min(maxRadius, proportionalRadius))
                        allRadii[i] = constrainedRadius
                    }
                    
                    print("🔄 CORNER RADIUS TOOL: Ratio mode - scaling by \(String(format: "%.3f", ratio))")
                } else {
                    // Uniform mode: When starting from 0, set ALL corners to the same radius
                    for i in 0..<4 {
                        let constrainedRadius = max(0.0, min(maxRadius, newRadius))
                        allRadii[i] = constrainedRadius
                    }
                    
                    print("🔄 CORNER RADIUS TOOL: Uniform mode - setting all corners to \(String(format: "%.1f", newRadius))pt")
                }
                
                // Update all corner radii proportionally
                updateAllCornerRadiiToValues(
                    shapeID: shape.id,
                    cornerRadii: allRadii
                )
            } else {
                // Apply the constrained radius to just this corner
                updateCornerRadiusToValue(
                    shapeID: shape.id,
                    cornerIndex: cornerIndex,
                    newRadius: newRadius
                )
            }
        }
    }
    
    /// Finish corner radius tool drag operation
    private func finishCornerRadiusToolDrag() {
        if isDraggingCorner {
            // Round corner radius to nearest integer when user releases handle
            if let selectedShape = getSelectedRectangleShape() {
                let currentRadius = selectedShape.cornerRadii[safe: draggedCornerIndex ?? -1] ?? 0.0
                let roundedRadius = round(currentRadius)
                
                // Only update if the value actually changed
                if abs(currentRadius - roundedRadius) > 0.01 {
                    let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
                    if isShiftCurrentlyPressed {
                        Log.fileOperation("🔄 CORNER RADIUS TOOL ROUNDING: Shift detected during finish", level: .info)
                        // Proportional rounding: Round all corners proportionally when shift is held
                        var allRadii = selectedShape.cornerRadii
                        while allRadii.count < 4 {
                            allRadii.append(0.0)
                        }
                        
                        let originalRadius = allRadii[draggedCornerIndex ?? 0]
                        
                        if originalRadius > 0 {
                            // Ratio mode: When corners have existing radius, scale proportionally
                            let ratio = roundedRadius / originalRadius
                            
                            for i in 0..<4 {
                                let originalCornerRadius = allRadii[i]
                                allRadii[i] = round(originalCornerRadius * ratio)
                            }
                            
                            Log.fileOperation("🔄 CORNER RADIUS TOOL: Proportional rounding ratio mode", level: .info)
                        } else {
                            // Uniform mode: When starting from 0, set ALL corners to the same radius
                            for i in 0..<4 {
                                allRadii[i] = round(max(0.0, roundedRadius))
                            }
                            
                            Log.fileOperation("🔄 CORNER RADIUS TOOL: Proportional rounding uniform mode", level: .info)
                        }
                        
                        updateAllCornerRadiiToValues(
                            shapeID: selectedShape.id,
                            cornerRadii: allRadii
                        )
                    } else {
                        // Round just this corner
                        updateCornerRadiusToValue(
                            shapeID: selectedShape.id,
                            cornerIndex: draggedCornerIndex ?? 0,
                            newRadius: roundedRadius
                        )
                    }
                }
            }
            
            // Save to undo stack when drag ends
            document.saveToUndoStack()
            
            // Reset drag state
            isDraggingCorner = false
            draggedCornerIndex = nil
            cornerDragStart = .zero
            initialCornerRadius = 0.0
            currentMousePosition = .zero
            
            Log.fileOperation("🔧 CORNER RADIUS TOOL: Finished dragging corner \(draggedCornerIndex ?? -1)", level: .info)
        }
    }
}
