//
//  CanvasUtilities.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Canvas Utility Functions
extension DrawingCanvas {
    
    /// Calculate distance between two points
    internal func distance(_ point1: CGPoint, _ point2: CGPoint) -> Double {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Setup canvas with default settings
    internal func setupCanvas(geometry: GeometryProxy) {
        // SKIP INITIAL POSITIONING: Don't call setupDefaultView to avoid transition
        // The MainView will handle fit-to-page directly without intermediate positioning
        initialZoomLevel = document.zoomLevel // Initialize for zoom gestures
        print("🎯 STREAMLINED CANVAS SETUP: Skipping intermediate positioning for direct fit-to-page")
    }
} 
