import SwiftUI

extension DrawingCanvas {
    internal var allowedZoomSteps: [CGFloat] { [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 2.0, 4.0, 8.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 640.0] }

    internal func quantizeZoomToNearestAllowed(_ zoom: CGFloat) -> CGFloat {
        let clamped = max(allowedZoomSteps.first ?? 0.5, min(allowedZoomSteps.last ?? 640.0, zoom))
        var best = allowedZoomSteps.first ?? 0.5
        var bestDiff = abs(clamped - best)
        for step in allowedZoomSteps {
            let d = abs(clamped - step)
            if d < bestDiff {
                bestDiff = d
                best = step
            }
        }
        return best
    }

    internal func nextAllowedStepUp(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        for step in allowedZoomSteps {
            if step > zoom + epsilon { return step }
        }
        return allowedZoomSteps.last ?? 640.0
    }

    internal func nextAllowedStepDown(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        for step in allowedZoomSteps.reversed() {
            if step < zoom - epsilon { return step }
        }
        return allowedZoomSteps.first ?? 0.5
    }

    internal func handleZoomGestureChanged(value: CGFloat, geometry: GeometryProxy) {
        guard !isBezierDrawing && !isPanGestureActive else {
            return
        }

        if !isZoomGestureActive {
            isZoomGestureActive = true
        }

        let newZoomLevel = max(0.5, min(640.0, initialZoomLevel * value))

        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: newZoomLevel, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: newZoomLevel, focalPoint: viewCenter, geometry: geometry)
        }
    }

    internal func handleZoomGestureEnded(value: CGFloat, geometry: GeometryProxy) {
        defer {
            isZoomGestureActive = false
        }

        guard !isBezierDrawing && !isPanGestureActive else {
            return
        }

        let finalZoomLevel = max(0.5, min(640.0, initialZoomLevel * value))

        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: viewCenter, geometry: geometry)
        }

        initialZoomLevel = finalZoomLevel

        #if os(macOS)
        if isCanvasHovering && document.viewState.currentTool == .zoom {
            MagnifyingGlassCursor.set()
            DispatchQueue.main.async { if isCanvasHovering && document.viewState.currentTool == .zoom { MagnifyingGlassCursor.set() } }
        }
        #endif
    }

    internal func handleZoomRequest(_ request: ZoomRequest, geometry: GeometryProxy) {

        switch request.mode {
        case .fitToPage:
            fitToPage(geometry: geometry)

        case .actualSize:
            actualSize(geometry: geometry)

        case .zoomIn, .zoomOut:
            if currentMousePosition != .zero {
                handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: currentMousePosition, geometry: geometry)
            } else {
                let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
                handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: viewCenter, geometry: geometry)
            }

        case .custom(let focalPoint):
            handleZoomAtPoint(newZoomLevel: request.targetZoom, focalPoint: focalPoint, geometry: geometry)
        }

        document.clearZoomRequest()

        #if os(macOS)
        if isCanvasHovering {
            switch document.viewState.currentTool {
            case .hand:
                NSCursor.openHand.set()
            case .eyedropper:
                EyedropperCursor.set()
            case .selectSameColor:
                EyedropperCursor.set()
            case .zoom:
                MagnifyingGlassCursor.set()
            default:
                break
            }
            DispatchQueue.main.async {
                if isCanvasHovering {
                    switch document.viewState.currentTool {
                    case .hand:
                        NSCursor.openHand.set()
                    case .eyedropper:
                        EyedropperCursor.set()
                    case .zoom:
                        MagnifyingGlassCursor.set()
                    default:
                        break
                    }
                }
            }
        }
        #endif
    }
}
