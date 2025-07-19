//
//  DrawingCanvas+GestureHandling.swift
//  logos inkpen.io
//
//  Gesture handling functionality
//

import SwiftUI

extension DrawingCanvas {
    internal func handleDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        // PASTEBOARD TAP SIMULATION: Convert zero-distance drags to taps for tools that need it
        // This fixes the issue where .onTapGesture doesn't work for pasteboard coordinates
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let tapThreshold: Double = 3.0 // Very small movement counts as a tap
        
        if dragDistance <= tapThreshold {
            // This was essentially a tap (zero or minimal drag distance)
            let canvasLocation = screenToCanvas(value.startLocation, geometry: geometry)
            let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612)
            let isInPasteboardArea = !canvasBounds.contains(canvasLocation)
            
            if isInPasteboardArea {
                // PASTEBOARD TAP: Convert zero-distance drag to tap
                print("🎯 PASTEBOARD TAP SIMULATION: Zero-distance drag (\(String(format: "%.1f", dragDistance))px) converted to tap")
                print("🎯 PASTEBOARD CLICK at canvas: \(canvasLocation)")
                
                // Call the appropriate tap handler based on current tool
                switch document.currentTool {
                case .selection:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleSelectionTap(at: canvasLocation)
                case .directSelection:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleDirectSelectionTap(at: canvasLocation)
                case .convertAnchorPoint:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleConvertAnchorPointTap(at: canvasLocation)
                case .rotate:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleSelectionTap(at: canvasLocation)
                case .shear:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleSelectionTap(at: canvasLocation)
                case .envelope:
                    if isBezierDrawing { cancelBezierDrawing() }
                    handleSelectionTap(at: canvasLocation)
                case .bezierPen:
                    // ✅ ISOLATION FIX: Pen tool works the same everywhere - canvas or pasteboard
                    // Never automatically finish paths - only add points for continuous tracing
                    handleBezierPenTap(at: canvasLocation)
                    // Note: Pen tool is isolated from existing objects and layers
                    // TEXT TOOL COMPLETELY REMOVED
                default:
                    break
                }
                
                // Early return - don't process as regular drag end
                return
            }
        }
        
        // Regular drag end processing for actual drags (not taps)
        switch document.currentTool {
        case .hand:
            // PROFESSIONAL HAND TOOL: Clean state reset for next drag operation
            // This ensures each new drag operation starts with fresh reference points
            let finalOffset = document.canvasOffset
            initialCanvasOffset = CGPoint.zero
            handToolDragStart = CGPoint.zero
            isPanGestureActive = false  // PROFESSIONAL GESTURE COORDINATION
            print("✋ HAND TOOL: Drag operation completed successfully, UI fully responsive")
            print("   Final canvas position: (\(String(format: "%.1f", finalOffset.x)), \(String(format: "%.1f", finalOffset.y)))")
            print("   State reset - ready for next drag operation")
        case .line, .rectangle, .circle, .star, .polygon:
            finishShapeDrawing(value: value, geometry: geometry)
            // Reset drawing state for shape tools
            isDrawing = false
            currentPath = nil
            currentDrawingPoints.removeAll()
            
            // PROFESSIONAL SHAPE DRAWING: Additional state cleanup
            shapeDragStart = CGPoint.zero
            shapeStartPoint = CGPoint.zero
            // TEXT TOOL COMPLETELY REMOVED
        case .selection:
            finishSelectionDrag()
            isDrawing = false
        case .directSelection:
            finishDirectSelectionDrag()
        case .bezierPen:
            finishBezierPenDrag()
            // Don't reset bezier state here - it continues until double-tap
        default:
            break
        }
    }
    
    internal func handleDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        // PROFESSIONAL FIX: DrawingCanvas drags are automatically constrained to view bounds
        // SwiftUI ensures drag gestures only fire within the DrawingCanvas area
        let canvasStart = screenToCanvas(value.startLocation, geometry: geometry)
        let _ = screenToCanvas(value.location, geometry: geometry)
        
        // DETAILED LOGGING: Determine if this started in canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let startedInCanvasArea = canvasBounds.contains(canvasStart)
        let _ = startedInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        // Calculate drag distance to understand if this should have been a tap
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        
        // PASTEBOARD OPTIMIZATION: Use 0-pixel threshold for pasteboard to maximize single-click sensitivity
        let _ = startedInCanvasArea ? 40.0 : 0.0
        
        //print("🎯 DRAG GESTURE CHANGED at start: \(canvasStart) current: \(canvasCurrent) in \(areaType)")
        //print("🎯 DRAG GESTURE: This is CLICK AND DRAG, not a single click")
        //print("🎯 Drag distance: \(String(format: "%.2f", dragDistance)) pixels (threshold: \(effectiveThreshold))")
        
        // PASTEBOARD OPTIMIZATION: Handle small movements as selections, not drags
        if !startedInCanvasArea && document.currentTool == .selection {
            if dragDistance < 3.0 {
                // Very small movement on pasteboard - treat as selection, not drag
                print("🎯 PASTEBOARD: Tiny movement (\(String(format: "%.1f", dragDistance))px) - treating as selection")
                selectObjectAt(canvasStart)
                return
            } else if dragDistance < 8.0 {
                // Small movement - only proceed if we have selected objects to drag
                if document.selectedShapeIDs.isEmpty {
                    print("🎯 PASTEBOARD: Small movement (\(String(format: "%.1f", dragDistance))px) with no selection - trying selection first")
                    selectObjectAt(canvasStart)
                    return
                }
            }
        }
        
        // CANVAS STABILITY: Use higher threshold for canvas to prevent hand tremor issues
        if startedInCanvasArea && dragDistance < 8.0 {
            // Small movement on canvas - be more tolerant of hand tremor
            if document.currentTool == .selection && document.selectedShapeIDs.isEmpty {
                print("🎯 CANVAS: Small movement (\(String(format: "%.1f", dragDistance))px) - trying selection")
                selectObjectAt(canvasStart)
                return
            }
        }
        
        switch document.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)
        case .line, .rectangle, .circle, .star, .polygon:
            handleShapeDrawing(value: value, geometry: geometry)
            // TEXT TOOL COMPLETELY REMOVED
        case .selection:
            if !isDrawing {
                // Check if we're starting a drag on a selected object
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                
                // If nothing is selected, or if we're dragging on an unselected object, try to select it first
                if (document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty) || !isDraggingSelectedObject(at: startLocation) {
                    selectObjectAt(startLocation)
                }
                
                // Only start drag if we have something selected (shapes or text)
                if !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty {
                    // PROFESSIONAL OBJECT DRAGGING: Capture reference cursor position (like hand tool)
                    selectionDragStart = value.startLocation
                    startSelectionDrag()
                    isDrawing = true
                    print("🎯 SELECTION DRAG: Started at cursor position (\(String(format: "%.1f", selectionDragStart.x)), \(String(format: "%.1f", selectionDragStart.y)))")
                }
            }
            
            if isDrawing {
                handleSelectionDrag(value: value, geometry: geometry)
            }



        case .envelope:
            // Envelope tool doesn't handle drag gestures directly - warping is handled by the envelope handles
            // Just handle selection like the selection tool
            if !isDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                
                if (document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty) || !isDraggingSelectedObject(at: startLocation) {
                    selectObjectAt(startLocation)
                }
            }
        case .directSelection:
            // Handle direct selection dragging for moving points and handles
            handleDirectSelectionDrag(value: value, geometry: geometry)
        case .bezierPen:
            // Handle bezier pen dragging for creating handles or moving points
            // FIXED: Always call drag handler to support first point creation
            handleBezierPenDrag(value: value, geometry: geometry)
        default:
            break
        }
    }
    
    internal func handleTap(at location: CGPoint, geometry: GeometryProxy) {
        // PROFESSIONAL FIX: DrawingCanvas gestures are automatically constrained to view bounds
        // SwiftUI ensures gestures only fire within the DrawingCanvas area - no manual blocking needed
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        // DETAILED LOGGING: Determine if this is canvas or pasteboard area
        let canvasBounds = CGRect(x: 0, y: 0, width: 792, height: 612) // Standard canvas
        let isInCanvasArea = canvasBounds.contains(canvasLocation)
        let areaType = isInCanvasArea ? "CANVAS AREA" : "PASTEBOARD AREA"
        
        print("🎯 SINGLE CLICK TAP at screen: \(location) canvas: \(canvasLocation) in \(areaType)")
        print("🎯 TAP GESTURE: This is a SINGLE CLICK, not a drag")
        print("🎯 Canvas bounds: \(canvasBounds), click in canvas: \(isInCanvasArea)")
        
        switch document.currentTool {
        case .selection:
            // Cancel bezier drawing if switching to selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleSelectionTap(at: canvasLocation)
        case .scale:
            // Scale tool handles selection just like selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleSelectionTap(at: canvasLocation)
        case .rotate:
            // Rotate tool handles selection just like selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleSelectionTap(at: canvasLocation)
        case .shear:
            // Shear tool handles selection just like selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleSelectionTap(at: canvasLocation)
        case .envelope:
            // Envelope tool handles selection just like selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleSelectionTap(at: canvasLocation)
        case .directSelection:
            // Cancel bezier drawing if switching to direct selection tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleDirectSelectionTap(at: canvasLocation)
        case .convertAnchorPoint:
            // Cancel bezier drawing if switching to convert anchor point tool
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            handleConvertAnchorPointTap(at: canvasLocation)
        case .bezierPen:
            handleBezierPenTap(at: canvasLocation)
        case .font:
            handleFontToolTap(at: canvasLocation)
        case .line, .rectangle, .circle, .star, .polygon:
            // SHAPE TOOLS: Do nothing on click - they are drag-only tools
            // Cancel bezier drawing if switching to shape tools
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            print("🎨 SHAPE TOOL CLICK: Ignored - shape tools (\(document.currentTool.rawValue)) only work with click and drag")
        default:
            // Cancel bezier drawing if switching to other tools
            if isBezierDrawing {
                cancelBezierDrawing()
            }
            break
        }
    }
    
    internal func handleHover(phase: HoverPhase, geometry: GeometryProxy) {
        if case .active(let location) = phase {
            currentMouseLocation = location
            
            // PROFESSIONAL REAL-TIME PATH UPDATES (Adobe Illustrator/FreeHand/CorelDraw Style)
            if isBezierDrawing && document.currentTool == .bezierPen && bezierPoints.count > 0 {
                let canvasLocation = screenToCanvas(location, geometry: geometry)
                
                // PROFESSIONAL CLOSE PATH VISUAL FEEDBACK
                if bezierPoints.count >= 3 {
                    let firstPoint = bezierPoints[0]
                    let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                    let closeTolerance: Double = 25.0
                    
                    if distance(canvasLocation, firstPointLocation) <= closeTolerance {
                        showClosePathHint = true
                        closePathHintLocation = firstPointLocation
                        
                        // Let rubber band preview handle closing visualization
                        // updateLivePathWithClosingPreview(mouseLocation: canvasLocation)
                    } else {
                        showClosePathHint = false
                        
                        // Let rubber band preview handle visualization instead of live path updates
                        // updateLivePathWithRubberBand(mouseLocation: canvasLocation)
                    }
                } else {
                    // First point - let rubber band handle visualization
                    // updateLivePathWithRubberBand(mouseLocation: canvasLocation)
                }
            } else {
                showClosePathHint = false
            }
        } else {
            currentMouseLocation = nil
            showClosePathHint = false
            
            // Note: Using rubber band preview overlay instead of live path updates
            // The actual path remains unchanged until a new point is added
        }
    }
} 