import SwiftUI
import AppKit

import MetalKit

extension DrawingCanvas {

//    @ViewBuilder
//    internal func optionalMetalAcceleratedOverlay(geometry: GeometryProxy) -> some View {
//        SafeMetalView(performanceMonitor: metalPerformanceMonitor) { cgContext, size in
//            renderCanvasWithMetal(cgContext: cgContext, size: size, geometry: geometry)
//            if let preview = brushPreviewPath {
//                cgContext.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
//                cgContext.setStrokeColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0))
//                let cgPath = CGMutablePath()
//                for e in preview.elements {
//                    switch e {
//                    case .move(let to):
//                        cgPath.move(to: transformPointToView(to.cgPoint, geometry: geometry))
//                    case .line(let to):
//                        cgPath.addLine(to: transformPointToView(to.cgPoint, geometry: geometry))
//                    case .curve(let to, let c1, let c2):
//                        cgPath.addCurve(to: transformPointToView(to.cgPoint, geometry: geometry),
//                                        control1: transformPointToView(c1.cgPoint, geometry: geometry),
//                                        control2: transformPointToView(c2.cgPoint, geometry: geometry))
//                    case .quadCurve(let to, let c):
//                        cgPath.addQuadCurve(to: transformPointToView(to.cgPoint, geometry: geometry),
//                                            control: transformPointToView(c.cgPoint, geometry: geometry))
//                    case .close:
//                        if !cgPath.isEmpty {
//                            cgPath.closeSubpath()
//                        }
//                    }
//                }
//                cgContext.addPath(cgPath)
//                cgContext.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.0))
//                cgContext.fillPath()
//            }
//        }
//        .allowsHitTesting(true)
//    }

    private func renderCanvasWithMetal(cgContext: CGContext, size: CGSize, geometry: GeometryProxy) {

        if document.gridSettings.snapToGrid {
            renderGridWithMetal(cgContext: cgContext, size: size, geometry: geometry)
        }

        if let currentPath = currentPath, isDrawing {
            renderCurrentPathWithMetal(cgContext: cgContext, path: currentPath, geometry: geometry)
        }

        if !document.viewState.selectedObjectIDs.isEmpty {
            renderSelectionOverlaysWithMetal(cgContext: cgContext, geometry: geometry)
        }

        if document.gridSettings.snapToPoint, let snapPoint = currentSnapPoint {
            let mouseLocation = currentMouseLocation ?? bezierPoints.last?.cgPoint ?? .zero
            let mousePointView = transformPointToView(mouseLocation, geometry: geometry)
            let snapPointView = transformPointToView(snapPoint, geometry: geometry)
            drawSnapPointFeedback(in: cgContext, at: mousePointView, snapPointView: snapPointView)
        }
    }

    private func renderGridWithMetal(cgContext: CGContext, size: CGSize, geometry: GeometryProxy) {
        let gridSpacing: CGFloat = 20 * zoomLevel
        let offset = canvasOffset

        cgContext.setStrokeColor(CGColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5))
        cgContext.setLineWidth(0.5)

        var x: CGFloat = fmod(offset.x, gridSpacing)
        while x < size.width {
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: size.height))
            x += gridSpacing
        }

        var y: CGFloat = fmod(offset.y, gridSpacing)
        while y < size.height {
            cgContext.move(to: CGPoint(x: 0, y: y))
            cgContext.addLine(to: CGPoint(x: size.width, y: y))
            y += gridSpacing
        }

        cgContext.strokePath()
    }

    private func renderCurrentPathWithMetal(cgContext: CGContext, path: VectorPath, geometry: GeometryProxy) {
        cgContext.setStrokeColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.8))
        cgContext.setLineWidth(2.0)

        let cgPath = CGMutablePath()
        for element in path.elements {
            switch element {
            case .move(let to):
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.move(to: transformedPoint)
            case .line(let to):
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.addLine(to: transformedPoint)
            case .curve(let to, let control1, let control2):
                let transformedCP1 = transformPointToView(control1.cgPoint, geometry: geometry)
                let transformedCP2 = transformPointToView(control2.cgPoint, geometry: geometry)
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.addCurve(to: transformedPoint, control1: transformedCP1, control2: transformedCP2)
            case .quadCurve(let to, let control):
                let transformedControl = transformPointToView(control.cgPoint, geometry: geometry)
                let transformedPoint = transformPointToView(to.cgPoint, geometry: geometry)
                cgPath.addQuadCurve(to: transformedPoint, control: transformedControl)
            case .close:
                if !cgPath.isEmpty {
                    cgPath.closeSubpath()
                }
            }
        }

        cgContext.addPath(cgPath)
        cgContext.strokePath()
    }

    private func renderSelectionOverlaysWithMetal(cgContext: CGContext, geometry: GeometryProxy) {
        cgContext.setFillColor(CGColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 0.1))

        for shapeID in document.viewState.selectedObjectIDs {
            if let shape = findShape(by: shapeID) {
                let bounds = shape.bounds
                let transformedBounds = transformRectToView(bounds, geometry: geometry)
                cgContext.fill(transformedBounds)
            }
        }
    }

    private func transformPointToView(_ point: CGPoint, geometry: GeometryProxy) -> CGPoint {
        return CGPoint(
            x: point.x * zoomLevel + canvasOffset.x,
            y: point.y * zoomLevel + canvasOffset.y
        )
    }

    private func transformRectToView(_ rect: CGRect, geometry: GeometryProxy) -> CGRect {
        return CGRect(
            x: rect.origin.x * zoomLevel + canvasOffset.x,
            y: rect.origin.y * zoomLevel + canvasOffset.y,
            width: rect.width * zoomLevel,
            height: rect.height * zoomLevel
        )
    }

    private func findShape(by id: UUID) -> VectorShape? {
        for unifiedObject in document.snapshot.objects.values {
            if case .shape(let shape) = unifiedObject.objectType,
               shape.id == id {
                return shape
            }
        }
        return nil
    }
}

