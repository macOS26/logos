//
//  DrawingCanvas+Zoom.swift
//  logos inkpen.io
//
//  Zoom functionality
//

import SwiftUI

extension DrawingCanvas {
    /// PROFESSIONAL ZOOM GESTURE HANDLING (Adobe Illustrator Standards)
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
            print("🔍 ZOOM GESTURE STARTED: UI remains fully responsive")
        }
        
        let newZoomLevel = max(0.1, min(10.0, initialZoomLevel * value))
        
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
    
    /// Handle zoom gesture end - finalize zoom level
    internal func handleZoomGestureEnded(value: CGFloat, geometry: GeometryProxy) {
        // Always reset gesture state to ensure UI responsiveness
        defer {
            isZoomGestureActive = false
        }
        
        // PROFESSIONAL GESTURE COORDINATION: Only finalize zoom when appropriate
        guard !isDrawing && !isBezierDrawing && !isPanGestureActive else {
            // Gesture ended but we weren't processing it - UI remains responsive
            print("🔍 ZOOM GESTURE IGNORED: Drawing/Pan in progress, UI remains responsive")
            return
        }
        
        let finalZoomLevel = max(0.1, min(10.0, initialZoomLevel * value))
        
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
        print("🔍 PROFESSIONAL ZOOM COMPLETED: Final zoom level = \(String(format: "%.3f", finalZoomLevel))x, focal point: \(currentMousePosition), UI responsive")
    }
    
    /// Handle coordinated zoom requests from menu/toolbar (Adobe Illustrator Standards)
    internal func handleZoomRequest(_ request: ZoomRequest, geometry: GeometryProxy) {
        
        switch request.mode {
        case .fitToPage:
            // Fit to page: Calculate optimal zoom and center
            fitToPage(geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: Fit to Page")
            
        case .actualSize:
            // Actual size: Set to 100% and center properly
            actualSize(geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: Actual Size (100%)")
            
        case .zoomIn, .zoomOut:
            // Zoom in/out: Maintain current focal point
            handleSimplifiedZoom(newZoomLevel: request.targetZoom, geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: \(request.mode) to \(String(format: "%.1f", request.targetZoom * 100))%")
            
        case .custom(let focalPoint):
            // Custom zoom with specific focal point
            handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: focalPoint, geometry: geometry)
            print("🔍 HANDLED ZOOM REQUEST: Custom zoom to \(String(format: "%.1f", request.targetZoom * 100))% at \(focalPoint)")
        }
        
        // Clear the request after processing
        document.clearZoomRequest()
    }
} 