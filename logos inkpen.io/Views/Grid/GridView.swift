//
//  LayerView+GridView.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI
import AppKit
import SwiftUI

struct GridView: View {
    let document: VectorDocument
    let geometry: GeometryProxy
    
    var body: some View {
        // Reduce grid density based on unit type
        // Multiply spacing to have FEWER lines (larger gaps between lines)
        let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit
        let spacingMultiplier: CGFloat = {
            switch document.settings.unit {
            case .pixels, .points:
                return 25.0
            case .millimeters:
                return 10.0
            case .picas:
                // Align with major ruler marks (every 4 picas)
                return 4.0
            default:
                return 1.0
            }
        }()
        let gridSpacing = baseSpacing * spacingMultiplier
        let canvasSize = document.settings.sizeInPoints

        // Major grid lines every 4 grid spaces (matches typical ruler major marks)
        let majorGridInterval = 4

        // Prevent infinite loop when grid spacing is 0
        if gridSpacing > 0 {
            ZStack {
                // Regular grid lines
                Path { path in
                    let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1

                    // Vertical lines
                    for i in 0...gridSteps {
                        // Skip lines that will be drawn as major grid lines
                        if i % majorGridInterval != 0 {
                            let x = CGFloat(i) * gridSpacing
                            if x <= canvasSize.width {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                            }
                        }
                    }

                    // Horizontal lines
                    for i in 0...gridSteps {
                        // Skip lines that will be drawn as major grid lines
                        if i % majorGridInterval != 0 {
                            let y = CGFloat(i) * gridSpacing
                            if y <= canvasSize.height {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                            }
                        }
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5 / document.zoomLevel)
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)

                // Major grid lines (2x thicker)
                Path { path in
                    let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1

                    // Vertical major lines
                    for i in 0...gridSteps {
                        if i % majorGridInterval == 0 {
                            let x = CGFloat(i) * gridSpacing
                            if x <= canvasSize.width {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                            }
                        }
                    }

                    // Horizontal major lines
                    for i in 0...gridSteps {
                        if i % majorGridInterval == 0 {
                            let y = CGFloat(i) * gridSpacing
                            if y <= canvasSize.height {
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                            }
                        }
                    }
                }
                .stroke(Color.gray.opacity(0.4), lineWidth: 1.0 / document.zoomLevel)  // 2x thicker
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            }
        } else {
            // Return empty view when grid spacing is 0
            EmptyView()
        }
    }
}
