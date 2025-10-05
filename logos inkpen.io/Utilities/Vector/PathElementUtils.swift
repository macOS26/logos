//
//  PathElementUtils.swift
//  logos inkpen.io
//
//  Shared helpers for converting model PathElement arrays into SwiftUI Path commands.
//

import SwiftUI

/// Adds an array of `PathElement` into a SwiftUI `Path`.
/// This is a shared helper so views and utilities can build paths consistently.
/// CRITICAL FIX: Validates all points for NaN and tracks current point to prevent CoreGraphics errors.
@inline(__always)
func addPathElements(_ elements: [PathElement], to path: inout Path) {
    var hasCurrentPoint = false

    for element in elements {
        switch element {
        case .move(let to):
            let point = to.cgPoint
            // CRITICAL FIX: Skip NaN values to prevent CoreGraphics errors
            guard !point.x.isNaN && !point.y.isNaN else {
                continue
            }
            path.move(to: point)
            hasCurrentPoint = true

        case .line(let to):
            let point = to.cgPoint
            // CRITICAL FIX: Skip NaN values and check for current point
            guard !point.x.isNaN && !point.y.isNaN else {
                continue
            }
            if hasCurrentPoint {
                path.addLine(to: point)
            }

        case .curve(let to, let control1, let control2):
            let toPoint = to.cgPoint
            let cp1 = control1.cgPoint
            let cp2 = control2.cgPoint
            // CRITICAL FIX: Skip NaN values and check for current point
            guard !toPoint.x.isNaN && !toPoint.y.isNaN &&
                  !cp1.x.isNaN && !cp1.y.isNaN &&
                  !cp2.x.isNaN && !cp2.y.isNaN else {
                continue
            }
            if hasCurrentPoint {
                path.addCurve(to: toPoint, control1: cp1, control2: cp2)
            }

        case .quadCurve(let to, let control):
            let toPoint = to.cgPoint
            let cp = control.cgPoint
            // CRITICAL FIX: Skip NaN values and check for current point
            guard !toPoint.x.isNaN && !toPoint.y.isNaN &&
                  !cp.x.isNaN && !cp.y.isNaN else {
                continue
            }
            if hasCurrentPoint {
                path.addQuadCurve(to: toPoint, control: cp)
            }

        case .close:
            // CRITICAL FIX: Only close subpath if there's a current point
            if hasCurrentPoint {
                path.closeSubpath()
                hasCurrentPoint = false
            }
        }
    }
}


