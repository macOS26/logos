import SwiftUI

@inline(__always)
func addPathElements(_ elements: [PathElement], to path: inout Path) {
    for element in elements {
        switch element {
        case .move(let to):
            path.move(to: to.cgPoint)
        case .line(let to, _):
            path.addLine(to: to.cgPoint)
        case .curve(let to, let control1, let control2, _):
            path.addCurve(to: to.cgPoint, control1: control1.cgPoint, control2: control2.cgPoint)
        case .quadCurve(let to, let control, _):
            path.addQuadCurve(to: to.cgPoint, control: control.cgPoint)
        case .close:
            path.closeSubpath()
        }
    }
}
