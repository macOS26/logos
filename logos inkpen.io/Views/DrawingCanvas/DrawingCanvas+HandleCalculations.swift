//
//  HandleCalculations.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Handle Calculation Functions
extension DrawingCanvas {
    
    /// Updates the opposite handle of the SAME anchor point to maintain smooth curves
    /// PROFESSIONAL BEHAVIOR: Smooth points work like a teeter-totter - both handles move together in a straight line
    /// ENHANCED: Also handles coincident points (first/last in closed paths) as smooth points
    internal func updateLinkedHandle(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) {
        
        // FIRST: Check for coincident points (exact same X,Y coordinates)
        if handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: draggedHandleID, newDraggedPosition: newDraggedPosition) {
            return // Handled by coincident point logic
        }
        
        // Don't link handles for line or quadCurve elements (corner and cusp points)
        // Only link handles for curve elements with both handles extended (smooth points)
        
        if draggedHandleID.handleType == .control2 {
            // Dragging INCOMING handle (control2) of current curve element
            // This handle belongs to the anchor point at the END of this curve
            guard case .curve(let anchorTo, let control1, _) = elements[draggedHandleID.elementIndex] else { return }
            
            let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
            
            // Find the OUTGOING handle of the same anchor point (control1 of NEXT curve element)
            let nextIndex = draggedHandleID.elementIndex + 1
            if nextIndex < elements.count, case .curve(let nextTo, let currentOutgoing, let nextControl2) = elements[nextIndex] {
                
                // Calculate the opposite handle position (180° from dragged handle through anchor point)
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentOutgoing.x, y: currentOutgoing.y)
                )
                
                // Update both handles: the dragged one and its opposite
                elements[draggedHandleID.elementIndex] = .curve(to: anchorTo, control1: control1, control2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[nextIndex] = .curve(to: nextTo, control1: VectorPoint(oppositeHandle.x, oppositeHandle.y), control2: nextControl2)
            }
            
        } else if draggedHandleID.handleType == .control1 {
            // Dragging OUTGOING handle (control1) of current curve element
            // This handle belongs to the anchor point where the PREVIOUS curve ended
            
            let prevIndex = draggedHandleID.elementIndex - 1
            if prevIndex >= 0, case .curve(let anchorTo, let prevControl1, let currentIncoming) = elements[prevIndex] {
                
                let anchorPoint = CGPoint(x: anchorTo.x, y: anchorTo.y)
                
                // Calculate the opposite handle position (180° from dragged handle through anchor point)
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: currentIncoming.x, y: currentIncoming.y)
                )
                
                // Update both handles: the dragged one and its opposite
                if case .curve(let currentTo, _, let currentControl2) = elements[draggedHandleID.elementIndex] {
                    elements[prevIndex] = .curve(to: anchorTo, control1: prevControl1, control2: VectorPoint(oppositeHandle.x, oppositeHandle.y))
                    elements[draggedHandleID.elementIndex] = .curve(to: currentTo, control1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y), control2: currentControl2)
                }
            }
        }
    }
    
    /// Detects if Option/Alt key is pressed for independent handle control
    internal func optionPressed() -> Bool {
        return isOptionPressed
    }
} 
