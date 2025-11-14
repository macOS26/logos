import SwiftUI

extension DrawingCanvas {

    internal func setupCanvas() {
        initialZoomLevel = zoomLevel

        // Build spatial index for O(1) hit testing (GPU-accelerated)
        if let metalIndex = metalSpatialIndex {
            metalIndex.rebuild(from: document.snapshot)
        } else {
            spatialIndex.rebuild(from: document.snapshot)
        }
    }
}