//extension DrawingCanvas {
//    @ViewBuilder
//    private func performanceOverlay() -> some View {
//        IsolatedPerformanceOverlay(
//            monitor: metalPerformanceMonitor,
//            document: document
//        )
//    }
//
//    private func countActiveDrawElements() -> Int {
//        var count = 0
//
//        count += document.snapshot.objects.values.compactMap { unifiedObject -> VectorShape? in
//            if case .shape(let shape) = unifiedObject.objectType {
//                return shape.isVisible ? shape : nil
//            }
//            return nil
//        }.count
//
//        count += document.snapshot.objects.values.filter { unifiedObject in
//            if case .text(let shape) = unifiedObject.objectType {
//                return shape.isVisible
//            }
//            return false
//        }.count
//
//        if currentPath != nil && isDrawing {
//            count += 1
//        }
//
//        if !document.viewState.selectedObjectIDs.isEmpty {
//            count += document.viewState.selectedObjectIDs.count * 8
//        }
//
//        return count
//    }
//}

extension DrawingCanvas {

    @ViewBuilder
    internal func enhancedCanvasMainContent(geometry: GeometryProxy) -> some View {
        ZStack {
            //optionalMetalAcceleratedOverlay(geometry: geometry)

            canvasBaseContent(geometry: geometry, imagePreviewQuality: imagePreviewQuality, imageTileSize: imageTileSize)

            pressureSensitiveOverlay(geometry: geometry)

            CanvasCursorOverlayView(
                isHovering: isCanvasHovering,
                currentTool: document.viewState.currentTool,
                isPanActive: isPanGestureActive,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
            )

//            if appState.showPerformanceOverlay {
//                performanceOverlay()
//            }
        }
        .onAppear {
            setupCanvas()
            previousTool = document.viewState.currentTool
        }
        .onDisappear {
            // teardownKeyEventMonitoring()
        }
        .onChange(of: document.viewState.currentTool) { oldTool, newTool in
            handleToolChange(oldTool: oldTool, newTool: newTool)
            if isCanvasHovering {
                if newTool == .hand {
                    HandOpenCursor.set()
                } else if newTool == .eyedropper {
                    EyedropperCursor.set()
                } else if newTool == .selectSameColor {
                    EyedropperCursor.set()
                } else if newTool == .zoom {
                    MagnifyingGlassCursor.set()
                } else if newTool == .rectangle || newTool == .square || newTool == .circle || newTool == .equilateralTriangle || newTool == .isoscelesTriangle || newTool == .rightTriangle || newTool == .acuteTriangle || newTool == .cone || newTool == .polygon || newTool == .pentagon || newTool == .hexagon || newTool == .heptagon || newTool == .octagon || newTool == .nonagon {
                    CrosshairCursor.set()
                } else {
                    NSCursor.arrow.set()
                }
            }
        }
        .onHover { isHovering in
            isCanvasHovering = isHovering
            if isHovering {
                if document.viewState.currentTool == .hand {
                    HandOpenCursor.set()
                } else if document.viewState.currentTool == .eyedropper {
                    EyedropperCursor.set()
                } else if document.viewState.currentTool == .selectSameColor {
                    EyedropperCursor.set()
                } else if document.viewState.currentTool == .zoom {
                    MagnifyingGlassCursor.set()
                } else if document.viewState.currentTool == .rectangle || document.viewState.currentTool == .square || document.viewState.currentTool == .circle || document.viewState.currentTool == .equilateralTriangle || document.viewState.currentTool == .isoscelesTriangle || document.viewState.currentTool == .rightTriangle || document.viewState.currentTool == .acuteTriangle || document.viewState.currentTool == .cone || document.viewState.currentTool == .polygon || document.viewState.currentTool == .pentagon || document.viewState.currentTool == .hexagon || document.viewState.currentTool == .heptagon || document.viewState.currentTool == .octagon || document.viewState.currentTool == .nonagon {
                    CrosshairCursor.set()
                }
            } else {
                NSCursor.arrow.set()
            }
        }
        .onContinuousHover { phase in
            handleHover(phase: phase, geometry: geometry)
            if isCanvasHovering && document.viewState.currentTool == .zoom {
                MagnifyingGlassCursor.set()
            }
        }
        .onTapGesture { location in
            handleUnifiedTap(at: location, geometry: geometry)
            let pointInView = location
            let insideCanvas = pointInView.x >= 0 && pointInView.y >= 0 &&
                pointInView.x <= geometry.size.width && pointInView.y <= geometry.size.height
            if insideCanvas || isCanvasHovering {
                switch document.viewState.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .selectSameColor:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    CrosshairCursor.set()
                default:
                    NSCursor.arrow.set()
                }
                DispatchQueue.main.async {
                    if (insideCanvas || self.isCanvasHovering) {
                        switch self.document.viewState.currentTool {
                        case .hand:
                            HandOpenCursor.set()
                        case .eyedropper:
                            EyedropperCursor.set()
                        case .zoom:
                            MagnifyingGlassCursor.set()
                        case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                            CrosshairCursor.set()
                        default:
                            NSCursor.arrow.set()
                        }
                    }
                }
            }
        }
        .onTapGesture { location in
            handleUnifiedTap(at: location, geometry: geometry)
        }
        .simultaneousGesture(
            document.viewState.currentTool != .gradient && document.viewState.currentTool != .cornerRadius ?
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    handleUnifiedDragChanged(value: value, geometry: geometry)
                }
                .onEnded { value in
                    handleUnifiedDragEnded(value: value, geometry: geometry)
                } : nil
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    handleZoomGestureChanged(value: value, geometry: geometry)
                }
                .onEnded { value in
                    handleZoomGestureEnded(value: value, geometry: geometry)
                }
        )
        .onChange(of: document.viewState.zoomRequest) {
            if let request = document.viewState.zoomRequest {
                handleZoomRequest(request, geometry: geometry)
            }
        }
        .onChange(of: zoomLevel) { _, _ in
            if isCanvasHovering {
                switch document.viewState.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .selectSameColor:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    CrosshairCursor.set()
                default:
                    break
                }
                DispatchQueue.main.async {
                    if self.isCanvasHovering {
                        switch self.document.viewState.currentTool {
                        case .hand:
                            HandOpenCursor.set()
                        case .eyedropper:
                            EyedropperCursor.set()
                        case .zoom:
                            MagnifyingGlassCursor.set()
                        case .rectangle, .square, .circle, .equilateralTriangle, .isoscelesTriangle, .rightTriangle, .acuteTriangle, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                            CrosshairCursor.set()
                        default:
                            break
                        }
                    }
                }
            }
        }
        .onChange(of: canvasOffset) { _, _ in
            if isCanvasHovering {
                switch document.viewState.currentTool {
                case .hand:
                    HandOpenCursor.set()
                case .eyedropper:
                    EyedropperCursor.set()
                case .selectSameColor:
                    EyedropperCursor.set()
                case .zoom:
                    MagnifyingGlassCursor.set()
                case .square, .circle, .equilateralTriangle, .cone, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon:
                    NSCursor.crosshair.set()
                default:
                    break
                }
            }
        }
        .contextMenu {
            directSelectionContextMenu
        }
    }
}

