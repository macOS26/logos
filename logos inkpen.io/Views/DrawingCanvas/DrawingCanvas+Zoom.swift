import SwiftUI
import simd

extension DrawingCanvas {
    internal var allowedZoomSteps: [CGFloat] { [0.5, 0.6, 0.7, 0.8, 0.9, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 640.0] }

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

        // Natural exponential zoom - feels more natural than linear
        // Use SIMD vector for performance (vectorized operations)
        let zoomData = SIMD2<Float>(Float(initialZoomLevel), Float(value - 1.0))
        let currentZoom = zoomData.x
        let delta = zoomData.y

        // Exponential sensitivity: pow(2, delta * scale) gives natural feel
        // Scale factor depends on current zoom level for context-aware speed
        let scale: Float = currentZoom < 16.0 ? 0.3 : 0.5  // Slower at low zoom, faster at high zoom
        let exponent = delta * scale
        let multiplier = pow(2.0, exponent)

        let newZoomLevel = CGFloat(currentZoom * multiplier)
        let clampedZoom = max(0.5, min(640.0, newZoomLevel))

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

        // Natural exponential zoom using SIMD for performance
        let zoomData = SIMD2<Float>(Float(initialZoomLevel), Float(value - 1.0))
        let currentZoom = zoomData.x
        let delta = zoomData.y

        // Exponential sensitivity with context-aware scaling
        let scale: Float = currentZoom < 16.0 ? 0.3 : 0.5
        let exponent = delta * scale
        let multiplier = pow(2.0, exponent)

        let finalZoomLevel = max(0.5, min(640.0, CGFloat(currentZoom * multiplier)))

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
