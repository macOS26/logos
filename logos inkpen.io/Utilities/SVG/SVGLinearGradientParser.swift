import SwiftUI

extension SVGParser {

    internal func parseLinearGradient(attributes: [String: String]) {
        guard let id = attributes["id"] else {
            return
        }

        currentGradientId = id
        currentGradientType = "linearGradient"
        currentGradientAttributes = attributes
        currentGradientStops = []
        isParsingGradient = true

    }

    internal func finishLinearGradientElement(inheritedGradient: VectorGradient?) -> VectorGradient {
        let attributes = currentGradientAttributes
        let gradientUnits = parseGradientUnits(from: attributes)

        let x1Raw = attributes["x1"] ?? "0%"
        let y1Raw = attributes["y1"] ?? "0%"
        let x2Raw = attributes["x2"] ?? "100%"
        let y2Raw = attributes["y2"] ?? "0%"
        var x1 = parseGradientCoordinate(x1Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        var y1 = parseGradientCoordinate(y1Raw, gradientUnits: gradientUnits, isXCoordinate: false)
        var x2 = parseGradientCoordinate(x2Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        var y2 = parseGradientCoordinate(y2Raw, gradientUnits: gradientUnits, isXCoordinate: false)

        var startPoint: CGPoint
        var endPoint: CGPoint

        if let inherited = inheritedGradient, case .linear(let inh) = inherited,
           attributes["x1"] == nil && attributes["y1"] == nil && attributes["x2"] == nil && attributes["y2"] == nil {
            startPoint = inh.startPoint
            endPoint = inh.endPoint
        } else {
            startPoint = CGPoint(x: x1, y: y1)
            endPoint = CGPoint(x: x2, y: y2)
        }

        let spreadMethod = parseSpreadMethod(from: attributes)

        if gradientUnits == .userSpaceOnUse {
            // userSpaceOnUse: apply full gradientTransform to coordinate points at parse time
            // (usvg/SVGView approach — pre-resolve everything)
            if let gradientTransformRaw = attributes["gradientTransform"] {
                let transform = parseTransform(gradientTransformRaw)
                startPoint = startPoint.applying(transform)
                endPoint = endPoint.applying(transform)
                x1 = startPoint.x
                y1 = startPoint.y
                x2 = endPoint.x
                y2 = endPoint.y
            }

            let originX = (startPoint.x + endPoint.x) / 2.0
            let originY = (startPoint.y + endPoint.y) / 2.0
            let angleDegrees = radiansToDegrees(atan2(y2 - y1, x2 - x1))

            var linearGradient = LinearGradient(
                startPoint: startPoint,
                endPoint: endPoint,
                stops: currentGradientStops,
                spreadMethod: spreadMethod,
                units: gradientUnits
            )

            if let inherited = inheritedGradient, case .linear(let inh) = inherited {
                if attributes["gradientUnits"] == nil { linearGradient.units = inh.units }
                if attributes["spreadMethod"] == nil { linearGradient.spreadMethod = inh.spreadMethod }
            }

            linearGradient.originPoint = CGPoint(x: originX, y: originY)
            linearGradient.storedAngle = angleDegrees

            return VectorGradient.linear(linearGradient)
        }

        // objectBoundingBox: existing angle/scale decomposition behavior
        let transformInfo = parseGradientTransformFromAttributes(attributes)

        var deltaX = x2 - x1
        var deltaY = y2 - y1

        if transformInfo.scaleX != 1.0 || transformInfo.scaleY != 1.0 {
            deltaX *= transformInfo.scaleX
            deltaY *= transformInfo.scaleY
        }

        var computedAngle = radiansToDegrees(atan2(deltaY, deltaX))

        if transformInfo.angle != 0.0 {
            computedAngle += transformInfo.angle
        }

        let angleDegrees = computedAngle

        let originX = clamp((startPoint.x + endPoint.x) / 2.0, 0.0, 1.0)
        let originY = clamp((startPoint.y + endPoint.y) / 2.0, 0.0, 1.0)
        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: currentGradientStops,
            spreadMethod: spreadMethod,
            units: gradientUnits
        )

        if let inherited = inheritedGradient, case .linear(let inh) = inherited {
            if attributes["gradientUnits"] == nil { linearGradient.units = inh.units }
            if attributes["spreadMethod"] == nil { linearGradient.spreadMethod = inh.spreadMethod }
        }

        linearGradient.originPoint = CGPoint(x: originX, y: originY)
        linearGradient.angle = angleDegrees

        return VectorGradient.linear(linearGradient)
    }
}
