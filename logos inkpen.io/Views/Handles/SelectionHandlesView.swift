
import SwiftUI
import AppKit

struct SelectionHandlesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    let isShiftPressed: Bool
    let isOptionPressed: Bool
    let isCommandPressed: Bool
    let dragPreviewDelta: CGPoint

    var body: some View {
        ZStack {
            ForEach(document.unifiedObjects.indices, id: \.self) { unifiedObjectIndex in
                let unifiedObject = document.unifiedObjects[unifiedObjectIndex]

                if case .shape(let groupShape) = unifiedObject.objectType, groupShape.isGroupContainer {
                    ForEach(groupShape.groupedShapes, id: \.id) { childShape in
                        if document.selectedObjectIDs.contains(childShape.id) {
                            renderHandlesForShape(childShape)
                        }
                    }
                }

                if document.selectedObjectIDs.contains(unifiedObject.id) {
                    switch unifiedObject.objectType {
                    case .shape(let shape):
                        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                        if !isBackgroundShape {
                            if document.currentTool == .warp {
                                EnvelopeHandles(
                                    document: document,
                                    shape: shape,
                                    zoomLevel: document.zoomLevel,
                                    canvasOffset: document.canvasOffset
                                )
                            } else if shape.isWarpObject {
                                PersistentWarpMarquee(
                                    document: document,
                                    shape: shape,
                                    zoomLevel: document.zoomLevel,
                                    canvasOffset: document.canvasOffset,
                                    isEnvelopeTool: false
                                )
                            } else {
                                if document.currentTool == .selection {
                                    if isCommandPressed {
                                        PathOutline(
                                            shape: shape,
                                            zoomLevel: document.zoomLevel,
                                            canvasOffset: document.canvasOffset
                                        )
                                    } else {
                                        TransformBoxHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: document.zoomLevel,
                                            canvasOffset: document.canvasOffset,
                                            isShiftPressed: isShiftPressed,
                                            transformOrigin: document.transformOrigin
                                        )
                                        .offset(x: dragPreviewDelta.x * document.zoomLevel,
                                                y: dragPreviewDelta.y * document.zoomLevel)
                                    }
                                } else if document.currentTool == .scale {
                                    ScaleHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.zoomLevel,
                                        canvasOffset: document.canvasOffset,
                                        isShiftPressed: isShiftPressed
                                    )
                                } else if document.currentTool == .rotate {
                                    RotateHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.zoomLevel,
                                        canvasOffset: document.canvasOffset,
                                        isShiftPressed: isShiftPressed
                                    )
                                } else if document.currentTool == .shear {
                                    ShearHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.zoomLevel,
                                        canvasOffset: document.canvasOffset,
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
            if document.currentTool == .warp {
                EnvelopeHandles(
                    document: document,
                    shape: shape,
                    zoomLevel: document.zoomLevel,
                    canvasOffset: document.canvasOffset
                )
            } else if shape.isWarpObject {
                PersistentWarpMarquee(
                    document: document,
                    shape: shape,
                    zoomLevel: document.zoomLevel,
                    canvasOffset: document.canvasOffset,
                    isEnvelopeTool: false
                )
            } else {
                if document.currentTool == .selection {
                    if isCommandPressed {
                        PathOutline(
                            shape: shape,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    } else {
                        TransformBoxHandles(
                            document: document,
                            shape: shape,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset,
                            isShiftPressed: isShiftPressed,
                            transformOrigin: document.transformOrigin
                        )
                        .offset(x: dragPreviewDelta.x * document.zoomLevel,
                                y: dragPreviewDelta.y * document.zoomLevel)
                    }
                } else if document.currentTool == .scale {
                    ScaleHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                } else if document.currentTool == .rotate {
                    RotateHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                } else if document.currentTool == .shear {
                    ShearHandles(
                        document: document,
                        shape: shape,
                        zoomLevel: document.zoomLevel,
                        canvasOffset: document.canvasOffset,
                        isShiftPressed: isShiftPressed
                    )
                }
            }
        }
    }
}