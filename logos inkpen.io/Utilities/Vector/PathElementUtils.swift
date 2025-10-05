//
//  PathElementUtils.swift
//  logos inkpen.io
//
//  Shared helpers for converting model PathElement arrays into SwiftUI Path commands.
//

import SwiftUI

/// Adds an array of `PathElement` into a SwiftUI `Path`.
/// This is a shared helper so views and utilities can build paths consistently.
@inline(__always)
func addPathElements(_ elements: [PathElement], to path: inout Path) {
    for element in elements {
        switch element {
        case .move(let to):
            path.move(to: to.cgPoint)
        case .line(let to):
            path.addLine(to: to.cgPoint)
        case .curve(let to, let control1, let control2):
            path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
        case .quadCurve(let to, let control):
            path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
        case .close:
            path.closeSubpath()
        }
    }
}


