//
//  PathManipulation.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Path Manipulation Functions
extension DrawingCanvas {

    /// Updates the bezier path with handles
    internal func updatePathWithHandles() {
        guard let path = bezierPath, bezierPoints.count >= 1 else { return }
        
        var newElements: [PathElement] = []
        
        // Start with move to first point
        newElements.append(.move(to: bezierPoints[0]))
        
        // Pure handle-based approach: only create curves when handles exist
        for i in 1..<bezierPoints.count {
            let currentPoint = bezierPoints[i]
            let previousPoint = bezierPoints[i - 1]
            
            // Check for handles on both points
            let previousHandles = bezierHandles[i - 1]
            let currentHandles = bezierHandles[i]
            
            // Only create curves if there are actual handles to define them
            let hasOutgoingHandle = previousHandles?.control2 != nil
            let hasIncomingHandle = currentHandles?.control1 != nil
            
            if hasOutgoingHandle || hasIncomingHandle {
                // Create curve using available handles
                let control1 = previousHandles?.control2 ?? VectorPoint(previousPoint.x, previousPoint.y)
                let control2 = currentHandles?.control1 ?? VectorPoint(currentPoint.x, currentPoint.y)
                
                newElements.append(.curve(to: currentPoint, control1: control1, control2: control2))
            } else {
                // No handles - use straight line
                newElements.append(.line(to: currentPoint))
            }
        }
        
        // Update the path
        bezierPath = VectorPath(elements: newElements, isClosed: path.isClosed)
    }
} 