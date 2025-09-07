//
//  DrawingCanvas+PointHandleUtilities.swift
//  logos inkpen.io
//
//  Point and handle position utilities
//

import SwiftUI

extension DrawingCanvas {
    internal func captureOriginalPositions() {
        originalPointPositions.removeAll()
        originalHandlePositions.removeAll()
        
        // Capture original positions of selected points
        for pointID in selectedPoints {
            if let point = getPointPosition(pointID) {
                originalPointPositions[pointID] = point
            }
        }
        
        // Capture original positions of selected handles
        for handleID in selectedHandles {
            if let handle = getHandlePosition(handleID) {
                originalHandlePositions[handleID] = handle
            }
        }
    }
    
    internal func getPointPosition(_ pointID: PointID) -> VectorPoint? {
        // Find the shape and get the point position
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < shape.path.elements.count else { return nil }
                let element = shape.path.elements[pointID.elementIndex]
                
                switch element {
                case .move(let to), .line(let to):
                    return to
                case .curve(let to, _, _), .quadCurve(let to, _):
                    return to
                case .close:
                    return nil
                }
            }
        }
        return nil
    }
    
    internal func getHandlePosition(_ handleID: HandleID) -> VectorPoint? {
        // Find the shape and get the handle position
        for layer in document.layers {
            if let shape = layer.shapes.first(where: { $0.id == handleID.shapeID }) {
                guard handleID.elementIndex < shape.path.elements.count else { return nil }
                let element = shape.path.elements[handleID.elementIndex]
                
                switch element {
                case .curve(_, let control1, let control2):
                    return handleID.handleType == .control1 ? control1 : control2
                case .quadCurve(_, let control):
                    return handleID.handleType == .control1 ? control : nil
                default:
                    return nil
                }
            }
        }
        return nil
    }
    
    internal func movePointToAbsolutePosition(_ pointID: PointID, to newPosition: CGPoint) {
        movePointToAbsolutePositionOptimized(pointID, to: newPosition, isLiveDrag: isDraggingPoint)
    }
    
    private func movePointToAbsolutePositionOptimized(_ pointID: PointID, to newPosition: CGPoint, isLiveDrag: Bool) {
        // Find the shape and update the point position
        for layerIndex in document.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == pointID.shapeID }),
               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                guard pointID.elementIndex < shape.path.elements.count else { return }
                
                let newPoint = VectorPoint(newPosition.x, newPosition.y)
                var elements = shape.path.elements
                
                // Get the original point position before moving
                let originalPosition: CGPoint
                switch elements[pointID.elementIndex] {
                case .move(let to), .line(let to):
                    originalPosition = CGPoint(x: to.x, y: to.y)
                case .curve(let to, _, _):
                    originalPosition = CGPoint(x: to.x, y: to.y)
                case .quadCurve(let to, _):
                    originalPosition = CGPoint(x: to.x, y: to.y)
                case .close:
                    return
                }
                
                // Calculate the movement delta
                let deltaX = newPosition.x - originalPosition.x
                let deltaY = newPosition.y - originalPosition.y
                //let delta = CGPoint(x: deltaX, y: deltaY)
                
                // STEP 1: Update the anchor point AND its handles
                switch elements[pointID.elementIndex] {
                case .move(_):
                    elements[pointID.elementIndex] = .move(to: newPoint)
                case .line(_):
                    elements[pointID.elementIndex] = .line(to: newPoint)
                case .curve(let oldTo, let control1, let control2):
                    // Check if handles are collapsed to the anchor point
                    let _ = (abs(control1.x - oldTo.x) < 0.1 && abs(control1.y - oldTo.y) < 0.1) // control1Collapsed - unused
                    let control2Collapsed = (abs(control2.x - oldTo.x) < 0.1 && abs(control2.y - oldTo.y) < 0.1)
                    
                    // ADOBE ILLUSTRATOR BEHAVIOR: 
                    // control1 belongs to PREVIOUS point - do NOT move it with current point
                    // control2 belongs to CURRENT point - move it only if collapsed, otherwise leave it
                    let newControl1 = control1  // DON'T MOVE - belongs to previous point
                    let newControl2 = control2Collapsed ? newPoint : VectorPoint(control2.x + deltaX, control2.y + deltaY)
                    
                    elements[pointID.elementIndex] = .curve(to: newPoint, control1: newControl1, control2: newControl2)
                case .quadCurve(_, let control):
                    elements[pointID.elementIndex] = .quadCurve(to: newPoint, control: control)
                case .close:
                    break
                }
                
                // STEP 2: Update the outgoing handle that belongs to THIS point (control1 of NEXT element)
                if pointID.elementIndex + 1 < elements.count {
                    if case .curve(let nextTo, let nextControl1, let nextControl2) = elements[pointID.elementIndex + 1] {
                        // Check if the outgoing handle is collapsed to the original anchor position
                        let outgoingCollapsed = (abs(nextControl1.x - originalPosition.x) < 0.1 && abs(nextControl1.y - originalPosition.y) < 0.1)
                        
                        // If collapsed, keep it collapsed to the NEW anchor position
                        // Otherwise, move it by the delta
                        let newNextControl1 = outgoingCollapsed ? newPoint : VectorPoint(nextControl1.x + deltaX, nextControl1.y + deltaY)
                        elements[pointID.elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                    }
                }
                
                // ADOBE ILLUSTRATOR BEHAVIOR: Only move the selected point and its handles
                // Neighboring points and their handles stay stationary
                // Coincident points are handled by selection logic, not automatic movement
                
                var updatedShape = shape
                updatedShape.path.elements = elements
                
                if isLiveDrag {
                    // Skip expensive updateBounds during live drag for smoother performance
                    // OPTIMIZED: During live drag, update only the specific shape in unified objects for targeted rendering
                    if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                        if case .shape(let unifiedShape) = unifiedObj.objectType {
                            return unifiedShape.id == pointID.shapeID
                        }
                        return false
                    }) {
                        // Update the specific unified object with the new shape data
                        if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: currentShape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                        }
                    }
                    
                    // Force immediate UI update for visual responsiveness
                    document.objectWillChange.send()
                } else {
                    // FULL UPDATE: On drag end, update bounds and do full sync for consistency
                    updatedShape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                    document.updateUnifiedObjectsOptimized()
                    document.objectWillChange.send()
                }
                return
            }
        }
    }
    
    /// Detects if a point is a smooth curve point (has handles that are not collapsed to the anchor)
    private func isSmoothCurvePoint(elements: [PathElement], elementIndex: Int) -> Bool {
        guard elementIndex < elements.count else { return false }
        
        switch elements[elementIndex] {
        case .curve(let to, _, let control2):
            // Check if incoming handle (control2) is not collapsed to anchor point
            let incomingHandleCollapsed = (abs(control2.x - to.x) < 0.1 && abs(control2.y - to.y) < 0.1)
            
            // Check if outgoing handle (control1 of NEXT element) is not collapsed to anchor point
            var outgoingHandleCollapsed = true // Default to true if no next element
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(_, let nextControl1, _) = nextElement {
                    outgoingHandleCollapsed = (abs(nextControl1.x - to.x) < 0.1 && abs(nextControl1.y - to.y) < 0.1)
                }
            }
            
            // Point is smooth if BOTH handles are NOT collapsed (opposite of corner point logic)
            return !incomingHandleCollapsed && !outgoingHandleCollapsed
            
        default:
            return false
        }
    }
    
    /// Moves handles with an anchor point, maintaining their relative positions
    /// This properly handles both smooth curve handles and collapsed handles (corner points)
    private func moveHandlesWithAnchorPoint(elements: inout [PathElement], elementIndex: Int, delta: CGPoint) {
        guard elementIndex < elements.count else { return }
        
        switch elements[elementIndex] {
        case .curve(let to, let control1, let control2):
            // Move incoming handle (control2) by the same delta
            // This maintains the handle's position relative to the anchor point
            // If the handle is collapsed to the anchor, it stays collapsed
            let newControl2 = VectorPoint(control2.x + delta.x, control2.y + delta.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: newControl2)
            
            // Move outgoing handle (control1 of NEXT element) if it exists
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                    // Move the outgoing handle by the same delta
                    // This maintains its position relative to the anchor point
                    let newNextControl1 = VectorPoint(nextControl1.x + delta.x, nextControl1.y + delta.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
            
        case .move(_), .line(_):
            // For move/line elements, check if the NEXT element has an outgoing handle
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                    // Move the outgoing handle by the same delta
                    let newNextControl1 = VectorPoint(nextControl1.x + delta.x, nextControl1.y + delta.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
            
        default:
            break
        }
    }
    
    internal func moveHandleToAbsolutePosition(_ handleID: HandleID, to newPosition: CGPoint) {
        moveHandleToAbsolutePositionOptimized(handleID, to: newPosition, isLiveDrag: isDraggingHandle)
    }
    
    private func moveHandleToAbsolutePositionOptimized(_ handleID: HandleID, to newPosition: CGPoint, isLiveDrag: Bool) {
        // Find the shape and update the handle position
        for layerIndex in document.layers.indices {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == handleID.shapeID }),
               let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                guard handleID.elementIndex < shape.path.elements.count else { return }
                
                let newHandle = VectorPoint(newPosition.x, newPosition.y)
                var elements = shape.path.elements
                
                // STEP 1: Update the dragged handle
                switch elements[handleID.elementIndex] {
                case .curve(let to, let control1, let control2):
                    if handleID.handleType == .control1 {
                        elements[handleID.elementIndex] = .curve(to: to, control1: newHandle, control2: control2)
                    } else {
                        elements[handleID.elementIndex] = .curve(to: to, control1: control1, control2: newHandle)
                    }
                case .quadCurve(let to, _):
                    if handleID.handleType == .control1 {
                        elements[handleID.elementIndex] = .quadCurve(to: to, control: newHandle)
                    }
                default:
                    break
                }
                
                // STEP 2: PROFESSIONAL LINKED HANDLES - Update the opposite handle of THE SAME ANCHOR POINT
                if !optionPressed() {
                    updateLinkedHandle(
                        elements: &elements,
                        draggedHandleID: handleID,
                        newDraggedPosition: newPosition
                    )
                }
                
                var updatedShape = shape
                updatedShape.path.elements = elements
                
                if isLiveDrag {
                    // Skip expensive updateBounds during live drag for smoother performance
                    // OPTIMIZED: During live drag, update only the specific shape in unified objects for targeted rendering
                    if let unifiedIndex = document.unifiedObjects.firstIndex(where: { unifiedObj in
                        if case .shape(let unifiedShape) = unifiedObj.objectType {
                            return unifiedShape.id == handleID.shapeID
                        }
                        return false
                    }) {
                        // Update the specific unified object with the new shape data
                        if let currentShape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                            document.unifiedObjects[unifiedIndex] = VectorObject(shape: currentShape, layerIndex: layerIndex, orderID: document.unifiedObjects[unifiedIndex].orderID)
                        }
                    }
                    
                    // Force immediate UI update for visual responsiveness
                    document.objectWillChange.send()
                } else {
                    // FULL UPDATE: On drag end, update bounds and do full sync for consistency
                    updatedShape.updateBounds()
                    document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: updatedShape)
                    document.updateUnifiedObjectsOptimized()
                    document.objectWillChange.send()
                }
                return
            }
        }
    }
} 
