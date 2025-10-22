import SwiftUI

// Optimized grid using cached paths for better performance
// This version properly renders major and minor lines within canvas bounds
struct OptimizedGridView: View, Equatable {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let unit: MeasurementUnit
    let zoomLevel: Double
    let canvasOffset: CGPoint

    static func == (lhs: OptimizedGridView, rhs: OptimizedGridView) -> Bool {
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

        OptimizedGridCanvasView(
            gridSpacing: actualGridSpacing,
            canvasSize: canvasSize,
            majorGridInterval: majorGridInterval,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset
        )
    }
}

// Cache for grid paths based on configuration
private class GridPathCache {
    static let shared = GridPathCache()

    private var cache: [CacheKey: (minor: Path, major: Path)] = [:]

    struct CacheKey: Hashable {
        let gridSpacing: CGFloat
        let canvasSize: CGSize
        let majorInterval: Int
        let zoomLevel: Double
        let canvasOffset: CGPoint
    }

    func getPaths(
        gridSpacing: CGFloat,
        canvasSize: CGSize,
        majorInterval: Int,
        zoomLevel: Double,
        canvasOffset: CGPoint
    ) -> (minor: Path, major: Path) {
        let key = CacheKey(
            gridSpacing: gridSpacing,
            canvasSize: canvasSize,
            majorInterval: majorInterval,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset
        )

        if let cached = cache[key] {
            return cached
        }

        let paths = createGridPaths(
            gridSpacing: gridSpacing,
            canvasSize: canvasSize,
            majorInterval: majorInterval,
            zoomLevel: zoomLevel,
            canvasOffset: canvasOffset
        )

        // Limit cache size to prevent excessive memory usage
        if cache.count > 10 {
            cache.removeAll()
        }

        cache[key] = paths
        return paths
    }

    private func createGridPaths(
        gridSpacing: CGFloat,
        canvasSize: CGSize,
        majorInterval: Int,
        zoomLevel: Double,
        canvasOffset: CGPoint
    ) -> (minor: Path, major: Path) {
        var minorPath = Path()
        var majorPath = Path()

        let gridSteps = Int(ceil(max(canvasSize.width, canvasSize.height) / gridSpacing)) + 1

        // Draw vertical lines
        for i in 0...gridSteps {
            let x = CGFloat(i) * gridSpacing
            if x <= canvasSize.width {
                let transformedX = x * zoomLevel + canvasOffset.x
                let startY = canvasOffset.y
                let endY = canvasSize.height * zoomLevel + canvasOffset.y

                if i % majorInterval == 0 {
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
            let y = CGFloat(i) * gridSpacing
            if y <= canvasSize.height {
                let transformedY = y * zoomLevel + canvasOffset.y
                let startX = canvasOffset.x
                let endX = canvasSize.width * zoomLevel + canvasOffset.x

                if i % majorInterval == 0 {
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

        return (minorPath, majorPath)
    }
}

struct OptimizedGridCanvasView: View {
    let gridSpacing: CGFloat
    let canvasSize: CGSize
    let majorGridInterval: Int
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        Canvas { context, size in
            // Determine grid visibility based on zoom
            let shouldShowMinor = zoomLevel > 0.25
            let minorLineWidth: CGFloat = 0.5
            let majorLineWidth: CGFloat = zoomLevel <= 0.5 ? minorLineWidth : 1.0

            // Get cached paths
            let paths = GridPathCache.shared.getPaths(
                gridSpacing: gridSpacing,
                canvasSize: canvasSize,
                majorInterval: majorGridInterval,
                zoomLevel: zoomLevel,
                canvasOffset: canvasOffset
            )

            // Smart line width scaling
            let adjustedMinorWidth: CGFloat
            let adjustedMajorWidth: CGFloat
            if zoomLevel < 1.0 {
                // Zoomed out - scale down to prevent thick lines
                adjustedMinorWidth = minorLineWidth / zoomLevel
                adjustedMajorWidth = majorLineWidth / zoomLevel
            } else {
                // Zoomed in - use minimum to keep visible
                adjustedMinorWidth = max(minorLineWidth / zoomLevel, minorLineWidth * 0.75)
                adjustedMajorWidth = max(majorLineWidth / zoomLevel, majorLineWidth * 0.75)
            }

            // Draw minor grid lines (if visible at this zoom)
            if shouldShowMinor {
                context.stroke(
                    paths.minor,
                    with: .color(.gray.opacity(0.3)),
                    lineWidth: adjustedMinorWidth
                )
            }

            // Draw major grid lines
            context.stroke(
                paths.major,
                with: .color(.gray.opacity(0.4)),
                lineWidth: adjustedMajorWidth
            )
        }
    }
}