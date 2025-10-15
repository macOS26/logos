import SwiftUI

struct ProfessionalBezierMathematics {

    struct BezierPoint: Codable, Hashable {
        var point: VectorPoint
        var incomingHandle: VectorPoint?
        var outgoingHandle: VectorPoint?
        var pointType: AnchorPointType
        var handleConstraint: HandleConstraint

        init(point: VectorPoint,
             incomingHandle: VectorPoint? = nil,
             outgoingHandle: VectorPoint? = nil,
             pointType: AnchorPointType = .corner,
             handleConstraint: HandleConstraint = .independent) {
            self.point = point
            self.incomingHandle = incomingHandle
            self.outgoingHandle = outgoingHandle
            self.pointType = pointType
            self.handleConstraint = handleConstraint
        }

        static func smoothPoint(at location: VectorPoint, handleLength: Double, angle: Double) -> BezierPoint {
            let handleVector = VectorPoint(
                cos(angle) * handleLength,
                sin(angle) * handleLength
            )
            return BezierPoint(
                point: location,
                incomingHandle: VectorPoint(location.x - handleVector.x, location.y - handleVector.y),
                outgoingHandle: VectorPoint(location.x + handleVector.x, location.y + handleVector.y),
                pointType: .smoothCurve,
                handleConstraint: .symmetric
            )
        }

        static func cornerPoint(at location: VectorPoint) -> BezierPoint {
            return BezierPoint(
                point: location,
                incomingHandle: nil,
                outgoingHandle: nil,
                pointType: .corner,
                handleConstraint: .independent
            )
        }
    }

    enum AnchorPointType: String, CaseIterable, Codable {
        case corner = "Corner"
        case smoothCurve = "Smooth Curve"
        case smoothCorner = "Smooth Corner"
        case cusp = "Cusp"
        case connector = "Connector"

        var description: String {
            switch self {
            case .corner:
                return "Corner point with sharp edges"
            case .smoothCurve:
                return "Smooth curve point with symmetric handles"
            case .smoothCorner:
                return "Smooth corner with different handle lengths"
            case .cusp:
                return "Cusp point with independent handle directions"
            case .connector:
                return "Intelligent connector point (FreeHand style)"
            }
        }

        var hasHandles: Bool {
            switch self {
            case .corner: return false
            case .smoothCurve, .smoothCorner, .cusp, .connector: return true
            }
        }
    }

    enum HandleConstraint: String, CaseIterable, Codable {
                case symmetric = "Symmetric"
case aligned = "Aligned"
case independent = "Independent"
        case automatic = "Automatic"

        var description: String {
            switch self {
            case .symmetric:
                return "Symmetric handles (equal length and opposite direction)"
            case .aligned:
                return "Aligned handles (opposite direction, different lengths)"
            case .independent:
                return "Independent handles (move separately)"
            case .automatic:
                return "Automatic handles (system optimized)"
            }
        }
    }

    static func deCasteljauEvaluation(points: [VectorPoint], t: Double) -> VectorPoint {
        guard !points.isEmpty else { return VectorPoint(0, 0) }
        guard points.count > 1 else { return points[0] }

        var currentPoints = points

        while currentPoints.count > 1 {
            var nextLevel: [VectorPoint] = []

            for i in 0..<(currentPoints.count - 1) {
                let p0 = currentPoints[i]
                let p1 = currentPoints[i + 1]

                let interpolated = VectorPoint(
                    (1.0 - t) * p0.x + t * p1.x,
                    (1.0 - t) * p0.y + t * p1.y
                )
                nextLevel.append(interpolated)
            }

            currentPoints = nextLevel
        }

        return currentPoints[0]
    }

    static func bernsteinBasis(i: Int, n: Int, t: Double) -> Double {
        let binomialCoeff = binomialCoefficient(n: n, k: i)
        let tPower = pow(t, Double(i))
        let oneMinusTPower = pow(1.0 - t, Double(n - i))
        return Double(binomialCoeff) * tPower * oneMinusTPower
    }

    private static var binomialLookup: [[Int]] = []

    static func binomialCoefficient(n: Int, k: Int) -> Int {
        guard n >= 0 && k >= 0 && k <= n else { return 0 }

        while binomialLookup.count <= n {
            let currentN = binomialLookup.count
            var newRow: [Int] = []

            for i in 0...currentN {
                if i == 0 || i == currentN {
                    newRow.append(1)
                } else {
                    let value = binomialLookup[currentN - 1][i - 1] + binomialLookup[currentN - 1][i]
                    newRow.append(value)
                }
            }

            binomialLookup.append(newRow)
        }

        return binomialLookup[n][k]
    }

    static func evaluateCubicBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let u2 = u * u
        let u3 = u2 * u
        let t2 = t * t
        let t3 = t2 * t

