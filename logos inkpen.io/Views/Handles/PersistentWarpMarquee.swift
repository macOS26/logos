//
//  PersistentWarpMarquee.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import SwiftUI
import SwiftUI

// MARK: - Persistent Warp Marquee (Always Visible for Warp Objects)
struct PersistentWarpMarquee: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isEnvelopeTool: Bool
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        ZStack {
            // BLUE WARP MARQUEE: Always visible for warp objects
            if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                // Draw the blue envelope marquee lines
                warpEnvelopeOutline()
                
                // Show corner handles only when envelope tool is active
                if isEnvelopeTool {
                    warpCornerHandles()
                } else {
                    // Show small blue dots when not using envelope tool
                    warpCornerDots()
                    
                    // ARROW TOOL: Show warp grid in darker blue
                    if document.currentTool == .selection {
                        warpGridOverlay()
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func warpEnvelopeOutline() -> some View {
        // Draw the blue dashed envelope outline connecting the 4 corners
        if shape.warpEnvelope.count >= 4 {
            let corners = shape.warpEnvelope
            
            Path { path in
                // Connect all 4 corners to form the envelope quadrilateral
                path.move(to: corners[0])        // Top-left
                path.addLine(to: corners[1])     // Top-right
                path.addLine(to: corners[2])     // Bottom-right
                path.addLine(to: corners[3])     // Bottom-left
                path.closeSubpath()              // Back to top-left
            }
            .stroke(
                Color.blue,
                style: SwiftUI.StrokeStyle(
                    lineWidth: 2.0 / zoomLevel,
                    dash: [6.0 / zoomLevel, 4.0 / zoomLevel]
                )
            )
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(shape.transform)
        }
    }
    
    @ViewBuilder
    private func warpCornerHandles() -> some View {
        // Full envelope handles when using envelope tool
        if shape.warpEnvelope.count >= 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = shape.warpEnvelope[cornerIndex]
                
                Rectangle()
                    .fill(Color.green)  // GREEN = warpable
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(cornerPos)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
        }
    }
    
    @ViewBuilder
    private func warpCornerDots() -> some View {
        // Small blue dots when not using envelope tool
        if shape.warpEnvelope.count >= 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = shape.warpEnvelope[cornerIndex]
                
                Circle()
                    .fill(Color.blue)
                    .frame(width: 4.0 / zoomLevel, height: 4.0 / zoomLevel)
                    .position(cornerPos)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(shape.transform)
            }
        }
    }
    
    @ViewBuilder
    private func warpGridOverlay() -> some View {
        // Show darker blue warp grid for arrow tool selection
        if shape.warpEnvelope.count >= 4 {
            let gridLines = 4
            let corners = shape.warpEnvelope
            
            // Horizontal grid lines
            ForEach(0..<4) { row in
                let t = CGFloat(row) / CGFloat(gridLines - 1)
                Path { path in
                    let startPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: 0.0, v: t
                    )
                    let endPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: 1.0, v: t
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .opacity(0.8) // Darker blue for completed warp
            }
            
            // Vertical grid lines
            ForEach(0..<4) { col in
                let u = CGFloat(col) / CGFloat(gridLines - 1)
                Path { path in
                    let startPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: u, v: 0.0
                    )
                    let endPoint = bilinearInterpolation(
                        topLeft: corners[0],
                        topRight: corners[1],
                        bottomLeft: corners[3],
                        bottomRight: corners[2],
                        u: u, v: 1.0
                    )
                    path.move(to: startPoint)
                    path.addLine(to: endPoint)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [2.0 / zoomLevel, 2.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(shape.transform)
                .opacity(0.8) // Darker blue for completed warp
            }
        }
    }
    
    // MARK: - Bilinear Interpolation Helper
    
    private func bilinearInterpolation(topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint, u: CGFloat, v: CGFloat) -> CGPoint {
        // Standard bilinear interpolation formula
        let top = CGPoint(
            x: topLeft.x * (1 - u) + topRight.x * u,
            y: topLeft.y * (1 - u) + topRight.y * u
        )
        let bottom = CGPoint(
            x: bottomLeft.x * (1 - u) + bottomRight.x * u,
            y: bottomLeft.y * (1 - u) + bottomRight.y * u
        )
        
        return CGPoint(
            x: top.x * (1 - v) + bottom.x * v,
            y: top.y * (1 - v) + bottom.y * v
        )
    }
}

