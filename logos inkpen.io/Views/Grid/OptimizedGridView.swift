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
            let shouldShowMinor = zoomLevel > 0.5  // No minor lines at 50% and lower
            // At 50% and lower: make lines 50% thinner (0.3125 instead of 0.625)
            // Above 50%: normal thickness (0.625)
            let minorLineWidth: CGFloat = 0.625
            let majorLineWidth: CGFloat = zoomLevel <= 0.5 ? 0.3125 : 0.625

            // Create separate patterns for minor and major lines
            let (minorPattern, majorPattern) = createTilePatterns(
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

            // Draw grid using the tile patterns as reusable "symbols"
            // Only draw visible tiles, reusing the same patterns
            for tileX in tileStartX...tileEndX {
                for tileY in tileStartY...tileEndY {
                    let x = CGFloat(tileX) * tileSize
                    let y = CGFloat(tileY) * tileSize

                    // Check if tile is within canvas bounds
                    if x < canvasSize.width && y < canvasSize.height {
                        // Transform for this tile position
                        var transform = CGAffineTransform.identity
                        transform = transform.translatedBy(
                            x: x * zoomLevel + canvasOffset.x,
                            y: y * zoomLevel + canvasOffset.y
                        )
                        transform = transform.scaledBy(x: zoomLevel, y: zoomLevel)

                        // Draw minor lines if visible
                        if shouldShowMinor && !minorPattern.isEmpty {
                            let transformedMinor = minorPattern.applying(transform)
                            context.stroke(
                                transformedMinor,
                                with: .color(.gray.opacity(0.3)),
                                lineWidth: minorLineWidth
                            )
                        }

                        // Draw major lines (10% lighter = 0.45 opacity instead of 0.5)
                        if !majorPattern.isEmpty {
                            let transformedMajor = majorPattern.applying(transform)
                            context.stroke(
                                transformedMajor,
                                with: .color(.gray.opacity(0.45)),
                                lineWidth: majorLineWidth
                            )
                        }
                    }
                }
            }

        }
    }

    // Creates separate tile patterns for minor and major lines
    private func createTilePatterns(
        tileSize: CGFloat,
        gridSpacing: CGFloat,
        majorInterval: Int,
        showMinor: Bool
    ) -> (minor: Path, major: Path) {
        var minorPath = Path()
        var majorPath = Path()

        // Draw minor grid lines within the tile (if needed)
        if showMinor {
            for i in 1..<majorInterval {
                let offset = CGFloat(i) * gridSpacing

                // Vertical minor lines
                minorPath.move(to: CGPoint(x: offset, y: 0))
                minorPath.addLine(to: CGPoint(x: offset, y: tileSize))

                // Horizontal minor lines
                minorPath.move(to: CGPoint(x: 0, y: offset))
                minorPath.addLine(to: CGPoint(x: tileSize, y: offset))
            }
        }

        // Draw major lines at ALL tile edges (left, top, right, bottom)
        // Left edge (x = 0)
        majorPath.move(to: CGPoint(x: 0, y: 0))
        majorPath.addLine(to: CGPoint(x: 0, y: tileSize))

        // Top edge (y = 0)
        majorPath.move(to: CGPoint(x: 0, y: 0))
        majorPath.addLine(to: CGPoint(x: tileSize, y: 0))

        // Right edge
        majorPath.move(to: CGPoint(x: tileSize, y: 0))
        majorPath.addLine(to: CGPoint(x: tileSize, y: tileSize))

        // Bottom edge
        majorPath.move(to: CGPoint(x: 0, y: tileSize))
        majorPath.addLine(to: CGPoint(x: tileSize, y: tileSize))

        return (minorPath, majorPath)
    }
}