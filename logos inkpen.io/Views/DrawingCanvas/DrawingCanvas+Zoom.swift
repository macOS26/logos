//
//  DrawingCanvas+Zoom.swift
//  logos inkpen.io
//
//  Zoom functionality
//

import SwiftUI

extension DrawingCanvas {
    // MARK: - Zoom Quantization Helpers (Custom scale)
    // Allowed zoom steps (25%, 50%, 75%, 100%, 200%, 300%, 400%, 600%, 800%, 1200%, 1600%)
    internal var allowedZoomSteps: [CGFloat] { [0.25, 0.5, 0.75, 1.0, 2.0, 3.0, 4.0, 6.0, 8.0, 12.0, 16.0] }

    internal func quantizeZoomToNearestAllowed(_ zoom: CGFloat) -> CGFloat {
        let clamped = max(allowedZoomSteps.first ?? 0.25, min(allowedZoomSteps.last ?? 16.0, zoom))
        var best = allowedZoomSteps.first ?? 0.25
        var bestDiff = abs(clamped - best)
        for step in allowedZoomSteps {
            let d = abs(clamped - step)
            if d < bestDiff {
                bestDiff = d
                best = step
            }
        }
        return best
    }

    internal func nextAllowedStepUp(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        for step in allowedZoomSteps {
            if step > zoom + epsilon { return step }
        }
        return allowedZoomSteps.last ?? 16.0
    }

    internal func nextAllowedStepDown(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        for step in allowedZoomSteps.reversed() {
            if step < zoom - epsilon { return step }
        }
        return allowedZoomSteps.first ?? 0.25
    }

            /// PROFESSIONAL ZOOM GESTURE HANDLING (Professional Standards)
    /// Always available but conditionally processed to prevent UI lockups
    internal func handleZoomGestureChanged(value: CGFloat, geometry: GeometryProxy) {
        // PROFESSIONAL GESTURE COORDINATION: Only zoom when appropriate
        // Don't block the gesture - just ignore it during drawing operations
        guard !isDrawing && !isBezierDrawing && !isPanGestureActive else {
            // Gesture is active but we're not processing it - UI remains responsive
            return
        }
        
        if !isZoomGestureActive {
            isZoomGestureActive = true
        }
        // Do not override the cursor during pinch-to-zoom to avoid interfering with other tools
        
        let newZoomLevel = max(0.1, min(16.0, initialZoomLevel * value))
        
        // PROFESSIONAL ZOOM AT MOUSE POSITION: Use current mouse position as focal point
        // If no mouse position available, fall back to center of view
        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: newZoomLevel, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            // Fallback to view center if no mouse position tracked
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: newZoomLevel, focalPoint: viewCenter, geometry: geometry)
        }
    }
    
    /// Handle zoom gesture end - finalize zoom level (continuous, no snapping)
    internal func handleZoomGestureEnded(value: CGFloat, geometry: GeometryProxy) {
        // Always reset gesture state to ensure UI responsiveness
        defer {
            isZoomGestureActive = false
        }
        
        // PROFESSIONAL GESTURE COORDINATION: Only finalize zoom when appropriate
        guard !isDrawing && !isBezierDrawing && !isPanGestureActive else {
            // Gesture ended but we weren't processing it - UI remains responsive
            return
        }
        
        // Keep pinch zoom continuous (no rounding to steps)
        let finalZoomLevel = max(0.1, min(16.0, initialZoomLevel * value))
        
        // PROFESSIONAL ZOOM AT MOUSE POSITION: Final zoom also uses focal point
        // If no mouse position available, fall back to center of view
        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            // Fallback to view center if no mouse position tracked
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: viewCenter, geometry: geometry)
        }
        
        // Update the initial zoom level for next gesture
        initialZoomLevel = finalZoomLevel

        // After pinch ends, if still over canvas and zoom tool active, restore cursor now and next runloop
        if isCanvasHovering && document.currentTool == .zoom {
            MagnifyingGlassCursor.set()
            DispatchQueue.main.async { if isCanvasHovering && document.currentTool == .zoom { MagnifyingGlassCursor.set() } }
        }
    }
    
            /// Handle coordinated zoom requests from menu/toolbar (Professional Standards)
    internal func handleZoomRequest(_ request: ZoomRequest, geometry: GeometryProxy) {
        
        switch request.mode {
        case .fitToPage:
            // Fit to page: Calculate optimal zoom and center
            fitToPage(geometry: geometry)
            
        case .actualSize:
            // Actual size: Set to 100% and center properly
            actualSize(geometry: geometry)
            
        case .zoomIn, .zoomOut:
            // Zoom in/out: Use mouse position as focal point for professional behavior
            if currentMousePosition != .zero {
                handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: currentMousePosition, geometry: geometry)
            } else {
                // Fallback to view center if no mouse position tracked
                let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
                handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: viewCenter, geometry: geometry)
            }
            
        case .custom(let focalPoint):
            // Custom zoom with specific focal point
            handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: focalPoint, geometry: geometry)
        }
        
        // Clear the request after processing
        document.clearZoomRequest()

        // After completing a programmatic zoom request, restore the active tool cursor
        if isCanvasHovering {
            switch document.currentTool {
            case .hand:
                NSCursor.openHand.set()
            case .eyedropper:
                EyedropperCursor.set()
            case .zoom:
                MagnifyingGlassCursor.set()
            default:
                break
            }
            // Also assert on next runloop to win races
            DispatchQueue.main.async {
                if isCanvasHovering {
                    switch document.currentTool {
                    case .hand:
                        NSCursor.openHand.set()
                    case .eyedropper:
                        EyedropperCursor.set()
                    case .zoom:
                        MagnifyingGlassCursor.set()
                    default:
                        break
                    }
                }
            }
        }
    }
} 
