import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Gradient Edit Tool
    
    /// Shows gradient edit controls when a gradient is selected
    @ViewBuilder
    func gradientEditTool(geometry: GeometryProxy) -> some View {
        if let selectedGradient = getSelectedShapeGradient(document: document),
           let selectedShape = getSelectedShapeWithGradient() {
            
            // Get the gradient center point in screen coordinates
            let centerPoint = getGradientCenterPoint(gradient: selectedGradient, shape: selectedShape)
            let screenPoint = canvasToScreen(centerPoint, geometry: geometry)
            
            // Gradient center marker
            ZStack {
                // Outer circle
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .stroke(Color.white, lineWidth: 2.0)
                    .frame(width: 16, height: 16)
                
                // Type indicator (small inner circle for radial, line for linear)
                switch selectedGradient {
                case .radial:
                    Circle()
                        .fill(Color.white)
                        .frame(width: 6, height: 6)
                case .linear:
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 8, height: 2)
                        .rotationEffect(.degrees(45))
                }
            }
            .position(screenPoint)
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .gesture(
                DragGesture(minimumDistance: 0)  // OPTIMIZED: Reduce minimum distance for smoother real-time updates
                    .onChanged { value in
                        handleGradientCenterDrag(value: value, geometry: geometry, shape: selectedShape, gradient: selectedGradient)
                    }
                    .onEnded { _ in
                        // OPTIMIZATION: Do full sync after drag completes for consistency
                        document.updateUnifiedObjectsOptimized()
                        
                        // Save to undo stack when drag ends
                        document.saveToUndoStack()
                    }
            )
        }
    }
    
    // MARK: - Helper Functions
    
    /// Get the selected shape that has a gradient
    private func getSelectedShapeWithGradient() -> VectorShape? {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
              let fillStyle = shape.fillStyle,
              case .gradient = fillStyle.color else {
            return nil
        }
        return shape
    }
    
    /// Get gradient center point in canvas coordinates
    private func getGradientCenterPoint(gradient: VectorGradient, shape: VectorShape) -> CGPoint {
        let shapeBounds = shape.bounds
        
        switch gradient {
        case .linear(let linear):
            // FIXED: Use the EXACT same coordinate system as LayerView linear gradient rendering
            // Origin point should NOT be scaled - it defines the center position
            let originX = linear.originPoint.x
            let originY = linear.originPoint.y
            
            // Calculate the center position in canvas coordinates (no scaling applied to position)
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            
            return CGPoint(x: centerX, y: centerY)
            
        case .radial(let radial):
            // FIXED: Use the EXACT same coordinate system as LayerView radial gradient rendering
            // Origin point should NOT be scaled - it defines the center position
            let originX = radial.originPoint.x
            let originY = radial.originPoint.y
            
            // Calculate the center position in canvas coordinates (no scaling applied to position)
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            
            return CGPoint(x: centerX, y: centerY)
        }
    }
    
    /// Get gradient scale (same as stroke/fill panel)
    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX // Use scaleX as the primary scale
        case .radial(let radial):
            return radial.scaleX // Use scaleX as the primary scale
        }
    }
    
    /// Same origin point functions as stroke/fill panel
    private func getGradientOriginX(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.x
        case .radial(let radial):
            return radial.originPoint.x
        }
    }
    
    private func getGradientOriginY(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.originPoint.y
        case .radial(let radial):
            return radial.originPoint.y
        }
    }
    
    /// Handle gradient center point dragging
    private func handleGradientCenterDrag(value: DragGesture.Value, geometry: GeometryProxy, shape: VectorShape, gradient: VectorGradient) {
        // Convert screen coordinates to canvas coordinates
        let canvasPoint = screenToCanvas(value.location, geometry: geometry)
        
        let shapeBounds = shape.bounds
        
        switch gradient {
        case .linear(_):
            // FIXED: Use the EXACT same coordinate system as LayerView linear gradient rendering
            // Convert canvas coordinates to relative coordinates within shape bounds (no scaling)
            let relativeX = (canvasPoint.x - shapeBounds.minX) / shapeBounds.width
            let relativeY = (canvasPoint.y - shapeBounds.minY) / shapeBounds.height
            
            // Log.fileOperation("🎯 Linear gradient drag - Canvas: \(canvasPoint), Origin: (\(relativeX), \(relativeY))", level: .info) // Disabled for performance
            
            // OPTIMIZED: Use combined update for maximum performance - single update instead of two separate calls
            updateGradientOriginXYOptimized(relativeX, relativeY, shape: shape, applyToShapes: true, isLiveDrag: true)
            
        case .radial(_):
            // FIXED: Use the EXACT same coordinate system as LayerView radial gradient rendering
            // Convert canvas coordinates to relative coordinates within shape bounds (no scaling)
            let relativeX = (canvasPoint.x - shapeBounds.minX) / shapeBounds.width
            let relativeY = (canvasPoint.y - shapeBounds.minY) / shapeBounds.height
            
            // Log.fileOperation("🎯 Radial gradient drag - Canvas: \(canvasPoint), Relative: (\(relativeX), \(relativeY))", level: .info) // Disabled for performance
            
            // Don't clamp the coordinates - allow them to extend beyond object bounds
            // This allows the origin point to move freely within the scaled gradient area
            // OPTIMIZED: Use combined update for maximum performance - single update instead of two separate calls
            updateGradientOriginXYOptimized(relativeX, relativeY, shape: shape, applyToShapes: true, isLiveDrag: true)
        }
    }
    
    /// Same update functions as stroke/fill panel
    private func updateGradientOriginX(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true) {
        updateGradientOriginXOptimized(newX, shape: shape, applyToShapes: applyToShapes, isLiveDrag: false)
    }
    
    private func updateGradientOriginY(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true) {
        updateGradientOriginYOptimized(newY, shape: shape, applyToShapes: applyToShapes, isLiveDrag: false)
    }
    
    /// Optimized origin X update with live drag support
    private func updateGradientOriginXOptimized(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            updateShapeGradientOptimized(shape: shape, newGradient: .linear(linear), isLiveDrag: isLiveDrag)
        case .radial(var radial):
            radial.originPoint.x = newX
            // Set focal point to match origin point (same as StrokeFillPanel)
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }
    
    /// Optimized origin Y update with live drag support
    private func updateGradientOriginYOptimized(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            updateShapeGradientOptimized(shape: shape, newGradient: .linear(linear), isLiveDrag: isLiveDrag)
        case .radial(var radial):
            radial.originPoint.y = newY
            // Set focal point to match origin point (same as StrokeFillPanel)
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }
    
    /// PERFORMANCE OPTIMIZED: Combined X+Y update for maximum speed - single update instead of two separate calls
    private func updateGradientOriginXYOptimized(_ newX: Double, _ newY: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            linear.originPoint.y = newY
            updateShapeGradientOptimized(shape: shape, newGradient: .linear(linear), isLiveDrag: isLiveDrag)
        case .radial(var radial):
            radial.originPoint.x = newX
            radial.originPoint.y = newY
            // Set focal point to match origin point (same as StrokeFillPanel)
            radial.focalPoint = CGPoint(x: newX, y: newY)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }
    
    /// Helper function to update shape gradient
    private func updateShapeGradient(shape: VectorShape, newGradient: VectorGradient) {
        updateShapeGradientOptimized(shape: shape, newGradient: newGradient, isLiveDrag: false)
    }
    
    /// Optimized gradient update with option to skip expensive operations during live dragging
    private func updateShapeGradientOptimized(shape: VectorShape, newGradient: VectorGradient, isLiveDrag: Bool) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        // Log.fileOperation("🎯 GRADIENT TOOL: updateShapeGradientOptimized called with isLiveDrag: \(isLiveDrag)", level: .info) // Disabled for performance
        
        // Find and update the shape in the document
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            var updatedShape = shape
            updatedShape.fillStyle = FillStyle(color: .gradient(newGradient))
            document.layers[layerIndex].shapes[shapeIndex] = updatedShape
            
            if isLiveDrag {
                // OPTIMIZED: During live drag, update only the specific shape in unified objects for targeted rendering
                if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                    if case .shape(let unifiedShape) = unifiedObj.objectType {
                        return unifiedShape.id == shape.id
                    }
                    return false
                }) {
                    // Update the specific unified object with the new shape data
                    document.unifiedObjects[unifiedIndex] = VectorObject(shape: updatedShape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                }
                
                // Force immediate UI update for visual responsiveness
                document.objectWillChange.send()
            } else {
                // FULL UPDATE: On drag end, do full sync for consistency
                document.updateUnifiedObjectsOptimized()
                DispatchQueue.main.async {
                    self.document.objectWillChange.send()
                }
            }
            
            Log.fileOperation("🎨 GRADIENT TOOL: Updated shape gradient for \(shape.id.uuidString.prefix(8)) (liveDrag: \(isLiveDrag))", level: .info)
        }
    }
    
    /// Helper function to get selected shape gradient (copied from StrokeFillPanel)
    private func getSelectedShapeGradient(document: VectorDocument) -> VectorGradient? {
        guard let layerIndex = document.selectedLayerIndex,
              let firstSelectedID = document.selectedShapeIDs.first,
              let shape = document.layers[layerIndex].shapes.first(where: { $0.id == firstSelectedID }),
              let fillStyle = shape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
    }
} 
