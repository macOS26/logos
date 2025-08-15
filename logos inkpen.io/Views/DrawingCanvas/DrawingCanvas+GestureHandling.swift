//
//  DrawingCanvas+GestureHandling.swift
//  logos inkpen.io
//
//  Gesture handling functionality - Legacy hover support
//  Main gesture handling moved to DrawingCanvas+UnifiedGestures.swift
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

extension DrawingCanvas {
    // NOTE: Main gesture handling (tap, drag) moved to DrawingCanvas+UnifiedGestures.swift
    // This file now only contains hover handling which is not part of the unified system
    
    internal func handleHover(phase: HoverPhase, geometry: GeometryProxy) {
        if case .active(let location) = phase {
            currentMouseLocation = location
            // Also update mouse position for zoom focal point
            currentMousePosition = location
            #if os(macOS)
            // Maintain correct cursor while hovering over the canvas
            if document.currentTool == .hand {
                switch isPanGestureActive {
                case true: HandClosedCursor.set()
                case false: HandOpenCursor.set()
                }
            } else if document.currentTool == .eyedropper {
                EyedropperCursor.set()
            } else if document.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
            #endif
            
            // PROFESSIONAL REAL-TIME PATH UPDATES (Professional Style)
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
            #if os(macOS)
            // SwiftUI may emit a transient hover exit during mouseDown; don't override zoom/hand cursors
            if !isCanvasHovering {
                NSCursor.arrow.set()
            }
            #endif
            
            // Note: Using rubber band preview overlay instead of live path updates
            // The actual path remains unchanged until a new point is added
        }
    }
} 