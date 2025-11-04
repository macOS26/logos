import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct LayerView: View {
    @ObservedObject var document: VectorDocument
    let layerIndex: Int
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let selectedShapeIDs: Set<UUID>
    let viewMode: ViewMode
    let isShiftPressed: Bool
    let dragPreviewDelta: CGPoint
    let dragPreviewTrigger: Bool

    private var layer: Layer {
        document.snapshot.layers[layerIndex]
    }

    private var isCanvasLayer: Bool {
        return layer.name == "Canvas"
    }

    private var isPasteboardLayer: Bool {
        return layer.name == "Pasteboard"
    }

    var body: some View {
        let shapes = document.getShapesForLayer(layerIndex)
        return ZStack {
            ForEach(shapes, id: \.id) { currentShape in
                if currentShape.isClippingPath {
                    EmptyView()
                } else if let clipID = currentShape.clippedByShapeID, let maskShape = document.findShape(by: clipID) {
                    let clippedPath = createPreTransformedPath(for: currentShape)
                    let maskPath = createPreTransformedPath(for: maskShape)

                    ClippingMaskShapeView(
                        clippedShape: currentShape,
                        maskShape: maskShape,
                        clippedPath: clippedPath,
                        maskPath: maskPath,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isSelected: selectedShapeIDs.contains(currentShape.id) || selectedShapeIDs.contains(maskShape.id),
                        dragPreviewDelta: (selectedShapeIDs.contains(currentShape.id) || selectedShapeIDs.contains(maskShape.id)) ? dragPreviewDelta : .zero,
                        dragPreviewTrigger: dragPreviewTrigger,
                        viewMode: viewMode
                    )
                } else {
                    ZStack {
                        ShapeView(
                            shape: currentShape,
                            zoomLevel: zoomLevel,
                            canvasOffset: canvasOffset,
                            isSelected: selectedShapeIDs.contains(currentShape.id),
                            viewMode: viewMode,
                            isCanvasLayer: isCanvasLayer,
                            isPasteboardLayer: isPasteboardLayer,
                            dragPreviewDelta: dragPreviewDelta,
                            dragPreviewTrigger: dragPreviewTrigger,
                            liveScaleTransform: .identity,
                            liveGradientOriginX: nil,
                            liveGradientOriginY: nil
                        )

                        // Only show NSTextView when editing (blue mode)
                        // When selected (green) or unselected (gray), render on Canvas
                        if currentShape.textContent != nil, currentShape.typography != nil, currentShape.isEditing == true {
                            ProfessionalTextCanvas(
                                document: document,
                                textObjectID: currentShape.id,
                                dragPreviewDelta: dragPreviewDelta,
                                dragPreviewTrigger: dragPreviewTrigger,
                                viewMode: viewMode
                            )
                            .allowsHitTesting(document.viewState.currentTool == .font)
                        }
                    }
                }
            }
        }
        .opacity(layer.opacity)
    }

    private func createPreTransformedPath(for shape: VectorShape) -> CGPath {
        let path = CGMutablePath()

        for element in shape.path.elements {
            switch element {
            case .move(let to, _):
                path.move(to: to.cgPoint)
            case .line(let to, _):
                path.addLine(to: to.cgPoint)
            case .curve(let to, let control1, let control2, _):
                path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
            case .quadCurve(let to, let control, _):
                path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
            case .close:
                path.closeSubpath()
            }
        }

        if !shape.transform.isIdentity {
            let transformedPath = CGMutablePath()
            transformedPath.addPath(path, transform: shape.transform)
            return transformedPath
        }

        return path
    }
}