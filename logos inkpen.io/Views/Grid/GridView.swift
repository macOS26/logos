import SwiftUI
import AppKit

private func createGridPath(
    gridSpacing: CGFloat,
    canvasSize: CGSize,
    majorGridInterval: Int,
    isMajor: Bool
) -> Path {
    Path { path in
        let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1
        
        for i in 0...gridSteps {
            let shouldDraw = isMajor ? (i % majorGridInterval == 0) : (i % majorGridInterval != 0)
            if shouldDraw {
                let x = CGFloat(i) * gridSpacing
                if x <= canvasSize.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: canvasSize.height))
                }
            }
        }
        
        for i in 0...gridSteps {
            let shouldDraw = isMajor ? (i % majorGridInterval == 0) : (i % majorGridInterval != 0)
            if shouldDraw {
                let y = CGFloat(i) * gridSpacing
                if y <= canvasSize.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
            }
        }
    }
}

private struct GridLines: View {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let majorGridInterval: Int
    let isMajor: Bool
    let opacity: Double
    let lineWidth: CGFloat
    let zoomLevel: Double
    let canvasOffset: CGPoint
    var body: some View {
        createGridPath(
            gridSpacing: gridSpacing,
            canvasSize: canvasSize,
            majorGridInterval: majorGridInterval,
            isMajor: isMajor
        )
        .stroke(Color.gray.opacity(opacity), lineWidth: lineWidth / zoomLevel)
        .scaleEffect(zoomLevel, anchor: .topLeading)
        .offset(x: canvasOffset.x, y: canvasOffset.y)
    }
}

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
                GridLines(
                    gridSpacing: gridSpacing,
                    canvasSize: canvasSize,
                    majorGridInterval: majorGridInterval,
                    isMajor: false,
                    opacity: 0.3,
                    lineWidth: 0.5,
                    zoomLevel: document.zoomLevel,
                    canvasOffset: document.canvasOffset
                )
                
                GridLines(
                    gridSpacing: gridSpacing,
                    canvasSize: canvasSize,
                    majorGridInterval: majorGridInterval,
                    isMajor: true,
                    opacity: 0.4,
                    lineWidth: 1.0,
                    zoomLevel: document.zoomLevel,
                    canvasOffset: document.canvasOffset
                )
            }
        } else {
            EmptyView()
        }
    }
}
