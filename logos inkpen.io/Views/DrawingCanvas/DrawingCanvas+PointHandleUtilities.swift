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
        // Find the shape and update the point position
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) {
                guard pointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let newPoint = VectorPoint(newPosition.x, newPosition.y)
                var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
                
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
                let delta = CGPoint(x: deltaX, y: deltaY)
                
                // STEP 1: Update the anchor point position
                switch elements[pointID.elementIndex] {
                case .move(_):
                    elements[pointID.elementIndex] = .move(to: newPoint)
                case .line(_):
                    elements[pointID.elementIndex] = .line(to: newPoint)
                case .curve(_, let control1, let control2):
                    elements[pointID.elementIndex] = .curve(to: newPoint, control1: control1, control2: control2)
                case .quadCurve(_, let control):
                    elements[pointID.elementIndex] = .quadCurve(to: newPoint, control: control)
                case .close:
                    break
                }
                
                // STEP 2: Check if this is a smooth curve point and move its handles
                if isSmoothCurvePoint(elements: elements, elementIndex: pointID.elementIndex) {
                    moveSmoothCurveHandles(elements: &elements, elementIndex: pointID.elementIndex, delta: delta)
                }
                
                // STEP 3: NEW - Check if this point has coincident points and apply smooth curve logic to them
                let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                if !coincidentPoints.isEmpty {
                    moveCoincidentPointsWithSmoothLogic(pointID: pointID, to: newPosition, delta: delta)
                }
                
                document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
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
    
    /// Moves the handles of a smooth curve point while maintaining 180-degree alignment
    private func moveSmoothCurveHandles(elements: inout [PathElement], elementIndex: Int, delta: CGPoint) {
        guard elementIndex < elements.count else { return }
        
        switch elements[elementIndex] {
        case .curve(let to, let control1, let control2):
            // Move incoming handle (control2) of current element by the same delta
            let newControl2 = VectorPoint(control2.x + delta.x, control2.y + delta.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: newControl2)
            
            // Move outgoing handle (control1 of NEXT element) by the same delta if it exists
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                    // Move the outgoing handle by the same delta to maintain relationship
                    let newNextControl1 = VectorPoint(nextControl1.x + delta.x, nextControl1.y + delta.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
            
        default:
            break
        }
    }
    
    internal func moveHandleToAbsolutePosition(_ handleID: HandleID, to newPosition: CGPoint) {
        // Find the shape and update the handle position
        for layerIndex in document.layers.indices {
            if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == handleID.shapeID }) {
                guard handleID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
                
                let newHandle = VectorPoint(newPosition.x, newPosition.y)
                var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
                
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
                
                document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                return
            }
        }
    }
} 