import SwiftUI

// Simplified grid - single Canvas view, no subviews
struct OptimizedGridView: View {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let unit: MeasurementUnit
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            // Calculate actual grid spacing based on unit
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

            // Determine grid visibility based on zoom
            // At 50% and lower, only show major lines at 0.5px
            let shouldShowMinor = zoomLevel > 0.5
            let minorLineWidth: CGFloat = 0.5
            let majorLineWidth: CGFloat = 1.0

            // Smart line width scaling
            let adjustedMinorWidth: CGFloat
            let adjustedMajorWidth: CGFloat

            if zoomLevel <= 0.5 {
                // At 50% and lower - major lines at exactly 0.5px, no scaling
                adjustedMinorWidth = minorLineWidth  // Won't be used anyway
                adjustedMajorWidth = 0.5  // Exactly 0.5px
            } else if zoomLevel < 1.0 {
                // Between 50% and 100% - scale down to prevent thick lines
                adjustedMinorWidth = minorLineWidth / zoomLevel
                adjustedMajorWidth = majorLineWidth / zoomLevel
            } else {
                // Zoomed in - use minimum to keep visible
                adjustedMinorWidth = max(minorLineWidth / zoomLevel, minorLineWidth * 0.75)
                adjustedMajorWidth = max(majorLineWidth / zoomLevel, majorLineWidth * 0.75)
            }

            // Build grid paths
            var minorPath = Path()
            var majorPath = Path()

            let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / actualGridSpacing)) + 1

            // Draw vertical lines
            for i in 0...gridSteps {
                let x = CGFloat(i) * actualGridSpacing
                if x <= canvasSize.width {
                    let transformedX = x * zoomLevel + canvasOffset.x
                    let startY = canvasOffset.y
                    let endY = canvasSize.height * zoomLevel + canvasOffset.y

                    if i % majorGridInterval == 0 {
                        // Major line
                        majorPath.move(to: CGPoint(x: transformedX, y: startY))
                        majorPath.addLine(to: CGPoint(x: transformedX, y: endY))
                    } else {
                        // Minor line
                        minorPath.move(to: CGPoint(x: transformedX, y: startY))
                        minorPath.addLine(to: CGPoint(x: transformedX, y: endY))
                    }
                }
            }

            // Draw horizontal lines
            for i in 0...gridSteps {
                let y = CGFloat(i) * actualGridSpacing
                if y <= canvasSize.height {
                    let transformedY = y * zoomLevel + canvasOffset.y
                    let startX = canvasOffset.x
                    let endX = canvasSize.width * zoomLevel + canvasOffset.x

                    if i % majorGridInterval == 0 {
                        // Major line
                        majorPath.move(to: CGPoint(x: startX, y: transformedY))
                        majorPath.addLine(to: CGPoint(x: endX, y: transformedY))
                    } else {
                        // Minor line
                        minorPath.move(to: CGPoint(x: startX, y: transformedY))
                        minorPath.addLine(to: CGPoint(x: endX, y: transformedY))
                    }
                }
            }

            // Draw minor grid lines (if visible at this zoom)
            if shouldShowMinor {
                context.stroke(
                    minorPath,
                    with: .color(.gray.opacity(0.3)),
                    lineWidth: adjustedMinorWidth
                )
            }

            // Draw major grid lines
            context.stroke(
                majorPath,
                with: .color(.gray.opacity(0.4)),
                lineWidth: adjustedMajorWidth
            )
        }
    }
}