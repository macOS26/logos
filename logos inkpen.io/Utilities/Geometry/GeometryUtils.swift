import Foundation
import CoreGraphics
import simd

struct GeometryUtils {

    static func constrainToAngle(from reference: CGPoint, to target: CGPoint, constraintAngles: [Double]) -> CGPoint {
        let dx = target.x - reference.x
        let dy = target.y - reference.y
        let distance = sqrt(dx * dx + dy * dy)

        guard distance > 0.001 else { return target }

        let angle = atan2(dy, dx)
        var angleDegrees = angle * 180.0 / .pi
        if angleDegrees < 0 {
            angleDegrees += 360
        }

        var closestAngle = constraintAngles[0]
        var minDifference = 360.0

        for constraintAngle in constraintAngles {
            let diff = abs(angleDegrees - constraintAngle)
            let wrappedDiff = min(diff, 360 - diff)
            if wrappedDiff < minDifference {
                minDifference = wrappedDiff
                closestAngle = constraintAngle
            }
        }

        let constrainedAngleRad = closestAngle * .pi / 180.0
        let constrainedX = reference.x + distance * cos(constrainedAngleRad)
        let constrainedY = reference.y + distance * sin(constrainedAngleRad)

        return CGPoint(x: constrainedX, y: constrainedY)
    }
}

// MARK: - SIMD4 Extensions for Performance

extension CGRect {
    /// Convert CGRect to SIMD4 for batch processing (x, y, width, height)
    @inline(__always)
    var simd: SIMD4<Double> {
        SIMD4(Double(origin.x), Double(origin.y), Double(size.width), Double(size.height))
    }

    /// Create CGRect from SIMD4 (x, y, width, height)
    @inline(__always)
    init(simd: SIMD4<Double>) {
        self.init(x: CGFloat(simd.x), y: CGFloat(simd.y), width: CGFloat(simd.z), height: CGFloat(simd.w))
    }

    /// Fast bounds intersection test using SIMD
    @inline(__always)
    func intersectsSIMD(_ other: CGRect) -> Bool {
        let a = self.simd
        let b = other.simd

        // Extract min/max coordinates
        let aMin = SIMD2(a.x, a.y)
        let aMax = SIMD2(a.x + a.z, a.y + a.w)
        let bMin = SIMD2(b.x, b.y)
        let bMax = SIMD2(b.x + b.z, b.y + b.w)

        // Check overlap: aMin < bMax && aMax > bMin
        let overlap = (aMin .< bMax) .& (aMax .> bMin)
        return all(overlap)
    }
}

/// Batch rect operations using SIMD
struct SIMDRectOps {
    /// Compute union bounds of multiple rects using SIMD
    @inline(__always)
    static func unionBounds(_ rects: [CGRect]) -> CGRect {
        guard !rects.isEmpty else { return .zero }
        guard rects.count > 1 else { return rects[0] }

        var minX = CGFloat.infinity
        var minY = CGFloat.infinity
        var maxX = -CGFloat.infinity
        var maxY = -CGFloat.infinity

        for rect in rects {
            let simd = rect.simd
            let rectMinX = simd.x
            let rectMinY = simd.y
            let rectMaxX = simd.x + simd.z
            let rectMaxY = simd.y + simd.w

            minX = min(minX, CGFloat(rectMinX))
            minY = min(minY, CGFloat(rectMinY))
            maxX = max(maxX, CGFloat(rectMaxX))
            maxY = max(maxY, CGFloat(rectMaxY))
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Filter rects that intersect viewport using SIMD
    @inline(__always)
    static func filterIntersecting(_ rects: [CGRect], viewport: CGRect) -> [CGRect] {
        rects.filter { $0.intersectsSIMD(viewport) }
    }
}
