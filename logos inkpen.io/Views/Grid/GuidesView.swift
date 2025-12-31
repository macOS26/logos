import SwiftUI

/// Renders guide lines on the canvas in non-photo blue
struct GuidesView: View {
    @ObservedObject var document: VectorDocument
    let zoomLevel: Double
    let canvasOffset: CGPoint
    let canvasSize: CGSize

    @State private var selectedGuideID: UUID?
    @State private var isDraggingGuide = false
    @State private var dragStartPosition: CGFloat = 0

    private let hitTolerance: CGFloat = 5.0

    var body: some View {
        let guides = document.gridSettings.guides
        let showGuides = document.gridSettings.showGuides
        let guidesLocked = document.gridSettings.guidesLocked

        if showGuides && !guides.isEmpty {
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

                // Hit testing overlay when guides are unlocked
                if !guidesLocked {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    if !isDraggingGuide {
                                        // Check if we hit a guide
                                        if let hitGuide = hitTestGuide(at: value.startLocation) {
                                            selectedGuideID = hitGuide.id
                                            isDraggingGuide = true
                                            dragStartPosition = hitGuide.position
                                        }
                                    }

                                    // Move the selected guide
                                    if isDraggingGuide, let guideID = selectedGuideID,
                                       let guideIndex = document.gridSettings.guides.firstIndex(where: { $0.id == guideID }) {
                                        let guide = document.gridSettings.guides[guideIndex]
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
                                    // Delete guide if dragged back to ruler area
                                    if let guideID = selectedGuideID,
                                       let guideIndex = document.gridSettings.guides.firstIndex(where: { $0.id == guideID }) {
                                        let guide = document.gridSettings.guides[guideIndex]
                                        let shouldDelete: Bool
                                        switch guide.orientation {
                                        case .horizontal:
                                            shouldDelete = value.location.y < 20  // Ruler thickness
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
                        .onTapGesture { location in
                            if let hitGuide = hitTestGuide(at: location) {
                                selectedGuideID = hitGuide.id
                            } else {
                                selectedGuideID = nil
                            }
                        }
                }
            }
            .onDeleteCommand {
                // Delete selected guide when Delete key is pressed
                if let guideID = selectedGuideID {
                    document.gridSettings.guides.removeAll { $0.id == guideID }
                    selectedGuideID = nil
                }
            }
        }
    }

    private func hitTestGuide(at location: CGPoint) -> Guide? {
        for guide in document.gridSettings.guides {
            switch guide.orientation {
            case .horizontal:
                let screenY = guide.position * zoomLevel + canvasOffset.y
                if abs(location.y - screenY) < hitTolerance {
                    return guide
                }
            case .vertical:
                let screenX = guide.position * zoomLevel + canvasOffset.x
                if abs(location.x - screenX) < hitTolerance {
                    return guide
                }
            }
        }
        return nil
    }
}
