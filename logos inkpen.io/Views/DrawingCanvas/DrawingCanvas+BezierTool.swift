//
//  DrawingCanvas+BezierTool.swift
//  logos inkpen.io
//
//  Bezier tool functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func cancelBezierDrawing() {
        bezierPath = nil
        bezierPoints.removeAll()
        isBezierDrawing = false
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        activeBezierPointIndex = nil
        bezierHandles.removeAll()
        currentMouseLocation = nil
        showClosePathHint = false
        activeBezierShape = nil // Clear the real shape reference
    }
    
    internal func handleBezierPenTap(at location: CGPoint) {
        // 🔒 COMPLETE ISOLATION: Pen tool is TOTALLY isolated from existing objects
        // ✅ NO hit-testing against existing shapes, locked objects, or other layers
        // ✅ NO interference from pasteboard vs canvas area differences
        // ✅ NO automatic finishing except explicit user actions (green close hints)
        // ✅ ONLY interacts with the current path being drawn
        
        // Check if we're trying to close the CURRENT path by clicking near its first point
        // CRITICAL: Only allow closing if the green close hint is showing (explicit user intent)
        if isBezierDrawing && bezierPoints.count >= 3 && showClosePathHint {
            let firstPoint = bezierPoints[0]
            let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
            if distance(location, firstPointLocation) <= 25.0 { // Close tolerance (Adobe Illustrator standard)
                closeBezierPath()
                return
            }
        }
        
        if !isBezierDrawing {
            // CREATE FIRST POINT IMMEDIATELY: Handle both canvas and pasteboard areas consistently
            // This allows click-and-drag for smooth points or simple clicks for corner points
            
            // Create the bezier path and add the first point as a corner point
            bezierPath = VectorPath(elements: [.move(to: VectorPoint(location))])
            bezierPoints = [VectorPoint(location)]
            isBezierDrawing = true
            activeBezierPointIndex = 0 // First point is active (solid)
            bezierHandles.removeAll()
            
            // Create real VectorShape with document default colors
            let strokeStyle = StrokeStyle(
                color: document.defaultStrokeColor,
                width: 1.0,
                opacity: document.defaultStrokeOpacity
            )
            let fillStyle = FillStyle(
                color: document.defaultFillColor,
                opacity: document.defaultFillOpacity
            )
            
            activeBezierShape = VectorShape(
                name: "Bezier Path",
                path: bezierPath!,
                strokeStyle: strokeStyle,
                fillStyle: fillStyle
            )
            
            // Add the real shape to the document immediately
            document.addShape(activeBezierShape!)
            
            print("🎯 CREATED FIRST POINT: Started new path at \(location)")
            print("🎨 PEN TOOL INITIAL COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
            return
        } else {
            // PURE CLICK: Add corner point (no handles)
            // Make previous point inactive (hollow)
            let previousActiveIndex = activeBezierPointIndex
            
            // Add new corner point and make it active (solid)
            let newPoint = VectorPoint(location)
            bezierPoints.append(newPoint)
            activeBezierPointIndex = bezierPoints.count - 1
            
            // CRITICAL FIX: Check if previous point has handles and create curve accordingly
            // This ensures intermediate path matches rubber band preview
            
            let previousPointIndex = bezierPoints.count - 2 // Previous point (before the new one)
            
            if previousPointIndex >= 0,
               let previousHandles = bezierHandles[previousPointIndex],
               let previousControl2 = previousHandles.control2 {
                // CURVE: Previous point has outgoing handle, create curve like rubber band preview
                print("🔧 DEBUG STEP 2: Creating CURVE (matches rubber band preview)")
                print("   Previous point \(previousPointIndex) has outgoing handle at: (\(previousControl2.x), \(previousControl2.y))")
                
                // FIXED: Use EXACT same math as step 3 - no complex handle calculation!
                // Step 3 uses: control1: previousControl2, control2: targetPoint
                // This creates natural curves without hooks
                bezierPath?.addElement(.curve(to: newPoint, control1: previousControl2, control2: newPoint))
                print("   ✅ Added CURVE element (matches rubber band preview)")
            } else {
                // STRAIGHT LINE: Previous point has no handles or is first point
                print("🔧 DEBUG STEP 2: Creating straight line - previous point has no handles")
                bezierPath?.addElement(.line(to: newPoint))
            }
            
            // Update the real shape in the document immediately
            updateActiveBezierShapeInDocument()
            
            print("🎯 CORNER POINT: Added point \(bezierPoints.count) at \(location) (pure click - no drag)")
            print("📍 Previous point \(previousActiveIndex ?? -1) is now hollow, current point \(activeBezierPointIndex ?? -1) is solid")
        }
    }
    
    internal func handleBezierPenDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        let currentLocation = screenToCanvas(value.location, geometry: geometry)
        
        // Calculate actual drag distance to distinguish click vs drag
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let minimumDragThreshold: Double = 8.0 // Must drag at least 8 pixels to create handles
        
        // First point creation is now handled in handleBezierPenTap()
        // This drag handler only deals with subsequent points and handle manipulation
        if !isBezierDrawing {
            print("⚠️ Warning: Drag detected but no bezier path active - first point should be created in tap handler")
            return
        }
        
        // Regular bezier pen drag handling (for existing paths)
        guard isBezierDrawing else { return }
        
        // Only proceed with handle creation if user has dragged significantly
        if dragDistance < minimumDragThreshold {
            print("🎯 BEZIER PEN: Drag distance (\(String(format: "%.1f", dragDistance))px) below threshold - treating as CLICK, no handles created")
            return
        }
        
        print("🎯 BEZIER PEN: Drag distance (\(String(format: "%.1f", dragDistance))px) above threshold - FIRST plotting new point, THEN creating handles")
        
        // Check if we're dragging from an existing anchor point (editing existing handles)
        let tolerance: Double = 8.0
        var draggedPointIndex: Int? = nil
        
        for (index, point) in bezierPoints.enumerated() {
            let pointLocation = CGPoint(x: point.x, y: point.y)
            if distance(startLocation, pointLocation) <= tolerance {
                draggedPointIndex = index
                break
            }
        }
        
        if let pointIndex = draggedPointIndex {
            // EXISTING POINT: User is dragging from an existing anchor point to edit its handles
            if !isDraggingBezierHandle {
                isDraggingBezierHandle = true
                isDraggingBezierPoint = true
                print("📝 EDITING: Dragging handles from existing point \(pointIndex)")
            }
            
            // Create/update bezier handles for this existing point
            let point = bezierPoints[pointIndex]
            let pointLocation = CGPoint(x: point.x, y: point.y)
            
            // Calculate handle positions based on drag direction
            let dragVector = CGPoint(
                x: currentLocation.x - pointLocation.x,
                y: currentLocation.y - pointLocation.y
            )
            
            // FIXED: Create symmetric handles with correct assignment (professional behavior)
            // control1 = INCOMING handle (opposite to drag direction)
            // control2 = OUTGOING handle (follows drag direction)
            let control1 = VectorPoint(
                pointLocation.x - dragVector.x,
                pointLocation.y - dragVector.y
            )
            let control2 = VectorPoint(
                pointLocation.x + dragVector.x,
                pointLocation.y + dragVector.y
            )
            
            // Store handle information
            bezierHandles[pointIndex] = BezierHandleInfo(
                control1: control1,
                control2: control2,
                hasHandles: true
            )
            
            // Update the path elements to use curves where handles exist
            updatePathWithHandles()
            
            // Update the real shape in the document immediately
            updateActiveBezierShapeInDocument()
            
        } else {
            // NEW POINT: User is creating a new point with drag
            if !isDraggingBezierHandle {
                isDraggingBezierHandle = true
                
                // ✨ NEW BEHAVIOR: First plot the new anchor point at click location
                let newPoint = VectorPoint(startLocation)
                bezierPoints.append(newPoint)
                activeBezierPointIndex = bezierPoints.count - 1
                
                // Add the new point to the path as a line segment initially
                bezierPath?.addElement(.line(to: newPoint))
                
                print("🎯 NEW POINT: First plotted anchor point \(bezierPoints.count) at \(startLocation)")
                print("📏 Now creating smooth curve handles as user drags...")
            }
            
            // Create handles for the newly placed point based on drag direction
            let activeIndex = bezierPoints.count - 1
            let activePoint = bezierPoints[activeIndex]
            let activeLocation = CGPoint(x: activePoint.x, y: activePoint.y)
            
            let dragVector = CGPoint(
                x: currentLocation.x - activeLocation.x,
                y: currentLocation.y - activeLocation.y
            )
            
            // FIXED: Correct handle assignment for intuitive UX
            // control1 = INCOMING handle (opposite to drag direction)
            // control2 = OUTGOING handle (follows drag direction - this is what user sees)
            let control1 = VectorPoint(
                activeLocation.x - dragVector.x * 0.5,
                activeLocation.y - dragVector.y * 0.5
            )
            let control2 = VectorPoint(
                activeLocation.x + dragVector.x * 0.5,
                activeLocation.y + dragVector.y * 0.5
            )
            
            bezierHandles[activeIndex] = BezierHandleInfo(
                control1: control1,
                control2: control2,
                hasHandles: true
            )
            
            updatePathWithHandles()
            
            // Update the real shape in the document immediately
            updateActiveBezierShapeInDocument()
        }
    }
    
    // MARK: - Professional Real-Time Path Updates (Adobe Illustrator Style)
    
    /// Updates the active bezier shape in the document with the current path
    /// This gives real-time visual feedback like professional vector apps
    internal func updateActiveBezierShapeInDocument() {
        guard let activeBezierShape = activeBezierShape,
              let updatedPath = bezierPath,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Find the shape in the document and update it
        for shapeIndex in document.layers[layerIndex].shapes.indices {
            if document.layers[layerIndex].shapes[shapeIndex].id == activeBezierShape.id {
                // Update the path with the latest bezier path data
                document.layers[layerIndex].shapes[shapeIndex].path = updatedPath
                
                // Update stroke color to match current toolbar selection (real-time)
                document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                    color: document.defaultStrokeColor,
                    width: 1.0,
                    opacity: document.defaultStrokeOpacity
                )
                
                // REAL-TIME FILL WITH OPACITY: Show entire fill while drawing! (BETTER THAN ADOBE!)
                document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                    color: document.defaultFillColor,
                    opacity: 0.4 // Semi-transparent fill during drawing
                )
                
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                break
            }
        }
        
        // Force UI update for real-time visual feedback
        document.objectWillChange.send()
    }
} 