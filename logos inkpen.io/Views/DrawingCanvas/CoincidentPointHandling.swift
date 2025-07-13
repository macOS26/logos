//
//  CoincidentPointHandling.swift
//  logos inkpen.io
//
//  Created by Assistant on 1/20/25.
//

import SwiftUI
import Foundation

// MARK: - Coincident Point Handling Extension
extension DrawingCanvas {
    
    // MARK: - PROFESSIONAL COINCIDENT POINT HANDLING
    
    /// Finds all points that are coincident (at the same coordinates) with the given point
    /// This is essential for closed paths where moveTo and close points must stay together
    func findCoincidentPoints(to targetPointID: PointID, tolerance: Double = 1.0) -> Set<PointID> {
        guard let targetPosition = getPointPosition(targetPointID, in: document) else { return [] }
        
        var coincidentPoints: Set<PointID> = []
        let targetPoint = CGPoint(x: targetPosition.x, y: targetPosition.y)
        
        // Search through all layers and shapes for points at the same location
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes {
                if !shape.isVisible { continue }
                
                // Check each path element for coincident points
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    let pointID = PointID(
                        shapeID: shape.id,
                        pathIndex: 0,
                        elementIndex: elementIndex
                    )
                    
                    // Skip the original point itself
                    if pointID == targetPointID { continue }
                    
                    // Extract point location from element
                    let elementPoint: CGPoint?
                    switch element {
                    case .move(let to), .line(let to):
                        elementPoint = CGPoint(x: to.x, y: to.y)
                    case .curve(let to, _, _), .quadCurve(let to, _):
                        elementPoint = CGPoint(x: to.x, y: to.y)
                    case .close:
                        elementPoint = nil
                    }
                    
                    // Check if this point is coincident with the target
                    if let checkPoint = elementPoint {
                        let distance = sqrt(pow(targetPoint.x - checkPoint.x, 2) + pow(targetPoint.y - checkPoint.y, 2))
                        if distance <= tolerance {
                            coincidentPoints.insert(pointID)
                            print("🔗 COINCIDENT POINT: Found point at element \(elementIndex) in shape \(shape.name) coincident with target")
                            print("   Target: (\(targetPoint.x), \(targetPoint.y)), Found: (\(checkPoint.x), \(checkPoint.y)), Distance: \(distance)")
                        }
                    }
                }
            }
        }
        
        return coincidentPoints
    }
    
    /// Enhanced point selection that automatically includes coincident points
    /// This ensures points at the same coordinates move together to maintain continuity
    func selectPointWithCoincidents(_ pointID: PointID, addToSelection: Bool = false) {
        // Clear selection if not adding to it
        if !addToSelection {
            selectedPoints.removeAll()
            selectedHandles.removeAll()
        }
        
        // Add the primary point
        selectedPoints.insert(pointID)
        
        // Find and add all coincident points
        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
        for coincidentPoint in coincidentPoints {
            selectedPoints.insert(coincidentPoint)
        }
        
        if !coincidentPoints.isEmpty {
            print("🔗 COINCIDENT SELECTION: Selected \(coincidentPoints.count + 1) coincident points")
            print("   Primary point: \(pointID)")
            print("   Coincident points: \(coincidentPoints)")
        }
    }
    
    /// Checks if a point is part of a closed path and finds its corresponding endpoint
    /// For closed paths, the moveTo start point and the point before close should be coincident
    func findClosedPathEndpoints(for pointID: PointID) -> Set<PointID> {
        var endpointPairs: Set<PointID> = []
        
        // Find the shape containing this point
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                
                // Check if this is a closed path
                let hasCloseElement = shape.path.elements.contains { element in
                    if case .close = element { return true }
                    return false
                }
                
                if hasCloseElement || shape.path.isClosed {
                    // Find the moveTo and the last point before close
                    var moveToIndex: Int?
                    var lastPointIndex: Int?
                    
                    for (index, element) in shape.path.elements.enumerated() {
                        switch element {
                        case .move(_):
                            if moveToIndex == nil { // First moveTo
                                moveToIndex = index
                            }
                        case .line(_), .curve(_, _, _), .quadCurve(_, _):
                            lastPointIndex = index
                        case .close:
                            break
                        }
                    }
                    
                    // If this point is either the moveTo or the last point, include both
                    if let moveIndex = moveToIndex, let lastIndex = lastPointIndex {
                        if pointID.elementIndex == moveIndex {
                            endpointPairs.insert(PointID(shapeID: pointID.shapeID, pathIndex: pointID.pathIndex, elementIndex: lastIndex))
                        } else if pointID.elementIndex == lastIndex {
                            endpointPairs.insert(PointID(shapeID: pointID.shapeID, pathIndex: pointID.pathIndex, elementIndex: moveIndex))
                        }
                    }
                }
                break
            }
        }
        
        return endpointPairs
    }
    
    /// Analyzes and reports all coincident points in the current document
    /// Useful for debugging and understanding path structure
    func analyzeCoincidentPoints() {
        print("🔍 COINCIDENT POINT ANALYSIS:")
        print("Using tolerance: \(coincidentPointTolerance) pixels")
        
        var totalCoincidentGroups = 0
        var processedPoints: Set<PointID> = []
        
        // Scan all points in the document
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes {
                if !shape.isVisible { continue }
                
                print("\n📋 Analyzing shape: \(shape.name)")
                
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    let pointID = PointID(
                        shapeID: shape.id,
                        pathIndex: 0,
                        elementIndex: elementIndex
                    )
                    
                    // Skip if we already processed this point as part of a coincident group
                    if processedPoints.contains(pointID) { continue }
                    
                    // Skip close elements
                    switch element {
                    case .move(_), .line(_), .curve(_, _, _), .quadCurve(_, _):
                        break // Continue processing this element
                    case .close:
                        continue // Skip close elements
                    }
                    
                    // Find coincident points for this point
                    let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
                    
                    if !coincidentPoints.isEmpty {
                        totalCoincidentGroups += 1
                        if let position = getPointPosition(pointID, in: document) {
                            print("   🔗 Coincident Group \(totalCoincidentGroups) at (\(position.x), \(position.y)):")
                            print("      Primary: Element \(elementIndex)")
                            for coincidentPoint in coincidentPoints {
                                print("      Coincident: Element \(coincidentPoint.elementIndex) in shape \(coincidentPoint.shapeID)")
                            }
                            
                            // Mark all points in this group as processed
                            processedPoints.insert(pointID)
                            for coincidentPoint in coincidentPoints {
                                processedPoints.insert(coincidentPoint)
                            }
                        }
                    }
                }
            }
        }
        
        if totalCoincidentGroups == 0 {
            print("✅ No coincident points found in document")
        } else {
            print("\n📊 SUMMARY: Found \(totalCoincidentGroups) coincident point groups")
            print("💡 TIP: These points will move together when selected to maintain path continuity")
        }
    }
    
    // MARK: - Smooth Handle Management for Coincident Points
    
    /// Handles smooth curve behavior for coincident points (first/last in closed paths)
    /// Uses EXACT coordinate matching (no tolerance) and applies smooth point logic
    func handleCoincidentSmoothPoints(elements: inout [PathElement], draggedHandleID: HandleID, newDraggedPosition: CGPoint) -> Bool {
        guard elements.count >= 2 else { return false }
        
        // Get first and last point positions (exact coordinates)
        let firstPoint: CGPoint?
        let lastPoint: CGPoint?
        
        if case .move(let firstTo) = elements[0] {
            firstPoint = CGPoint(x: firstTo.x, y: firstTo.y)
        } else {
            firstPoint = nil
        }
        
        // Find last point (before any close element)
        var lastElementIndex = elements.count - 1
        if lastElementIndex >= 0 {
            if case .close = elements[lastElementIndex] {
                lastElementIndex -= 1 // Skip close element
            }
        }
        
        if lastElementIndex >= 0 {
            switch elements[lastElementIndex] {
            case .curve(let lastTo, _, _), .line(let lastTo), .quadCurve(let lastTo, _):
                lastPoint = CGPoint(x: lastTo.x, y: lastTo.y)
            default:
                lastPoint = nil
            }
        } else {
            lastPoint = nil
        }
        
        // Check if first and last points are EXACTLY coincident (no tolerance)
        guard let first = firstPoint, let last = lastPoint,
              abs(first.x - last.x) < 0.001 && abs(first.y - last.y) < 0.001 else {
            return false // Not coincident points
        }
        
        let anchorPoint = first // Use first point as anchor (they're the same)
        
        // Handle coincident smooth point behavior based on which handle is being dragged
        if draggedHandleID.handleType == .control1 && draggedHandleID.elementIndex == 1 {
            // Dragging OUTGOING handle from first point (control1 of second element)
            // Update INCOMING handle of last point (control2 of last element)
            
            if case .curve(let lastTo, let lastControl1, _) = elements[lastElementIndex] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: lastControl1.x, y: lastControl1.y) // Keep original length
                )
                
                // Update both handles
                elements[draggedHandleID.elementIndex] = updateElementControl1(elements[draggedHandleID.elementIndex], newControl1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[lastElementIndex] = .curve(to: lastTo, control1: lastControl1, control2: VectorPoint(oppositeHandle.x, oppositeHandle.y))
                
                print("🔗 COINCIDENT SMOOTH: Updated first→last handles")
                return true
            }
            
        } else if draggedHandleID.handleType == .control2 && draggedHandleID.elementIndex == lastElementIndex {
            // Dragging INCOMING handle to last point (control2 of last element)
            // Update OUTGOING handle from first point (control1 of second element)
            
            if elements.count > 1, case .curve(let secondTo, _, let secondControl2) = elements[1] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: secondControl2.x, y: secondControl2.y) // Keep original length
                )
                
                // Update both handles
                elements[draggedHandleID.elementIndex] = updateElementControl2(elements[draggedHandleID.elementIndex], newControl2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[1] = .curve(to: secondTo, control1: VectorPoint(oppositeHandle.x, oppositeHandle.y), control2: secondControl2)
                
                print("🔗 COINCIDENT SMOOTH: Updated last→first handles")
                return true
            }
        }
        
        return false // Not a coincident smooth point case
    }
    
    /// Helper to update control1 of a path element
    func updateElementControl1(_ element: PathElement, newControl1: VectorPoint) -> PathElement {
        switch element {
        case .curve(let to, _, let control2):
            return .curve(to: to, control1: newControl1, control2: control2)
        case .quadCurve(let to, _):
            return .quadCurve(to: to, control: newControl1)
        default:
            return element
        }
    }
    
    /// Helper to update control2 of a path element
    func updateElementControl2(_ element: PathElement, newControl2: VectorPoint) -> PathElement {
        switch element {
        case .curve(let to, let control1, _):
            return .curve(to: to, control1: control1, control2: newControl2)
        default:
            return element
        }
    }
} 