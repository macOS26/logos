import SwiftUI

extension DrawingCanvas {

    @discardableResult
    internal func screenToCanvas(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return screenToCanvas([point], geometry: geometry)[0]
    }

    internal func screenToCanvas(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        if false {
            let preciseOffsetX = Double(document.canvasOffset.x)
            let preciseOffsetY = Double(document.canvasOffset.y)
            let preciseZoom = Double(document.zoomLevel)

            let inverseTransform = CGAffineTransform(
                a: 1.0 / preciseZoom, b: 0,
                c: 0, d: 1.0 / preciseZoom,
                tx: -preciseOffsetX / preciseZoom, ty: -preciseOffsetY / preciseZoom
            )

            let metalEngine = MetalComputeEngine.shared
            let transformResult = metalEngine.transformPointsGPU(points, transform: inverseTransform)
            switch transformResult {
            case .success(let transformedPoints):
                return transformedPoints
            case .failure(_):
                return screenToCanvasCPU(points)
            }
        }
        return screenToCanvasCPU(points)
    }

    private func screenToCanvasCPU(_ points: [CGPoint]) -> [CGPoint] {
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)

        return points.map { point in
            let preciseScreenX = Double(point.x)
            let preciseScreenY = Double(point.y)

            let canvasX = (preciseScreenX - preciseOffsetX) / preciseZoom
            let canvasY = (preciseScreenY - preciseOffsetY) / preciseZoom

            return CGPoint(x: canvasX, y: canvasY)
        }
    }


    internal func canvasToScreen(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return canvasToScreen([point], geometry: geometry)[0]
    }

    internal func canvasToScreen(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        if false {
            let preciseOffsetX = Double(document.canvasOffset.x)
            let preciseOffsetY = Double(document.canvasOffset.y)
            let preciseZoom = Double(document.zoomLevel)

            let transform = CGAffineTransform(
                a: preciseZoom, b: 0,
                c: 0, d: preciseZoom,
                tx: preciseOffsetX, ty: preciseOffsetY
            )

            let metalEngine = MetalComputeEngine.shared
            let transformResult = metalEngine.transformPointsGPU(points, transform: transform)
            switch transformResult {
            case .success(let transformedPoints):
                return transformedPoints
            case .failure(_):
                return canvasToScreenCPU(points, geometry: geometry)
            }
        }
        return canvasToScreenCPU(points, geometry: geometry)
    }

    private func canvasToScreenCPU(_ points: [CGPoint], geometry: GeometryProxy) -> [CGPoint] {
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)
        let preciseZoom = Double(document.zoomLevel)

        return points.map { point in
            let preciseCanvasX = Double(point.x)
            let preciseCanvasY = Double(point.y)

            let screenX = (preciseCanvasX * preciseZoom) + preciseOffsetX
            let screenY = (preciseCanvasY * preciseZoom) + preciseOffsetY

            return CGPoint(x: screenX, y: screenY)
        }
    }


    internal func setupDefaultView(geometry: GeometryProxy) {

        let documentBounds = document.documentBounds
        let viewSize = geometry.size

        let rulerThickness: CGFloat = 20
        let rulerOffset = document.showRulers ? rulerThickness : 0

        let availableWidth = viewSize.width - rulerOffset
        let availableHeight = viewSize.height - rulerOffset

        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let uniformScale = min(scaleX, scaleY)

        let defaultZoom = max(0.25, min(1.5, uniformScale))
        document.zoomLevel = defaultZoom

        let rulerBorderCompensationY: CGFloat = document.showRulers ? 0.5 : 0.0
        let visibleCenter = CGPoint(
            x: (viewSize.width - rulerOffset) / 2.0 + rulerOffset,
            y: (viewSize.height - rulerOffset) / 2.0 + rulerOffset + rulerBorderCompensationY
        )

        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        document.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * document.zoomLevel),
            y: visibleCenter.y - (documentCenter.y * document.zoomLevel)
        )

        initialZoomLevel = document.zoomLevel

    }

    internal func fitToPage(geometry: GeometryProxy) {
        let documentBounds = document.documentBounds
        let viewSize = geometry.size

        let rulerThickness: CGFloat = 20
        let rulerOffset = document.showRulers ? rulerThickness : 0

        let availableWidth = viewSize.width - rulerOffset
        let availableHeight = viewSize.height - rulerOffset

        let scaleX = availableWidth / documentBounds.width
        let scaleY = availableHeight / documentBounds.height
        let fitZoom = min(scaleX, scaleY)

        document.zoomLevel = max(0.1, min(16.0, fitZoom))

        let visibleCenter = CGPoint(
            x: (viewSize.width + rulerOffset) / 2.0,
            y: (viewSize.height + rulerOffset) / 2.0
        )

        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        document.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * document.zoomLevel),
            y: visibleCenter.y - (documentCenter.y * document.zoomLevel)
        )

        initialZoomLevel = document.zoomLevel

    }

    internal func actualSize(geometry: GeometryProxy) {
        let newZoomLevel: Double = 1.0

        let rulerThickness: CGFloat = 20
        let rulerOffset = document.showRulers ? rulerThickness : 0

        let viewSize = geometry.size
        let rulerBorderCompensationY: CGFloat = document.showRulers ? 0.5 : 0.0
        let visibleCenter = CGPoint(
            x: (viewSize.width - rulerOffset) / 2.0 + rulerOffset,
            y: (viewSize.height - rulerOffset) / 2.0 + rulerOffset + rulerBorderCompensationY
        )

        let documentBounds = document.documentBounds
        let documentCenter = CGPoint(
            x: documentBounds.midX,
            y: documentBounds.midY
        )

        document.zoomLevel = newZoomLevel

        document.canvasOffset = CGPoint(
            x: visibleCenter.x - (documentCenter.x * CGFloat(newZoomLevel)),
            y: visibleCenter.y - (documentCenter.y * CGFloat(newZoomLevel))
        )

        initialZoomLevel = CGFloat(newZoomLevel)

    }

    internal func handleZoomAtPoint(newZoomLevel: CGFloat, focalPoint: CGPoint, geometry: GeometryProxy) {
        let oldZoomLevel = document.zoomLevel

        guard abs(newZoomLevel - oldZoomLevel) > 0.001 else { return }

        let preciseOldZoom = Double(oldZoomLevel)
        let preciseNewZoom = Double(newZoomLevel)
        let preciseFocalX = Double(focalPoint.x)
        let preciseFocalY = Double(focalPoint.y)
        let preciseOffsetX = Double(document.canvasOffset.x)
        let preciseOffsetY = Double(document.canvasOffset.y)

        let canvasPointAtFocus = CGPoint(
            x: (preciseFocalX - preciseOffsetX) / preciseOldZoom,
            y: (preciseFocalY - preciseOffsetY) / preciseOldZoom
        )

        document.zoomLevel = newZoomLevel

        let newOffset = CGPoint(
            x: preciseFocalX - (Double(canvasPointAtFocus.x) * preciseNewZoom),
            y: preciseFocalY - (Double(canvasPointAtFocus.y) * preciseNewZoom)
        )

        document.canvasOffset = newOffset

    }

    internal func handleSimplifiedZoom(newZoomLevel: CGFloat, geometry: GeometryProxy) {
        let oldZoomLevel = document.zoomLevel

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

        document.zoomLevel = newZoomLevel

        let newOffset = CGPoint(
            x: viewCenter.x - (documentCenter.x * newZoomLevel),
            y: viewCenter.y - (documentCenter.y * newZoomLevel)
        )

        document.canvasOffset = newOffset

    }
}
