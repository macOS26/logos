import SwiftUI
import Combine

extension DrawingCanvas {
    
    @ViewBuilder
    func gradientEditTool(geometry: GeometryProxy) -> some View {
        if let selectedGradient = getSelectedShapeGradient(document: document),
           let selectedShape = getSelectedShapeWithGradient() {
            // Use live state if dragging, otherwise get from document
            let originX = liveGradientOriginX ?? getGradientOriginX(selectedGradient)
            let originY = liveGradientOriginY ?? getGradientOriginY(selectedGradient)

            let shapeBounds = selectedShape.bounds
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            let centerPoint = CGPoint(x: centerX, y: centerY)
            let screenPoint = canvasToScreen(centerPoint, geometry: geometry)
            
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.8))
                    .stroke(Color.white, lineWidth: 2.0)
                    .frame(width: 16, height: 16)
                
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
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleGradientCenterDrag(value: value, geometry: geometry, shape: selectedShape, gradient: selectedGradient)
                    }
                    .onEnded { value in
                        handleGradientCenterDragEnd(value: value, geometry: geometry, shape: selectedShape, gradient: selectedGradient)
                    }
            )
        }
    }
    
    private func getSelectedShapeWithGradient() -> VectorShape? {
        guard let firstSelectedID = document.viewState.selectedObjectIDs.first else { return nil }
        guard let shape = document.findShape(by: firstSelectedID),
              let fillStyle = shape.fillStyle,
              case .gradient = fillStyle.color else {
            return nil
        }
        return shape
    }
    
    private func getGradientCenterPoint(gradient: VectorGradient, shape: VectorShape) -> CGPoint {
        let shapeBounds = shape.bounds
        
        switch gradient {
        case .linear(let linear):
            let originX = linear.originPoint.x
            let originY = linear.originPoint.y
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            
            return CGPoint(x: centerX, y: centerY)
            
        case .radial(let radial):
            let originX = radial.originPoint.x
            let originY = radial.originPoint.y
            let centerX = shapeBounds.minX + shapeBounds.width * originX
            let centerY = shapeBounds.minY + shapeBounds.height * originY
            
            return CGPoint(x: centerX, y: centerY)
        }
    }
    
    private func getGradientScale(_ gradient: VectorGradient) -> Double {
        switch gradient {
        case .linear(let linear):
            return linear.scaleX
        case .radial(let radial):
            return radial.scaleX
        }
    }
    
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
    
    private func handleGradientCenterDrag(value: DragGesture.Value, geometry: GeometryProxy, shape: VectorShape, gradient: VectorGradient) {
        let canvasPoint = screenToCanvas(value.location, geometry: geometry)
        let shapeBounds = shape.bounds

        let relativeX = (canvasPoint.x - shapeBounds.minX) / shapeBounds.width
        let relativeY = (canvasPoint.y - shapeBounds.minY) / shapeBounds.height

        // Update live state for immediate UI feedback
        liveGradientOriginX = relativeX
        liveGradientOriginY = relativeY

        // Apply live update to shape (like Grade panel does)
        updateGradientOriginXYOptimized(relativeX, relativeY, shape: shape, applyToShapes: true, isLiveDrag: true)
    }

    private func handleGradientCenterDragEnd(value: DragGesture.Value, geometry: GeometryProxy, shape: VectorShape, gradient: VectorGradient) {
        let canvasPoint = screenToCanvas(value.location, geometry: geometry)
        let shapeBounds = shape.bounds

        let relativeX = (canvasPoint.x - shapeBounds.minX) / shapeBounds.width
        let relativeY = (canvasPoint.y - shapeBounds.minY) / shapeBounds.height

        // Final update with notification
        updateGradientOriginXYOptimized(relativeX, relativeY, shape: shape, applyToShapes: true, isLiveDrag: false)

        // Clear live state
        liveGradientOriginX = nil
        liveGradientOriginY = nil
    }
    
    private func updateGradientOriginX(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true) {
        updateGradientOriginXOptimized(newX, shape: shape, applyToShapes: applyToShapes, isLiveDrag: false)
    }
    
    private func updateGradientOriginY(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true) {
        updateGradientOriginYOptimized(newY, shape: shape, applyToShapes: applyToShapes, isLiveDrag: false)
    }
    
    private func updateGradientOriginXOptimized(_ newX: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.x = newX
            updateShapeGradientOptimized(shape: shape, newGradient: .linear(linear), isLiveDrag: isLiveDrag)
        case .radial(var radial):
            radial.originPoint.x = newX
            radial.focalPoint = CGPoint(x: newX, y: radial.originPoint.y)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }
    
    private func updateGradientOriginYOptimized(_ newY: Double, shape: VectorShape, applyToShapes: Bool = true, isLiveDrag: Bool) {
        guard let selectedGradient = getSelectedShapeGradient(document: document) else { return }
        
        switch selectedGradient {
        case .linear(var linear):
            linear.originPoint.y = newY
            updateShapeGradientOptimized(shape: shape, newGradient: .linear(linear), isLiveDrag: isLiveDrag)
        case .radial(var radial):
            radial.originPoint.y = newY
            radial.focalPoint = CGPoint(x: radial.originPoint.x, y: newY)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }
    
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
            radial.focalPoint = CGPoint(x: newX, y: newY)
            updateShapeGradientOptimized(shape: shape, newGradient: .radial(radial), isLiveDrag: isLiveDrag)
        }
    }
    
    private func updateShapeGradient(shape: VectorShape, newGradient: VectorGradient) {
        updateShapeGradientOptimized(shape: shape, newGradient: newGradient, isLiveDrag: false)
    }
    
    private func updateShapeGradientOptimized(shape: VectorShape, newGradient: VectorGradient, isLiveDrag: Bool) {
        // Use the same method as the Grade panel for live updates
        document.updateShapeGradientInUnified(id: shape.id, gradient: newGradient, target: document.viewState.activeColorTarget)
    }
    
    private func getSelectedShapeGradient(document: VectorDocument) -> VectorGradient? {
        guard let firstSelectedID = document.viewState.selectedObjectIDs.first else { return nil }
        guard let shape = document.findShape(by: firstSelectedID),
              let fillStyle = shape.fillStyle,
              case .gradient(let gradient) = fillStyle.color else {
            return nil
        }
        return gradient
    }
}
