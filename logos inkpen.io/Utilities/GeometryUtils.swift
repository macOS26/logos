import Foundation

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
