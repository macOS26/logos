import SwiftUI
import AppKit

struct SelectionHandlesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isShiftPressed: Bool
    let isOptionPressed: Bool
    let isCommandPressed: Bool
    let isTemporarySelectionViaCommand: Bool
    let dragPreviewDelta: CGPoint
    @Binding var liveScaleTransform: CGAffineTransform
    @Binding var liveScaleDimensions: CGSize

    // Force view to update when selection changes
    private var selectionID: String {
        document.viewState.selectedObjectIDs.map { $0.uuidString }.sorted().joined()
    }

    var body: some View {
        ZStack {
            // Only render if there are selected objects
            if !document.viewState.selectedObjectIDs.isEmpty {
                // For multi-selection, show ONE combined bounding box
                if document.viewState.selectedObjectIDs.count > 1 {
                    renderCombinedSelectionBox()
                } else {
                    // Single selection - render individual handles
                    ForEach(Array(document.viewState.selectedObjectIDs), id: \.self) { selectedID in
                        if let newVectorObject = document.snapshot.objects[selectedID] {
                            if case .group(let groupShape) = newVectorObject.objectType {
                                ForEach(groupShape.groupedShapes, id: \.id) { childShape in
                                    if document.viewState.selectedObjectIDs.contains(childShape.id) {
                                        renderHandlesForShape(childShape)
                                    }
                                }
                            }

                            switch newVectorObject.objectType {
                            case .shape(let shape),
                                 .image(let shape),
                                 .warp(let shape),
                                 .group(let shape),
                                 .clipGroup(let shape),
                                 .clipMask(let shape),
                                 .text(let shape):
                                let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                                if !isBackgroundShape {
                                    if document.viewState.currentTool == .warp && dragPreviewDelta == .zero {
                                        EnvelopeHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset
                                        )
                                    } else if shape.isWarpObject && dragPreviewDelta == .zero {
                                        PersistentWarpMarquee(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isEnvelopeTool: false
                                        )
                                    } else {
                                        let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                                                 .circle, .ellipse, .oval, .egg, .cone,
                                                                 .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                                                 .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)

                                        if (document.viewState.currentTool == .selection || document.viewState.currentTool == .font || isShapeDrawingTool) && dragPreviewDelta == .zero {
                                            TransformBoxHandles(
                                                document: document,
                                                shape: shape,
                                                zoomLevel: zoomLevel,
                                                canvasOffset: canvasOffset,
                                                isShiftPressed: isShiftPressed,
                                                transformOrigin: document.viewState.transformOrigin,
                                                strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5),
                                                liveScaleTransform: $liveScaleTransform,
                                                liveScaleDimensions: $liveScaleDimensions
                                            )
                                    } else if document.viewState.currentTool == .scale {
                                        ScaleHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isShiftPressed: isShiftPressed,
                                            liveScaleTransform: $liveScaleTransform,
                                            liveScaleDimensions: $liveScaleDimensions
                                        )
                                    } else if document.viewState.currentTool == .rotate {
                                        RotateHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isShiftPressed: isShiftPressed
                                        )
                                    } else if document.viewState.currentTool == .shear {
                                        ShearHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: zoomLevel,
                                            canvasOffset: canvasOffset,
                                            isShiftPressed: isShiftPressed
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                }  // Close else block for multi-selection check
            }
        }
        .id(selectionID) // Force re-render when selection changes
    }

    @ViewBuilder
    private func renderHandlesForShape(_ shape: VectorShape) -> some View {
        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
        if !isBackgroundShape {
            if document.viewState.currentTool == .warp && dragPreviewDelta == .zero {
                EnvelopeHandles(
                    document: document,
                    shape: shape,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset
                )
            } else if shape.isWarpObject && dragPreviewDelta == .zero {
                PersistentWarpMarquee(
                    document: document,
                    shape: shape,
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    isEnvelopeTool: false
                )
            } else {
                let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                         .circle, .ellipse, .oval, .egg, .cone,
                                         .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                         .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)

                if (document.viewState.currentTool == .selection || document.viewState.currentTool == .font || isShapeDrawingTool) && dragPreviewDelta == .zero {
                    TransformBoxHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed,
                        transformOrigin: document.viewState.transformOrigin,
                        strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5),
                        liveScaleTransform: $liveScaleTransform,
                        liveScaleDimensions: $liveScaleDimensions
                    )
                } else if document.viewState.currentTool == .scale {
                    ScaleHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed,
                        liveScaleTransform: $liveScaleTransform,
                        liveScaleDimensions: $liveScaleDimensions
                    )
                } else if document.viewState.currentTool == .rotate {
                    RotateHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                } else if document.viewState.currentTool == .shear {
                    ShearHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                }
            }
        }
    }

    // Computed property for combined selection bounds
    private var combinedSelectionBounds: CGRect? {
        var combinedBounds: CGRect?
        let settings = ApplicationSettings.shared

        for objectID in document.viewState.selectedObjectIDs {
            guard let object = document.snapshot.objects[objectID] else { continue }

            switch object.objectType {
            case .shape(let shape), .image(let shape), .warp(let shape), .group(let shape), .clipGroup(let shape), .clipMask(let shape), .text(let shape):
                var baseBounds = shape.isGroupContainer ? shape.groupBounds : shape.bounds

                // Apply stroke expansion if preference is enabled and shape has stroke
                if settings.boundingBoxIncludesStrokes && shape.strokeStyle != nil && shape.typography == nil {
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeExpansion = strokeWidth / 2.0
                    baseBounds = baseBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                }

                let transformedBounds = baseBounds.applying(shape.transform)

                if let existing = combinedBounds {
                    combinedBounds = existing.union(transformedBounds)
                } else {
                    combinedBounds = transformedBounds
                }
            }
        }

        return combinedBounds
    }

    private func createCombinedShape(from bounds: CGRect) -> VectorShape {
        var combinedShape = VectorShape(
            name: "Combined Selection",
            path: VectorPath(elements: [
                .move(to: VectorPoint(0, 0)),
                .line(to: VectorPoint(bounds.width, 0)),
                .line(to: VectorPoint(bounds.width, bounds.height)),
                .line(to: VectorPoint(0, bounds.height)),
                .close
            ], isClosed: true)
        )
        combinedShape.bounds = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        combinedShape.transform = CGAffineTransform(translationX: bounds.origin.x, y: bounds.origin.y)
        return combinedShape
    }

    @ViewBuilder
    private func renderCombinedSelectionBox() -> some View {
        if let bounds = combinedSelectionBounds {
            let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                     .circle, .ellipse, .oval, .egg, .cone,
                                     .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                     .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)

            if (document.viewState.currentTool == .selection || document.viewState.currentTool == .font || isShapeDrawingTool) && dragPreviewDelta == .zero {
                // Render TransformBoxHandles for the combined selection
                TransformBoxHandles(
                    document: document,
                    shape: createCombinedShape(from: bounds),
                    zoomLevel: zoomLevel,
                    canvasOffset: canvasOffset,
                    isShiftPressed: isShiftPressed,
                    transformOrigin: document.viewState.transformOrigin,
                    strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5),
                    liveScaleTransform: $liveScaleTransform,
                    liveScaleDimensions: $liveScaleDimensions
                )
            }
        }
    }
}
