import SwiftUI
import AppKit

fileprivate let enableHandToolLogging = false

extension DrawingCanvas {
    internal func handlePanGesture(value: DragGesture.Value, geometry: GeometryProxy) {

        if initialCanvasOffset == CGPoint.zero && handToolDragStart == CGPoint.zero {
            initialCanvasOffset = document.viewState.canvasOffset
            handToolDragStart = value.startLocation
            isPanGestureActive = true

            HandClosedCursor.set()
        }

        let cursorDelta = CGPoint(
            x: value.location.x - handToolDragStart.x,
            y: value.location.y - handToolDragStart.y
        )

        if document.currentTool == .hand {
            HandClosedCursor.set()
        }
        document.viewState.canvasOffset = CGPoint(
            x: initialCanvasOffset.x + cursorDelta.x,
            y: initialCanvasOffset.y + cursorDelta.y
        )

    }
}