        let x = u3 * p0.x + 3 * u2 * t * p1.x + 3 * u * t2 * p2.x + t3 * p3.x
        let y = u3 * p0.y + 3 * u2 * t * p1.y + 3 * u * t2 * p2.y + t3 * p3.y

        return VectorPoint(x, y)
    }

    static func evaluateQuadraticBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t
        let u2 = u * u
        let t2 = t * t

        let x = u2 * p0.x + 2 * u * t * p1.x + t2 * p2.x
        let y = u2 * p0.y + 2 * u * t * p1.y + t2 * p2.y

        return VectorPoint(x, y)
    }

    static func cubicBezierFirstDerivative(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t

        let dx = 3 * (u * u * (p1.x - p0.x) + 2 * u * t * (p2.x - p1.x) + t * t * (p3.x - p2.x))
        let dy = 3 * (u * u * (p1.y - p0.y) + 2 * u * t * (p2.y - p1.y) + t * t * (p3.y - p2.y))

        return VectorPoint(dx, dy)
    }

    static func cubicBezierSecondDerivative(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> VectorPoint {
        let u = 1.0 - t

        let dx = 6 * (u * (p2.x - 2 * p1.x + p0.x) + t * (p3.x - 2 * p2.x + p1.x))
        let dy = 6 * (u * (p2.y - 2 * p1.y + p0.y) + t * (p3.y - 2 * p2.y + p1.y))

        return VectorPoint(dx, dy)
    }

    static func calculateCurvature(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> Double {
        let firstDeriv = cubicBezierFirstDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)
        let secondDeriv = cubicBezierSecondDerivative(p0: p0, p1: p1, p2: p2, p3: p3, t: t)

        let crossProduct = firstDeriv.x * secondDeriv.y - firstDeriv.y * secondDeriv.x
        let speedSquared = firstDeriv.x * firstDeriv.x + firstDeriv.y * firstDeriv.y
        let speed = sqrt(speedSquared)

        guard speed > 1e-10 else { return 0.0 }

        return abs(crossProduct) / (speedSquared * speed)
    }

    static func splitCubicBezier(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, t: Double) -> ([VectorPoint], [VectorPoint]) {
        let q1 = VectorPoint.lerp(p0, p1, t)
        let q2 = VectorPoint.lerp(p1, p2, t)

        let r1 = VectorPoint.lerp(q1, q2, t)
        let r2 = VectorPoint.lerp(p2, p3, t)

        let s1 = VectorPoint.lerp(r1, r2, t)

        let pointOnCurve = VectorPoint.lerp(s1, s1, t)

        let leftCurve = [p0, q1, r1, pointOnCurve]
        let rightCurve = [pointOnCurve, s1, r2, p3]

        return (leftCurve, rightCurve)
    }

    static func generateSmoothHandles(previousPoint: VectorPoint?, currentPoint: VectorPoint, nextPoint: VectorPoint?, tension: Double = 0.33) -> (VectorPoint?, VectorPoint?) {
        var incomingHandle: VectorPoint?
        var outgoingHandle: VectorPoint?

        if let prev = previousPoint, let next = nextPoint {
            let direction = VectorPoint(next.x - prev.x, next.y - prev.y)
            let directionLength = sqrt(direction.x * direction.x + direction.y * direction.y)

            guard directionLength > 1e-10 else { return (nil, nil) }

            let normalizedDirection = VectorPoint(direction.x / directionLength, direction.y / directionLength)

            let prevDistance = sqrt((currentPoint.x - prev.x) * (currentPoint.x - prev.x) + (currentPoint.y - prev.y) * (currentPoint.y - prev.y))
            let nextDistance = sqrt((next.x - currentPoint.x) * (next.x - currentPoint.x) + (next.y - currentPoint.y) * (next.y - currentPoint.y))

            let avgDistance = (prevDistance + nextDistance) / 2.0
            let baseTension = tension
            let distanceMultiplier = min(avgDistance / 50.0, 2.0)
            let dynamicTension = baseTension * (1.0 + distanceMultiplier * 0.5)

            let incomingLength = prevDistance * dynamicTension
            let outgoingLength = nextDistance * dynamicTension

            incomingHandle = VectorPoint(
                currentPoint.x - normalizedDirection.x * incomingLength,
                currentPoint.y - normalizedDirection.y * incomingLength
            )

            outgoingHandle = VectorPoint(
                currentPoint.x + normalizedDirection.x * outgoingLength,
                currentPoint.y + normalizedDirection.y * outgoingLength
            )
        } else if let prev = previousPoint {
            let direction = VectorPoint(currentPoint.x - prev.x, currentPoint.y - prev.y)
            let directionLength = sqrt(direction.x * direction.x + direction.y * direction.y)

            if directionLength > 1e-10 {
                let distanceMultiplier = min(directionLength / 50.0, 2.0)
                let dynamicTension = tension * (1.0 + distanceMultiplier * 0.5)
                let handleLength = directionLength * dynamicTension

                let normalizedDirection = VectorPoint(direction.x / directionLength, direction.y / directionLength)
                outgoingHandle = VectorPoint(
                    currentPoint.x + normalizedDirection.x * handleLength,
                    currentPoint.y + normalizedDirection.y * handleLength
                )
            }
        } else if let next = nextPoint {
            let direction = VectorPoint(next.x - currentPoint.x, next.y - currentPoint.y)
            let directionLength = sqrt(direction.x * direction.x + direction.y * direction.y)

            if directionLength > 1e-10 {
                let distanceMultiplier = min(directionLength / 50.0, 2.0)
                let dynamicTension = tension * (1.0 + distanceMultiplier * 0.5)
                let handleLength = directionLength * dynamicTension

                let normalizedDirection = VectorPoint(direction.x / directionLength, direction.y / directionLength)
                incomingHandle = VectorPoint(
                    currentPoint.x - normalizedDirection.x * handleLength,
                    currentPoint.y - normalizedDirection.y * handleLength
                )
            }
        }

        return (incomingHandle, outgoingHandle)
    }

    enum ContinuityType: String, CaseIterable, Codable {
        case c0 = "C0"
        case g1 = "G1"
        case c1 = "C1"
        case g2 = "G2"
        case c2 = "C2"
        case none = "None"
    }

    static func analyzeContinuity(curve1: [VectorPoint], curve2: [VectorPoint], tolerance: Double = 1e-10) -> ContinuityType {
        guard curve1.count == 4 && curve2.count == 4 else { return .none }

        let p2 = curve1[2], p3 = curve1[3]
        let q0 = curve2[0], q1 = curve2[1]

        let positionDiff = sqrt((p3.x - q0.x) * (p3.x - q0.x) + (p3.y - q0.y) * (p3.y - q0.y))
        guard positionDiff < tolerance else { return .none }

        let curve1EndTangent = VectorPoint(p3.x - p2.x, p3.y - p2.y)
        let curve2StartTangent = VectorPoint(q1.x - q0.x, q1.y - q0.y)

        let tangent1Length = sqrt(curve1EndTangent.x * curve1EndTangent.x + curve1EndTangent.y * curve1EndTangent.y)
        let tangent2Length = sqrt(curve2StartTangent.x * curve2StartTangent.x + curve2StartTangent.y * curve2StartTangent.y)

        guard tangent1Length > tolerance && tangent2Length > tolerance else { return .c0 }

        let normalizedTangent1 = VectorPoint(curve1EndTangent.x / tangent1Length, curve1EndTangent.y / tangent1Length)
        let normalizedTangent2 = VectorPoint(curve2StartTangent.x / tangent2Length, curve2StartTangent.y / tangent2Length)

        let tangentDiff = sqrt((normalizedTangent1.x - normalizedTangent2.x) * (normalizedTangent1.x - normalizedTangent2.x) +
                              (normalizedTangent1.y - normalizedTangent2.y) * (normalizedTangent1.y - normalizedTangent2.y))

        guard tangentDiff < tolerance else { return .c0 }

        let derivativeDiff = abs(tangent1Length - tangent2Length)
        if derivativeDiff < tolerance {
            return .c1
        } else {
            return .g1
        }
    }

    static func fitCubicBezierToPoints(points: [VectorPoint]) -> [VectorPoint]? {
        guard points.count >= 4 else { return nil }

        guard let p0 = points.first, let p3 = points.last else { return nil }

        let midIndex1 = points.count / 3
        let midIndex2 = (points.count * 2) / 3

        let p1 = points[min(midIndex1, points.count - 1)]
        let p2 = points[min(midIndex2, points.count - 1)]

        return [p0, p1, p2, p3]
    }

    static func calculateArcLength(p0: VectorPoint, p1: VectorPoint, p2: VectorPoint, p3: VectorPoint, subdivisions: Int = 10) -> Double {
        var totalLength: Double = 0.0
        let dt = 1.0 / Double(subdivisions)

        for i in 0..<subdivisions {
            let t1 = Double(i) * dt
            let t2 = Double(i + 1) * dt

            let point1 = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t1)
            let point2 = evaluateCubicBezier(p0: p0, p1: p1, p2: p2, p3: p3, t: t2)

            let segmentLength = sqrt((point2.x - point1.x) * (point2.x - point1.x) + (point2.y - point1.y) * (point2.y - point1.y))
            totalLength += segmentLength
        }

        return totalLength
    }
}

