import CoreGraphics
import simd

extension CGPoint {
    /// Create CGPoint from SIMD2
    init(_ simd: SIMD2<Double>) {
        self.init(x: simd.x, y: simd.y)
    }

    /// Convert to SIMD2<Double> for faster arithmetic
    var simd: SIMD2<Double> {
        SIMD2(Double(x), Double(y))
    }

    // MARK: - SIMD-optimized operations

    /// Distance between two points using SIMD
    func distance(to other: CGPoint) -> CGFloat {
        CGFloat(simd_distance(self.simd, other.simd))
    }

    /// Squared distance (faster, no sqrt)
    func distanceSquared(to other: CGPoint) -> CGFloat {
        CGFloat(simd_distance_squared(self.simd, other.simd))
    }

    /// Linear interpolation using SIMD
    func lerp(to other: CGPoint, t: CGFloat) -> CGPoint {
        let t_double = Double(t)
        let result = self.simd + (other.simd - self.simd) * t_double
        return CGPoint(result)
    }

    /// Add using SIMD
    func adding(_ other: CGPoint) -> CGPoint {
        CGPoint(self.simd + other.simd)
    }

    /// Subtract using SIMD
    func subtracting(_ other: CGPoint) -> CGPoint {
        CGPoint(self.simd - other.simd)
    }

    /// Scale using SIMD
    func scaled(by factor: CGFloat) -> CGPoint {
        CGPoint(self.simd * Double(factor))
    }

    /// Divide using SIMD
    func divided(by divisor: CGFloat) -> CGPoint {
        CGPoint(self.simd / Double(divisor))
    }
}
