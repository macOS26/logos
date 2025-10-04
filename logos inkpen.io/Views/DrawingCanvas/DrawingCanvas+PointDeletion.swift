//
//  DrawingCanvas+PointDeletion.swift
//  logos inkpen.io
//
//  Point deletion functionality
//

import SwiftUI
import Combine

extension DrawingCanvas {
    internal func deleteSelectedPoints() {
        // Group selected points by shape ID
        let pointsByShape = Dictionary(grouping: selectedPoints) { $0.shapeID }
        
        for (shapeID, points) in pointsByShape {
            // Find the shape
            for layerIndex in document.layers.indices {
                let shapes = document.getShapesForLayer(layerIndex)
                if let shapeIndex = shapes.firstIndex(where: { $0.id == shapeID }),
                   let shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) {
                    
                    // If all points are selected, delete the entire shape
                    let pathPointCount = shape.path.elements.filter { element in
                        switch element {
                        case .move, .line, .curve, .quadCurve: return true
                        case .close: return false
                        }
                    }.count
                    
                    if points.count >= pathPointCount || pathPointCount <= 2 {
                        // Delete entire shape using unified helper
                        document.removeShapeFromUnifiedSystem(id: shape.id)
                    } else {
                        // Delete specific points while maintaining path integrity
                        let updatedPath = deletePointsFromPath(shape.path, selectedPoints: points)
                        document.updateShapePathUnified(id: shape.id, path: updatedPath)
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
    
            // MARK: - Professional Point Deletion (Professional Standards)
    internal func closeBezierPath() {
        guard bezierPath != nil,
                let activeShape = activeBezierShape,
              bezierPoints.count >= 3 else {
            cancelBezierDrawing()
            return
        }
        
        // CRITICAL FIX: Update path with handles BEFORE closing to preserve curve data
        updatePathWithHandles()
        
        // PROFESSIONAL PATH CLOSING: Connect last point to first with proper curve
        guard let updatedPath = bezierPath else {
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
        } else if let lastControl2 = lastPointHandles?.control2 {
            // Only last point has handle - create asymmetric curve
            finalElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstPoint))
        } else if let firstControl1 = firstPointHandles?.control1 {
            // Only first point has handle - create asymmetric curve
            finalElements.append(.curve(to: firstPoint, control1: VectorPoint(bezierPoints[lastIndex].x, bezierPoints[lastIndex].y), control2: firstControl1))
        } else {
            // No handles - straight line close
            finalElements.append(.line(to: firstPoint))
        }
        
        // Add close element to mark path as closed
        finalElements.append(.close)
        
        // Create final closed path preserving all curve data
        let closedPath = VectorPath(elements: finalElements, isClosed: true)
        
        // PROFESSIONAL REAL-TIME CLOSED PATH: Update the existing shape with closed path and default fill
        // Closed paths get both stroke AND fill using document defaults
        if let layerIndex = document.selectedLayerIndex {
            let shapes = document.getShapesForLayer(layerIndex)
            if let shapeIndex = shapes.firstIndex(where: { $0.id == activeShape.id }) {
                guard var shape = document.getShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex) else { return }
                
                // Update the existing shape to be closed with fill
                shape.path = closedPath
                // FINAL FILL: Make fully opaque when path is closed
                shape.fillStyle = FillStyle(
                    color: document.defaultFillColor,
                    opacity: document.defaultFillOpacity // Full opacity (usually 1.0)
                )
                shape.updateBounds()
                
                // Update the shape using unified setter
                document.setShapeAtIndex(layerIndex: layerIndex, shapeIndex: shapeIndex, shape: shape)
            }
        }
        

        
        // CRITICAL FIX: Force UI update to ensure the closed shape is immediately visible
        document.objectWillChange.send()
        
        // TRACING WORKFLOW IMPROVEMENT: Don't auto-switch tools to allow continuous pen tool usage
        // This allows users to trace multiple objects without tool interruption

        
        // Clear bezier state BUT KEEP pen tool active for continuous tracing
        cancelBezierDrawing()

        // Clear the current shape ID since we're done drawing
        currentShapeId = nil
        
        // Hide any close path hints
        showClosePathHint = false
        showContinuePathHint = false
        
        // NOTE: Removed automatic tool switch to direct selection
        // Users can manually switch tools when they're ready to edit points
        // This enables uninterrupted tracing workflows
        
    }
} 