extension VectorPoint {
    static func lerp(_ a: VectorPoint, _ b: VectorPoint, _ t: Double) -> VectorPoint {
        return VectorPoint(
            a.x + t * (b.x - a.x),
            a.y + t * (b.y - a.y)
        )
    }

    static func lerpBatch(_ startPoints: [VectorPoint], _ endPoints: [VectorPoint], _ t: Double) -> [VectorPoint] {
        guard startPoints.count == endPoints.count else { return [] }

        let startCGPoints = startPoints.map { CGPoint(x: $0.x, y: $0.y) }
        let endCGPoints = endPoints.map { CGPoint(x: $0.x, y: $0.y) }

        let metalEngine = MetalComputeEngine.shared
        let results = metalEngine.lerpVectorsGPU(from: startCGPoints, to: endCGPoints, t: Float(t))
        switch results {
        case .success(let interpolatedVectors):
            return interpolatedVectors.map { VectorPoint($0) }
        case .failure(_):
            return zip(startPoints, endPoints).map { start, end in
                VectorPoint.lerp(start, end, t)
            }
        }
    }

    func distance(to other: VectorPoint) -> Double {
        let dx = self.x - other.x
        let dy = self.y - other.y
        return sqrt(dx * dx + dy * dy)
    }

    static func distancesBatch(from sourcePoints: [VectorPoint], to targetPoints: [VectorPoint]) -> [Double] {
        guard sourcePoints.count == targetPoints.count else { return [] }

        let sourceCGPoints = sourcePoints.map { CGPoint(x: $0.x, y: $0.y) }
        let targetCGPoints = targetPoints.map { CGPoint(x: $0.x, y: $0.y) }

        let metalEngine = MetalComputeEngine.shared
        let results = metalEngine.calculateDistancesGPU(from: sourceCGPoints, to: targetCGPoints)
        switch results {
        case .success(let distances):
            return distances.map { Double($0) }
        case .failure(_):
            return zip(sourcePoints, targetPoints).map { source, target in
                source.distance(to: target)
            }
        }
    }

