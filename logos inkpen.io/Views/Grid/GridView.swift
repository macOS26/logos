
import SwiftUI
import AppKit
import SwiftUI

struct GridView: View {
    let document: VectorDocument
    let geometry: GeometryProxy

    var body: some View {
        let baseSpacing = document.settings.gridSpacing * document.settings.unit.pointsPerUnit
        let spacingMultiplier: CGFloat = {
            switch document.settings.unit {
            case .pixels, .points:
                return 25.0
            case .millimeters:
                return 10.0
            case .picas:
                return 4.0
            default:
                return 1.0
            }
        }()
        let gridSpacing = baseSpacing * spacingMultiplier
        let canvasSize = document.settings.sizeInPoints

        let majorGridInterval = 4

        if gridSpacing > 0 {
            ZStack {
                Path { path in
                    let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1

                    for i in 0...gridSteps {
                        if i % majorGridInterval != 0 {
                            let x = CGFloat(i) * gridSpacing
                            if x <= canvasSize.width {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                            }
                        }
                    }

                    for i in 0...gridSteps {
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

                Path { path in
                    let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1

                    for i in 0...gridSteps {
                        if i % majorGridInterval == 0 {
                            let x = CGFloat(i) * gridSpacing
                            if x <= canvasSize.width {
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                            }
                        }
                    }

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
                .stroke(Color.gray.opacity(0.4), lineWidth: 1.0 / document.zoomLevel)
                .scaleEffect(document.zoomLevel, anchor: .topLeading)
                .offset(x: document.canvasOffset.x, y: document.canvasOffset.y)
            }
        } else {
            EmptyView()
        }
    }
}
