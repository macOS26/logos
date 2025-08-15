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
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        handleGradientCenterDrag(value: value, geometry: geometry, shape: selectedShape, gradient: selectedGradient)
                    }
                    .onEnded { _ in
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
            
            Log.fileOperation("🎯 Linear gradient drag - Canvas: \(canvasPoint), Origin: (\(relativeX), \(relativeY))", level: .info)
            
            updateGradientOriginX(relativeX, shape: shape, applyToShapes: true)
            updateGradientOriginY(relativeY, shape: shape, applyToShapes: true)
            
        case .radial(_):
            // FIXED: Use the EXACT same coordinate system as LayerView radial gradient rendering
            // Convert canvas coordinates to relative coordinates within shape bounds (no scaling)
            let relativeX = (canvasPoint.x - shapeBounds.minX) / shapeBounds.width
            let relativeY = (canvasPoint.y - shapeBounds.minY) / shapeBounds.height
            
            Log.fileOperation("🎯 Radial gradient drag - Canvas: \(canvasPoint), Relative: (\(relativeX), \(relativeY))", level: .info)
            
            // Don't clamp the coordinates - allow them to extend beyond object bounds
            // This allows the origin point to move freely within the scaled gradient area
            updateGradientOriginX(relativeX, shape: shape, applyToShapes: true)
            updateGradientOriginY(relativeY, shape: shape, applyToShapes: true)
        }
    }
    
    /// Same update functions as stroke/fill panel
    private func updateGradientOriginX(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        //Log.fileOperation("📐 Updating gradient origin X to: \(newX)", level: .info)
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            updateShapeGradient(shape: shape, newGradient: .linear(linear))
        case .radial(var radial):
            radial.originPoint.x = newX
            // Set focal point to match origin point (same as StrokeFillPanel)
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            updateShapeGradient(shape: shape, newGradient: .radial(radial))
        }
    }
    
    private func updateGradientOriginY(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        //Log.fileOperation("📐 Updating gradient origin Y to: \(newY)", level: .info)
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            updateShapeGradient(shape: shape, newGradient: .linear(linear))
        case .radial(var radial):
            radial.originPoint.y = newY
            // Set focal point to match origin point (same as StrokeFillPanel)
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            updateShapeGradient(shape: shape, newGradient: .radial(radial))
        }
    }
    
    /// Helper function to update shape gradient
    private func updateShapeGradient(shape: VectorShape, newGradient: VectorGradient) {
        guard let layerIndex = document.selectedLayerIndex else { return }
        
        // Find and update the shape in the document
        if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shape.id }) {
            var updatedShape = shape
            updatedShape.fillStyle = FillStyle(color: .gradient(newGradient))
            document.layers[layerIndex].shapes[shapeIndex] = updatedShape
            
            // CRITICAL: Force UI refresh by triggering document change
            // This ensures the StrokeFillPanel updates its gradient display
            DispatchQueue.main.async {
                self.document.objectWillChange.send()
            }
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
