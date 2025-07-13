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
        // FIXED COORDINATE SYSTEM: Set up default view with deterministic positioning
        setupDefaultView(geometry: geometry)
        initialZoomLevel = document.zoomLevel // Initialize for zoom gestures
        print("🎯 FIXED CANVAS SETUP: Using default 75% zoom, no race conditions")
    }
} 