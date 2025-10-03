//
//  DrawingCanvas+GestureHandling.swift
//  logos inkpen.io
//
//  Gesture handling functionality - Legacy hover support
//  Main gesture handling moved to DrawingCanvas+UnifiedGestures.swift
//

import SwiftUI
import AppKit

extension DrawingCanvas {
    // NOTE: Main gesture handling (tap, drag) moved to DrawingCanvas+UnifiedGestures.swift
    // This file now only contains hover handling which is not part of the unified system
    
    internal func handleHover(phase: HoverPhase, geometry: GeometryProxy) {
        if case .active(let location) = phase {
            currentMouseLocation = location
            // Also update mouse position for zoom focal point
            currentMousePosition = location
            // Maintain correct cursor while hovering over the canvas
            if isTextEditingMode {
                // Keep I-beam cursor when in text editing mode
                NSCursor.iBeam.set()
            } else if document.currentTool == .hand {
                switch isPanGestureActive {
                case true: HandClosedCursor.set()
                case false: HandOpenCursor.set()
                }
            } else if document.currentTool == .eyedropper {
                EyedropperCursor.set()
            } else if document.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }

            // PROFESSIONAL REAL-TIME PATH UPDATES (Professional Style)
            if isBezierDrawing && document.currentTool == .bezierPen && bezierPoints.count > 0 {
                let canvasLocation = screenToCanvas(location, geometry: geometry)
                
                // PROFESSIONAL CLOSE PATH VISUAL FEEDBACK
                if bezierPoints.count >= 3 {
                    let firstPoint = bezierPoints[0]
                    let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                    
                    // ZOOM-AWARE CLOSE TOLERANCE: Scale tolerance based on zoom level
                    // At high zoom levels, small physical movements translate to large canvas movements
                    // So we need to reduce the tolerance proportionally
                    let baseCloseTolerance: Double = 5.0 // Base tolerance in screen pixels (reduced from 25.0 for precision)
                    let zoomLevel = document.zoomLevel
                    let closeTolerance = max(2.0, baseCloseTolerance / zoomLevel) // Minimum 2px, scales with zoom
                    
                    if distance(canvasLocation, firstPointLocation) <= closeTolerance {
                        showClosePathHint = true
                        closePathHintLocation = firstPointLocation
                        // Let rubber band preview handle closing visualization
                    } else {
                        showClosePathHint = false
                        // Let rubber band preview handle visualization instead of live path updates
                    }
                } else {
                    // First point - let rubber band handle visualization
                }
            } else if document.currentTool == .bezierPen && !isBezierDrawing {
                // CONTINUE PATH HINT: Show hint when bezier pen tool is active and a point is selected
                let (shouldShow, hintLocation) = shouldShowContinuePathHint()
                if shouldShow, let location = hintLocation {
                    // Show continue path hint at the selected point location
                    showContinuePathHint = true
                    continuePathHintLocation = location
                } else {
                    showContinuePathHint = false
                }
            } else {
                showClosePathHint = false
                showContinuePathHint = false
            }
        } else {
            currentMouseLocation = nil
            showClosePathHint = false
            // SwiftUI may emit a transient hover exit during mouseDown; don't override zoom/hand cursors
            if !isCanvasHovering {
                NSCursor.arrow.set()
            }

            // Note: Using rubber band preview overlay instead of live path updates
            // The actual path remains unchanged until a new point is added
        }
    }
} 
