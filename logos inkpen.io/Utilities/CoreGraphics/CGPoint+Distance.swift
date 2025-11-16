import CoreGraphics

extension CGPoint {
    /// Calculate distance to another point using optimized hypot
    func distance(to other: CGPoint) -> CGFloat {
        hypot(x - other.x, y - other.y)
    }

    /// Calculate squared distance (faster, no sqrt)
    func distanceSquared(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return dx * dx + dy * dy
    }
}
