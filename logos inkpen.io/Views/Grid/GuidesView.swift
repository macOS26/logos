import SwiftUI

/// Renders guide lines on the canvas in non-photo blue
/// Guides are now stored as VectorShape objects in the Guides layer (index 2)
struct GuidesView: View {
    @ObservedObject var document: VectorDocument
    let showGuides: Bool
    let zoomLevel: Double
    let canvasOffset: CGPoint

    var body: some View {
        if showGuides {
            let guideShapes = document.getGuideShapes()
            if !guideShapes.isEmpty {
                Canvas { context, size in
                    for shape in guideShapes {
                        guard shape.isGuide, let orientation = shape.guideOrientation else { continue }

                        // Extract position from the shape's path
                        let position = extractGuidePosition(from: shape, orientation: orientation)

                        let path = Path { p in
                            switch orientation {
                            case .horizontal:
                                let screenY = position * zoomLevel + canvasOffset.y
                                p.move(to: CGPoint(x: 0, y: screenY))
                                p.addLine(to: CGPoint(x: size.width, y: screenY))
                            case .vertical:
                                let screenX = position * zoomLevel + canvasOffset.x
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

    /// Extracts the guide position from the shape's path
    private func extractGuidePosition(from shape: VectorShape, orientation: Guide.Orientation) -> CGFloat {
        // The guide position is stored in the path - for horizontal it's Y, for vertical it's X
        guard let firstElement = shape.path.elements.first else { return 0 }

        switch firstElement {
        case .move(let point):
            switch orientation {
            case .horizontal:
                return CGFloat(point.y)
            case .vertical:
                return CGFloat(point.x)
            }
        default:
            return 0
        }
    }
}
