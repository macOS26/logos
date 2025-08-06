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
            // SAFETY CHECK: Only create if we haven't already started a path
            if activeBezierShape == nil {
                // Create the bezier path and add the first point as a corner point
                bezierPath = VectorPath(elements: [.move(to: VectorPoint(location))])
                bezierPoints = [VectorPoint(location)]
                isBezierDrawing = true
                activeBezierPointIndex = 0 // First point is active (solid)
                bezierHandles.removeAll()
                
                // Create real VectorShape with document default colors
                let strokeStyle = StrokeStyle(
                    color: document.defaultStrokeColor,
                    width: document.defaultStrokeWidth, // Use user's default stroke width
                    lineCap: document.defaultStrokeLineCap, // Use user's default line cap
                    lineJoin: document.defaultStrokeLineJoin, // Use user's default line join
                    miterLimit: document.defaultStrokeMiterLimit, // Use user's default miter limit
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
            } else {
                print("🎯 BEZIER PEN TAP: Path already started - ignoring duplicate creation attempt")
            }
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
        
        // Handle first point creation if no bezier path is active (fixes gesture ordering issue)
        // SAFETY CHECK: Only create if we haven't already started a path
        if !isBezierDrawing && activeBezierShape == nil {
            // Create the first point immediately at the start location
            let firstPoint = VectorPoint(startLocation)
            bezierPath = VectorPath(elements: [.move(to: firstPoint)])
            bezierPoints = [firstPoint]
            isBezierDrawing = true
            activeBezierPointIndex = 0
            bezierHandles.removeAll()
            
            // Create real VectorShape with document default colors
            let strokeStyle = StrokeStyle(
                color: document.defaultStrokeColor,
                width: document.defaultStrokeWidth, // Use user's default stroke width
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
            
            print("🎯 CREATED FIRST POINT FROM DRAG: Started new path at \(startLocation)")
        } else if !isBezierDrawing && activeBezierShape != nil {
            print("🎯 BEZIER PEN DRAG: Path already started by tap handler - continuing with existing path")
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
                
                // DUPLICATE POINT FIX: Check if the last point was just created at this location
                // This prevents duplicate points when both tap and drag handlers fire
                let lastPoint = bezierPoints.last
                let distanceToLastPoint = lastPoint.map { distance(startLocation, CGPoint(x: $0.x, y: $0.y)) } ?? Double.infinity
                
                if distanceToLastPoint > 5.0 {
                    // Only add new point if it's not too close to the last one
                    let newPoint = VectorPoint(startLocation)
                    bezierPoints.append(newPoint)
                    activeBezierPointIndex = bezierPoints.count - 1
                    
                    // Add the new point to the path as a line segment initially
                    bezierPath?.addElement(.line(to: newPoint))
                    
                    print("🎯 NEW POINT: First plotted anchor point \(bezierPoints.count) at \(startLocation)")
                    // Creating smooth curve handles as user drags...
                } else {
                    // Point already exists nearby (probably from tap handler)
                    activeBezierPointIndex = bezierPoints.count - 1
                    print("🎯 EXISTING POINT: Using last point at (\(String(format: "%.1f", lastPoint?.x ?? 0)), \(String(format: "%.1f", lastPoint?.y ?? 0))) - no duplicate created")
                    // Creating smooth curve handles as user drags...
                }
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
                    width: document.defaultStrokeWidth, // Use user's default stroke width
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

    internal func finishBezierPath() {
        guard let activeBezierShape = activeBezierShape, bezierPoints.count >= 2 else {
            print("Cannot finish bezier path - insufficient points or no active shape")
            cancelBezierDrawing()
            return
        }
        
        // PROFESSIONAL REAL-TIME PATH COMPLETION: Apply final colors like Adobe Illustrator
        // Open paths should get both stroke AND fill using document defaults (toolbar selection)
        if let layerIndex = document.selectedLayerIndex {
            for shapeIndex in document.layers[layerIndex].shapes.indices {
                if document.layers[layerIndex].shapes[shapeIndex].id == activeBezierShape.id {
                    // Update the existing shape to have proper fill and stroke from toolbar
                    document.layers[layerIndex].shapes[shapeIndex].strokeStyle = StrokeStyle(
                        color: document.defaultStrokeColor,
                        width: document.defaultStrokeWidth, // Use user's default stroke width
                        opacity: document.defaultStrokeOpacity
                    )
                    // FINAL FILL: Make fully opaque when path is finished
                    document.layers[layerIndex].shapes[shapeIndex].fillStyle = FillStyle(
                        color: document.defaultFillColor,
                        opacity: document.defaultFillOpacity // Full opacity (usually 1.0)
                    )
                    document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                    break
                }
            }
        }
        
        print("✅ Finished bezier path with \(bezierPoints.count) points using toolbar colors")
        print("Path elements: \(activeBezierShape.path.elements.count)")
        print("Shape bounds: \(activeBezierShape.bounds)")
        print("🎨 PEN TOOL FINAL COLORS: stroke=\(document.defaultStrokeColor), fill=\(document.defaultFillColor)")
        print("🔍 Shape fill applied: \(FillStyle(color: document.defaultFillColor, opacity: document.defaultFillOpacity))")
        print("🔍 Shape stroke applied: \(StrokeStyle(color: document.defaultStrokeColor, width: document.defaultStrokeWidth, opacity: document.defaultStrokeOpacity))")
        
        // TRACING WORKFLOW IMPROVEMENT: Don't auto-switch tools to allow continuous pen tool usage
        // This allows users to trace multiple objects without tool interruption

        
        // Reset bezier state BUT KEEP pen tool active for continuous tracing
        cancelBezierDrawing()
        
        // NOTE: Removed automatic tool switch to direct selection
        // Users can manually switch tools when they're ready to edit points
        // This enables uninterrupted tracing workflows
        
        print("✅ FINISHED PATH: Pen tool remains active for continuous tracing")
    }
    
    internal func finishBezierPenDrag() {
        // Reset bezier drag state
        isDraggingBezierHandle = false
        isDraggingBezierPoint = false
        
        // Update the real shape in the document
        updateActiveBezierShapeInDocument()
    }
    
    /// Updates the active bezier shape with a specific path (used for live previews)
    internal func updateActiveBezierShapeWithPath(_ path: VectorPath) {
        guard let activeBezierShape = activeBezierShape,
              let layerIndex = document.selectedLayerIndex else { return }
        
        // Find the shape in the document and update it
        for shapeIndex in document.layers[layerIndex].shapes.indices {
            if document.layers[layerIndex].shapes[shapeIndex].id == activeBezierShape.id {
                // Update the path with the live preview path
                document.layers[layerIndex].shapes[shapeIndex].path = path
                document.layers[layerIndex].shapes[shapeIndex].updateBounds()
                break
            }
        }
        
        // Force UI update for real-time visual feedback
        document.objectWillChange.send()
    }
    
    /// Updates the live path with a closing preview
    internal func updateLivePathWithClosingPreview(mouseLocation: CGPoint) {
        guard let currentBezierPath = bezierPath else { return }
        
        var liveElements = currentBezierPath.elements
        let lastPointIndex = bezierPoints.count - 1
        let firstPoint = bezierPoints[0]
        
        // Check for handles to create appropriate closing curve
        let lastPointHandles = bezierHandles[lastPointIndex]
        let firstPointHandles = bezierHandles[0]
        
        if let lastControl2 = lastPointHandles?.control2, let firstControl1 = firstPointHandles?.control1 {
            // Both points have handles - smooth closing curve
            liveElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstControl1))
        } else if let lastControl2 = lastPointHandles?.control2 {
            // Only last point has handle - asymmetric curve
            liveElements.append(.curve(to: firstPoint, control1: lastControl2, control2: firstPoint))
        } else {
            // Straight line close
            liveElements.append(.line(to: firstPoint))
        }
        
        // Add close element for preview
        liveElements.append(.close)
        
        // Update the live path
        let livePath = VectorPath(elements: liveElements, isClosed: true)
        updateActiveBezierShapeWithPath(livePath)
    }
    
    /// Updates the live path with a rubber band preview to the mouse location
    internal func updateLivePathWithRubberBand(mouseLocation: CGPoint) {
        guard let currentBezierPath = bezierPath else { return }
        
        var liveElements = currentBezierPath.elements
        let lastPointIndex = bezierPoints.count - 1
        let lastPoint = bezierPoints[lastPointIndex]
        let lastPointLocation = CGPoint(x: lastPoint.x, y: lastPoint.y)
        
        // Check if the last point has an outgoing handle (control2)
        if let lastPointHandles = bezierHandles[lastPointIndex],
           let lastControl2 = lastPointHandles.control2 {
            // CURVE RUBBER BAND: Add live curve preview with CORRECT direction
            let _ = CGPoint(x: lastControl2.x, y: lastControl2.y)
            
            // FIXED: Calculate incoming handle direction (should flow naturally from the outgoing curve)
            // Make incoming handle point in a direction that creates smooth continuation
            let distance = sqrt(pow(mouseLocation.x - lastPointLocation.x, 2) + pow(mouseLocation.y - lastPointLocation.y, 2))
            let handleLength = distance * 0.3 // About 1/3 of the distance for natural curves
            
            // Direction from mouse back toward the curve's natural flow
            let mouseToLastDirection = CGPoint(
                x: lastPointLocation.x - mouseLocation.x,
                y: lastPointLocation.y - mouseLocation.y
            )
            let mouseToLastLength = sqrt(pow(mouseToLastDirection.x, 2) + pow(mouseToLastDirection.y, 2))
            
            let incomingHandle = if mouseToLastLength > 0 {
                VectorPoint(
                    mouseLocation.x + (mouseToLastDirection.x / mouseToLastLength) * handleLength,
                    mouseLocation.y + (mouseToLastDirection.y / mouseToLastLength) * handleLength
                )
            } else {
                // Fallback if points are too close
                VectorPoint(mouseLocation.x, mouseLocation.y)
            }
            
            liveElements.append(.curve(
                to: VectorPoint(mouseLocation),
                control1: lastControl2,
                control2: incomingHandle
            ))
        } else {
            // STRAIGHT RUBBER BAND: Add live line preview
            liveElements.append(.line(to: VectorPoint(mouseLocation)))
        }
        
        // Update the live path
        let livePath = VectorPath(elements: liveElements, isClosed: false)
        updateActiveBezierShapeWithPath(livePath)
    }
} 