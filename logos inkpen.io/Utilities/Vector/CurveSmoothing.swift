import SwiftUI

struct CurveSmoothing {

    static func chaikinSmooth(points: [CGPoint], iterations: Int = 1, ratio: Double = 0.25) -> [CGPoint] {
        guard points.count >= 3 else { return points }

        var smoothedPoints = points

        for _ in 0..<iterations {
            if smoothedPoints.count >= 50 {
                let metalEngine = MetalComputeEngine.shared
                let smoothingResult = metalEngine.chaikinSmoothingGPU(points: smoothedPoints, ratio: Float(ratio))
                switch smoothingResult {
                case .success(let smoothed):
                    smoothedPoints = smoothed
                case .failure(_):
                    smoothedPoints = applySingleChaikinIteration(points: smoothedPoints, ratio: ratio)
                }
            } else {
                smoothedPoints = applySingleChaikinIteration(points: smoothedPoints, ratio: ratio)
            }

            if smoothedPoints.count < 3 {
                break
            }
        }

        return smoothedPoints
    }

    private static func applySingleChaikinIteration(points: [CGPoint], ratio: Double) -> [CGPoint] {
        guard points.count >= 2 else { return points }

        var newPoints: [CGPoint] = []

        newPoints.append(points[0])

        for i in 0..<points.count-1 {
            let p0 = points[i]
            let p1 = points[i + 1]
            let q = CGPoint(
                x: p0.x + (p1.x - p0.x) * ratio,
                y: p0.y + (p1.y - p0.y) * ratio
            )

            let r = CGPoint(
                x: p0.x + (p1.x - p0.x) * (1.0 - ratio),
                y: p0.y + (p1.y - p0.y) * (1.0 - ratio)
            )

            newPoints.append(q)
            newPoints.append(r)
        }

        if let lastPoint = points.last {
            newPoints.append(lastPoint)
        }

        return newPoints
    }

    static func improvedDouglassPeucker(points: [CGPoint], tolerance: Double, preserveSharpCorners: Bool = true) -> [CGPoint] {
        guard points.count > 2 else { return points }

        return improvedDPRecursive(points: points, tolerance: tolerance, startIndex: 0, endIndex: points.count - 1, preserveSharpCorners: preserveSharpCorners)
    }

    private static func improvedDPRecursive(points: [CGPoint], tolerance: Double, startIndex: Int, endIndex: Int, preserveSharpCorners: Bool) -> [CGPoint] {
        var maxDistance: Double = 0
        var maxIndex = 0
        var maxCurvature: Double = 0

        for i in startIndex + 1..<endIndex {
            let distance = perpendicularDistance(point: points[i], lineStart: points[startIndex], lineEnd: points[endIndex])

            if distance > maxDistance {
                maxDistance = distance
                maxIndex = i
            }

            if preserveSharpCorners && i > startIndex && i < endIndex - 1 {
                let curvature = calculateCurvature(p0: points[i-1], p1: points[i], p2: points[i+1])
                maxCurvature = max(maxCurvature, curvature)
            }
        }

        let isSharpCorner = preserveSharpCorners && maxCurvature > 0.7

        if maxDistance > tolerance || isSharpCorner {
            let leftPoints = improvedDPRecursive(points: points, tolerance: tolerance, startIndex: startIndex, endIndex: maxIndex, preserveSharpCorners: preserveSharpCorners)
            let rightPoints = improvedDPRecursive(points: points, tolerance: tolerance, startIndex: maxIndex, endIndex: endIndex, preserveSharpCorners: preserveSharpCorners)

            return leftPoints + Array(rightPoints.dropFirst())
        } else {
            return [points[startIndex], points[endIndex]]
        }
    }

