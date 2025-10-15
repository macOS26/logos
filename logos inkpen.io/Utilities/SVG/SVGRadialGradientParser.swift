import SwiftUI

extension SVGParser {

    internal func parseRadialGradientCoordinates(from attributes: [String: String]) -> (cx: String, cy: String, r: String, fx: String?, fy: String?) {
        return (
            cx: attributes["cx"] ?? "50%",
            cy: attributes["cy"] ?? "50%",
            r: attributes["r"] ?? "50%",
            fx: attributes["fx"],
            fy: attributes["fy"]
        )
    }

    internal func parseRadialGradient(attributes: [String: String]) {
        guard let id = attributes["id"] else {
            return
        }

        currentGradientId = id
        currentGradientType = "radialGradient"
        currentGradientAttributes = attributes
        currentGradientStops = []
        isParsingGradient = true

        let (cxRaw, cyRaw, rRaw, fxRaw, fyRaw) = parseRadialGradientCoordinates(from: attributes)
        let hasExtremeValues = detectExtremeValuesInRadialGradient(
            cx: cxRaw, cy: cyRaw, r: rRaw, fx: fxRaw, fy: fyRaw
        )

        if hasExtremeValues {
            detectedExtremeValues = true
            useExtremeValueHandling = true
        }

    }

    internal func detectExtremeValuesInRadialGradient(cx: String, cy: String, r: String, fx: String?, fy: String?) -> Bool {
        let coordinates = [cx, cy, r, fx, fy].compactMap { $0 }

        for coord in coordinates {
            if coord.hasSuffix("%") { continue }

            if let value = Double(coord) {
                if value < -10000 || value > 10000 {
                    return true
                }

                if viewBoxWidth > 0 && viewBoxHeight > 0 {
                    let normalizer = coord == cx || coord == fx ? viewBoxWidth : viewBoxHeight
                    let normalizedValue = value / normalizer

                    if normalizedValue < 0.0 || normalizedValue > 1.0 {
                        return true
                    }
                }
            }
        }

        return false
    }

    internal func finishRadialGradientElement(inheritedGradient: VectorGradient?) -> VectorGradient {
        let attributes = currentGradientAttributes
        let gradientUnits = parseGradientUnits(from: attributes)

        let (cxRaw, cyRaw, rRaw, fxRaw, fyRaw) = parseRadialGradientCoordinates(from: attributes)
        let useExtremeHandling = useExtremeValueHandling && detectedExtremeValues

        let cx = parseGradientCoordinate(cxRaw, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling)
        let cy = parseGradientCoordinate(cyRaw, gradientUnits: gradientUnits, isXCoordinate: false, useExtremeValueHandling: useExtremeHandling)
        let r = parseGradientCoordinate(rRaw, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling)
        let fx = fxRaw != nil ? parseGradientCoordinate(fxRaw!, gradientUnits: gradientUnits, isXCoordinate: true, useExtremeValueHandling: useExtremeHandling) : cx
        let fy = fyRaw != nil ? parseGradientCoordinate(fyRaw!, gradientUnits: gradientUnits, isXCoordinate: false, useExtremeValueHandling: useExtremeHandling) : cy
        var centerPoint: CGPoint
        var focalPoint: CGPoint

        if useExtremeHandling {
            centerPoint = CGPoint(x: 0.5, y: 0.5)
            focalPoint = CGPoint(x: 0.5, y: 0.5)
        } else {
            centerPoint = CGPoint(x: cx, y: cy)
            focalPoint = CGPoint(x: fx, y: fy)
        }

        let finalRadius: Double
        if useExtremeHandling {
            finalRadius = 0.5
        } else {
            finalRadius = r
        }

        let spreadMethod = parseSpreadMethod(from: attributes)
        let (gradientAngle, gradientScaleX, gradientScaleY) = parseGradientTransformFromAttributes(attributes)

        var radialGradient = RadialGradient(
            centerPoint: centerPoint,
            radius: max(0.001, finalRadius),
            stops: currentGradientStops,
            focalPoint: focalPoint,
            spreadMethod: spreadMethod,
            units: .objectBoundingBox
        )

        if let inherited = inheritedGradient, case .radial(let inh) = inherited {
            if attributes["cx"] == nil && attributes["cy"] == nil { radialGradient.centerPoint = inh.centerPoint }
            if attributes["r"] == nil { radialGradient.radius = inh.radius }
            if attributes["gradientUnits"] == nil { radialGradient.units = inh.units }
            if attributes["spreadMethod"] == nil { radialGradient.spreadMethod = inh.spreadMethod }
        }

        radialGradient.originPoint = centerPoint
        radialGradient.angle = gradientAngle
        radialGradient.scaleX = abs(gradientScaleX)
        radialGradient.scaleY = abs(gradientScaleY)

        let vectorGradient = VectorGradient.radial(radialGradient)

        return vectorGradient
    }
}
