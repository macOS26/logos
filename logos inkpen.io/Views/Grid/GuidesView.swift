import SwiftUI

/// Renders guide lines on the canvas in non-photo blue
/// Guides are movable when Guides layer is unlocked
struct GuidesView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint

    @State private var selectedGuideID: UUID?
    @State private var isDraggingGuide = false

    private let hitTolerance: CGFloat = 8.0

    /// Check if Guides layer is locked
    private var guidesLayerLocked: Bool {
        // Guides layer is at index 2
        guard document.snapshot.layers.count > 2 else { return true }
        return document.snapshot.layers[2].isLocked
    }

    /// Check if Guides layer is visible
    private var guidesLayerVisible: Bool {
        guard document.snapshot.layers.count > 2 else { return false }
        return document.snapshot.layers[2].isVisible
    }

    var body: some View {
        let guides = document.gridSettings.guides

        if guidesLayerVisible && !guides.isEmpty {
            ZStack {
                // Render all guides
                Canvas { context, size in
                    for guide in guides {
                        let isSelected = guide.id == selectedGuideID
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
                        let lineWidth: CGFloat = isSelected ? 2 : 1
                        context.stroke(path, with: .color(Color.nonPhotoBlue), lineWidth: lineWidth)
                    }
                }
                .allowsHitTesting(false)

                // Hit testing areas ONLY on guide lines when unlocked
                if !guidesLayerLocked {
                    ForEach(guides) { guide in
                        guideHitArea(for: guide)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func guideHitArea(for guide: Guide) -> some View {
        GeometryReader { geometry in
            guideHitRectangle(for: guide, in: geometry.size)
        }
    }

    @ViewBuilder
    private func guideHitRectangle(for guide: Guide, in size: CGSize) -> some View {
        let hitArea: CGRect = {
            switch guide.orientation {
            case .horizontal:
                let screenY = guide.position * zoomLevel + canvasOffset.y
                return CGRect(x: 0, y: screenY - hitTolerance, width: size.width, height: hitTolerance * 2)
            case .vertical:
                let screenX = guide.position * zoomLevel + canvasOffset.x
                return CGRect(x: screenX - hitTolerance, y: 0, width: hitTolerance * 2, height: size.height)
            }
        }()

        Rectangle()
            .fill(Color.clear)
            .frame(width: hitArea.width, height: hitArea.height)
            .position(x: hitArea.midX, y: hitArea.midY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        selectedGuideID = guide.id
                        isDraggingGuide = true

                        // Move the guide
                        if let guideIndex = document.gridSettings.guides.firstIndex(where: { $0.id == guide.id }) {
                            let newPosition: CGFloat
                            switch guide.orientation {
                            case .horizontal:
                                newPosition = (value.location.y - canvasOffset.y) / zoomLevel
                            case .vertical:
                                newPosition = (value.location.x - canvasOffset.x) / zoomLevel
                            }
                            document.gridSettings.guides[guideIndex].position = newPosition
                        }
                    }
                    .onEnded { value in
                        // Delete guide if dragged back to ruler area (< 20 pixels)
                        if let guideIndex = document.gridSettings.guides.firstIndex(where: { $0.id == guide.id }) {
                            let shouldDelete: Bool
                            switch guide.orientation {
                            case .horizontal:
                                shouldDelete = value.location.y < 20
                            case .vertical:
                                shouldDelete = value.location.x < 20
                            }
                            if shouldDelete {
                                document.gridSettings.guides.remove(at: guideIndex)
                            }
                        }
                        isDraggingGuide = false
                    }
            )
    }
}
