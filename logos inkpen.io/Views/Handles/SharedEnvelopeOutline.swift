//
//  SharedEnvelopeOutline.swift
//  logos inkpen.io
//
//  Shared envelope outline drawing for both warp and selection tools
//

import SwiftUI

struct SharedEnvelopeOutline: View {
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let color: Color
    let lineWidth: Double
    let isDashed: Bool

    var body: some View {
        if shape.isWarpObject && shape.warpEnvelope.count >= 4 {
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
                color,
                style: isDashed ?
                    SwiftUI.StrokeStyle(
                        lineWidth: lineWidth / zoomLevel,
                        dash: [6.0 / zoomLevel, 4.0 / zoomLevel]
                    ) :
                    SwiftUI.StrokeStyle(lineWidth: lineWidth / zoomLevel)
            )
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
        }
    }
}

struct SharedEnvelopeCorners: View {
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let handleSize: CGFloat
    let handleColor: Color

    var body: some View {
        if shape.isWarpObject && shape.warpEnvelope.count >= 4 {
            ForEach(0..<4) { cornerIndex in
                let cornerPos = shape.warpEnvelope[cornerIndex]

                Rectangle()
                    .fill(handleColor)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize, height: handleSize)
                    .position(CGPoint(
                        x: cornerPos.x * zoomLevel + canvasOffset.x,
                        y: cornerPos.y * zoomLevel + canvasOffset.y
                    ))
            }
        }
    }
}