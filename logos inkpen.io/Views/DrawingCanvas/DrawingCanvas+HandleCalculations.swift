//
//  HandleCalculations.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Handle Calculation Functions
extension DrawingCanvas {
    
    /// Calculates the linked handle position for smooth curve behavior
    /// 🚀 GPU-ACCELERATED: Uses Metal compute shaders when available
    internal func calculateLinkedHandle(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
        // 🚀 PHASE 7: Try GPU acceleration first
        let metalEngine = MetalComputeEngine.shared
        let results = metalEngine.calculateLinkedHandlesGPU(
            anchorPoints: [anchorPoint], 
            draggedHandles: [draggedHandle], 
            originalOppositeHandles: [originalOppositeHandle]
        )
        switch results {
        case .success(let linkedHandles):
            if let result = linkedHandles.first {
                print("🔧 GPU CALC: Anchor(\(String(format: "%.1f", anchorPoint.x)), \(String(format: "%.1f", anchorPoint.y))) Dragged(\(String(format: "%.1f", draggedHandle.x)), \(String(format: "%.1f", draggedHandle.y))) Original(\(String(format: "%.1f", originalOppositeHandle.x)), \(String(format: "%.1f", originalOppositeHandle.y))) → Result(\(String(format: "%.1f", result.x)), \(String(format: "%.1f", result.y)))")
                return result
            }
        case .failure(let error):
            print("⚠️ GPU CALC FAILED: \(error) - falling back to CPU")
            // Fallback to CPU calculation
            break
        }
        
        // CPU fallback
        let cpuResult = calculateLinkedHandleCPU(anchorPoint: anchorPoint, draggedHandle: draggedHandle, originalOppositeHandle: originalOppositeHandle)
        print("🔧 CPU CALC: Anchor(\(String(format: "%.1f", anchorPoint.x)), \(String(format: "%.1f", anchorPoint.y))) Dragged(\(String(format: "%.1f", draggedHandle.x)), \(String(format: "%.1f", draggedHandle.y))) Original(\(String(format: "%.1f", originalOppositeHandle.x)), \(String(format: "%.1f", originalOppositeHandle.y))) → Result(\(String(format: "%.1f", cpuResult.x)), \(String(format: "%.1f", cpuResult.y)))")
        return cpuResult
    }
    
    private func calculateLinkedHandleCPU(anchorPoint: CGPoint, draggedHandle: CGPoint, originalOppositeHandle: CGPoint) -> CGPoint {
        // Vector from anchor to dragged handle
        let draggedVector = CGPoint(
            x: draggedHandle.x - anchorPoint.x,
            y: draggedHandle.y - anchorPoint.y
        )
        
        // Keep the original opposite handle length
        let originalVector = CGPoint(
            x: originalOppositeHandle.x - anchorPoint.x,
            y: originalOppositeHandle.y - anchorPoint.y
        )
        let originalLength = sqrt(originalVector.x * originalVector.x + originalVector.y * originalVector.y)
        
        // Create opposite vector (180° from dragged handle) with original length
        let draggedLength = sqrt(draggedVector.x * draggedVector.x + draggedVector.y * draggedVector.y)
        guard draggedLength > 0.1 else { return originalOppositeHandle } // Avoid division by zero
        
        let normalizedDragged = CGPoint(
            x: draggedVector.x / draggedLength,
            y: draggedVector.y / draggedLength
        )
        
        // Opposite direction with original length
        let linkedHandle = CGPoint(
            x: anchorPoint.x - normalizedDragged.x * originalLength,
            y: anchorPoint.y - normalizedDragged.y * originalLength
        )
        
        return linkedHandle
    }
    

    
    /// SIMPLE 180-DEGREE SYMMETRIC HANDLES - NO COMPLEX MATH!
    private func calculateSmoothHandles(for point: VectorPoint, elementIndex: Int, in elements: [PathElement]) -> (incoming: VectorPoint, outgoing: VectorPoint) {
        // Just create simple horizontal 180-degree handles like Adobe Illustrator
        let handleLength: Double = 30.0
        
        let incomingHandle = VectorPoint(point.x - handleLength, point.y)
        let outgoingHandle = VectorPoint(point.x + handleLength, point.y)
        
        return (incomingHandle, outgoingHandle)
    }
    
    /// Updates the opposite handle of the SAME anchor point to maintain smooth curves
    /// PROFESSIONAL BEHAVIOR: Smooth points work like a teeter-totter - both handles move together in a straight line
    /// ENHANCED: Also handles coincident points (first/last in closed paths) as smooth points
    internal func updateLinkedHandle(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) {
        
        // FIRST: Check for coincident points (exact same X,Y coordinates)
        if handleCoincidentSmoothPoints(elements: &elements, draggedHandleID: draggedHandleID, newDraggedPosition: newDraggedPosition) {
            return // Handled by coincident point logic
        }
        
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
