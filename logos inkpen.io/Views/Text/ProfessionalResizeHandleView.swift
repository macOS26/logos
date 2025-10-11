
import SwiftUI

struct ProfessionalResizeHandleView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let zoomLevel: CGFloat
    let onResizeChanged: (DragGesture.Value) -> Void
    let onResizeEnded: () -> Void
    let onResizeStarted: () -> Void

    @State private var hasResizeStarted = false

    var body: some View {
        Circle()
            .fill(Color.blue)
            .stroke(Color.white, lineWidth: 1.0 / zoomLevel)
            .frame(width: 10 / zoomLevel, height: 10 / zoomLevel)
            .position(
                x: viewModel.textBoxFrame.maxX + dragOffset.width + resizeOffset.width,
                y: viewModel.textBoxFrame.maxY + dragOffset.height + resizeOffset.height
            )
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if !hasResizeStarted {
                            hasResizeStarted = true
                            onResizeStarted()
                        }
                        onResizeChanged(value)
                    }
                    .onEnded { _ in
                        hasResizeStarted = false
                        onResizeEnded()
                    }
            )
            .onAppear {
            }
    }
}
