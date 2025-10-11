import SwiftUI

struct RealTimeSmoothing {

    static func applyRealTimeSmoothing(
        newPoint: CGPoint,
        recentPoints: inout [CGPoint],
        windowSize: Int = 5,
        strength: Double = 0.3
    ) -> CGPoint {
        recentPoints.append(newPoint)

        if recentPoints.count > windowSize {
            recentPoints = Array(recentPoints.suffix(windowSize))
        }

        guard recentPoints.count >= 3 else {
            return newPoint
        }

        let smoothed = weightedAverageSmoothing(points: recentPoints, strength: strength)
        return smoothed.last ?? newPoint
    }

    private static func weightedAverageSmoothing(points: [CGPoint], strength: Double) -> [CGPoint] {
        guard points.count >= 3 else { return points }

        var smoothedPoints = points

        for i in 1..<points.count - 1 {
            let prev = points[i - 1]
            let curr = points[i]
            let next = points[i + 1]

            let smoothX = prev.x * 0.25 + curr.x * 0.5 + next.x * 0.25
            let smoothY = prev.y * 0.25 + curr.y * 0.5 + next.y * 0.25

            smoothedPoints[i] = CGPoint(
                x: curr.x * (1.0 - strength) + smoothX * strength,
                y: curr.y * (1.0 - strength) + smoothY * strength
            )
        }

        return smoothedPoints
    }
}
