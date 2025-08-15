//
//  GridView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

struct GridView: View {
    let document: VectorDocument
    let geometry: GeometryProxy
    
    var body: some View {
        let gridSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit
        let canvasSize = document.settings.sizeInPoints
        
        // Prevent infinite loop when grid spacing is 0
        if gridSpacing > 0 {
        Path { path in
            // UNIFIED COORDINATE SYSTEM: Draw grid in canvas space then transform
            let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1
            
            // Vertical lines
            for i in 0...gridSteps {
                let x = CGFloat(i) * gridSpacing
                if x <= canvasSize.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                }
            }
            
            // Horizontal lines
            for i in 0...gridSteps {
                let y = CGFloat(i) * gridSpacing
                if y <= canvasSize.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
            }
        }
        .stroke(Color.gray.opacity(0.3), lineWidth: 0.5 / document.zoomLevel)
        .scaleEffect(document.zoomLevel, anchor: .topLeading)
        .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
        } else {
            // Return empty view when grid spacing is 0
            EmptyView()
        }
    }
}
