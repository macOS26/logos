import SwiftUI

/// Renders guide lines on the canvas in non-photo blue
struct GuidesView: View, Equatable {
    let guides: [Guide]
    let showGuides: Bool
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let canvasSize: CGSize

    static func == (lhs: GuidesView, rhs: GuidesView) -> Bool {
        lhs.guides == rhs.guides &&
        lhs.showGuides == rhs.showGuides &&
        lhs.zoomLevel == rhs.zoomLevel &&
        lhs.canvasOffset == rhs.canvasOffset &&
        lhs.canvasSize == rhs.canvasSize
    }

    var body: some View {
        if showGuides && !guides.isEmpty {
            Canvas { context, size in
                for guide in guides {
                    let path = Path { p in
                        switch guide.orientation {
                        case .horizontal:
                            let screenY = guide.position * zoomLevel + canvasOffset.y
                            p.move(to: CGPoint(x: 0, y: screenY))
                            p.addLine(to: CGPoint(x: size.width, y: screenY))
                        case .vertical:
                            let screenX = guide.position * zoomLevel + canvasOffset.x
                            p.move(to: CGPoint(x: screenX, y: 0))
                            p.addLine(to: CGPoint(x: screenX, y: size.height))
                        }
                    }
                    context.stroke(path, with: .color(Color.nonPhotoBlue), lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }
    }
}
