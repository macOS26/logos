import SwiftUI

struct ProfessionalTextBoxView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let dragOffset: CGSize
    let resizeOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    let isResizeHandleActive: Bool
    let onTextBoxSelect: (CGPoint) -> Void
    let zoomLevel: CGFloat
    let viewMode: ViewMode

    private func getBorderColor() -> Color {
        if viewMode == .keyline {
            return Color.black.opacity(0.5)
        }

        // All states use clear - TransformBoxHandles shows the bounding box
        return Color.clear
    }

    private func getOppositeHueColor(from vectorColor: VectorColor) -> Color {
        switch vectorColor {
        case .white, .black, .clear:
            return Color.blue.opacity(0.5)
        default:
            break
        }

        let nsColor = NSColor(vectorColor.color)
        guard let hsbColor = nsColor.usingColorSpace(.deviceRGB) else {
            return Color.blue.opacity(0.5)
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        hsbColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        if saturation < 0.1 {
            return Color.blue.opacity(0.5)
        }

        let oppositeHue = (hue + 0.5).truncatingRemainder(dividingBy: 1.0)

        return Color(hue: Double(oppositeHue), saturation: Double(saturation), brightness: Double(brightness))
            .opacity(0.5)
    }

    var body: some View {
        ZStack {
            // Use textObject.bounds directly - same as TransformBoxHandles
            let bounds = viewModel.textObject.bounds
            let position = viewModel.textObject.position
            Rectangle()
                .fill(Color.clear)
                .stroke(getBorderColor(), lineWidth: 1.0 / max(zoomLevel, 0.0001))
                .frame(
                    width: bounds.width + resizeOffset.width,
                    height: bounds.height + resizeOffset.height
                )
                .position(
                    x: position.x + dragOffset.width + bounds.width / 2 + resizeOffset.width / 2,
                    y: position.y + dragOffset.height + bounds.height / 2 + resizeOffset.height / 2
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
    let viewMode: ViewMode
    var body: some View {
        Group {
            // Use textObject.bounds directly - same as TransformBoxHandles
            let bounds = viewModel.textObject.bounds
            let position = viewModel.textObject.position
            ProfessionalTextContentView(
                viewModel: viewModel,
                textBoxState: textBoxState,
                viewMode: viewMode
            )
            .position(
                x: position.x + dragOffset.width + bounds.width / 2,
                y: position.y + dragOffset.height + bounds.height / 2
            )
        }
    }
}

struct ProfessionalTextContentView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    var viewMode: ViewMode = .color
    var body: some View {
        let shouldAllowHitTesting = textBoxState == .blue
        // Use textObject.bounds directly - same as TransformBoxHandles
        let bounds = viewModel.textObject.bounds
        ProfessionalUniversalTextView(viewModel: viewModel, textBoxState: textBoxState, viewMode: viewMode)
            .allowsHitTesting(shouldAllowHitTesting)
            .frame(
                width: bounds.width,
                height: bounds.height,
                alignment: .topLeading
            )
            .onAppear {
            }
    }
}
