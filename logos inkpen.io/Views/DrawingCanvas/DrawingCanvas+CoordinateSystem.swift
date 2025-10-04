//
//  CoordinateSystem.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Coordinate System Functions
extension DrawingCanvas {
    
    /// Convert screen coordinates to canvas coordinates
    /// PERFECT COORDINATE SYSTEM: Match exactly with .scaleEffect(zoomLevel, anchor: .topLeading).offset(canvasOffset)
    /// Mathematical inverse: (screen - canvasOffset) / zoomLevel = canvas
    /// 🚀 GPU-ACCELERATED: Uses Metal compute shaders for batch operations
    @discardableResult
    internal func screenToCanvas(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return screenToCanvas([point], geometry: geometry)[0]
    }
    
    /// Convert multiple screen coordinates to canvas coordinates efficiently
    /// 🚀 GPU-ACCELERATED: Uses Metal compute shaders (GPU required)
    internal func screenToCanvas(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        // TEMPORARILY DISABLED: Metal acceleration causing zoom/position issues
        // TODO: Re-enable when Metal coordinate transformations are fixed
        // 🚀 GPU-ONLY: Use Metal for all coordinate transformations
        if false {
            // Create inverse transformation matrix for screen-to-canvas
            let preciseOffsetX = Double(document.canvasOffset.x)
            let preciseOffsetY = Double(document.canvasOffset.y)
            let preciseZoom = Double(document.zoomLevel)
            
            let inverseTransform = CGAffineTransform(
                a: 1.0 / preciseZoom, b: 0,
                c: 0, d: 1.0 / preciseZoom,
                tx: -preciseOffsetX / preciseZoom, ty: -preciseOffsetY / preciseZoom
            )
            
            let metalEngine = MetalComputeEngine.shared
            let transformResult = metalEngine.transformPointsGPU(points, transform: inverseTransform)
            switch transformResult {
            case .success(let transformedPoints):
                return transformedPoints
            case .failure(_):
                // Fallback to CPU calculation
                return screenToCanvasCPU(points)
            }
        }
        // CPU fallback
        return screenToCanvasCPU(points)
    }
    
    private func screenToCanvasCPU(_ points: [CGPoint]) -> [CGPoint] {
        // Use high precision to prevent floating-point drift
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)
        