    static func adaptiveCurveFitting(points: [CGPoint], adaptiveTension: Bool = true, baseTension: Double = 0.3) -> [PathElement] {
        guard points.count >= 2 else { return [] }

        var elements: [PathElement] = []
        elements.append(.move(to: VectorPoint(points[0])))

        if points.count == 2 {
            elements.append(.line(to: VectorPoint(points[1])))
            return elements
        }

        for i in 1..<points.count {
            let p0 = points[max(0, i - 2)]
            let p1 = points[i - 1]
            let p2 = points[i]
            let p3 = points[min(points.count - 1, i + 1)]
            var tension = baseTension
            if adaptiveTension {
                let curvature = calculateCurvature(p0: p0, p1: p1, p2: p2)
                let distance = p2.distance(to: p1)

                tension = baseTension * (1.0 - curvature * 0.5) * min(2.0, distance / 50.0)
                tension = max(0.1, min(0.8, tension))
            }

            let (control1, control2) = calculateCentripetalControls(p0: p0, p1: p1, p2: p2, p3: p3, tension: tension)

            elements.append(.curve(
                to: VectorPoint(p2),
                control1: VectorPoint(control1),
                control2: VectorPoint(control2)
            ))
        }

        return elements
    }

    private static func perpendicularDistance(point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> Double {
        let A = point.x - lineStart.x
        let B = point.y - lineStart.y
        let C = lineEnd.x - lineStart.x
        let D = lineEnd.y - lineStart.y
        let dot = A * C + B * D
        let lenSq = C * C + D * D

        if lenSq == 0 {
            return sqrt(A * A + B * B)
        }

        let param = dot / lenSq
        let xx, yy: Double
        if param < 0 {
            xx = lineStart.x
            yy = lineStart.y
        } else if param > 1 {
            xx = lineEnd.x
            yy = lineEnd.y
        } else {
            xx = lineStart.x + param * C
            yy = lineStart.y + param * D
        }

        let dx = point.x - xx
        let dy = point.y - yy
        return sqrt(dx * dx + dy * dy)
    }

    private static func calculateCurvature(p0: CGPoint, p1: CGPoint, p2: CGPoint) -> Double {
        let v1 = CGPoint(x: p1.x - p0.x, y: p1.y - p0.y)
        let v2 = CGPoint(x: p2.x - p1.x, y: p2.y - p1.y)
        let len1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let len2 = sqrt(v2.x * v2.x + v2.y * v2.y)

        if len1 == 0 || len2 == 0 {
            return 0
        }

        let n1 = CGPoint(x: v1.x / len1, y: v1.y / len1)
        let n2 = CGPoint(x: v2.x / len2, y: v2.y / len2)
        let dotProduct = n1.x * n2.x + n1.y * n2.y

        return 1.0 - abs(dotProduct)
    }

    static func calculateCurvatureBatch(points: [CGPoint]) -> [Double] {
        guard points.count >= 3 else { return [] }

        if points.count >= 100 {
            let metalEngine = MetalComputeEngine.shared
            let results = metalEngine.calculateCurvatureGPU(points: points)
            switch results {
            case .success(let curvatures):
                return curvatures.map { Double($0) }
            case .failure(_):
                break
            }
        }

        var curvatures: [Double] = []

        curvatures.append(0.0)

        for i in 1..<(points.count - 1) {
            let curvature = calculateCurvature(p0: points[i-1], p1: points[i], p2: points[i+1])
            curvatures.append(curvature)
        }

        curvatures.append(0.0)

        return curvatures
    }

    private static func calculateCentripetalControls(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, tension: Double) -> (CGPoint, CGPoint) {
        let d1 = p1.distance(to: p0)
        let d2 = p2.distance(to: p1)
        let d3 = p3.distance(to: p2)
        let d1Safe = max(d1, 0.001)
        let d2Safe = max(d2, 0.001)
        let d3Safe = max(d3, 0.001)
        let t1 = CGPoint(
            x: (p2.x - p0.x) / (d1Safe + d2Safe),
            y: (p2.y - p0.y) / (d1Safe + d2Safe)
        )

        let t2 = CGPoint(
            x: (p3.x - p1.x) / (d2Safe + d3Safe),
            y: (p3.y - p1.y) / (d2Safe + d3Safe)
        )

        let control1 = CGPoint(
            x: p1.x + t1.x * d2Safe * tension,
            y: p1.y + t1.y * d2Safe * tension
        )

        let control2 = CGPoint(
            x: p2.x - t2.x * d2Safe * tension,
            y: p2.y - t2.y * d2Safe * tension
        )

        return (control1, control2)
    }
}
