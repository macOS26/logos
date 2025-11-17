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

        // Use live delta for instant feedback without redrawing canvas
        livePanDelta = CGPoint(x: CGFloat(delta.x), y: CGFloat(delta.y))
    }
}
