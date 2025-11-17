import SwiftUI

enum DrawingCanvasPathHelpers {

    static func douglasPeuckerSimplify(points: [CGPoint], tolerance: Double) -> [CGPoint] {
        guard points.count > 2 else { return points }

        return douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1)
    }

    static func douglasPeuckerRecursive(points: [CGPoint], tolerance: Double, startIndex: Int, endIndex: Int) -> [CGPoint] {
        guard endIndex - startIndex > 1 else {
            return [points[startIndex], points[endIndex]]
        }

        let startPoint = points[startIndex]
        let endPoint = points[endIndex]
        var maxDistance: Double = 0
        var maxIndex = startIndex

        for i in (startIndex + 1)..<endIndex {
            let distance = perpendicularDistance(point: points[i], lineStart: startPoint, lineEnd: endPoint)
            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }
        }

        if maxDistance > tolerance {
            let leftSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: startIndex, endIndex: maxIndex)
            let rightSegment = douglasPeuckerRecursive(points: points, tolerance: tolerance, startIndex: maxIndex, endIndex: endIndex)

            return leftSegment + Array(rightSegment.dropFirst())
        } else {
            return [startPoint, endPoint]
        }
    }

    static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let A = lineEnd.y - lineStart.y
        let B = lineStart.x - lineEnd.x
        let C = lineEnd.x * lineStart.y - lineStart.x * lineEnd.y
        // SIMD-optimized distance calculation
        let distance = abs(A * point.x + B * point.y + C) / simd_length(SIMD2(A, B))
        return distance
    }

    static func createSmoothBezierPath(from points: [CGPoint]) -> VectorPath {
        guard points.count >= 2 else {
            return VectorPath(elements: [])
        }

        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))

        if points.count == 2 {
            elements.append(.line(to: VectorPoint(points[1])))
        } else {
            let curveSegments = fitBezierCurves(through: points)
            elements.append(contentsOf: curveSegments)
        }

        return VectorPath(elements: elements)
    }

    static func fitBezierCurves(through points: [CGPoint]) -> [PathElement] {
        var elements: [PathElement] = []

        for i in 1..<points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let isFirstSegment = (i == 1)
            let isLastSegment = (i == points.count - 1)

            if isFirstSegment || isLastSegment {
                elements.append(.line(to: VectorPoint(p1)))
            } else {
                let tension: Double = 0.25
                let distance = p1.distance(to: p0)
                let prevTangent = i > 1 ? calculateTangent(p0: points[i - 2], p1: p0, p2: p1) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let nextTangent = i < points.count - 1 ? calculateTangent(p0: p0, p1: p1, p2: points[i + 1]) : CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
                let controlLength = distance * tension

                let control1 = CGPoint(
                    x: p0.x + prevTangent.x * controlLength,
                    y: p0.y + prevTangent.y * controlLength
                )

                let control2 = CGPoint(
                    x: p1.x - nextTangent.x * controlLength,
                    y: p1.y - nextTangent.y * controlLength
                )

                elements.append(.curve(
                    to: VectorPoint(p1),
                    control1: VectorPoint(control1),
                    control2: VectorPoint(control2)
                ))
            }
        }

        return elements
    }

    // SIMD-optimized tangent calculation
    static func calculateTangent(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let v1 = p1.simd - p0.simd
        let v2 = p2.simd - p1.simd
        let avg = (v1 + v2) * 0.5
        let length = simd_length(avg)
        if length > 0 {
            let normalized = simd_normalize(avg)
            return CGPoint(normalized)
        } else {
            return CGPoint(x: 1, y: 0)
        }
    }

    /// Remove coincident (duplicate) points from an array
    /// - Parameters:
    ///   - points: Input points
    ///   - passes: Number of removal passes (0-3)
    ///   - tolerance: Distance threshold for considering points coincident (default 0.1)
    /// - Returns: Filtered points with coincident points removed
    static func removeCoincidentPoints(_ points: [CGPoint], passes: Int, tolerance: Double = 0.1) -> [CGPoint] {
        guard passes > 0 && points.count > 1 else { return points }

        var filtered = points
        for _ in 0..<min(passes, 3) {
            var result: [CGPoint] = []
            result.append(filtered[0])

            for i in 1..<filtered.count {
                let current = filtered[i]
                let previous = result.last!

                let distance = hypot(current.x - previous.x, current.y - previous.y)
                if distance >= tolerance {
                    result.append(current)
                }
            }

            filtered = result
            if filtered.count <= 2 { break }
        }

        return filtered
    }
}
