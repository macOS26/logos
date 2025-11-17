import SwiftUI
import AppKit

fileprivate let enableHandToolLogging = false

extension DrawingCanvas {
    internal func handlePanGesture(value: DragGesture.Value, geometry: GeometryProxy) {

        if initialCanvasOffset == CGPoint.zero && handToolDragStart == CGPoint.zero {
            initialCanvasOffset = canvasOffset
            handToolDragStart = value.startLocation
            isPanGestureActive = true

            #if os(macOS)
            HandClosedCursor.set()
            #endif
        }

        let cursorDelta = CGPoint(
            x: value.location.x - handToolDragStart.x,
            y: value.location.y - handToolDragStart.y
        )

        #if os(macOS)
        if document.viewState.currentTool == .hand {
            HandClosedCursor.set()
        }
        #endif
        canvasOffset = CGPoint(
            x: initialCanvasOffset.x + cursorDelta.x,
            y: initialCanvasOffset.y + cursorDelta.y
        )

    }
}
