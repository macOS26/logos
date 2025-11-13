import SwiftUI
import AppKit

fileprivate let enableHandToolLogging = false

extension DrawingCanvas {
    internal func handlePanGesture(value: DragGesture.Value, geometry: GeometryProxy) {

        if initialCanvasOffset == CGPoint.zero && handToolDragStart == CGPoint.zero {
            initialCanvasOffset = canvasOffset
            handToolDragStart = value.startLocation
            isPanGestureActive = true
            isActivelyPanning = true

            HandClosedCursor.set()
        }

        let cursorDelta = CGPoint(
            x: value.location.x - handToolDragStart.x,
            y: value.location.y - handToolDragStart.y
        )

        if document.viewState.currentTool == .hand {
            HandClosedCursor.set()
        }

        // ONLY update livePanDelta during gesture (NOT real canvasOffset!)
        livePanDelta = cursorDelta
        print("📍 PAN DELTA: \(cursorDelta) | canvasOffset: \(canvasOffset) (should NOT change)")

    }
}
