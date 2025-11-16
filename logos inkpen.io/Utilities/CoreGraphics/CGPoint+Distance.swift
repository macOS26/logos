import CoreGraphics
import simd

extension CGPoint {
    // MARK: - SIMD conversion

    /// Convert to SIMD2<Double> for vectorized operations
    var simd: SIMD2<Double> {
        SIMD2(Double(x), Double(y))
    }

    /// Create from SIMD2<Double>
    init(_ simd: SIMD2<Double>) {
        self.init(x: CGFloat(simd.x), y: CGFloat(simd.y))
    }

    // MARK: - SIMD-optimized operations

    /// Add using SIMD
    func adding(_ other: CGPoint) -> CGPoint {
        CGPoint(simd + other.simd)
    }

    /// Subtract using SIMD
    func subtracting(_ other: CGPoint) -> CGPoint {
        CGPoint(simd - other.simd)
    }

    /// Scale using SIMD
    func scaled(by factor: CGFloat) -> CGPoint {
        CGPoint(simd * Double(factor))
    }

    /// Negate using SIMD
    func negated() -> CGPoint {
        CGPoint(-simd)
    }

    // MARK: - Distance

    /// SIMD-optimized distance using simd_length
    func distance(to other: CGPoint) -> CGFloat {
        CGFloat(simd_length(simd - other.simd))
    }

    /// SIMD-optimized squared distance using simd_length_squared
    func distanceSquared(to other: CGPoint) -> CGFloat {
        CGFloat(simd_length_squared(simd - other.simd))
    }
}