//// Simple performance overlay using Canvas for no SwiftUI interference
//private struct IsolatedPerformanceOverlay: View {
//   // var monitor: PerformanceMonitor
//    let document: VectorDocument
//
//    var body: some View {
//        TimelineView(.animation(minimumInterval: 0.5)) { _ in
//            Canvas { context, size in
//                let totalObjects = document.snapshot.objects.values.count
//                let visibleLayers = document.layers.filter { $0.isVisible }.count
//
//                let padding: CGFloat = 16
//                let boxPadding: CGFloat = 8
//                let lineHeight: CGFloat = 14
//                let fontSize: CGFloat = 10
//
//                let texts = [
//                    "FPS: \(Int(monitor.fps))",
//                    "\(monitor.renderingMode)",
//                    "Device: \(monitor.metalDeviceName)",
//                    "Memory: \(String(format: "%.1f", monitor.memoryUsage)) MB",
//                    "Objects: \(totalObjects)",
//                    "Layers: \(visibleLayers)/\(document.layers.count)"
//                ]
//
//                let boxWidth: CGFloat = 200
//                let boxHeight = CGFloat(texts.count) * lineHeight + boxPadding * 2
//
//                // Draw background box
//                let boxRect = CGRect(x: padding, y: padding, width: boxWidth, height: boxHeight)
//                context.fill(Path(roundedRect: boxRect, cornerRadius: 6), with: .color(.black.opacity(0.75)))
//
//                // Draw text
//                for (index, text) in texts.enumerated() {
//                    let yPos = padding + boxPadding + CGFloat(index) * lineHeight
//                    context.draw(Text(text)
//                        .font(.system(size: fontSize, design: .monospaced))
//                        .foregroundColor(.green),
//                        at: CGPoint(x: padding + boxPadding, y: yPos),
//                        anchor: .topLeading)
//                }
//            }
//            .allowsHitTesting(false)
//        }
//    }
//}
