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
        guard let targetPosition = getPointPosition(targetPointID) else { return [] }
        
        var coincidentPoints: Set<PointID> = []
        let targetPoint = CGPoint(x: targetPosition.x, y: targetPosition.y)
		
		// CRITICAL: Restrict coincident searches to ACTIVE/SELECTED shapes only
		// This prevents dragging points on one object from affecting other, non-selected objects
		let allowedShapeIDs: Set<UUID> = {
			let active = document.getActiveShapeIDs()
			// Always include the target point's shape as a fallback
			return active.isEmpty ? [targetPointID.shapeID] : active
		}()
        
        // Search through all layers and shapes for points at the same location
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
			for shape in layer.shapes {
				// Only consider shapes that are currently active/selected
				if !allowedShapeIDs.contains(shape.id) { continue }
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
                            Log.info("🔗 COINCIDENT POINT: Found point at element \(elementIndex) in shape \(shape.name) coincident with target", category: .general)
                            Log.info("   Target: (\(targetPoint.x), \(targetPoint.y)), Found: (\(checkPoint.x), \(checkPoint.y)), Distance: \(distance)", category: .general)
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
        
        // CRITICAL FIX: For closed paths, ALWAYS include first/last point pairs regardless of handle state
        // This ensures first and last points move together even when handles are retracted
        let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
        for endpointID in closedPathEndpoints {
            selectedPoints.insert(endpointID)
            Log.info("🔗 CLOSED PATH ENDPOINT: Added endpoint \(endpointID) to selection", category: .general)
        }
        
        let totalCoincident = coincidentPoints.count + closedPathEndpoints.count
        if totalCoincident > 0 {
            Log.info("🔗 COINCIDENT SELECTION: Selected \(totalCoincident + 1) total points", category: .general)
            Log.info("   Primary point: \(pointID)", category: .general)
            Log.info("   Coordinate coincident points: \(coincidentPoints.count)", category: .general)
            Log.info("   Closed path endpoints: \(closedPathEndpoints.count)", category: .general)
        }
    }
    
    /// Checks if a point is part of a closed path and finds its corresponding endpoint
    /// CRITICAL: For closed paths, ONLY considers first/last points coincident if they are at the SAME LOCATION
    func findClosedPathEndpoints(for pointID: PointID) -> Set<PointID> {
        var endpointPairs: Set<PointID> = []
        
        // Find the shape containing this point
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if let shape = layer.shapes.first(where: { $0.id == pointID.shapeID }) {
                
                // MUST have a close command to be considered a closed path
                let hasCloseElement = shape.path.elements.contains { element in
                    if case .close = element { return true }
                    return false
                }
                
                // Only proceed if there's actually a close command
                if hasCloseElement {
                    // Find the moveTo and the last point before close
                    var moveToIndex: Int?
                    var lastPointIndex: Int?
                    var moveToPoint: VectorPoint?
                    var lastPoint: VectorPoint?
                    
                    for (index, element) in shape.path.elements.enumerated() {
                        switch element {
                        case .move(let to):
                            if moveToIndex == nil { // First moveTo
                                moveToIndex = index
                                moveToPoint = to
                            }
                        case .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                            lastPointIndex = index
                            lastPoint = to
                        case .close:
                            break
                        }
                    }
                    
                    // CRITICAL: Only treat as coincident if points are actually at the same location
                    if let moveIndex = moveToIndex, let lastIndex = lastPointIndex,
                       let firstPoint = moveToPoint, let endPoint = lastPoint {
                        
                        // Check if first and last points are at the same coordinates (within tolerance)
                        let distance = sqrt(pow(firstPoint.x - endPoint.x, 2) + pow(firstPoint.y - endPoint.y, 2))
                        let tolerance = 1.0 // Same tolerance as coordinate-based coincident detection
                        
                        if distance <= tolerance {
                            // Points are actually coincident - include the pair
                            if pointID.elementIndex == moveIndex {
                                endpointPairs.insert(PointID(shapeID: pointID.shapeID, pathIndex: pointID.pathIndex, elementIndex: lastIndex))
                                Log.info("🔗 CLOSED PATH COINCIDENT: First point links to last point (distance: \(String(format: "%.3f", distance)))", category: .general)
                            } else if pointID.elementIndex == lastIndex {
                                endpointPairs.insert(PointID(shapeID: pointID.shapeID, pathIndex: pointID.pathIndex, elementIndex: moveIndex))
                                Log.info("🔗 CLOSED PATH COINCIDENT: Last point links to first point (distance: \(String(format: "%.3f", distance)))", category: .general)
                            }
                        } else {
                            Log.info("🔍 CLOSED PATH CHECK: First/last points not coincident (distance: \(String(format: "%.3f", distance)) > \(tolerance))", category: .general)
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
        Log.info("🔍 COINCIDENT POINT ANALYSIS:", category: .general)
        Log.info("Using tolerance: \(coincidentPointTolerance) pixels", category: .general)
        
        var totalCoincidentGroups = 0
        var processedPoints: Set<PointID> = []
        
        // Scan all points in the document
        for layerIndex in document.layers.indices {
            let layer = document.layers[layerIndex]
            if !layer.isVisible { continue }
            
            for shape in layer.shapes {
                if !shape.isVisible { continue }
                
                Log.info("\n📋 Analyzing shape: \(shape.name)", category: .general)
                
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
                        if let position = getPointPosition(pointID) {
                            Log.info("   🔗 Coincident Group \(totalCoincidentGroups) at (\(position.x), \(position.y)):", category: .general)
                            Log.info("      Primary: Element \(elementIndex)", category: .general)
                            for coincidentPoint in coincidentPoints {
                                Log.info("      Coincident: Element \(coincidentPoint.elementIndex) in shape \(coincidentPoint.shapeID)", category: .general)
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
            Log.info("✅ No coincident points found in document", category: .fileOperations)
        } else {
            Log.info("\n📊 SUMMARY: Found \(totalCoincidentGroups) coincident point groups", category: .general)
            Log.fileOperation("💡 TIP: These points will move together when selected to maintain path continuity", level: .info)
        }
    }
    
    // MARK: - Smooth Handle Management for Coincident Points
    
    /// Enhanced function to move coincident points together with smooth curve logic
    /// This ensures that when coincident points are moved, their handles maintain 180-degree alignment
    func moveCoincidentPointsWithSmoothLogic(pointID: PointID, to newPosition: CGPoint, delta: CGPoint) {
        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
        
        for coincidentPointID in coincidentPoints {
            // Skip the original point (it's handled separately)
            if coincidentPointID == pointID { continue }
            
            // Find and update the coincident point
            for layerIndex in document.layers.indices {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == coincidentPointID.shapeID }) {
                    guard coincidentPointID.elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { continue }
                    
                    var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
                    let newPoint = VectorPoint(newPosition.x, newPosition.y)
                    
                    // Move the coincident point to the same new position
                    switch elements[coincidentPointID.elementIndex] {
                    case .move(_):
                        elements[coincidentPointID.elementIndex] = .move(to: newPoint)
                    case .line(_):
                        elements[coincidentPointID.elementIndex] = .line(to: newPoint)
                    case .curve(_, let control1, let control2):
                        elements[coincidentPointID.elementIndex] = .curve(to: newPoint, control1: control1, control2: control2)
                    case .quadCurve(_, let control):
                        elements[coincidentPointID.elementIndex] = .quadCurve(to: newPoint, control: control)
                    case .close:
                        continue
                    }
                    
                    // Apply smooth curve logic if this coincident point is a smooth curve point
                    if isSmoothCurvePoint(elements: elements, elementIndex: coincidentPointID.elementIndex) {
                        moveSmoothCurveHandles(elements: &elements, elementIndex: coincidentPointID.elementIndex, delta: delta)
                        Log.info("🔗 COINCIDENT SMOOTH: Applied smooth curve logic to coincident point at element \(coincidentPointID.elementIndex) in shape \(coincidentPointID.shapeID)", category: .general)
                    }
                    
                    // Update the shape
                    document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    break
                }
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
            // Move the anchor point (already done in the calling function)
            let anchorPoint = CGPoint(x: to.x, y: to.y)
            
            // Move incoming handle (control2) of current element
            let newControl2 = VectorPoint(control2.x + delta.x, control2.y + delta.y)
            elements[elementIndex] = .curve(to: to, control1: control1, control2: newControl2)
            
            // Move outgoing handle (control1 of NEXT element) if it exists
            if elementIndex + 1 < elements.count {
                let nextElement = elements[elementIndex + 1]
                if case .curve(let nextTo, let nextControl1, let nextControl2) = nextElement {
                    // Use the existing calculateLinkedHandle logic to maintain 180-degree alignment
                    let oppositeHandle = calculateLinkedHandle(
                        anchorPoint: anchorPoint,
                        draggedHandle: CGPoint(x: newControl2.x, y: newControl2.y),
                        originalOppositeHandle: CGPoint(x: nextControl1.x, y: nextControl1.y)
                    )
                    
                    let newNextControl1 = VectorPoint(oppositeHandle.x, oppositeHandle.y)
                    elements[elementIndex + 1] = .curve(to: nextTo, control1: newNextControl1, control2: nextControl2)
                }
            }
            
        default:
            break
        }
    }
    
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
            
            if case .curve(let lastTo, let lastControl1, let lastControl2) = elements[lastElementIndex] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: lastControl2.x, y: lastControl2.y) // Use INCOMING handle of last point
                )
                
                // Update both handles
                elements[draggedHandleID.elementIndex] = updateElementControl1(elements[draggedHandleID.elementIndex], newControl1: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[lastElementIndex] = .curve(to: lastTo, control1: lastControl1, control2: VectorPoint(oppositeHandle.x, oppositeHandle.y))
                
                Log.info("🔗 COINCIDENT SMOOTH: Updated first→last handles", category: .general)
                return true
            }
            
        } else if draggedHandleID.handleType == .control2 && draggedHandleID.elementIndex == lastElementIndex {
            // Dragging INCOMING handle to last point (control2 of last element)
            // Update OUTGOING handle from first point (control1 of second element)
            
            if elements.count > 1, case .curve(let secondTo, let secondControl1, let secondControl2) = elements[1] {
                let oppositeHandle = calculateLinkedHandle(
                    anchorPoint: anchorPoint,
                    draggedHandle: newDraggedPosition,
                    originalOppositeHandle: CGPoint(x: secondControl1.x, y: secondControl1.y) // Use OUTGOING handle from first point
                )
                
                // Update both handles
                elements[draggedHandleID.elementIndex] = updateElementControl2(elements[draggedHandleID.elementIndex], newControl2: VectorPoint(newDraggedPosition.x, newDraggedPosition.y))
                elements[1] = .curve(to: secondTo, control1: VectorPoint(oppositeHandle.x, oppositeHandle.y), control2: secondControl2)
                
                Log.info("🔗 COINCIDENT SMOOTH: Updated last→first handles", category: .general)
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
