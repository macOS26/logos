import SwiftUI

// Symbol-based grid using tiled pattern for memory efficiency
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

            // Create a single tile size (4x4 grid cells)
            let tileSize = actualGridSpacing * CGFloat(majorGridInterval)

            // Determine what to show based on zoom
            let shouldShowMinor = zoomLevel > 0.5
            let lineWidth: CGFloat = zoomLevel <= 0.5 ? 0.5 : 0.5

            // Create the tile pattern path once (this is our "symbol")
            let tilePattern = createTilePattern(
                tileSize: tileSize,
                gridSpacing: actualGridSpacing,
                majorInterval: majorGridInterval,
                showMinor: shouldShowMinor
            )

            // Calculate visible tile range
            let visibleStartX = max(0, -canvasOffset.x / zoomLevel)
            let visibleEndX = min(canvasSize.width, (size.width - canvasOffset.x) / zoomLevel)
            let visibleStartY = max(0, -canvasOffset.y / zoomLevel)
            let visibleEndY = min(canvasSize.height, (size.height - canvasOffset.y) / zoomLevel)

            let tileStartX = Int(floor(visibleStartX / tileSize))
            let tileEndX = Int(ceil(visibleEndX / tileSize))
            let tileStartY = Int(floor(visibleStartY / tileSize))
            let tileEndY = Int(ceil(visibleEndY / tileSize))

            // Draw grid using the tile pattern as a reusable "symbol"
            // Only draw visible tiles, reusing the same pattern
            for tileX in tileStartX...tileEndX {
                for tileY in tileStartY...tileEndY {
                    let x = CGFloat(tileX) * tileSize
                    let y = CGFloat(tileY) * tileSize

                    // Check if tile is within canvas bounds
                    if x < canvasSize.width && y < canvasSize.height {
                        // Transform and draw the tile pattern
                        var transform = CGAffineTransform.identity
                        transform = transform.translatedBy(
                            x: x * zoomLevel + canvasOffset.x,
                            y: y * zoomLevel + canvasOffset.y
                        )
                        transform = transform.scaledBy(x: zoomLevel, y: zoomLevel)

                        // Reuse the same tile pattern - this is the "symbol"
                        let transformedTile = tilePattern.applying(transform)

                        context.stroke(
                            transformedTile,
                            with: .color(.gray.opacity(shouldShowMinor ? 0.3 : 0.4)),
                            lineWidth: lineWidth
                        )
                    }
                }
            }

        }
    }

    // Creates the tile pattern that acts as our reusable "symbol"
    private func createTilePattern(
        tileSize: CGFloat,
        gridSpacing: CGFloat,
        majorInterval: Int,
        showMinor: Bool
    ) -> Path {
        var path = Path()

        // Draw minor grid lines within the tile (if needed)
        if showMinor {
            for i in 1..<majorInterval {
                let offset = CGFloat(i) * gridSpacing

                // Vertical minor lines
                path.move(to: CGPoint(x: offset, y: 0))
                path.addLine(to: CGPoint(x: offset, y: tileSize))

                // Horizontal minor lines
                path.move(to: CGPoint(x: 0, y: offset))
                path.addLine(to: CGPoint(x: tileSize, y: offset))
            }
        }

        // Draw major lines at ALL tile edges (left, top, right, bottom)
        // Left edge (x = 0)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: 0, y: tileSize))

        // Top edge (y = 0)
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: tileSize, y: 0))

        // Right edge
        path.move(to: CGPoint(x: tileSize, y: 0))
        path.addLine(to: CGPoint(x: tileSize, y: tileSize))

        // Bottom edge
        path.move(to: CGPoint(x: 0, y: tileSize))
        path.addLine(to: CGPoint(x: tileSize, y: tileSize))

        return path
    }
}