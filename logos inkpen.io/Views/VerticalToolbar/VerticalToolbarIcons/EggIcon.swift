//
//  EggIcon.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/22/25.
//

import Foundation
import SwiftUI

struct EggIcon: View {
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            // Create a proper egg shape using simple 4-curve approach
            let center = CGPoint(x: 10, y: 10)
            let radiusX: CGFloat = 4 + IconStrokeExpand
            let radiusY: CGFloat = 6 + IconStrokeExpand
            
            // SIMPLE EGG FORMULA: Use standard ellipse with vertical offset
            // The narrow end should be rounded, not pointed
            let eggOffset = radiusY * 0.3  // Vertical offset to create egg asymmetry
            
            // Use standard ellipse control points (0.552) for smooth curves
            let controlPointOffsetX = radiusX * 0.552
            let controlPointOffsetY = radiusY * 0.552
            
            // Start at rightmost point
            path.move(to: CGPoint(x: center.x + radiusX, y: center.y))
            
            // Curve 1: Right → Top (wider end)
            path.addCurve(
                to: CGPoint(x: center.x, y: center.y - radiusY - eggOffset),
                control1: CGPoint(x: center.x + radiusX, y: center.y - controlPointOffsetY),
                control2: CGPoint(x: center.x + controlPointOffsetX, y: center.y - radiusY - eggOffset)
            )
            
            // Curve 2: Top → Left (wider end)
            path.addCurve(
                to: CGPoint(x: center.x - radiusX, y: center.y),
                control1: CGPoint(x: center.x - controlPointOffsetX, y: center.y - radiusY - eggOffset),
                control2: CGPoint(x: center.x - radiusX, y: center.y - controlPointOffsetY)
            )
            
            // Curve 3: Left → Bottom (narrower end)
            path.addCurve(
                to: CGPoint(x: center.x, y: center.y + radiusY - eggOffset),
                control1: CGPoint(x: center.x - radiusX, y: center.y + controlPointOffsetY),
                control2: CGPoint(x: center.x - controlPointOffsetX, y: center.y + radiusY - eggOffset)
            )
            
            // Curve 4: Bottom → Right (narrower end)
            path.addCurve(
                to: CGPoint(x: center.x + radiusX, y: center.y),
                control1: CGPoint(x: center.x + controlPointOffsetX, y: center.y + radiusY - eggOffset),
                control2: CGPoint(x: center.x + radiusX, y: center.y + controlPointOffsetY)
            )
            
            path.closeSubpath()
        }
        .stroke(Color.primary, lineWidth: IconStrokeWidth)
        .frame(width: 20, height: 20)
    }
}
