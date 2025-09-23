//
//  FileOperations.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

class FileOperations {
    /// Convert VectorPath to CGPath
    static func convertVectorPathToCGPath(_ vectorPath: VectorPath) -> CGPath {
        let cgPath = CGMutablePath()

        for element in vectorPath.elements {
            switch element {
            case .move(let point):
                cgPath.move(to: CGPoint(x: point.x, y: point.y))
            case .line(let point):
                cgPath.addLine(to: CGPoint(x: point.x, y: point.y))
            case .curve(let point, let control1, let control2):
                cgPath.addCurve(
                    to: CGPoint(x: point.x, y: point.y),
                    control1: CGPoint(x: control1.x, y: control1.y),
                    control2: CGPoint(x: control2.x, y: control2.y)
                )
            case .quadCurve(let point, let control):
                cgPath.addQuadCurve(
                    to: CGPoint(x: point.x, y: point.y),
                    control: CGPoint(x: control.x, y: control.y)
                )
            case .close:
                cgPath.closeSubpath()
            }
        }

        return cgPath
    }
}