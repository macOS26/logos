import SwiftUI
import AppKit

extension DrawingCanvas {

    internal func handleHover(phase: HoverPhase, geometry: GeometryProxy) {
        if case .active(let location) = phase {
            currentMouseLocation = location
            currentMousePosition = location
            if isTextEditingMode {
                NSCursor.iBeam.set()
            } else if document.currentTool == .hand {
                switch isPanGestureActive {
                case true: HandClosedCursor.set()
                case false: HandOpenCursor.set()
                }
            } else if document.currentTool == .eyedropper {
                EyedropperCursor.set()
            } else if document.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }

            if isBezierDrawing && document.currentTool == .bezierPen && bezierPoints.count > 0 {
                let canvasLocation = screenToCanvas(location, geometry: geometry)

                if bezierPoints.count >= 3 {
                    let firstPoint = bezierPoints[0]
                    let firstPointLocation = CGPoint(x: firstPoint.x, y: firstPoint.y)
                    let baseCloseTolerance: Double = 5.0
                    let zoomLevel = document.viewState.zoomLevel
                    let closeTolerance = max(2.0, baseCloseTolerance / zoomLevel)

                    if distance(canvasLocation, firstPointLocation) <= closeTolerance {
                        showClosePathHint = true
                        closePathHintLocation = firstPointLocation
                    } else {
                        showClosePathHint = false
                    }
                } else {
                }
            } else if document.currentTool == .bezierPen && !isBezierDrawing {
                let (shouldShow, hintLocation) = shouldShowContinuePathHint()
                if shouldShow, let location = hintLocation {
                    showContinuePathHint = true
                    continuePathHintLocation = location
                } else {
                    showContinuePathHint = false
                }
            } else {
                showClosePathHint = false
                showContinuePathHint = false
            }
        } else {
            currentMouseLocation = nil
            showClosePathHint = false
            if !isCanvasHovering {
                NSCursor.arrow.set()
            }

        }
    }
}
