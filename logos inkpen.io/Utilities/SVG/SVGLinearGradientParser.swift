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


        let x1 = parseGradientCoordinate(x1Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        let y1 = parseGradientCoordinate(y1Raw, gradientUnits: gradientUnits, isXCoordinate: false)
        let x2 = parseGradientCoordinate(x2Raw, gradientUnits: gradientUnits, isXCoordinate: true)
        let y2 = parseGradientCoordinate(y2Raw, gradientUnits: gradientUnits, isXCoordinate: false)


        let transformInfo = parseGradientTransformFromAttributes(attributes)

        let startPoint: CGPoint
        let endPoint: CGPoint

        if let inherited = inheritedGradient, case .linear(let inh) = inherited,
           attributes["x1"] == nil && attributes["y1"] == nil && attributes["x2"] == nil && attributes["y2"] == nil {
            startPoint = inh.startPoint
            endPoint = inh.endPoint
        } else {
            startPoint = CGPoint(x: x1, y: y1)
            endPoint = CGPoint(x: x2, y: y2)
        }

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


        let spreadMethod = parseSpreadMethod(from: attributes)

        let originX = clamp((startPoint.x + endPoint.x) / 2.0, 0.0, 1.0)
        let originY = clamp((startPoint.y + endPoint.y) / 2.0, 0.0, 1.0)

        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: currentGradientStops,
            spreadMethod: spreadMethod,
            units: .objectBoundingBox
        )

        if let inherited = inheritedGradient, case .linear(let inh) = inherited {
            if attributes["gradientUnits"] == nil { linearGradient.units = inh.units }
            if attributes["spreadMethod"] == nil { linearGradient.spreadMethod = inh.spreadMethod }
        }

        linearGradient.originPoint = CGPoint(x: originX, y: originY)
        linearGradient.angle = angleDegrees

        let vectorGradient = VectorGradient.linear(linearGradient)

        return vectorGradient
    }
}
