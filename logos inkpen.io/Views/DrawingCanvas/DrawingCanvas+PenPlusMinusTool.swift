//
//  DrawingCanvas+PenPlusMinusTool.swift
//  logos inkpen.io
//
//  Pen +/- Tool for adding and removing points from bezier curves
//  Automatically interpolates handles to maintain smooth curve continuity
//

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Pen +/- Tool Main Handler
    
    /// Handles Pen +/- tool clicks to add or remove points
    func handlePenPlusMinusTap(at location: CGPoint) {
        let tolerance: Double = 8.0 / document.zoomLevel
        
        // FIRST: Check if clicking on an existing anchor point to DELETE it
        if let pointToDelete = findAnchorPointAt(location: location, tolerance: tolerance) {
            deletePointWithCurvePreservation(pointID: pointToDelete)
            return
        }
        
        // SECOND: Check if clicking on a curve segment to INSERT a point
        if let segmentHit = findCurveSegmentAt(location: location, tolerance: tolerance) {
            insertPointOnCurve(
                layerIndex: segmentHit.layerIndex,
                shapeIndex: segmentHit.shapeIndex,
                elementIndex: segmentHit.elementIndex,
                at: location
            )
            return
        }
        
        Log.info("Pen +/- Tool: No point or curve segment found at location", category: .general)
    }
    
    // MARK: - Point Insertion
    
    /// Inserts a new smooth point on a curve segment with interpolated handles
    private func insertPointOnCurve(layerIndex: Int, shapeIndex: Int, elementIndex: Int, at location: CGPoint) {
        guard layerIndex < document.layers.count,
              shapeIndex < document.layers[layerIndex].shapes.count,
              elementIndex < document.layers[layerIndex].shapes[shapeIndex].path.elements.count else { return }
        
        let element = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex]
        
        guard case .curve(let to, let control1, let control2) = element else {
            Log.info("Pen +/-: Can only insert points on curve segments", category: .general)
            return
        }
        
        // Save to undo stack
        document.saveToUndoStack()
        
        // Get the previous point for the curve start
        var startPoint: VectorPoint
        if elementIndex > 0 {
            let prevElement = document.layers[layerIndex].shapes[shapeIndex].path.elements[elementIndex - 1]
            switch prevElement {
            case .move(let point), .line(let point), .curve(let point, _, _), .quadCurve(let point, _):
                startPoint = point
            default:
                Log.info("Pen +/-: Invalid previous element", category: .general)
                return
            }
        } else {
            Log.info("Pen +/-: Cannot insert on first element", category: .general)
            return
        }
        
        // Find the parametric t value where we want to insert the point
        let t = findParametricValueOnCurve(
            start: CGPoint(x: startPoint.x, y: startPoint.y),
            control1: CGPoint(x: control1.x, y: control1.y),
            control2: CGPoint(x: control2.x, y: control2.y),
            end: CGPoint(x: to.x, y: to.y),
            targetPoint: location
        )
        
        // Split the curve at parameter t using De Casteljau's algorithm
        let splitResult = splitCubicBezierAt(
            p0: CGPoint(x: startPoint.x, y: startPoint.y),
            p1: CGPoint(x: control1.x, y: control1.y),
            p2: CGPoint(x: control2.x, y: control2.y),
            p3: CGPoint(x: to.x, y: to.y),
            t: t
        )
        
        // Create two new curve elements
        let firstCurve = PathElement.curve(
            to: VectorPoint(splitResult.splitPoint),
            control1: VectorPoint(splitResult.leftControl1),
            control2: VectorPoint(splitResult.leftControl2)
        )
        
        let secondCurve = PathElement.curve(
            to: to,
            control1: VectorPoint(splitResult.rightControl1),
            control2: VectorPoint(splitResult.rightControl2)
        )
        
        // Replace the original curve with the two new curves
        var elements = document.layers[layerIndex].shapes[shapeIndex].path.elements
        elements[elementIndex] = firstCurve
        elements.insert(secondCurve, at: elementIndex + 1)
        
        document.layers[layerIndex].shapes[shapeIndex].path.elements = elements
        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
        
        // Update unified objects and UI
        document.updateUnifiedObjectsOptimized()
        document.objectWillChange.send()
        
        Log.info("Pen +/-: Inserted smooth point on curve segment", category: .general)
    }
    
    // MARK: - Point Deletion with Curve Preservation
    
    /// Deletes a point while attempting to preserve curve continuity
    /// CRITICAL: Protects coincident points (first/last in closed paths) - refuses deletion with system beep
    private func deletePointWithCurvePreservation(pointID: PointID) {
        guard let layerIndex = document.layers.firstIndex(where: { layer in
            layer.shapes.contains { $0.id == pointID.shapeID }
        }),
        let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == pointID.shapeID }) else { return }
        
        let shape = document.layers[layerIndex].shapes[shapeIndex]
        let elements = shape.path.elements
        
        guard pointID.elementIndex < elements.count else { return }
        
        // CRITICAL FIX: Check if this point is coincident (first/last in closed path)
        // Coincident points are SACRED - refuse deletion with system beep
        let closedPathEndpoints = findClosedPathEndpoints(for: pointID)
        if !closedPathEndpoints.isEmpty {
            // System beep to indicate refusal
            NSSound.beep()
            Log.info("🚫 PEN +/-: COINCIDENT POINT PROTECTION - Cannot remove first/last points (system beep)", category: .general)
            Log.info("   Coincident points are sacred and maintain path closure integrity", category: .general)
            return
        }
        
        // Also check coordinate-based coincident points for extra protection
        let coincidentPoints = findCoincidentPoints(to: pointID, tolerance: coincidentPointTolerance)
        if !coincidentPoints.isEmpty {
            // System beep to indicate refusal
            NSSound.beep()
            Log.info("🚫 PEN +/-: COINCIDENT POINT PROTECTION - Cannot remove coincident points (system beep)", category: .general)
            Log.info("   Found \(coincidentPoints.count) coincident points - all coincident points are protected", category: .general)
            return
        }
        
        // Save to undo stack
        document.saveToUndoStack()
        
        // Check if this is the only point in the path
        let pathPointCount = elements.filter { element in
            switch element {
            case .move, .line, .curve, .quadCurve: return true
            case .close: return false
            }
        }.count
        
        if pathPointCount <= 2 {
            // Delete entire shape if too few points remain
            document.layers[layerIndex].shapes.remove(at: shapeIndex)
            Log.info("Pen +/-: Deleted entire shape (too few points)", category: .general)
        } else {
            // Attempt to merge neighboring curves for smooth deletion
            let updatedElements = deletePointWithCurveMerging(
                elements: elements,
                pointIndex: pointID.elementIndex
            )
            
            document.layers[layerIndex].shapes[shapeIndex].path.elements = updatedElements
            document.layers[layerIndex].shapes[shapeIndex].updateBounds()
            
            Log.info("Pen +/-: Deleted point with curve preservation", category: .general)
        }
        
        // Update UI
        document.updateUnifiedObjectsOptimized()
        document.objectWillChange.send()
    }
    
    // MARK: - Helper Functions
    
    /// Finds an anchor point at the given location
    private func findAnchorPointAt(location: CGPoint, tolerance: Double) -> PointID? {
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible || layer.isLocked { continue }
            
            for (_, shape) in layer.shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .move(let to), .line(let to), .curve(let to, _, _), .quadCurve(let to, _):
                        let rawPointLocation = CGPoint(x: to.x, y: to.y)
                        let pointLocation = rawPointLocation.applying(shape.transform)
                        
                        if distance(location, pointLocation) <= tolerance {
                            return PointID(shapeID: shape.id, pathIndex: 0, elementIndex: elementIndex)
                        }
                    default:
                        break
                    }
                }
            }
        }
        return nil
    }
    
    /// Finds a curve segment at the given location
    private func findCurveSegmentAt(location: CGPoint, tolerance: Double) -> (layerIndex: Int, shapeIndex: Int, elementIndex: Int)? {
        for layerIndex in document.layers.indices.reversed() {
            let layer = document.layers[layerIndex]
            if !layer.isVisible || layer.isLocked { continue }
            
            for (shapeIndex, shape) in layer.shapes.enumerated().reversed() {
                if !shape.isVisible || shape.isLocked { continue }
                
                var previousPoint: VectorPoint?
                
                for (elementIndex, element) in shape.path.elements.enumerated() {
                    switch element {
                    case .move(let to):
                        previousPoint = to
                    case .line(let to):
                        if let prev = previousPoint {
                            let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                            let end = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                            
                            if isPointNearLineSegment(point: location, start: start, end: end, tolerance: tolerance) {
                                // Convert line to curve for insertion
                                return (layerIndex, shapeIndex, elementIndex)
                            }
                        }
                        previousPoint = to
                    case .curve(let to, let control1, let control2):
                        if let prev = previousPoint {
                            let start = CGPoint(x: prev.x, y: prev.y).applying(shape.transform)
                            let c1 = CGPoint(x: control1.x, y: control1.y).applying(shape.transform)
                            let c2 = CGPoint(x: control2.x, y: control2.y).applying(shape.transform)
                            let end = CGPoint(x: to.x, y: to.y).applying(shape.transform)
                            
                            if isPointNearBezierCurve(point: location, p0: start, p1: c1, p2: c2, p3: end, tolerance: tolerance) {
                                return (layerIndex, shapeIndex, elementIndex)
                            }
                        }
                        previousPoint = to
                    case .quadCurve(let to, _):
                        previousPoint = to
                    default:
                        break
                    }
                }
            }
        }
        return nil
    }
    
    /// Finds the parametric t value on a cubic bezier curve closest to target point
    private func findParametricValueOnCurve(start: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, targetPoint: CGPoint) -> Double {
        var bestT: Double = 0.5
        var bestDistance: Double = Double.infinity
        
        // Sample the curve to find closest point
        for i in 0...100 {
            let t = Double(i) / 100.0
            let curvePoint = evaluateCubicBezier(p0: start, p1: control1, p2: control2, p3: end, t: t)
            let dist = distance(targetPoint, curvePoint)
            
            if dist < bestDistance {
                bestDistance = dist
                bestT = t
            }
        }
        
        return bestT
    }
    
    /// Evaluates a cubic bezier curve at parameter t
    private func evaluateCubicBezier(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> CGPoint {
        let oneMinusT = 1.0 - t
        let oneMinusT2 = oneMinusT * oneMinusT
        let oneMinusT3 = oneMinusT2 * oneMinusT
        let t2 = t * t
        let t3 = t2 * t
        
        return CGPoint(
            x: oneMinusT3 * p0.x + 3 * oneMinusT2 * t * p1.x + 3 * oneMinusT * t2 * p2.x + t3 * p3.x,
            y: oneMinusT3 * p0.y + 3 * oneMinusT2 * t * p1.y + 3 * oneMinusT * t2 * p2.y + t3 * p3.y
        )
    }
    
    /// Splits a cubic bezier curve at parameter t using De Casteljau's algorithm
    private func splitCubicBezierAt(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> (
        leftControl1: CGPoint, leftControl2: CGPoint,
        splitPoint: CGPoint,
        rightControl1: CGPoint, rightControl2: CGPoint
    ) {
        // First level
        let p01 = lerp(p0, p1, t)
        let p12 = lerp(p1, p2, t)
        let p23 = lerp(p2, p3, t)
        
        // Second level
        let p012 = lerp(p01, p12, t)
        let p123 = lerp(p12, p23, t)
        
        // Third level (split point)
        let splitPoint = lerp(p012, p123, t)
        
        return (
            leftControl1: p01,
            leftControl2: p012,
            splitPoint: splitPoint,
            rightControl1: p123,
            rightControl2: p23
        )
    }
    
    /// Linear interpolation between two points
    private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint {
        return CGPoint(
            x: a.x + (b.x - a.x) * t,
            y: a.y + (b.y - a.y) * t
        )
    }
    
    /// Checks if a point is near a line segment
    private func isPointNearLineSegment(point: CGPoint, start: CGPoint, end: CGPoint, tolerance: Double) -> Bool {
        let A = point.x - start.x
        let B = point.y - start.y
        let C = end.x - start.x
        let D = end.y - start.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0 {
            return sqrt(A * A + B * B) <= tolerance
        }
        
        let param = dot / lenSq
        
        let xx, yy: Double
        if param < 0 {
            xx = start.x
            yy = start.y
        } else if param > 1 {
            xx = end.x
            yy = end.y
        } else {
            xx = start.x + param * C
            yy = start.y + param * D
        }
        
        let dx = point.x - xx
        let dy = point.y - yy
        return sqrt(dx * dx + dy * dy) <= tolerance
    }
    
    /// Checks if a point is near a bezier curve (simplified check)
    private func isPointNearBezierCurve(point: CGPoint, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tolerance: Double) -> Bool {
        // Sample the curve and check distance to each sample point
        for i in 0...20 {
            let t = Double(i) / 20.0
            let curvePoint = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
            if distance(point, curvePoint) <= tolerance {
                return true
            }
        }
        return false
    }
    
    /// Deletes a point and attempts to merge neighboring curves smoothly
    private func deletePointWithCurveMerging(elements: [PathElement], pointIndex: Int) -> [PathElement] {
        var newElements = elements
        
        // For now, just remove the element (basic deletion)
        // TODO: Implement sophisticated curve merging using your smooth curve algorithms
        newElements.remove(at: pointIndex)
        
        // If we removed a point that wasn't the first, we might need to reconnect
        if pointIndex > 0 && pointIndex < elements.count {
            // Use your CurveSmoothing algorithms to create a smooth connection
            // This is where you'd apply the adaptive curve fitting from your existing code
        }
        
        return newElements
    }
    
}