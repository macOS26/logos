//
//  DrawingCanvas+PointDeletion.swift
//  logos inkpen.io
//
//  Point deletion functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func deleteSelectedPoints() {
        // Group selected points by shape ID
        let pointsByShape = Dictionary(grouping: selectedPoints) { $0.shapeID }
        
        for (shapeID, points) in pointsByShape {
            // Find the shape
            for layerIndex in document.layers.indices {
                if let shapeIndex = document.layers[layerIndex].shapes.firstIndex(where: { $0.id == shapeID }) {
                    let shape = document.layers[layerIndex].shapes[shapeIndex]
                    
                    // If all points are selected, delete the entire shape
                    let pathPointCount = shape.path.elements.filter { element in
                        switch element {
                        case .move, .line, .curve, .quadCurve: return true
                        case .close: return false
                        }
                    }.count
                    
                    if points.count >= pathPointCount || pathPointCount <= 2 {
                        // Delete entire shape
                        document.layers[layerIndex].shapes.remove(at: shapeIndex)
                        print("Deleted entire shape")
                    } else {
                        // Delete specific points while maintaining path integrity
                        let updatedPath = deletePointsFromPath(shape.path, selectedPoints: points)
                        document.layers[layerIndex].shapes[shapeIndex].path = updatedPath
                        document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                        print("Deleted \(points.count) points from path, \(updatedPath.elements.count) elements remain")
                    }
                    break
                }
            }
        }
        
        // Clear selection
        selectedPoints.removeAll()
        selectedHandles.removeAll()
        
        // Force UI update
        document.objectWillChange.send()
    }
    
    // MARK: - Professional Point Deletion (Adobe Illustrator Standards)
    internal func closeBezierPath() {
        guard let _ = bezierPath,
                let activeShape = activeBezierShape,
              bezierPoints.count >= 3 else {
            print("Cannot close bezier path - insufficient points or no path")
            cancelBezierDrawing()
            return
        }
        
        // CRITICAL FIX: Update path with handles BEFORE closing to preserve curve data
        updatePathWithHandles()
        
        // PROFESSIONAL PATH CLOSING: Connect last point to first with proper curve
        guard let updatedPath = bezierPath else {
            print("Failed to update path with handles")
            cancelBezierDrawing()
            return
        }
        
        // Check if we need to add a closing curve from last point to first point
        let firstPoint = bezierPoints[0]
        let lastIndex = bezierPoints.count - 1
        
        // Get handle information for proper closing curve
        let lastPointHandles = bezierHandles[lastIndex]
        let firstPointHandles = bezierHandles[0]
        
        var finalElements = updatedPath.elements
        
        // Add closing segment with proper curve handling
        if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
            // Both points have handles - create smooth closing curve
            finalElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstControl1))
            print("🎯 Created smooth closing curve with both handles")
        } else if let lastControl2 = lastPointHandles?.control2 {
            // Only last point has handle - create asymmetric curve
            finalElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstPoint))
            print("🎯 Created closing curve with outgoing handle")
        } else if let firstControl1 = firstPointHandles?.control1 {
            // Only first point has handle - create asymmetric curve
            finalElements.append(.curve(to: firstPoint, control1: VectorPoint(bezierPoints[lastIndex].x, bezierPoints[lastIndex].y), control2: firstControl1))
            print("🎯 Created closing curve with incoming handle")
        } else {
            // No handles - straight line close
            finalElements.append(.line(to: firstPoint))
            print("🎯 Created straight line closing")
        }
        
        // Add close element to mark path as closed
        finalElements.append(.close)
        
        // Create final closed path preserving all curve data
        let closedPath = VectorPath(elements: finalElements, isClosed: true)
        
        // PROFESSIONAL REAL-TIME CLOSED PATH: Update the existing shape with closed path and default fill
        // Closed paths get both stroke AND fill using document defaults
        if let layerIndex = document.selectedLayerIndex {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                if document.layers[layerIndex].shapes[shapeIndex].id == activeShape.id {
                    // Update the existing shape to be closed with fill
                    document.layers[layerIndex].shapes[shapeIndex].path = closedPath
                    // FINAL FILL: Make fully opaque when path is closed
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: document.defaultFillColor,
                        opacity: document.defaultFillOpacity // Full opacity (usually 1.0)
                    )
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    break
                }
            }
        }
        
        print("🔧 DEBUG STEP 3: Path CLOSED - final curve creation")
        print("✅ SUCCESSFULLY CLOSED BEZIER PATH with \(bezierPoints.count) points using document defaults")
        print("Path elements: \(closedPath.elements.count) (including close)")
        print("Curve data preserved: \(closedPath.elements.compactMap { if case .curve = $0 { return 1 } else { return nil } }.count) curves")
        print("🎨 PEN TOOL CLOSED PATH COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
        
        // TRACING WORKFLOW IMPROVEMENT: Don't auto-switch tools to allow continuous pen tool usage
        // This allows users to trace multiple objects without tool interruption
        let _ = activeShape.id // Unused variable
        
        // Clear bezier state BUT KEEP pen tool active for continuous tracing
        cancelBezierDrawing()
        
        // Hide any close path hints
        showClosePathHint = false
        
        // NOTE: Removed automatic tool switch to direct selection
        // Users can manually switch tools when they're ready to edit points
        // This enables uninterrupted tracing workflows
        
        print("✅ CLOSED PATH: Pen tool remains active for continuous tracing")
    }
} 