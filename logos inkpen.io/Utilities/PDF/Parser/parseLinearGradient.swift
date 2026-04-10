import SwiftUI

// MARK: - PDF Type 2 (Axial/Linear) Shading Parser
//
// Reference: Mozilla pdf.js src/core/pattern.js RadialAxialShading class (lines 139-329).
// https://github.com/mozilla/pdf.js/blob/master/src/core/pattern.js
//
// Per PDF 1.7 spec §8.7.4.5.2, a Type 2 (axial) shading dictionary has:
//   • Coords  — [x0 y0 x1 y1] in the shading's coordinate system (user space)
//   • Domain  — [t0 t1], optional, default [0.0 1.0]  (pattern.js:172-175)
//   • Extend  — [bool bool], optional, default [false false] (pattern.js:179-182)
//   • BBox    — optional bounding box (pattern.js:168)
//   • Background — optional color for areas outside the gradient when Extend is false
//
// IMPORTANT: Coords are in user space, NOT normalized pixel space. pdf.js never
// divides by page dimensions. The Matrix lives on the OUTER Pattern dict (not the
// Shading dict) and is applied at render time — see pattern_helper.js:179-206.

extension PDFCommandParser {

    func parseLinearGradient(from dict: CGPDFDictionaryRef) -> VectorGradient? {
        // Coords: [x0 y0 x1 y1] — pattern.js:156
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

        // Keep coordinates in user space — pdf.js does this (pattern.js:311-316)
        // and applies Matrix + CTM at render time. Dividing by pageSize here is wrong.
        let startPoint = CGPoint(x: Double(x0), y: Double(y0))
        let endPoint = CGPoint(x: Double(x1), y: Double(y1))

        // Extend: [extendStart, extendEnd], default [false, false] — pattern.js:179-182
        // PDF [true, true] == SVG spreadMethod="pad" (extend end colors outward).
        // PDF [false, false] means paint only between t=0 and t=1; background color
        // is used outside. InkPen doesn't have a direct equivalent — we map to .pad
        // and treat background handling as a future bite.
        let spreadMethod: GradientSpreadMethod = .pad

        let stops = extractGradientStops(from: dict)

        var linearGradient = LinearGradient(
            startPoint: startPoint,
            endPoint: endPoint,
            stops: stops,
            spreadMethod: spreadMethod
        )

        // Compute angle from the gradient vector (user space). The CTM rotation
        // is NOT applied here — pdf.js applies the full Matrix at render time
        // (pattern_helper.js:102-142), not during parsing.
        let deltaX = x1 - x0
        let deltaY = y1 - y0
        linearGradient.storedAngle = atan2(deltaY, deltaX) * 180.0 / .pi

        return .linear(linearGradient)
    }
}
