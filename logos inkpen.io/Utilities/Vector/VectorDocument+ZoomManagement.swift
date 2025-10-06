//
//  VectorDocument+ZoomManagement.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import SwiftUI

// MARK: - Zoom Management
extension VectorDocument {

    // MARK: - Professional Zoom Management

    /// Request a coordinated zoom operation that maintains proper focal point
    func requestZoom(to targetZoom: CGFloat, mode: ZoomMode) {
        let request = ZoomRequest(targetZoom: targetZoom, mode: mode)
        zoomRequest = request
    }
    
    /// Clear zoom request after processing
    func clearZoomRequest() {
        zoomRequest = nil
    }
}
