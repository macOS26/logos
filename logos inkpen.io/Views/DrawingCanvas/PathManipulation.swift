//
//  PathManipulation.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Path Manipulation Functions
extension DrawingCanvas {
    
    /// Add path elements to a SwiftUI Path
    internal func addPathElements(_ elements: [PathElement], to path: inout Path) {
        for element in elements {
            switch element {
            case .move(let to):
                path.move(to: to.cgPoint)
            case .line(let to):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                path.closeSubpath()
            }
        }
    }
    
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
    
    /// Delete specific points from a path while maintaining path integrity
    internal func deletePointsFromPath(_ path: VectorPath, selectedPoints: [PointID]) -> VectorPath {
        var elements = path.elements
        
        // Get element indices to delete (sorted in reverse order to avoid index shifting issues)
        let indicesToDelete = selectedPoints.compactMap { $0.elementIndex }.sorted(by: >)
        
        // Remove elements from back to front to maintain indices
        for index in indicesToDelete {
            if index < elements.count {
                // Check if this is a critical point for path integrity
                if canDeleteElement(at: index, in: elements) {
                    elements.remove(at: index)
                }
            }
        }
        
        // Ensure path still has a valid structure
        let validatedElements = validatePathElements(elements)
        
        return VectorPath(elements: validatedElements, isClosed: path.isClosed)
    }
    
    /// Check if an element can be safely deleted without breaking the path
    internal func canDeleteElement(at index: Int, in elements: [PathElement]) -> Bool {
        // Don't delete if it's the only move element
        if case .move = elements[index] {
            let moveCount = elements.compactMap { if case .move = $0 { return 1 } else { return nil } }.count
            return moveCount > 1
        }
        
        // Don't delete if it would result in too few elements
        let pointCount = elements.filter { element in
            switch element {
            case .move, .line, .curve, .quadCurve: return true
            case .close: return false
            }
        }.count
        
        return pointCount > 2 // Need at least 3 points for a valid path
    }
    
    /// Validate and fix path elements to maintain integrity
    internal func validatePathElements(_ elements: [PathElement]) -> [PathElement] {
        var validElements: [PathElement] = []
        
        for element in elements {
            switch element {
            case .move(_):
                // Always keep move elements
                validElements.append(element)
                
            case .line(_):
                // Keep line elements if we have a starting point
                if !validElements.isEmpty {
                    validElements.append(element)
                }
                
            case .curve(_, _, _):
                // Keep curve elements if we have a starting point
                if !validElements.isEmpty {
                    validElements.append(element)
                }
                
            case .quadCurve(_, _):
                // Keep quadratic curve elements if we have a starting point
                if !validElements.isEmpty {
                    validElements.append(element)
                }
                
            case .close:
                // Keep close elements if we have enough points
                let pointCount = validElements.filter { element in
                    switch element {
                    case .move, .line, .curve, .quadCurve: return true
                    case .close: return false
                    }
                }.count
                
                if pointCount >= 3 {
                    validElements.append(element)
                }
            }
        }
        
        // Ensure we have at least a move element
        if validElements.isEmpty {
            validElements.append(.move(to: VectorPoint(0, 0)))
        }
        
        return validElements
    }
} 