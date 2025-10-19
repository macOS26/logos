import SwiftUI
import AppKit

// Isolated Canvas-based grid view that doesn't update with VectorObject changes
struct GridCanvasView: View {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let majorGridInterval: Int
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            // Draw minor grid lines
            drawGridLines(
                context: context,
                gridSpacing: gridSpacing,
                canvasSize: canvasSize,
                majorGridInterval: majorGridInterval,
                isMajor: false,
                opacity: 0.3,
                lineWidth: 0.5,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
            )

            // Draw major grid lines
            drawGridLines(
                context: context,
                gridSpacing: gridSpacing,
                canvasSize: canvasSize,
                majorGridInterval: majorGridInterval,
                isMajor: true,
                opacity: 0.4,
                lineWidth: 1.0,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
            )
        }
    }

    private func drawGridLines(
        context: GraphicsContext,
        gridSpacing: CGFloat,
        canvasSize: CGSize,
        majorGridInterval: Int,
        isMajor: Bool,
        opacity: Double,
        lineWidth: CGFloat,
        zoomLevel: Double,
        canvasOffset: CGPoint
    ) {
        let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1

        var path = Path()

        // Draw vertical lines
        for i in 0...gridSteps {
            let shouldDraw = isMajor ? (i % majorGridInterval == 0) : (i % majorGridInterval != 0)
            if shouldDraw {
                let x = CGFloat(i) * gridSpacing
                if x <= canvasSize.width {
                    let transformedX = x * zoomLevel + canvasOffset.x
                    let startY = canvasOffset.y
                    let endY = canvasSize.height * zoomLevel + canvasOffset.y

                    path.move(to: CGPoint(x: transformedX, y: startY))
                    path.addLine(to: CGPoint(x: transformedX, y: endY))
                }
            }
        }

        // Draw horizontal lines
        for i in 0...gridSteps {
            let shouldDraw = isMajor ? (i % majorGridInterval == 0) : (i % majorGridInterval != 0)
            if shouldDraw {
                let y = CGFloat(i) * gridSpacing
                if y <= canvasSize.height {
                    let transformedY = y * zoomLevel + canvasOffset.y
                    let startX = canvasOffset.x
                    let endX = canvasSize.width * zoomLevel + canvasOffset.x

                    path.move(to: CGPoint(x: startX, y: transformedY))
                    path.addLine(to: CGPoint(x: endX, y: transformedY))
                }
            }
        }

        context.stroke(
            path,
            with: .color(.gray.opacity(opacity)),
            lineWidth: lineWidth / zoomLevel
        )
    }
}

// Equatable wrapper to prevent unnecessary updates
struct GridView: View, Equatable {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let unit: MeasurementUnit
    let zoomLevel: Double
    let canvasOffset: CGPoint

    static func == (lhs: GridView, rhs: GridView) -> Bool {
        lhs.gridSpacing == rhs.gridSpacing &&
        lhs.canvasSize == rhs.canvasSize &&
        lhs.unit == rhs.unit &&
        lhs.zoomLevel == rhs.zoomLevel &&
        lhs.canvasOffset == rhs.canvasOffset
    }

    var body: some View {
        let baseSpacing = gridSpacing * unit.pointsPerUnit
        let spacingMultiplier: CGFloat = {
            switch unit {
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
        let actualGridSpacing = baseSpacing * spacingMultiplier
        let majorGridInterval = 4

        GridCanvasView(
            gridSpacing: actualGridSpacing,
            canvasSize: canvasSize,
            majorGridInterval: majorGridInterval,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset
        )
    }
}
