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
        
        print("🎯 UNIFIED TAP at screen: \(location) canvas: \(canvasLocation)")
        print("🎯 UNIFIED: This is a SINGLE CLICK, not a drag")
        
        // Route to appropriate tool handler based on current tool
        switch document.currentTool {
        case .selection:
            if isBezierDrawing { cancelBezierDrawing() }
            handleSelectionTap(at: canvasLocation)
            
        case .scale:
            if isBezierDrawing { cancelBezierDrawing() }
            handleSelectionTap(at: canvasLocation)
            
        case .rotate:
            if isBezierDrawing { cancelBezierDrawing() }
            handleSelectionTap(at: canvasLocation)
            
        case .shear:
            if isBezierDrawing { cancelBezierDrawing() }
            handleSelectionTap(at: canvasLocation)
            
        case .envelope:
            if isBezierDrawing { cancelBezierDrawing() }
            handleSelectionTap(at: canvasLocation)
            
        case .directSelection:
            if isBezierDrawing { cancelBezierDrawing() }
            handleDirectSelectionTap(at: canvasLocation)
            
        case .convertAnchorPoint:
            if isBezierDrawing { cancelBezierDrawing() }
            handleConvertAnchorPointTap(at: canvasLocation)
            
        case .bezierPen:
            handleBezierPenTap(at: canvasLocation)
            
        case .font:
            handleFontToolTap(at: canvasLocation)
            
        case .line, .rectangle, .circle, .star, .polygon:
            // Shape tools are drag-only - ignore taps
            if isBezierDrawing { cancelBezierDrawing() }
            print("🎨 UNIFIED: Shape tools (\(document.currentTool.rawValue)) are drag-only - tap ignored")
            
        default:
            if isBezierDrawing { cancelBezierDrawing() }
            break
        }
    }
    
    /// UNIFIED DRAG CHANGED HANDLER - Works consistently for all areas
    /// Uses Drawing Canvas logic as the ideal template  
    internal func handleUnifiedDragChanged(value: DragGesture.Value, geometry: GeometryProxy) {
        // Calculate drag distance for tap vs drag detection
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        
        // Route to appropriate tool handler based on current tool
        switch document.currentTool {
        case .hand:
            handlePanGesture(value: value, geometry: geometry)
            
        case .line, .rectangle, .circle, .star, .polygon:
            handleShapeDrawing(value: value, geometry: geometry)
            
        case .selection:
            handleUnifiedSelectionDrag(value: value, geometry: geometry, dragDistance: dragDistance)
            
        case .directSelection:
            handleDirectSelectionDrag(value: value, geometry: geometry)
            
        case .bezierPen:
            handleBezierPenDrag(value: value, geometry: geometry)
            
        default:
            // Transform tools (scale, rotate, shear, envelope) don't use drag gestures
            break
        }
    }
    
    /// UNIFIED DRAG ENDED HANDLER - Works consistently for all areas
    /// Removes pasteboard tap simulation and uses clean logic
    internal func handleUnifiedDragEnded(value: DragGesture.Value, geometry: GeometryProxy) {
        // Calculate drag distance to determine if this was a tap or drag
        let dragDistance = sqrt(pow(value.location.x - value.startLocation.x, 2) + pow(value.location.y - value.startLocation.y, 2))
        let tapThreshold: Double = 3.0 // Very small movement counts as a tap
        
        // If this was essentially a tap (minimal movement), handle as tap
        if dragDistance <= tapThreshold {
            print("🎯 UNIFIED: Zero-distance drag (\(String(format: "%.1f", dragDistance))px) converted to tap")
            handleUnifiedTap(at: value.startLocation, geometry: geometry)
            return
        }
        
        // Otherwise handle as completed drag
        switch document.currentTool {
        case .hand:
            finishPanGesture()
            
        case .line, .rectangle, .circle, .star, .polygon:
            finishShapeDrawing(value: value, geometry: geometry)
            resetShapeDrawingState()
            
        case .selection:
            finishSelectionDrag()
            isDrawing = false
            
        case .directSelection:
            finishDirectSelectionDrag()
            
        case .bezierPen:
            finishBezierPenDrag()
            
        default:
            break
        }
    }
    
    // MARK: - Unified Selection Drag Handler
    
    /// UNIFIED SELECTION DRAG - Consolidates selection behavior for all areas
    private func handleUnifiedSelectionDrag(value: DragGesture.Value, geometry: GeometryProxy, dragDistance: Double) {
        let startLocation = screenToCanvas(value.startLocation, geometry: geometry)
        
        // Use consistent threshold for all areas
        let minimumDragThreshold: Double = 8.0
        
        // Small movements should attempt selection first
        if dragDistance < minimumDragThreshold {
            if document.selectedShapeIDs.isEmpty && document.selectedTextIDs.isEmpty {
                print("🎯 UNIFIED: Small movement (\(String(format: "%.1f", dragDistance))px) - attempting selection")
                selectObjectAt(startLocation)
                return
            }
        }
        
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