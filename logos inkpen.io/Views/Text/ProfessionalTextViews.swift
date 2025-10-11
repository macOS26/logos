import SwiftUI

struct ProfessionalTextBoxView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    let isResizeHandleActive: Bool
    let onTextBoxSelect: (CGPoint) -> Void
    let zoomLevel: CGFloat

    private func getBorderColor() -> Color {
        switch textBoxState {
        case .gray: return Color.clear
        case .green: return Color.clear
        case .blue: return Color.blue
        }
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .stroke(getBorderColor(), lineWidth: 1.0 / max(zoomLevel, 0.0001))
                .frame(
                    width: viewModel.textBoxFrame.width + resizeOffset.width,
                    height: viewModel.textBoxFrame.height + resizeOffset.height
                )
                .position(
                    x: viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2 + resizeOffset.width / 2,
                    y: viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2 + resizeOffset.height / 2
                )
                .onTapGesture(count: 1) { location in
                    onTextBoxSelect(location)
                }
                .onTapGesture(count: 2) { location in
                    viewModel.handleTextBoxInteraction(textID: viewModel.textObject.id, isDoubleClick: true)
                }
                .allowsHitTesting(true)

        }
    }
}

struct ProfessionalTextDisplayView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState

    var body: some View {
        Group {
            ProfessionalTextContentView(
                viewModel: viewModel,
                textBoxState: textBoxState
            )
            .position(
                x: viewModel.textBoxFrame.minX + dragOffset.width + viewModel.textBoxFrame.width / 2,
                y: viewModel.textBoxFrame.minY + dragOffset.height + viewModel.textBoxFrame.height / 2
            )
        }
    }
}

struct ProfessionalTextContentView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textBoxState: ProfessionalTextCanvas.TextBoxState

    var body: some View {
        let shouldAllowHitTesting = textBoxState == .blue
        ProfessionalUniversalTextView(viewModel: viewModel, textBoxState: textBoxState)
            .allowsHitTesting(shouldAllowHitTesting)
            .frame(
                width: viewModel.textBoxFrame.width,
                height: viewModel.textBoxFrame.height,
                alignment: .topLeading
            )
            .clipped()
            .onAppear {
            }
    }
}
