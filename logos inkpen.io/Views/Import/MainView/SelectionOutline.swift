import SwiftUI
import AppKit

struct SelectionOutline: View {
    @ObservedObject var document: VectorDocument
    let shape: VectorShape
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let isOptionPressed: Bool

    private let handleSize: CGFloat = 8

    var body: some View {
        if isOptionPressed {
            ZStack {
                if shape.isGroup && !shape.groupedShapes.isEmpty {
                    ForEach(Array(shape.groupedShapes.indices), id: \.self) { index in
                        let groupedShape = shape.groupedShapes[index]
                        let cachedPath = Path { path in
                            for element in groupedShape.path.elements {
                                switch element {
                                case .move(let to, _):
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
                        cachedPath
                            .stroke(Color.blue, lineWidth: 2.0 / zoomLevel)
                            .transformEffect(groupedShape.transform)
                            .scaleEffect(zoomLevel, anchor: .topLeading)
                            .offset(x: canvasOffset.x, y: canvasOffset.y)
                    }
                } else {
                    let cachedPath = Path { path in
                        for element in shape.path.elements {
                            switch element {
                            case .move(let to, _):
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
                    cachedPath
                        .stroke(Color.blue, lineWidth: 2.0 / zoomLevel)
                        .transformEffect(shape.transform)
                        .scaleEffect(zoomLevel, anchor: .topLeading)
                        .offset(x: canvasOffset.x, y: canvasOffset.y)
                }
            }
        } else if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
            let warpedBounds = shape.bounds
            let center = CGPoint(x: warpedBounds.midX, y: warpedBounds.midY)

            ZStack {
                Path { path in
                    path.addRect(warpedBounds)
                }
                .stroke(Color.blue, style: SwiftUI.StrokeStyle(lineWidth: 1.0 / zoomLevel, dash: [5.0 / zoomLevel, 5.0 / zoomLevel]))
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)

                Rectangle()
                    .fill(Color.blue)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize, height: handleSize)
                    .position(CGPoint(
                        x: center.x * zoomLevel + canvasOffset.x,
                        y: center.y * zoomLevel + canvasOffset.y
                    ))

                ForEach(0..<4) { i in
                    let position = cornerPosition(for: i, in: warpedBounds, center: center)

                    Rectangle()
                        .fill(Color.blue)
                        .stroke(Color.white, lineWidth: 1.0)
                        .frame(width: handleSize, height: handleSize)
                        .position(CGPoint(
                            x: position.x * zoomLevel + canvasOffset.x,
                            y: position.y * zoomLevel + canvasOffset.y
                        ))
                }
            }
        } else {
            let baseBounds: CGRect = {
                if shape.isWarpObject && !shape.warpEnvelope.isEmpty && shape.warpEnvelope.count == 4 {
                    let minX = shape.warpEnvelope.map { $0.x }.min() ?? 0
                    let maxX = shape.warpEnvelope.map { $0.x }.max() ?? 0
                    let minY = shape.warpEnvelope.map { $0.y }.min() ?? 0
                    let maxY = shape.warpEnvelope.map { $0.y }.max() ?? 0
                    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                } else if let warpBounds = document.viewState.warpBounds[shape.id] {
                    return warpBounds
                } else {
                    return shape.isGroupContainer ? shape.groupBounds : shape.bounds
                }
            }()

            let strokeExpandedBounds: CGRect = {
                let isStrokeOnly = (shape.fillStyle?.color == .clear || shape.fillStyle == nil)
                if isStrokeOnly && shape.strokeStyle != nil {
                    let strokeWidth = shape.strokeStyle?.width ?? 1.0
                    let strokeExpansion = strokeWidth / 2.0
                    return baseBounds.insetBy(dx: -strokeExpansion, dy: -strokeExpansion)
                } else {
                    return baseBounds
                }
            }()

            let center = CGPoint(x: strokeExpandedBounds.midX, y: strokeExpandedBounds.midY)
            let transformedBounds: CGRect = {
                if shape.isWarpObject && !shape.warpEnvelope.isEmpty {
                    return strokeExpandedBounds
                } else {
                    let t = shape.transform
                    let corners = [
                        CGPoint(x: strokeExpandedBounds.minX, y: strokeExpandedBounds.minY).applying(t),
                        CGPoint(x: strokeExpandedBounds.maxX, y: strokeExpandedBounds.minY).applying(t),
                        CGPoint(x: strokeExpandedBounds.maxX, y: strokeExpandedBounds.maxY).applying(t),
                        CGPoint(x: strokeExpandedBounds.minX, y: strokeExpandedBounds.maxY).applying(t)
                    ]
                    let minX = corners.map { $0.x }.min() ?? strokeExpandedBounds.minX
                    let minY = corners.map { $0.y }.min() ?? strokeExpandedBounds.minY
                    let maxX = corners.map { $0.x }.max() ?? strokeExpandedBounds.maxX
                    let maxY = corners.map { $0.y }.max() ?? strokeExpandedBounds.maxY
                    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                }
            }()

            ZStack {
                if shape.isWarpObject {
                    SharedEnvelopeOutline(
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        color: .blue,
                        lineWidth: 1.0,
                        isDashed: false
                    )
                } else {
                    Path { path in
                        path.addRect(transformedBounds)
                    }
                    .stroke(Color.blue, lineWidth: 1.0 / zoomLevel)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                }

                let transformedCenter = (shape.isWarpObject && !shape.warpEnvelope.isEmpty) ?
                    center : CGPoint(x: center.x, y: center.y).applying(shape.transform)
                Rectangle()
                    .fill(Color.blue)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize, height: handleSize)
                    .position(CGPoint(
                        x: transformedCenter.x * zoomLevel + canvasOffset.x,
                        y: transformedCenter.y * zoomLevel + canvasOffset.y
                    ))

                if shape.isWarpObject {
                    SharedEnvelopeCorners(
                        shape: shape,
                        zoomLevel: zoomLevel,
                        canvasOffset: canvasOffset,
                        handleSize: handleSize,
                        handleColor: .blue
                    )
                } else {
                    ForEach(0..<4) { i in
                        let position = cornerPosition(for: i, in: baseBounds, center: center)
                        let transformedCorner = CGPoint(x: position.x, y: position.y).applying(shape.transform)

                        Rectangle()
                            .fill(Color.blue)
                            .stroke(Color.white, lineWidth: 1.0)
                            .frame(width: handleSize, height: handleSize)
                            .position(CGPoint(
                                x: transformedCorner.x * zoomLevel + canvasOffset.x,
                                y: transformedCorner.y * zoomLevel + canvasOffset.y
                            ))
                    }
                }
            }
        }
    }

    private func cornerPosition(for index: Int, in bounds: CGRect, center: CGPoint) -> CGPoint {
        switch index {
        case 0: return CGPoint(x: bounds.minX, y: bounds.minY)
        case 1: return CGPoint(x: bounds.maxX, y: bounds.minY)
        case 2: return CGPoint(x: bounds.maxX, y: bounds.maxY)
        case 3: return CGPoint(x: bounds.minX, y: bounds.maxY)
        default: return center
        }
    }
}