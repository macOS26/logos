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
                
                document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                return
            }
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