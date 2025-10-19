import SwiftUI
import AppKit

struct SelectionHandlesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    let isShiftPressed: Bool
    let isOptionPressed: Bool
    let isCommandPressed: Bool
    let isTemporarySelectionViaCommand: Bool
    let dragPreviewDelta: CGPoint
    @Binding var liveScaleTransform: CGAffineTransform
    var body: some View {
        ZStack {
            ForEach(document.unifiedObjects.indices, id: \.self) { unifiedObjectIndex in
                let unifiedObject = document.unifiedObjects[unifiedObjectIndex]

                if case .group(let groupShape) = unifiedObject.objectType {
                    ForEach(groupShape.groupedShapes, id: \.id) { childShape in
                        if document.viewState.selectedObjectIDs.contains(childShape.id) {
                            renderHandlesForShape(childShape)
                        }
                    }
                }

                if document.viewState.selectedObjectIDs.contains(unifiedObject.id) {
                    switch unifiedObject.objectType {
                    case .shape(let shape),
                         .warp(let shape),
                         .group(let shape),
                         .clipGroup(let shape),
                         .clipMask(let shape),
                         .text(let shape):
                        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                        if !isBackgroundShape {
                            if document.viewState.currentTool == .warp {
                                EnvelopeHandles(
                                    document: document,
                                    shape: shape,
                                    zoomLevel: document.viewState.zoomLevel,
                                    canvasOffset: document.viewState.canvasOffset
                                )
                            } else if shape.isWarpObject {
                                PersistentWarpMarquee(
                                    document: document,
                                    shape: shape,
                                    zoomLevel: document.viewState.zoomLevel,
                                    canvasOffset: document.viewState.canvasOffset,
                                    isEnvelopeTool: false
                                )
                            } else {
                                let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                                         .circle, .ellipse, .oval, .egg, .cone,
                                                         .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                                         .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)

                                if (document.viewState.currentTool == .selection || isShapeDrawingTool) && dragPreviewDelta == .zero {
                                    TransformBoxHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.viewState.zoomLevel,
                                        canvasOffset: document.viewState.canvasOffset,
                                        isShiftPressed: isShiftPressed,
                                        transformOrigin: document.viewState.transformOrigin,
                                        strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5)
                                    )
                                } else if document.viewState.currentTool == .scale {
                                    ScaleHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.viewState.zoomLevel,
                                        canvasOffset: document.viewState.canvasOffset,
                                        isShiftPressed: isShiftPressed,
                                        liveScaleTransform: $liveScaleTransform
                                    )
                                } else if document.viewState.currentTool == .rotate {
                                    RotateHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.viewState.zoomLevel,
                                        canvasOffset: document.viewState.canvasOffset,
                                        isShiftPressed: isShiftPressed
                                    )
                                } else if document.viewState.currentTool == .shear {
                                    ShearHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.viewState.zoomLevel,
                                        canvasOffset: document.viewState.canvasOffset,
                                        isShiftPressed: isShiftPressed
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderHandlesForShape(_ shape: VectorShape) -> some View {
        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
        if !isBackgroundShape {
            if document.viewState.currentTool == .warp {
                EnvelopeHandles(
                    document: document,
                    shape: shape,
                    zoomLevel: document.viewState.zoomLevel,
                    canvasOffset: document.viewState.canvasOffset
                )
            } else if shape.isWarpObject {
                PersistentWarpMarquee(
                    document: document,
                    shape: shape,
                    zoomLevel: document.viewState.zoomLevel,
                    canvasOffset: document.viewState.canvasOffset,
                    isEnvelopeTool: false
                )
            } else {
                let isShapeDrawingTool = [.rectangle, .square, .roundedRectangle, .pill,
                                         .circle, .ellipse, .oval, .egg, .cone,
                                         .equilateralTriangle, .rightTriangle, .acuteTriangle, .isoscelesTriangle,
                                         .star, .polygon, .pentagon, .hexagon, .heptagon, .octagon, .nonagon].contains(document.viewState.currentTool)

                if (document.viewState.currentTool == .selection || isShapeDrawingTool) && dragPreviewDelta == .zero {
                    TransformBoxHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: document.viewState.zoomLevel,
                        canvasOffset: document.viewState.canvasOffset,
                        isShiftPressed: isShiftPressed,
                        transformOrigin: document.viewState.transformOrigin,
                        strokeColor: isTemporarySelectionViaCommand ? Color.red : Color.black.opacity(0.5)
                    )
                } else if document.viewState.currentTool == .scale {
                    ScaleHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: document.viewState.zoomLevel,
                        canvasOffset: document.viewState.canvasOffset,
                        isShiftPressed: isShiftPressed,
                        liveScaleTransform: $liveScaleTransform
                    )
                } else if document.viewState.currentTool == .rotate {
                    RotateHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: document.viewState.zoomLevel,
                        canvasOffset: document.viewState.canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                } else if document.viewState.currentTool == .shear {
                    ShearHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: document.viewState.zoomLevel,
                        canvasOffset: document.viewState.canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                }
            }
        }
    }
}
