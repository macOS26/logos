//
//  CanvasUtilities.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Canvas Utility Functions
extension DrawingCanvas {

    /// Setup canvas with default settings
    internal func setupCanvas() {
        // SKIP INITIAL POSITIONING: Don't call setupDefaultView to avoid transition
        // The MainView will handle fit-to-page directly without intermediate positioning
        initialZoomLevel = document.zoomLevel // Initialize for zoom gestures
        Log.fileOperation("🎯 STREAMLINED CANVAS SETUP: Skipping intermediate positioning for direct fit-to-page", level: .info)
    }
} 
