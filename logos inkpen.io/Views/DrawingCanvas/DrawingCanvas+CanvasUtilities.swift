import SwiftUI

extension DrawingCanvas {

    internal func setupCanvas() {
        initialZoomLevel = zoomLevel

        // Build spatial index for O(1) hit testing (GPU-accelerated)
        spatialIndex.rebuild(from: document.snapshot)
    }
}
