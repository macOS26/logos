//
//  DrawingCanvas+CornerRadiusEditTool.swift
//  logos inkpen.io
//
//  Live corner radius editing tool (professional style)
//

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Corner Radius Edit Tool
    
    /// Shows corner radius edit controls when a rectangle-based shape is selected
    @ViewBuilder
    func cornerRadiusEditTool(geometry: GeometryProxy) -> some View {
        if let selectedShape = getSelectedRectangleShape() {
            
            // Get corner positions in screen coordinates - FIXED: Proper bounds for squares
            let boundsToUse = getProperShapeBounds(for: selectedShape)
            let corners = getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)
            
            ForEach(Array(corners.enumerated()), id: \.offset) { index, screenPosition in
                cornerRadiusHandle(
                    cornerIndex: index,
                    position: (isDraggingCorner && draggedCornerIndex == index) 
                        ? currentMousePosition
                        : getCornerScreenPositions(bounds: boundsToUse, shape: selectedShape, geometry: geometry)[index], // FIXED: Always recalculate positions
                    radius: selectedShape.cornerRadii[safe: index] ?? 0.0,
                    shape: selectedShape,
                    geometry: geometry
                )
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
    
    /// Get the currently selected rectangle-based shape (can have corner radius support)
    internal func getSelectedRectangleShape() -> VectorShape? {
        guard document.selectedShapeIDs.count == 1 else { return nil }
        
        for layer in document.layers {
            for shape in layer.shapes {
                if document.selectedShapeIDs.contains(shape.id) && isRectangleBasedShape(shape) {
                    return shape
                }
            }
        }
        return nil
    }
    
    /// Check if a shape is a rectangle-based shape that can have corner radius
    private func isRectangleBasedShape(_ shape: VectorShape) -> Bool {
        let shapeName = shape.name.lowercased()
        return shapeName == "rectangle" || shapeName == "square" ||
               shapeName == "rounded rectangle" || shapeName == "pill"
    }
    
    /// Get proper bounds for a shape - ALWAYS uses current path bounds with transforms applied
    internal func getProperShapeBounds(for shape: VectorShape) -> CGRect {
        // FIXED: Always use current path bounds AND apply any pending transforms (handles scaling!)
        // This ensures corner handles track the actual visual position/size of scaled objects
        var pathBounds = shape.path.cgPath.boundingBox
        
        // CRITICAL FIX: Apply any pending transforms (scaling, rotation, etc.)
        if !shape.transform.isIdentity {
            // Transform the bounds to match the actual displayed shape
            pathBounds = pathBounds.applying(shape.transform)
        }
        
        // FIXED: Check for squares more robustly - check both name AND if it's actually square-shaped
        let isSquareByName = shape.name.lowercased() == "square"
        let isSquareBySizeRatio = abs(pathBounds.width - pathBounds.height) < 1.0 // Within 1 point difference
        
        if isSquareByName || (isSquareBySizeRatio && shape.name.lowercased() == "rectangle") {
            // Make it a perfect square using the larger dimension to avoid shrinking
            let size = max(pathBounds.width, pathBounds.height)
            let squareBounds = CGRect(
                x: pathBounds.origin.x,
                y: pathBounds.origin.y,
                width: size,
                height: size
            )
            return squareBounds
        }
        
        return pathBounds
    }
    
    /// Apply transform to corner radii and handle uneven scaling
    internal func applyTransformToCornerRadii(shape: inout VectorShape) {
        guard !shape.transform.isIdentity else { return }
        
        // Extract scale factors from transform
        let scaleX = sqrt(shape.transform.a * shape.transform.a + shape.transform.c * shape.transform.c)
        let scaleY = sqrt(shape.transform.b * shape.transform.b + shape.transform.d * shape.transform.d)
        
        // Check for uneven scaling that's too extreme
        let scaleRatio = max(scaleX, scaleY) / min(scaleX, scaleY)
        let maxReasonableRatio: CGFloat = 3.0 // Threshold for "reasonable" scaling
        
        if scaleRatio > maxReasonableRatio {
            // BREAK/EXPAND: Transform is too uneven - disable corner radius tools
            
            // Apply transform to path and reset transform
            if let transformedPath = shape.path.cgPath.copy(using: &shape.transform) {
                shape.path = VectorPath(cgPath: transformedPath)
            }
            shape.transform = .identity
            
            // Disable corner radius support
            shape.isRoundedRectangle = false
            shape.cornerRadii = []
            shape.originalBounds = nil
            
            return
        }
        
        // SCALE RADII: Apply proportional scaling to corner radii
        if !shape.cornerRadii.isEmpty {
            let averageScale = (scaleX + scaleY) / 2.0 // Use average scale for corner radii
            
            for i in shape.cornerRadii.indices {
                let oldRadius = shape.cornerRadii[i]
                let newRadius = oldRadius * Double(averageScale)
                shape.cornerRadii[i] = max(0.0, newRadius) // Ensure non-negative
            }
        }
        
        // Apply transform to path and reset transform matrix
        if let transformedPath = shape.path.cgPath.copy(using: &shape.transform) {
            shape.path = VectorPath(cgPath: transformedPath)
        }
        shape.transform = .identity
        
        // Update originalBounds to new transformed bounds
        shape.originalBounds = getProperShapeBounds(for: shape)
    }
    
    /// Get corner handle positions on the actual curves (not at rectangle corners)
    func getCornerScreenPositions(bounds: CGRect, shape: VectorShape, geometry: GeometryProxy) -> [CGPoint] {
        // The bounds are already transformed by getProperShapeBounds(), so use them directly
        let transformedBounds = bounds
        
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
        // PERFORMANCE FIX: Use simple constant instead of expensive GPU call for sqrt(2.0)
        let sqrt2: CGFloat = 1.41421356237 // sqrt(2.0) - precomputed constant
        let projectedDistance = (canvasDelta.x * direction.x + canvasDelta.y * direction.y) / sqrt2
        
        // Calculate radius change from the projected distance (in canvas coordinates)
        // FIXED: 1:1 mouse tracking - no scale factor needed
        let radiusChange = projectedDistance
        let tentativeRadius = initialCornerRadius + radiusChange
        
        // Calculate maximum radius based on shape dimensions
        if let originalBounds = shape.originalBounds {
            let maxRadius = min(originalBounds.width, originalBounds.height) / 2.0
            let newRadius = max(0.0, min(maxRadius, tentativeRadius))
            
            // PROPORTIONAL CORNER RADIUS: When shift is held, make all corners proportional
            // IMPROVED: Check shift key state directly as backup to prevent sporadic behavior
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                Log.fileOperation("🔄 CORNER RADIUS PROPORTIONAL: Shift detected - state=\(isShiftPressed), direct=\(NSEvent.modifierFlags.contains(.shift))", level: .info)
            }
            if isShiftCurrentlyPressed {
                // Get all current corner radii
                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }
                
                // FIXED: Use radius change instead of ratio for corners starting at 0
                let originalRadius = allRadii[cornerIndex]
                
                if originalRadius > 0 {
                    // RATIO MODE: When corners have existing radius, scale proportionally
                    let ratio = newRadius / originalRadius
                    
                    // Apply the same ratio to all corners
                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        let proportionalRadius = originalCornerRadius * ratio
                        let constrainedRadius = max(0.0, min(maxRadius, proportionalRadius))
                        allRadii[i] = constrainedRadius
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS: Ratio mode - scaling by \(String(format: "%.3f", ratio))")
                } else {
                    // UNIFORM MODE: When starting from 0, set ALL corners to the same radius as the dragged corner
                    // This ensures all corners move together when shift is held on a sharp rectangle
                    
                    for i in 0..<4 {
                        let constrainedRadius = max(0.0, min(maxRadius, newRadius))
                        allRadii[i] = constrainedRadius
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS: Uniform mode - setting all corners to \(String(format: "%.1f", newRadius))pt")
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
        } else {
            // Fallback: just use minimum constraint
            let newRadius = max(0.0, tentativeRadius)
            
            let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
            if isShiftCurrentlyPressed {
                // Proportional behavior for fallback case
                var allRadii = shape.cornerRadii
                while allRadii.count < 4 {
                    allRadii.append(0.0)
                }
                
                let originalRadius = allRadii[cornerIndex]
                
                if originalRadius > 0 {
                    // RATIO MODE: When corners have existing radius, scale proportionally
                    let ratio = newRadius / originalRadius
                    
                    for i in 0..<4 {
                        let originalCornerRadius = allRadii[i]
                        allRadii[i] = max(0.0, originalCornerRadius * ratio)
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS (fallback): Ratio mode - scaling by \(String(format: "%.3f", ratio))")
                } else {
                    // UNIFORM MODE: When starting from 0, set ALL corners to the same radius as the dragged corner
                    // This ensures all corners move together when shift is held on a sharp rectangle
                    
                    for i in 0..<4 {
                        allRadii[i] = max(0.0, newRadius)
                    }
                    
                    print("🔄 PROPORTIONAL CORNER RADIUS (fallback): Uniform mode - setting all corners to \(String(format: "%.1f", newRadius))pt")
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
    
    /// Finish corner radius drag operation
    private func finishCornerRadiusDrag() {
        if isDraggingCorner {
            // ROUND CORNER RADIUS: Round to nearest integer when user releases handle
            if let selectedShape = getSelectedRectangleShape() {
                let currentRadius = selectedShape.cornerRadii[safe: draggedCornerIndex ?? -1] ?? 0.0
                let roundedRadius = round(currentRadius)
                
                // Only update if the value actually changed (avoid unnecessary updates)
                if abs(currentRadius - roundedRadius) > 0.01 {
                    let isShiftCurrentlyPressed = isShiftPressed || NSEvent.modifierFlags.contains(.shift)
                    if isShiftCurrentlyPressed {
                        Log.fileOperation("🔄 CORNER RADIUS ROUNDING: Shift detected during finish - state=\(isShiftPressed), direct=\(NSEvent.modifierFlags.contains(.shift))", level: .info)
                        // PROPORTIONAL ROUNDING: Round all corners proportionally when shift is held
                        var allRadii = selectedShape.cornerRadii
                        while allRadii.count < 4 {
                            allRadii.append(0.0)
                        }
                        
                        let originalRadius = allRadii[draggedCornerIndex ?? 0]
                        
                        if originalRadius > 0 {
                            // RATIO MODE: When corners have existing radius, scale proportionally
                            let ratio = roundedRadius / originalRadius
                            
                            for i in 0..<4 {
                                let originalCornerRadius = allRadii[i]
                                allRadii[i] = round(originalCornerRadius * ratio)
                            }
                            
                            print("🔄 PROPORTIONAL ROUNDING: Ratio mode - scaling by \(String(format: "%.3f", ratio))")
                        } else {
                            // UNIFORM MODE: When starting from 0, set ALL corners to the same radius as the dragged corner
                            // This ensures all corners round to the same value when shift is held on a sharp rectangle
                            
                            for i in 0..<4 {
                                allRadii[i] = round(max(0.0, roundedRadius))
                            }
                            
                            print("🔄 PROPORTIONAL ROUNDING: Uniform mode - setting all corners to \(String(format: "%.1f", roundedRadius))pt")
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
            
            // PERFORMANCE OPTIMIZED: Do full sync after drag completes for consistency
            document.updateUnifiedObjectsOptimized()
            
            // Save to undo stack when drag ends
            document.saveToUndoStack()
            
            // Reset drag state
            isDraggingCorner = false
            draggedCornerIndex = nil
            cornerDragStart = .zero
            initialCornerRadius = 0.0
            currentMousePosition = .zero
            

        }
    }
    
    // MARK: - Optimized Shape Update Functions
    
    /// PERFORMANCE OPTIMIZED: Update shape with live drag optimization
    private func updateShapeWithOptimizedSync(_ shape: VectorShape, layerIndex: Int, shapeIndex: Int, isLiveDrag: Bool) {
        // Use unified helper to update shape
        document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: shape.cornerRadii, path: shape.path)
        
        if isLiveDrag {
            // OPTIMIZED: During live drag, update only the specific shape in unified objects for targeted rendering
            if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                if case .shape(let unifiedShape) = unifiedObj.objectType {
                    return unifiedShape.id == shape.id
                }
                return false
            }) {
                // Update the specific unified object with the new shape data
                document.unifiedObjects[unifiedIndex] = VectorObject(shape: shape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
            }
            
            // Force immediate UI update for visual responsiveness
            document.objectWillChange.send()
        } else {
            // FULL UPDATE: On completion, do full sync for consistency
            document.updateUnifiedObjectsOptimized()
            DispatchQueue.main.async {
                self.document.objectWillChange.send()
            }
        }
    }
    
    /// Update specific corner radius and regenerate path
    private func updateCornerRadius(shapeID: UUID, cornerIndex: Int, radiusChange: Double) {
        // Find and update the shape
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // ENABLE CORNER RADIUS SUPPORT: Convert regular rectangles/squares to corner-radius-enabled
                if !shape.isRoundedRectangle && isRectangleBasedShape(shape) {
                    // Use proper bounds calculation that handles squares correctly
                    shape.originalBounds = getProperShapeBounds(for: shape)
                    shape.isRoundedRectangle = true
                    
                    // Initialize corner radii if empty
                    if shape.cornerRadii.isEmpty {
                        shape.cornerRadii = [0.0, 0.0, 0.0, 0.0]
                    }
                }
                
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
                
                // FIXED: Always regenerate path using current bounds (handles moved objects correctly)
                // Get current bounds BEFORE modifying the shape to preserve position
                let currentBounds = shape.path.cgPath.boundingBox
                
                let newPath = createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                shape.path = newPath
                shape.updateBounds()
                
                // Update originalBounds to current bounds for consistency
                shape.originalBounds = currentBounds
                
                // Use unified helper to update shape
                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: shape.cornerRadii, path: shape.path)
                
                // PERFORMANCE OPTIMIZED: Use live drag optimization for smooth corner radius editing
                updateShapeWithOptimizedSync(shape, layerIndex: layerIndex, shapeIndex: shapeIndex, isLiveDrag: true)
                break
            }
        }
    }
    
    /// Update specific corner radius to an absolute value and regenerate path
    func updateCornerRadiusToValue(shapeID: UUID, cornerIndex: Int, newRadius: Double) {
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
                
                // FIXED: Always regenerate path using current bounds (handles moved objects correctly)
                // Get current bounds BEFORE modifying the shape to preserve position
                let currentBounds = shape.path.cgPath.boundingBox
                
                let newPath = createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                shape.path = newPath
                shape.updateBounds()
                
                // Update originalBounds to current bounds for consistency
                shape.originalBounds = currentBounds
                
                // Use unified helper to update shape
                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: shape.cornerRadii, path: shape.path)
                
                // PERFORMANCE OPTIMIZED: Use live drag optimization for smooth corner radius editing
                updateShapeWithOptimizedSync(shape, layerIndex: layerIndex, shapeIndex: shapeIndex, isLiveDrag: true)
                break
            }
        }
    }
    
    /// Update all corner radii to absolute values and regenerate path (for proportional editing)
    func updateAllCornerRadiiToValues(shapeID: UUID, cornerRadii: [Double]) {
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                var shape = document.layers[layerIndex].shapes[shapeIndex]
                
                // Ensure we have exactly 4 corner radii
                var updatedRadii = cornerRadii
                while updatedRadii.count < 4 {
                    updatedRadii.append(0.0)
                }
                if updatedRadii.count > 4 {
                    updatedRadii = Array(updatedRadii.prefix(4))
                }
                
                shape.cornerRadii = updatedRadii
                
                // FIXED: Always regenerate path using current bounds (handles moved objects correctly)
                // Get current bounds BEFORE modifying the shape to preserve position
                let currentBounds = shape.path.cgPath.boundingBox
                
                let newPath = createRoundedRectPathWithIndividualCorners(
                    rect: currentBounds,
                    cornerRadii: updatedRadii
                )
                shape.path = newPath
                shape.updateBounds()
                
                // Update originalBounds to current bounds for consistency
                shape.originalBounds = currentBounds
                
                // Use unified helper to update shape
                document.updateShapeCornerRadiiInUnified(id: shape.id, cornerRadii: shape.cornerRadii, path: shape.path)
                
                // PERFORMANCE OPTIMIZED: Use live drag optimization for smooth corner radius editing
                updateShapeWithOptimizedSync(shape, layerIndex: layerIndex, shapeIndex: shapeIndex, isLiveDrag: true)
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