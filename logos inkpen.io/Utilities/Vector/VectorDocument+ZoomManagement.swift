import SwiftUI

extension VectorDocument {

    func requestZoom(to targetZoom: CGFloat, mode: ZoomMode) {
        let request = ZoomRequest(targetZoom: targetZoom, mode: mode)
        zoomRequest = request
    }

    func clearZoomRequest() {
        zoomRequest = nil
    }
}
