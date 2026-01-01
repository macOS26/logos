import SwiftUI
import simd

extension DrawingCanvas {

    @discardableResult
    internal func screenToCanvas(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return screenToCanvas([point], geometry: geometry)[0]
    }

    internal func screenToCanvas(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        return screenToCanvasCPU(points)
    }

    private func screenToCanvasCPU(_ points: [CGPoint]) -> [CGPoint] {
        // Use GPU for large batches (> 100 points), CPU SIMD for small batches
        if points.count > 100 {
            return GPUCoordinateTransform.shared.transformPoints(
                points,
                offset: canvasOffset,
                zoom: CGFloat(zoomLevel),
                screenToCanvas: true
            )
        }

        // CPU SIMD optimization for batch coordinate transformation
        let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
        let zoom = Float(zoomLevel)

        return points.map { point in
            let screenVec = SIMD2<Float>(Float(point.x), Float(point.y))
            let canvasVec = (screenVec - offsetVec) / zoom

            return CGPoint(x: CGFloat(canvasVec.x), y: CGFloat(canvasVec.y))
        }
    }

    internal func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return canvasToScreen([point], geometry: geometry)[0]
    }

    internal func canvasToScreen(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        return canvasToScreenCPU(points, geometry: geometry)
    }

    private func canvasToScreenCPU(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        // Use GPU for large batches (> 100 points), CPU SIMD for small batches
        if points.count > 100 {
            return GPUCoordinateTransform.shared.transformPoints(
                points,
                offset: canvasOffset,
                zoom: CGFloat(zoomLevel),
                screenToCanvas: false
            )
        }

        // CPU SIMD optimization for batch coordinate transformation
        let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
        let zoom = Float(zoomLevel)

        return points.map { point in
            let canvasVec = SIMD2<Float>(Float(point.x), Float(point.y))
            let screenVec = canvasVec * zoom + offsetVec

            return CGPoint(x: CGFloat(screenVec.x), y: CGFloat(screenVec.y))
        }
    }

    internal func setupDefaultView(geometry: GeometryProxy) {

        let documentBounds = document.documentBounds
        let viewSize = geometry.size
        let rulerThickness: CGFloat = 20
        let rulerOffset = document.gridSettings.showRulers ? rulerThickness : 0
        let availableWidth = viewSize.width - rulerOffset
        let availableHeight = viewSize.height - rulerOffset
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let uniformScale = min(scaleX, scaleY)
        let defaultZoom = max(0.25, min(1.5, uniformScale))
        zoomLevel = defaultZoom

        let rulerBorderCompensationY: CGFloat = document.gridSettings.showRulers ? 0.5 : 0.0
        let visibleCenter = CGPoint(
            x: (viewSize.width - rulerOffset) / 2.0 + rulerOffset,
            y: (viewSize.height - rulerOffset) / 2.0 + rulerOffset + rulerBorderCompensationY
        )

        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * zoomLevel),
            y: visibleCenter.y - (documentCenter.y * zoomLevel)
        )

        initialZoomLevel = zoomLevel

    }

    internal func fitToPage(geometry: GeometryProxy) {
        let documentBounds = document.documentBounds
        let viewSize = geometry.size
        let rulerThickness: CGFloat = 20
        let rulerOffset = document.gridSettings.showRulers ? rulerThickness : 0
        let availableWidth = viewSize.width - rulerOffset
        let availableHeight = viewSize.height - rulerOffset
        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let fitZoom = min(scaleX, scaleY)

        zoomLevel = max(0.1, min(160.0, fitZoom))  // Up to 16000%

        let rulerBorderCompensationY: CGFloat = document.gridSettings.showRulers ? 0.5 : 0.0
        let visibleCenter = CGPoint(
            x: (viewSize.width - rulerOffset) / 2.0 + rulerOffset,
            y: (viewSize.height - rulerOffset) / 2.0 + rulerOffset + rulerBorderCompensationY
        )

        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * zoomLevel),
            y: visibleCenter.y - (documentCenter.y * zoomLevel)
        )

        initialZoomLevel = zoomLevel

    }

    internal func actualSize(geometry: GeometryProxy) {
        let newZoomLevel: Double = 1.0
        let rulerThickness: CGFloat = 20
        let rulerOffset = document.gridSettings.showRulers ? rulerThickness : 0
        let viewSize = geometry.size
        let rulerBorderCompensationY: CGFloat = document.gridSettings.showRulers ? 0.5 : 0.0
        let visibleCenter = CGPoint(
            x: (viewSize.width - rulerOffset) / 2.0 + rulerOffset,
            y: (viewSize.height - rulerOffset) / 2.0 + rulerOffset + rulerBorderCompensationY
        )

        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        zoomLevel = newZoomLevel

        canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * CGFloat(newZoomLevel)),
            y: visibleCenter.y - (documentCenter.y * CGFloat(newZoomLevel))
        )

        initialZoomLevel = CGFloat(newZoomLevel)

    }

    internal func handleZoomAtPoint(newZoomLevel: CGFloat, focalPoint: CGPoint, geometry: GeometryProxy, isLive: Bool = false) {
        let oldZoomLevel = zoomLevel

        guard abs(newZoomLevel - oldZoomLevel) > 0.001 else { return }

        // SIMD optimization for zoom focal point calculation
        let focalVec = SIMD2<Float>(Float(focalPoint.x), Float(focalPoint.y))
        let offsetVec = SIMD2<Float>(Float(canvasOffset.x), Float(canvasOffset.y))
        let oldZoom = Float(oldZoomLevel)
        let newZoom = Float(newZoomLevel)

        // Calculate canvas point at focal point: (focal - offset) / oldZoom
        let canvasPointAtFocus = (focalVec - offsetVec) / oldZoom

        // Calculate new offset: focal - (canvasPoint * newZoom)
        let newOffsetVec = focalVec - (canvasPointAtFocus * newZoom)

        let newOffset = CGPoint(x: CGFloat(newOffsetVec.x), y: CGFloat(newOffsetVec.y))

        if isLive {
            // During active gesture - update deltas only (GPU transform, no Canvas re-render)
            liveZoomDelta = newZoomLevel / zoomLevel
            let panDeltaVec = newOffsetVec - offsetVec
            livePanDelta = CGPoint(x: CGFloat(panDeltaVec.x), y: CGFloat(panDeltaVec.y))
        } else {
            // After gesture end - bake deltas into real values
            zoomLevel = newZoomLevel
            canvasOffset = newOffset
        }

    }

    internal func handleSimplifiedZoom(newZoomLevel: CGFloat, geometry: GeometryProxy) {
        let oldZoomLevel = zoomLevel

        guard abs(newZoomLevel - oldZoomLevel) > 0.001 else { return }

        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        let viewCenter = CGPoint(
            x: geometry.size.width / 2.0,
            y: geometry.size.height / 2.0
        )

        zoomLevel = newZoomLevel

        let newOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * newZoomLevel),
            y: viewCenter.y - (documentCenter.y * newZoomLevel)
        )

        canvasOffset = newOffset

    }
}
