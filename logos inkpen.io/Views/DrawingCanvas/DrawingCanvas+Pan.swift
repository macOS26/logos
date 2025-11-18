import SwiftUI
import AppKit
import simd

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

        // SIMD optimization for pan delta calculation
        let currentLoc = SIMD2<Float>(Float(value.location.x), Float(value.location.y))
        let startLoc = SIMD2<Float>(Float(handToolDragStart.x), Float(handToolDragStart.y))

        let delta = currentLoc - startLoc

        #if os(macOS)
        if document.viewState.currentTool == .hand {
            HandClosedCursor.set()
        }
        #endif

        // Use GPU transform for 60fps panning - don't update canvasOffset during drag
        livePanDelta = CGPoint(x: CGFloat(delta.x), y: CGFloat(delta.y))
    }

    internal func handlePanGestureEnd() {
        // Bake livePanDelta into canvasOffset
        let finalOffset = CGPoint(
            x: initialCanvasOffset.x + livePanDelta.x,
            y: initialCanvasOffset.y + livePanDelta.y
        )
        canvasOffset = finalOffset

        // Reset live state
        livePanDelta = .zero
        initialCanvasOffset = .zero
        handToolDragStart = .zero
        isPanGestureActive = false

        #if os(macOS)
        if document.viewState.currentTool == .hand {
            HandOpenCursor.set()
        }
        #endif
    }
}
