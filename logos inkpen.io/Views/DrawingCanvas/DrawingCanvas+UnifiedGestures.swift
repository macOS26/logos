//
//  DrawingCanvas+UnifiedGestures.swift
//  logos inkpen.io
//
//  Unified gesture management for Drawing Canvas and Pasteboard
//  Uses Drawing Canvas approach as the ideal template
//

import SwiftUI

extension DrawingCanvas {
    
    // MARK: - Unified Gesture System
    
    /// UNIFIED TAP HANDLER - Works consistently for all areas (Canvas + Pasteboard)
    /// Uses Drawing Canvas logic as the ideal template
    internal func handleUnifiedTap(at location: CGPoint, geometry: GeometryProxy) {
        let canvasLocation = screenToCanvas(location, geometry: geometry)
        
        // PERFORMANCE OPTIMIZATION: Wrap extensive debug logging in conditional compilation
        #if DEBUG_GESTURES
        print("🎯 UNIFIED TAP at screen: \(location) canvas: \(canvasLocation)")
        print("🎯 UNIFIED: This is a SINGLE CLICK, not a drag")
        print("🎯 UNIFIED: Current tool: \(document.currentTool.rawValue)")
        
        // DEBUGGING: Test text hit detection immediately
        let textHitResult = findTextAt(location: canvasLocation)
        print("🔍 DEBUG: Text hit test result: \(textHitResult?.uuidString.prefix(8) ?? "nil")")
        
        // DEBUGGING: Show all text boxes and their hit areas
        print("📝 DEBUG: Document has \(document.textObjects.count) text boxes:")
        for (index, textObj) in document.textObjects.enumerated() {
            print("  [\(index)] UUID: \(textObj.id.uuidString.prefix(8))")
            print("      Content: '\(textObj.content.prefix(30))'")
            print("      Position: \(textObj.position)")
            print("      Bounds: \(textObj.bounds)")
            print("      Visible: \(textObj.isVisible), Locked: \(textObj.isLocked)")
            
            // Calculate hit areas (same logic as findTextAt)
            let textContentArea = CGRect(
                x: textObj.position.x,
                y: textObj.position.y,
                width: max(textObj.bounds.width, 200.0),
                height: max(textObj.bounds.height, 60.0)
            )
            let exactBounds = CGRect(
                x: textObj.position.x + textObj.bounds.minX,
                y: textObj.position.y + textObj.bounds.minY,
                width: textObj.bounds.width,
                height: textObj.bounds.height
            )
            let expandedBounds = exactBounds.insetBy(dx: -30, dy: -20)
            
            print("      Hit Areas:")
            print("        Content: \(textContentArea)")
            print("        Exact: \(exactBounds)")
            print("        Expanded: \(expandedBounds)")
            
            let hits = textContentArea.contains(canvasLocation) || 
                      exactBounds.contains(canvasLocation) || 
                      expandedBounds.contains(canvasLocation)
            print("        SHOULD HIT: \(hits)")
        }
        #endif
        
        // Cancel bezier drawing for all tools except bezier pen
        if document.currentTool != .bezierPen && isBezierDrawing {
            cancelBezierDrawing()
        }
        
        // Route to appropriate tool handler based on current tool
        switch document.currentTool {
        case .selection, .scale, .rotate, .shear, .warp:
            // All transform tools use selection logic
            print("🎯 UNIFIED: Routing to handleSelectionTap...")
            handleSelectionTap(at: canvasLocation)
            // REMOVED: handleAggressiveBackgroundTap - this was deselecting objects immediately after selection!
            
        case .directSelection:
            handleDirectSelectionTap(at: canvasLocation)
            // REMOVED: handleAggressiveBackgroundTap - this was interfering with direct selection!
            
        case .convertAnchorPoint:
            handleConvertAnchorPointTap(at: canvasLocation)
            
        case .bezierPen:
            handleBezierPenTap(at: canvasLocation)
            
        case .font:
            // Font tool: Only handle editing existing text on tap, new text requires drag
            if let existingTextID = findTextAt(location: canvasLocation) {
                startEditingText(textID: existingTextID, at: canvasLocation)
            } else {
                print("📝 FONT TOOL: Tap on empty area - drag to create new text box (like rectangle tool)")
            }
            // Keep background tap handling for font tool only (this makes sense for font tool)
            handleAggressiveBackgroundTap(at: canvasLocation)
            
        case .line, .rectangle, .circle, .star, .polygon:
            // Shape tools are drag-only - ignore taps
            print("🎨 UNIFIED: Shape tools (\(document.currentTool.rawValue)) are drag-only - tap ignored")
            
        default:
            break
        }
    }
    
