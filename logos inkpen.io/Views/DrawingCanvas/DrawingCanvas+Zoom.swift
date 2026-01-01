import SwiftUI
import simd

extension DrawingCanvas {
    // Zoom steps from 25% to 16000%
    internal var allowedZoomSteps: [CGFloat] { [
        0.25, 0.33, 0.5, 0.67, 0.75, 1.0,           // 25% - 100%
        1.5, 2.0, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0,    // 150% - 1000%
        12.0, 16.0, 20.0, 25.0, 32.0, 40.0, 50.0,   // 1200% - 5000%
        64.0, 80.0, 100.0, 125.0, 160.0             // 6400% - 16000%
    ] }

    internal func quantizeZoomToNearestAllowed(_ zoom: CGFloat) -> CGFloat {
        let clamped = max(allowedZoomSteps.first ?? 0.25, min(allowedZoomSteps.last ?? 160.0, zoom))
        var best = allowedZoomSteps.first ?? 0.75
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
        return allowedZoomSteps.last ?? 160.0
    }

    internal func nextAllowedStepDown(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        for step in allowedZoomSteps.reversed() {
            if step < zoom - epsilon { return step }
        }
        return allowedZoomSteps.first ?? 0.25
    }

    internal func handleZoomGestureChanged(value: CGFloat, geometry: GeometryProxy) {
        guard !isBezierDrawing && !isPanGestureActive else {
            return
        }

        if !isZoomGestureActive {
            isZoomGestureActive = true
        }

        // SIMD optimization for performance on Apple Silicon
        let zoomData = SIMD2<Float>(Float(initialZoomLevel), Float(value))
        let currentZoom = zoomData.x
        let gestureValue = zoomData.y

        // Apply 1.5x speed multiplier directly to gesture
        let adjustedValue = 1.0 + (gestureValue - 1.0) * 1.5

        let newZoomLevel = CGFloat(currentZoom * adjustedValue)
        let clampedZoom = max(0.25, min(160.0, newZoomLevel))

        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: clampedZoom, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: clampedZoom, focalPoint: viewCenter, geometry: geometry)
        }
    }

    internal func handleZoomGestureEnded(value: CGFloat, geometry: GeometryProxy) {
        defer {
            isZoomGestureActive = false
        }

        guard !isBezierDrawing && !isPanGestureActive else {
            return
        }

        // SIMD optimization for performance on Apple Silicon
        let zoomData = SIMD2<Float>(Float(initialZoomLevel), Float(value))
        let currentZoom = zoomData.x
        let gestureValue = zoomData.y

        // Apply 1.5x speed multiplier directly to gesture
        let adjustedValue = 1.0 + (gestureValue - 1.0) * 1.5

        let finalZoomLevel = max(0.25, min(160.0, CGFloat(currentZoom * adjustedValue)))

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

        case .zoomIn:
            let newZoom = nextAllowedStepUp(from: zoomLevel)
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: newZoom, focalPoint: viewCenter, geometry: geometry)

        case .zoomOut:
            let newZoom = nextAllowedStepDown(from: zoomLevel)
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: newZoom, focalPoint: viewCenter, geometry: geometry)

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
