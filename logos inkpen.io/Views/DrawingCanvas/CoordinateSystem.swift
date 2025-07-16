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
    internal func screenToCanvas(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Use high precision to prevent floating-point drift
        let preciseScreenX = Double(point.x)
        let preciseScreenY = Double(point.y)
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)
        
        let canvasX = (preciseScreenX - preciseOffsetX) / preciseZoom
        let canvasY = (preciseScreenY - preciseOffsetY) / preciseZoom
        
        return CGPoint(x: canvasX, y: canvasY)
    }
    
    /// Convert canvas coordinates to screen coordinates
    /// PERFECT COORDINATE SYSTEM: Match exactly with .scaleEffect(zoomLevel, anchor: .topLeading).offset(canvasOffset)
    /// Visual chain: (canvas * zoomLevel) + canvasOffset = screen
    internal func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        // Use high precision to prevent floating-point drift
        let preciseCanvasX = Double(point.x)
        let preciseCanvasY = Double(point.y)
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)
        
        let screenX = (preciseCanvasX * preciseZoom) + preciseOffsetX
        let screenY = (preciseCanvasY * preciseZoom) + preciseOffsetY
        
        return CGPoint(x: screenX, y: screenY)
    }
    
    /// Set up default view with deterministic positioning
    internal func setupDefaultView(geometry: GeometryProxy) {
        // Use document bounds for zoom/fit calculations (standard approach)
        // No Canvas-specific coordinate logic needed
        
        let documentBounds = document.documentBounds
        let viewSize = geometry.size
        
        // ASPECT RATIO SCALING: Calculate both scales and use minimum for uniform scaling
        let padding: CGFloat = 100.0  // Leave some padding for professional look
        let availableWidth = viewSize.width - (padding * 2)
        let availableHeight = viewSize.height - (padding * 2)
        
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let uniformScale = min(scaleX, scaleY)  // ✅ UNIFORM SCALING - maintains aspect ratio
        
        // Cap the default zoom at reasonable bounds (like professional apps)
        let defaultZoom = max(0.25, min(1.5, uniformScale))
        document.zoomLevel = defaultZoom
        
        // Center canvas in view using the calculated uniform scale
        let viewCenter = CGPoint(
            x: viewSize.width / 2.0,
            y: viewSize.height / 2.0
        )
        
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Calculate offset to center document: screen = (document * zoom) + offset
        document.canvasOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * document.zoomLevel),
            y: viewCenter.y - (documentCenter.y * document.zoomLevel)
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = document.zoomLevel
        
        // print("🎯 DOCUMENT SCALING (Standard Approach):")
        // print("   Document Bounds: \(documentBounds)")
        // print("   Document Aspect Ratio: \(String(format: "%.3f", documentBounds.width / documentBounds.height))")
        // print("   View Size: \(String(format: "%.1f", viewSize.width)) × \(String(format: "%.1f", viewSize.height))")
        // print("   View Aspect Ratio: \(String(format: "%.3f", viewSize.width / viewSize.height))")
        // print("   Available Space: \(String(format: "%.1f", availableWidth)) × \(String(format: "%.1f", availableHeight))")
        // print("   Scale X: \(String(format: "%.3f", scaleX)) (width fit)")
        // print("   Scale Y: \(String(format: "%.3f", scaleY)) (height fit)")
        // print("   Uniform Scale: \(String(format: "%.3f", uniformScale)) (min of above - maintains aspect ratio)")
        // print("   Final Zoom: \(String(format: "%.1f", defaultZoom * 100))% (capped for usability)")
        // print("   Canvas Offset: (\(String(format: "%.1f", document.canvasOffset.x)), \(String(format: "%.1f", document.canvasOffset.y)))")
        // print("   ✅ CANVAS LAYER AUTO-SYNCS WITH ALL GRAPHICS!")
    }
    
    /// Fit canvas to page view
    internal func fitToPage(geometry: GeometryProxy) {
        // Use standard document bounds for fit-to-page calculations
        let documentBounds = document.documentBounds
        let viewSize = geometry.size
        
        // Calculate zoom level to fit the canvas in the view with padding
        let padding: CGFloat = 50.0
        let availableWidth = viewSize.width - (padding * 2)
        let availableHeight = viewSize.height - (padding * 2)
        
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let fitZoom = min(scaleX, scaleY)
        
        // Set zoom level to fit canvas in view
        document.zoomLevel = max(0.1, min(10.0, fitZoom))
        
        // Center canvas in view at the fit zoom
        let viewCenter = CGPoint(
            x: viewSize.width / 2.0,
            y: viewSize.height / 2.0
        )
        
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Calculate offset to center document
        document.canvasOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * document.zoomLevel),
            y: viewCenter.y - (documentCenter.y * document.zoomLevel)
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = document.zoomLevel
        
        // print("🔍 FIT TO PAGE: Using standard document bounds")
        // print("   Document Bounds: \(documentBounds)")
        // print("   Fit Zoom: \(String(format: "%.1f", fitZoom * 100))% (minimum scale to fit)")
        // print("   Standard coordinate system approach")
    }
    
    /// Set to actual size (100%) with proper centering (Adobe Illustrator standard)
    internal func actualSize(geometry: GeometryProxy) {
        let newZoomLevel: Double = 1.0 // 100% actual size
        
        // Calculate what canvas point is currently at the view center
        let viewCenter = CGPoint(
            x: geometry.size.width / 2.0,
            y: geometry.size.height / 2.0
        )
        
        // For actual size, we want to center the document center in the view
        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )
        
        // Update zoom level
        document.zoomLevel = newZoomLevel
        
        // Calculate offset to center the document
        document.canvasOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * CGFloat(newZoomLevel)),
            y: viewCenter.y - (documentCenter.y * CGFloat(newZoomLevel))
        )
        
        // Update initial zoom level for gesture handling
        initialZoomLevel = CGFloat(newZoomLevel)
        
        // print("🎯 ACTUAL SIZE: Set to 100% and centered document")
        // print("   Document center: (\(String(format: "%.1f", documentCenter.x)), \(String(format: "%.1f", documentCenter.y)))")
        // print("   View center: (\(String(format: "%.1f", viewCenter.x)), \(String(format: "%.1f", viewCenter.y)))")
        // print("   New offset: (\(String(format: "%.1f", document.canvasOffset.x)), \(String(format: "%.1f", document.canvasOffset.y)))")
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
        
        // print("🔍 FOCAL POINT ZOOM: \(String(format: "%.3f", oldZoomLevel))x → \(String(format: "%.3f", newZoomLevel))x")
        // print("   Focal point: (\(String(format: "%.1f", focalPoint.x)), \(String(format: "%.1f", focalPoint.y)))")
        // print("   Canvas point at focus: (\(String(format: "%.1f", canvasPointAtFocus.x)), \(String(format: "%.1f", canvasPointAtFocus.y)))")
        // print("   Stable offset: (\(String(format: "%.1f", newOffset.x)), \(String(format: "%.1f", newOffset.y)))")
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
        
        // print("🔍 STABLE ZOOM: \(String(format: "%.3f", oldZoomLevel))x → \(String(format: "%.3f", newZoomLevel))x")
        // print("   Document center: (\(String(format: "%.1f", documentCenter.x)), \(String(format: "%.1f", documentCenter.y)))")
        // print("   View center: (\(String(format: "%.1f", viewCenter.x)), \(String(format: "%.1f", viewCenter.y)))")
        // print("   Fixed offset: (\(String(format: "%.1f", newOffset.x)), \(String(format: "%.1f", newOffset.y)))")
    }
} 
