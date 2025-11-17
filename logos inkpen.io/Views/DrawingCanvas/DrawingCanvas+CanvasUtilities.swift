import SwiftUI

extension DrawingCanvas {

    internal func setupCanvas() {
        initialZoomLevel = zoomLevel
        // Spatial index is built in main onAppear - don't duplicate here
    }
}
