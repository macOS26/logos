import SwiftUI

extension PDFCommandParser {

    func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        CGPDFDictionaryApplyFunction(dict, { key, value, info in
            let keyString = String(cString: key)

            if keyString == "Matrix" || keyString == "Transform" {
                var array: CGPDFArrayRef?
                if CGPDFObjectGetValue(value, .array, &array), let matrixArray = array {
                    let count = CGPDFArrayGetCount(matrixArray)
                    var matrixValues: [CGFloat] = []
                    for i in 0..<count {
                        var num: CGFloat = 0
                        CGPDFArrayGetNumber(matrixArray, i, &num)
                        matrixValues.append(num)
                    }
                }
            }

        }, nil)

        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray else {
            return nil
        }

        var x0: CGFloat = 0, y0: CGFloat = 0, x1: CGFloat = 0, y1: CGFloat = 0
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &x1)
        CGPDFArrayGetNumber(coords, 3, &y1)

        let needsNormalization = (abs(x0) > 1.0 || abs(y0) > 1.0 || abs(x1) > 1.0 || abs(y1) > 1.0)

        let startPoint: CGPoint
        let endPoint: CGPoint

        if needsNormalization && pageSize.width > 0 && pageSize.height > 0 {
            startPoint = CGPoint(x: Double(x0 / pageSize.width), y: Double(y0 / pageSize.height))
            endPoint = CGPoint(x: Double(x1 / pageSize.width), y: Double(y1 / pageSize.height))
        } else {
            startPoint = CGPoint(x: Double(x0), y: Double(y0))
            endPoint = CGPoint(x: Double(x1), y: Double(y1))
        }

        let deltaX = x1 - x0
        let deltaY = y1 - y0
        let coordinateAngle = atan2(deltaY, deltaX) * 180.0 / .pi

        let ctmAngle = atan2(-currentTransformMatrix.b, currentTransformMatrix.a) * 180.0 / .pi
        let angleDegrees = coordinateAngle + ctmAngle

        let stops = extractGradientStops(from: dict)

        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: stops,
            spreadMethod: GradientSpreadMethod.pad
        )

        linearGradient.storedAngle = angleDegrees

        return .linear(linearGradient)
    }
}
