//
//  GeometryUtils.swift
//  logos inkpen.io
//
//  Geometry utility functions
//

import Foundation

struct GeometryUtils {

    // MARK: - Angle Calculations

/// Constrains a point to specific angles (0°, 30°, 45°, 60°, 90°) relative to a reference point
    /// Used when Shift key is held during drawing operations
    static func constrainToAngle(from reference: CGPoint, to target: CGPoint, constraintAngles: [Double]) -> CGPoint {
        let dx = target.x - reference.x
        let dy = target.y - reference.y
        let distance = sqrt(dx * dx + dy * dy)

        // If too close to reference, return target unchanged
        guard distance > 0.001 else { return target }

        // Calculate angle in radians (-π to π)
        let angle = atan2(dy, dx)

        // Convert to degrees (0 to 360)
        var angleDegrees = angle * 180.0 / .pi
        if angleDegrees < 0 {
            angleDegrees += 360
        }

        // Find closest constraint angle
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

        // Convert back to radians
        let constrainedAngleRad = closestAngle * .pi / 180.0

        // Calculate constrained point at the same distance
        let constrainedX = reference.x + distance * cos(constrainedAngleRad)
        let constrainedY = reference.y + distance * sin(constrainedAngleRad)

        return CGPoint(x: constrainedX, y: constrainedY)
    }
}