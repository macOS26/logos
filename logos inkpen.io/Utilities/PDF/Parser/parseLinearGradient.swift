import SwiftUI

// MARK: - PDF Type 2 (Axial/Linear) Shading Parser
// Ref: pdf.js pattern.js RadialAxialShading. Coords are user-space; Matrix on OUTER Pattern dict applied at render time.

extension PDFCommandParser {

    func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        var coordsArray: CGPDFArrayRef?
        guard CGPDFDictionaryGetArray(dict, "Coords", &coordsArray),
              let coords = coordsArray,
              CGPDFArrayGetCount(coords) >= 4 else {
            return nil
        }

        var x0: CGFloat = 0, y0: CGFloat = 0, x1: CGFloat = 0, y1: CGFloat = 0
        CGPDFArrayGetNumber(coords, 0, &x0)
        CGPDFArrayGetNumber(coords, 1, &y0)
        CGPDFArrayGetNumber(coords, 2, &x1)
        CGPDFArrayGetNumber(coords, 3, &y1)

        // User-space coords — Matrix + CTM applied at render time (pdf.js pattern.js:311-316).
        let startPoint = CGPoint(x: Double(x0), y: Double(y0))
        let endPoint = CGPoint(x: Double(x1), y: Double(y1))

        // Extend mapped to .pad; background-color handling is a future bite.
        let spreadMethod: GradientSpreadMethod = .pad

        let stops = extractGradientStops(from: dict)

        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: stops,
            spreadMethod: spreadMethod
        )

        // Angle from user-space vector; CTM rotation applied at render time (pdf.js pattern_helper.js:102-142).
        let deltaX = x1 - x0
        let deltaY = y1 - y0
        linearGradient.storedAngle = atan2(deltaY, deltaX) * 180.0 / .pi

        return .linear(linearGradient)
    }
}
