//
//  PathOutline.swift
//  logos
//
//  Created by Todd Bruss on 7/5/25.
//

import SwiftUI

// MARK: - Command Outline (Red with white outline)
struct PathOutline: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    
    var body: some View {
        ZStack {
            if shape.isGroup && !shape.groupedShapes.isEmpty {
                ForEach(shape.groupedShapes.indices, id: \.self) { index in
                    let groupedShape = shape.groupedShapes[index]
                    let cachedPath = Path { path in
                        for element in groupedShape.path.elements {
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
                    cachedPath
                        .stroke(Color.white, lineWidth: 3.0 / zoomLevel)
                        .overlay(
                            cachedPath
                                .stroke(Color.red, lineWidth: 1.5 / zoomLevel)
                        )
                        .transformEffect(groupedShape.transform)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                }
            } else {
                let cachedPath = Path { path in
                    addPathElements(shape.path.elements, to: &path)
                }
                cachedPath
                    .stroke(Color.white, lineWidth: 3.0 / zoomLevel)
                    .overlay(
                        cachedPath
                            .stroke(Color.red, lineWidth: 1.5 / zoomLevel)
                    )
                    .transformEffect(shape.transform)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
            }
        }
        .allowsHitTesting(false)
    }
}
