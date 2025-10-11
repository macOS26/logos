import SwiftUI
import SwiftUI


struct TextScaleHandles: View {
    @ObservedObject var document: VectorDocument
    let textObject: VectorText
    let zoomLevel: Double
    let canvasOffset: CGPoint

    private let handleSize: CGFloat = 8

    var body: some View {
        let bounds = textObject.bounds
        let absoluteBounds = CGRect(
            x: textObject.position.x,
            y: textObject.position.y,
            width: bounds.width,
            height: bounds.height
        )
        let center = CGPoint(x: absoluteBounds.midX, y: absoluteBounds.midY)

        ZStack {
            Rectangle()
                .stroke(Color.red, lineWidth: 1.0 / zoomLevel)
                .frame(width: absoluteBounds.width, height: absoluteBounds.height)
                .position(center)
                .scaleEffect(zoomLevel, anchor: .topLeading)
                .offset(x: canvasOffset.x, y: canvasOffset.y)
                .transformEffect(textObject.transform)

            ForEach(0..<4) { i in
                let position = cornerPosition(for: i, in: absoluteBounds, center: center)
                Rectangle()
                    .fill(Color.red)
                    .stroke(Color.white, lineWidth: 1.0)
                    .frame(width: handleSize / zoomLevel, height: handleSize / zoomLevel)
                    .position(position)
                    .scaleEffect(zoomLevel, anchor: .topLeading)
                    .offset(x: canvasOffset.x, y: canvasOffset.y)
                    .transformEffect(textObject.transform)
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
