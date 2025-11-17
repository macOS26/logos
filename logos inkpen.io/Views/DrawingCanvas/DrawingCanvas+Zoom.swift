import SwiftUI
import simd

extension DrawingCanvas {
    internal var allowedZoomSteps: [CGFloat] { [0.75, 0.8, 0.9, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 32.0, 64.0, 128.0, 256.0, 512.0, 640.0] }

    internal func quantizeZoomToNearestAllowed(_ zoom: CGFloat) -> CGFloat {
        let clamped = max(allowedZoomSteps.first ?? 0.75, min(allowedZoomSteps.last ?? 640.0, zoom))
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
        return allowedZoomSteps.last ?? 640.0
    }

    internal func nextAllowedStepDown(from zoom: CGFloat) -> CGFloat {
        let epsilon: CGFloat = 1e-6
        for step in allowedZoomSteps.reversed() {
            if step < zoom - epsilon { return step }
        }
        return allowedZoomSteps.first ?? 0.75
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

        // Allow elastic overshoot beyond limits (like Safari)
        let minZoom: CGFloat = 0.75
        let maxZoom: CGFloat = 640.0
        let elasticZoom: CGFloat

        if newZoomLevel < minZoom {
            // Elastic resistance when zooming out past minimum (like Safari)
            let overshoot = minZoom - newZoomLevel
            // Use a rubber-band formula: resistance increases with distance
            let dampenedOvershoot = sqrt(overshoot) * 0.15
            elasticZoom = minZoom - dampenedOvershoot
        } else if newZoomLevel > maxZoom {
            // Elastic resistance when zooming in past maximum (like Safari)
            let overshoot = newZoomLevel - maxZoom
            // Use a rubber-band formula: resistance increases with distance
            let dampenedOvershoot = sqrt(overshoot) * 0.5
            elasticZoom = maxZoom + dampenedOvershoot
        } else {
            elasticZoom = newZoomLevel
        }

        if currentMousePosition != .zero {
            handleZoomAtPoint(newZoomLevel: elasticZoom, focalPoint: currentMousePosition, geometry: geometry)
        } else {
            let viewCenter = CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)
            handleZoomAtPoint(newZoomLevel: elasticZoom, focalPoint: viewCenter, geometry: geometry)
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

        let unclamped = CGFloat(currentZoom * adjustedValue)
        let finalZoomLevel = max(0.75, min(640.0, unclamped))

        // Spring back to clamped value if we went past limits
        let focalPoint = currentMousePosition != .zero ? currentMousePosition : CGPoint(x: geometry.size.width / 2.0, y: geometry.size.height / 2.0)

        if unclamped != finalZoomLevel {
            // We were outside bounds, spring back with animation
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: focalPoint, geometry: geometry)
            }
        } else {
            // Normal case, no spring needed
            handleZoomAtPoint(newZoomLevel: finalZoomLevel, focalPoint: focalPoint, geometry: geometry)
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
