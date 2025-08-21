//
//  TextShearHandles.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/20/25.
//

import CoreGraphics
import SwiftUI

struct TextShearHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
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
        
        Rectangle()
            .stroke(Color.purple, lineWidth: 1.0 / zoomLevel)
            .frame(width: absoluteBounds.width, height: absoluteBounds.height)
            .position(center)
            .scaleEffect(zoomLevel, anchor: .topLeading)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .transformEffect(textObject.transform)
    }
}
