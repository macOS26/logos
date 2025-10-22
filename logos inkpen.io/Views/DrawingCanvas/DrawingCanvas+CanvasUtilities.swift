import SwiftUI

extension DrawingCanvas {

    internal func setupCanvas() {
        initialZoomLevel = document.viewState.zoomLevel

        // Build spatial index for O(1) hit testing
        spatialIndex.rebuild(from: document.snapshot)
    }
}
