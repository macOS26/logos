//
//  TextScaleHandles.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import CoreGraphics
import SwiftUI

// MARK: - Text Selection Views

// REMOVED: Legacy TextSelectionOutline view that was causing wrong blue boxes
// This view used old bounds calculations that didn't handle multi-line text properly
// ProfessionalTextCanvas now handles all text selection visualization correctly

// Scale handles for text objects with Scale tool
struct TextScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    private let handleSize: CGFloat = 8
    
    var body: some View {
        // SIMPLIFIED: Use text object position and bounds directly (no legacy calculation)
        let bounds = textObject.bounds
        let absoluteBounds = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: bounds.width,
            height: bounds.height
        )
        let center = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)
        
        ZStack {
            // Text bounding box outline (red for scale tool)
            Rectangle()
                .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                .frame(width: absoluteBounds.width, height: absoluteBounds.height)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)
            
            // 4 Corner scaling handles ONLY (simplified for now)
            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: absoluteBounds, center: center)
                Rectangle()
                    .fill(Color.red)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(textObject.transform)
                // TODO: Add text scaling gesture handling
            }
        }
    }
    
    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY) // Top-left
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY) // Top-right
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY) // Bottom-right
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY) // Bottom-left
        default: return center
        }
    }
}