        return points.map { point in
            let preciseScreenX = Double(point.x)
            let preciseScreenY = Double(point.y)
            
            let canvasX = (preciseScreenX - preciseOffsetX) / preciseZoom
            let canvasY = (preciseScreenY - preciseOffsetY) / preciseZoom
            
            return CGPoint(x: canvasX, y: canvasY)
        }
    }
    

    
    /// Convert canvas coordinates to screen coordinates
    /// PERFECT COORDINATE SYSTEM: Match exactly with .scaleEffect(zoomLevel, anchor: .topLeading).offset(canvasOffset)
    /// Visual chain: (canvas * zoomLevel) + canvasOffset = screen
    /// 🚀 GPU-ACCELERATED: Uses Metal compute shaders for batch operations
    internal func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return canvasToScreen([point], geometry: geometry)[0]
    }
    
    /// Convert multiple canvas coordinates to screen coordinates efficiently
    /// 🚀 GPU-ACCELERATED: Uses Metal compute shaders (GPU required)
    internal func canvasToScreen(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        // TEMPORARILY DISABLED: Metal acceleration causing zoom/position issues
        // TODO: Re-enable when Metal coordinate transformations are fixed
        // 🚀 GPU-ONLY: Use Metal for all coordinate transformations
        if false {
            // Create transformation matrix for canvas-to-screen
            let preciseOffsetX = Double(document.canvasOffset.x)
            let preciseOffsetY = Double(document.canvasOffset.y)
            let preciseZoom = Double(document.zoomLevel)
            
            let transform = CGAffineTransform(
                a: preciseZoom, b: 0,
                c: 0, d: preciseZoom,
                tx: preciseOffsetX, ty: preciseOffsetY
            )
            
            let metalEngine = MetalComputeEngine.shared
            let transformResult = metalEngine.transformPointsGPU(points, transform: transform)
            switch transformResult {
            case .success(let transformedPoints):
                return transformedPoints
            case .failure(_):
                // Fallback to CPU calculation
                return canvasToScreenCPU(points, geometry: geometry)
            }
        }
        // CPU fallback
        return canvasToScreenCPU(points, geometry: geometry)
    }
    
    private func canvasToScreenCPU(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        // Use high precision to prevent floating-point drift
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)
        
        return points.map { point in
            let preciseCanvasX = Double(point.x)
            let preciseCanvasY = Double(point.y)
            
            let screenX = (preciseCanvasX * preciseZoom) + preciseOffsetX
            let screenY = (preciseCanvasY * preciseZoom) + preciseOffsetY
            
            return CGPoint(x: screenX, y: screenY)
        }
    }
    

    
    /// Set up default view with deterministic positioning
    internal func setupDefaultView(geometry: GeometryProxy) {
        // Use document bounds for zoom/fit calculations (standard approach)
        // No Canvas-specific coordinate logic needed
        
        let documentBounds = document.documentBounds
        let viewSize = geometry.size
        
        // RULER ADJUSTMENT: Account for ruler space when calculating available area
        let rulerThickness: CGFloat = 20
        let rulerOffset = document.showRulers ? rulerThickness : 0
        
        // ASPECT RATIO SCALING: Calculate both scales and use minimum for uniform scaling
        let availableWidth = viewSize.width - rulerOffset
        let availableHeight = viewSize.height - rulerOffset
        
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let uniformScale = min(scaleX, scaleY)  // ✅ UNIFORM SCALING - maintains aspect ratio
        
        // Cap the default zoom at reasonable bounds (like professional apps)
        let defaultZoom = max(0.25, min(1.5, uniformScale))
        document.zoomLevel = defaultZoom
        
        // Center canvas in the VISIBLE area (accounting for rulers occupying top/left)
        // Visible rect starts at (rulerOffset, rulerOffset) and spans the remaining area
        // Add 1px compensation for the top ruler hairline so content doesn't sit under it
        let rulerBorderCompensationY: CGFloat = document.showRulers ? 0.5 : 0.0
        let visibleCenter = CGPoint(
            x: (viewSize.width - rulerOffset) / 2.0 + rulerOffset,
            y: (viewSize.height - rulerOffset) / 2.0 + rulerOffset + rulerBorderCompensationY
        )
        
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Calculate offset to center document: screen = (document * zoom) + offset
        document.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * document.zoomLevel),
            y: visibleCenter.y - (documentCenter.y * document.zoomLevel)
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = document.zoomLevel
        
    }
    
    /// Fit canvas to page view
    internal func fitToPage(geometry: GeometryProxy) {
        // Use standard document bounds for fit-to-page calculations
        let documentBounds = document.documentBounds
        let viewSize = geometry.size

        // RULER ADJUSTMENT: Account for ruler space when calculating available area
        let rulerThickness: CGFloat = 20
        let rulerOffset = document.showRulers ? rulerThickness : 0

        // Calculate zoom level to fit the canvas in the view - accounting for ruler space
        let availableWidth = viewSize.width - rulerOffset
        let availableHeight = viewSize.height - rulerOffset

        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let fitZoom = min(scaleX, scaleY)

        // Set zoom level to fit canvas in view
        document.zoomLevel = max(0.1, min(16.0, fitZoom))

        // Center canvas in the VISIBLE area at the fit zoom
        // The canvas offset positions the document origin (0,0) relative to the view origin
        // When rulers are shown, we need to account for the ruler space
        let visibleCenter = CGPoint(
            x: (viewSize.width + rulerOffset) / 2.0,  // Center of visible area
            y: (viewSize.height + rulerOffset) / 2.0  // Center of visible area
        )

        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        // Calculate offset to center document in the visible area
        // The offset positions the canvas so that the document appears centered
        document.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * document.zoomLevel),
            y: visibleCenter.y - (documentCenter.y * document.zoomLevel)
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = document.zoomLevel
        
    }
    
            /// Set to actual size (100%) with proper centering (professional standard)
    internal func actualSize(geometry: GeometryProxy) {
        let newZoomLevel: Double = 1.0 // 100% actual size
        
        // RULER ADJUSTMENT: Account for ruler space when centering
        let rulerThickness: CGFloat = 20
        let rulerOffset = document.showRulers ? rulerThickness : 0
        
        // Calculate visible center accounting for rulers occupying top/left
        let viewSize = geometry.size
        // Add 1px compensation for the top ruler hairline so content doesn't sit under it
        let rulerBorderCompensationY: CGFloat = document.showRulers ? 0.5 : 0.0
        let visibleCenter = CGPoint(
            x: (viewSize.width - rulerOffset) / 2.0 + rulerOffset,
            y: (viewSize.height - rulerOffset) / 2.0 + rulerOffset + rulerBorderCompensationY
        )
        
        // For actual size, we want to center the document center in the view
        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Update zoom level
        document.zoomLevel = newZoomLevel
        
        // Calculate offset to center the document in the visible area
        document.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * CGFloat(newZoomLevel)),
            y: visibleCenter.y - (documentCenter.y * CGFloat(newZoomLevel))
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = CGFloat(newZoomLevel)
        
    }
    
    /// Zoom at a specific point (stable version to prevent drift)
    internal func handleZoomAtPoint(newZoomLevel: CGFloat, focalPoint: CGPoint, geometry: GeometryProxy) {
        let oldZoomLevel = document.zoomLevel
        
        // Only proceed if zoom level actually changes
        guard abs(newZoomLevel - oldZoomLevel) > 0.001 else { return }
        
        // Use high precision arithmetic to prevent floating-point drift
        let preciseOldZoom = Double(oldZoomLevel)
        let preciseNewZoom = Double(newZoomLevel)
        let preciseFocalX = Double(focalPoint.x)
        let preciseFocalY = Double(focalPoint.y)
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        
        // Find the canvas coordinate at the focal point
        let canvasPointAtFocus = CGPoint(
            x: (preciseFocalX - preciseOffsetX) / preciseOldZoom,
            y: (preciseFocalY - preciseOffsetY) / preciseOldZoom
        )
        
        // Update zoom level
        document.zoomLevel = newZoomLevel
        
        // Calculate what the new offset should be to keep the same canvas point at the focal point
        let newOffset = CGPoint(
            x: preciseFocalX - (Double(canvasPointAtFocus.x) * preciseNewZoom),
            y: preciseFocalY - (Double(canvasPointAtFocus.y) * preciseNewZoom)
        )
        
        document.canvasOffset = newOffset
        
    }
    
    /// Handle simplified zoom
    internal func handleSimplifiedZoom(newZoomLevel: CGFloat, geometry: GeometryProxy) {
        let oldZoomLevel = document.zoomLevel
        
        // Only proceed if zoom level actually changes
        guard abs(newZoomLevel - oldZoomLevel) > 0.001 else { return }
        
        // STABLE ZOOM SYSTEM: Use document center as fixed reference point
        // This prevents coordinate drift by always using the same reference
        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Calculate view center
        let viewCenter = CGPoint(
            x: geometry.size.width / 2.0,
            y: geometry.size.height / 2.0
        )
        
        // Update zoom level
        document.zoomLevel = newZoomLevel
        
        // Calculate offset to keep document center at view center
        // This approach is stable and prevents drift
        let newOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * newZoomLevel),
            y: viewCenter.y - (documentCenter.y * newZoomLevel)
        )
        
        document.canvasOffset = newOffset
        
    }
} 