    /// UNIFIED DRAG CHANGED HANDLER - Works consistently for all areas
    /// Uses Drawing Canvas logic as the ideal template  
    internal func handleUnifiedDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        // Route to appropriate tool handler based on current tool
        switch document.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)
            
        case .line, .rectangle, .circle, .star, .polygon:
            handleShapeDrawing(value: value, geometry: geometry)
            
        case .font:
            handleTextBoxDrawing(value: value, geometry: geometry)
            
        case .selection:
            handleUnifiedSelectionDrag(value: value, geometry: geometry)
            
        case .directSelection:
            handleDirectSelectionDrag(value: value, geometry: geometry)
            
        case .bezierPen:
            handleBezierPenDrag(value: value, geometry: geometry)
            
        case .freehand:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isFreehandDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleFreehandDragStart(at: startLocation)
            }
            handleFreehandDragUpdate(at: currentLocation)
            
        case .brush:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isBrushDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleBrushDragStart(at: startLocation)
            }
            handleBrushDragUpdate(at: currentLocation)
            
        case .marker:
            let currentLocation = screenToCanvas(value.location, geometry: geometry)
            if !isMarkerDrawing {
                let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
                handleMarkerDragStart(at: startLocation)
            }
            handleMarkerDragUpdate(at: currentLocation)
            
        case .scale, .rotate, .shear, .warp:
            // Transform tools don't use drag gestures - handled by their own handles
            break
            
        default:
            break
        }
    }
    
    /// UNIFIED DRAG ENDED HANDLER - Works consistently for all areas
    /// CRITICAL FIX: NO drag-to-tap conversion to prevent interrupting real drags
    internal func handleUnifiedDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        // FIXED: Always handle as completed drag - NO conversion to tap
        // This prevents drags from getting "lost" mid-operation
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        print("🎯 UNIFIED: Drag ended - handling as completed drag operation (\(String(format: "%.1f", dragDistance))px)")
        
        // Handle as completed drag
        switch document.currentTool {
        case .hand:
            finishPanGesture()
            
        case .line, .rectangle, .circle, .star, .polygon:
            finishShapeDrawing(value: value, geometry: geometry)
            resetShapeDrawingState()
            
        case .font:
            finishTextBoxDrawing(value: value, geometry: geometry)
            resetTextBoxDrawingState()
            
        case .selection:
            finishSelectionDrag()
            isDrawing = false
            
        case .directSelection:
            finishDirectSelectionDrag()
            
        case .bezierPen:
            finishBezierPenDrag()
            
        case .freehand:
            handleFreehandDragEnd()
            
        case .brush:
            handleBrushDragEnd()
            
        case .marker:
            handleMarkerDragEnd()
            
        default:
            break
        }
    }
    
    // MARK: - Unified Selection Drag Handler
    
    /// UNIFIED SELECTION DRAG - Consolidates selection behavior for all areas  
    /// FIXED: Simplified logic to prevent bouncing behavior
    private func handleUnifiedSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        
        // Start drag if not already dragging
        if !isDrawing {
            // Try to select if nothing selected or dragging unselected object
            if (document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty) || !isDraggingSelectedObject(at: startLocation) {
                selectObjectAt(startLocation)
            }
            
            // Start drag if we have something selected
            if !document.selectedShapeIDs.isEmpty || !document.selectedTextIDs.isEmpty {
                selectionDragStart = value.startLocation
                startSelectionDrag()
                isDrawing = true
                print("🎯 UNIFIED SELECTION DRAG: Started at cursor position (\(String(format: "%.1f", selectionDragStart.x)), \(String(format: "%.1f", selectionDragStart.y)))")
            }
        }
        
        // Continue drag if active
        if isDrawing {
            handleSelectionDrag(value: value, geometry: geometry)
        }
    }
    
    // MARK: - State Reset Helpers
    
    private func finishPanGesture() {
        let finalOffset = document.canvasOffset
        initialCanvasOffset = CGPoint.zero
        handToolDragStart = CGPoint.zero
        isPanGestureActive = false
        print("✋ UNIFIED: Hand tool completed - final position: (\(String(format: "%.1f", finalOffset.x)), \(String(format: "%.1f", finalOffset.y)))")
    }
    
    private func resetShapeDrawingState() {
        isDrawing = false
        currentPath = nil
        currentDrawingPoints.removeAll()
        shapeDragStart = CGPoint.zero
        shapeStartPoint = CGPoint.zero
    }
} 