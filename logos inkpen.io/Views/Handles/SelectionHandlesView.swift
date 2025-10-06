//
//  LayerView+SelectionHandlesView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit

struct SelectionHandlesView: View {
    @ObservedObject var document: VectorDocument
    let geometry: GeometryProxy
    let isShiftPressed: Bool  // Passed from DrawingCanvas for transform tool constraints
    let isOptionPressed: Bool  // Passed from DrawingCanvas for path-based selection
    let isCommandPressed: Bool // When true, show red with white outline for selected shapes
    let dragPreviewDelta: CGPoint // Keep selection box in sync during 60fps preview
    
    var body: some View {
        ZStack {
            // Show different handles based on current tool using unified objects system
            ForEach(document.unifiedObjects.indices, id: \.self) { unifiedObjectIndex in
                let unifiedObject = document.unifiedObjects[unifiedObjectIndex]
                
                // Only show handles for selected objects
                if document.selectedObjectIDs.contains(unifiedObject.id) {
                    switch unifiedObject.objectType {
                    case .shape(let shape):
                        // Never show transform box for background shapes
                        let isBackgroundShape = (shape.name == "Canvas Background" || shape.name == "Pasteboard Background")
                        if !isBackgroundShape {
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
                                // Show different handles based on tool for regular shapes AND text objects
                                if document.currentTool == .selection {
                                    // Command key: show red with white outline instead of transform box
                                    if isCommandPressed {
                                        PathOutline(
                                            shape: shape,
                                            zoomLevel: document.zoomLevel,
                                            canvasOffset: document.canvasOffset
                                        )
                                    } else {
                                        // Arrow tool: Transform box with 8 handles + center (Illustrator-style)
                                        // Works for BOTH regular shapes AND text objects (isTextObject = true)
                                        TransformBoxHandles(
                                            document: document,
                                            shape: shape,
                                            zoomLevel: document.zoomLevel,
                                            canvasOffset: document.canvasOffset,
                                            isShiftPressed: isShiftPressed,
                                            transformOrigin: document.transformOrigin
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

                        // Text objects are handled as VectorShape with isTextObject = true
                        // and use the same TransformBoxHandles as regular shapes
                    }
                }
            }
        }
    }
}