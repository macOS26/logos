//
//  LayerView+SelectionHandlesView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import CoreGraphics

struct SelectionHandlesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    let isShiftPressed: Bool  // Passed from DrawingCanvas for transform tool constraints
    let isOptionPressed: Bool  // Passed from DrawingCanvas for path-based selection
    let isCommandPressed: Bool // When true, show red with white outline for selected shapes
    let dragPreviewDelta: CGPoint // Keep selection box in sync during 60fps preview
    
    var body: some View {
        ZStack {
            // Show different handles based on current tool
            ForEach(document.layers.indices, id: \.self) { layerIndex in
                let layer = document.layers[layerIndex]
                ForEach(layer.shapes.indices, id: \.self) { shapeIndex in
                    let shape = layer.shapes[shapeIndex]
                    // Never show transform box for background shapes
                    let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                    if document.selectedShapeIDs.contains(shape.id) && !isBackgroundShape {
                        // ENVELOPE TOOL: Always show active green envelope handles when using envelope tool
                        if document.currentTool == .warp {
                            EnvelopeHandles(
                                document: document,
                                shape: shape,
                                zoomLevel: document.zoomLevel,
                                canvasOffset: document.canvasOffset
                            )
                        } else if shape.isWarpObject {
                            // WARP OBJECT: Show blue marquee only when NOT using envelope tool
                            PersistentWarpMarquee(
                                document: document,
                                shape: shape,
                                zoomLevel: document.zoomLevel,
                                canvasOffset: document.canvasOffset,
                                isEnvelopeTool: false
                            )
                        } else {
                            // Show different handles based on tool for regular shapes
                            if document.currentTool == .selection {
                                // Command key: show red with white outline instead of transform box
                                if isCommandPressed {
                                    PathOutline(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.zoomLevel,
                                        canvasOffset: document.canvasOffset
                                    )
                                } else {
                                    // Arrow tool: Transform box with 8 handles + center (Illustrator-style)
                                    TransformBoxHandles(
                                        document: document,
                                        shape: shape,
                                        zoomLevel: document.zoomLevel,
                                        canvasOffset: document.canvasOffset,
                                        isShiftPressed: isShiftPressed
                                    )
                                    // Keep the selection bounds visually in sync with object preview movement
                                    .offset(x: dragPreviewDelta.x * document.zoomLevel,
                                            y: dragPreviewDelta.y * document.zoomLevel)
                                }
                            } else if document.currentTool == .scale {
                                // Scale tool: Only corner scaling handles
                                ScaleHandles(
                                    document: document,
                                    shape: shape,
                                    zoomLevel: document.zoomLevel,
                                    canvasOffset: document.canvasOffset,
                                    isShiftPressed: isShiftPressed
                                )
                            } else if document.currentTool == .rotate {
                                // Rotate tool: Rotation handles with anchor point
                                RotateHandles(
                                    document: document,
                                    shape: shape,
                                    zoomLevel: document.zoomLevel,
                                    canvasOffset: document.canvasOffset,
                                    isShiftPressed: isShiftPressed
                                )
                            } else if document.currentTool == .shear {
                                // Shear tool: Shear handles with anchor point
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
            
            // Show handles for selected text objects (Professional Standards)
            ForEach(document.textObjects.indices, id: \.self) { textIndex in
                let textObject = document.textObjects[textIndex]
                if document.selectedTextIDs.contains(textObject.id) {
                    // Only keep transform handles for scale/rotate/shear tools since those need to work with text
                    if document.currentTool == .scale {
                        // Scale tool: Text scaling handles
                        TextScaleHandles(
                            document: document,
                            textObject: textObject,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    } else if document.currentTool == .rotate {
                        // Rotate tool: Text rotation handles
                        TextRotateHandles(
                            document: document,
                            textObject: textObject,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    } else if document.currentTool == .shear {
                        // Shear tool: Text shear handles
                        TextShearHandles(
                            document: document,
                            textObject: textObject,
                            zoomLevel: document.zoomLevel,
                            canvasOffset: document.canvasOffset
                        )
                    }
                }
            }
        }
    }
}