    func angle(to other: VectorPoint) -> Double {
        return atan2(other.y - self.y, other.x - self.x)
    }

    var normalized: VectorPoint {
        let length = sqrt(x * x + y * y)
        guard length > 1e-10 else { return VectorPoint(0, 0) }
        return VectorPoint(x / length, y / length)
    }

    static func normalizeBatch(_ vectors: [VectorPoint]) -> [VectorPoint] {
        let cgVectors = vectors.map { CGPoint(x: $0.x, y: $0.y) }

        let metalEngine = MetalComputeEngine.shared
        let results = metalEngine.normalizeVectorsGPU(cgVectors)
        switch results {
        case .success(let normalizedVectors):
            return normalizedVectors.map { VectorPoint($0) }
        case .failure(_):
            return vectors.map { $0.normalized }
        }
    }
}

struct ProfessionalBezierFactory {

    static func createSmoothCurve(from startPoint: VectorPoint, to endPoint: VectorPoint, tension: Double = 0.33) -> [VectorPoint] {
        let direction = VectorPoint(endPoint.x - startPoint.x, endPoint.y - startPoint.y)
        let control1 = VectorPoint(
            startPoint.x + direction.x * tension,
            startPoint.y + direction.y * tension
        )

        let control2 = VectorPoint(
            endPoint.x - direction.x * tension,
            endPoint.y - direction.y * tension
        )

        return [startPoint, control1, control2, endPoint]
    }

    static func createCircularArc(center: VectorPoint, radius: Double, startAngle: Double, endAngle: Double) -> [VectorPoint] {
        let kappa = 0.5522847498307935

        let startPoint = VectorPoint(
            center.x + radius * cos(startAngle),
            center.y + radius * sin(startAngle)
        )

        let endPoint = VectorPoint(
            center.x + radius * cos(endAngle),
            center.y + radius * sin(endAngle)
        )

        let handleLength = radius * kappa

        let control1 = VectorPoint(
            startPoint.x + handleLength * cos(startAngle + .pi / 2),
            startPoint.y + handleLength * sin(startAngle + .pi / 2)
        )

        let control2 = VectorPoint(
            endPoint.x + handleLength * cos(endAngle - .pi / 2),
            endPoint.y + handleLength * sin(endAngle - .pi / 2)
        )

        return [startPoint, control1, control2, endPoint]
    }
}

extension ProfessionalBezierMathematics.ContinuityType {
    var priority: Int {
        switch self {
        case .none: return 0
        case .c0: return 1
        case .g1: return 2
        case .c1: return 3
        case .g2: return 4
        case .c2: return 5
        }
    }
}
