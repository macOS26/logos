//
//  PDFCurveOptimizer.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 8/31/25.
//

import SwiftUI

/// Utilities for curve optimization and path simplification
struct PDFCurveOptimizer {

    /// Check if a cubic curve can be represented as a quadratic curve
    static func convertToQuadCurve(
        from start: CGPoint,
        cp1: CGPoint,
        cp2: CGPoint,
        to end: CGPoint
    ) -> PathCommand? {

        // Check if cubic curve can be represented as quadratic
        // This happens when the control points follow the quadratic relationship:
        // cp1 = start + 2/3 * (quad_cp - start)
        // cp2 = end + 2/3 * (quad_cp - end)

        // Calculate potential quadratic control point
        let potentialQCP1 = CGPoint(
            x: start.x + 1.5 * (cp1.x - start.x),
            y: start.y + 1.5 * (cp1.y - start.y)
        )

        let potentialQCP2 = CGPoint(
            x: end.x + 1.5 * (cp2.x - end.x),
            y: end.y + 1.5 * (cp2.y - end.y)
        )

        // Check if both calculations give the same control point (within tolerance)
        let tolerance: CGFloat = 0.1
        if abs(potentialQCP1.x - potentialQCP2.x) < tolerance &&
           abs(potentialQCP1.y - potentialQCP2.y) < tolerance {

            let quadCP = CGPoint(
                x: (potentialQCP1.x + potentialQCP2.x) / 2,
                y: (potentialQCP1.y + potentialQCP2.y) / 2
            )

            return .quadCurveTo(cp: quadCP, to: end)
        }

        return nil
    }
}