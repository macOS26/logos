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

        switch textBoxState {
        case .gray : return Color.clear
        case .green: return Color.clear
        case .blue : return Color.blue.opacity(0.5)
        }
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
    let shape: VectorShape
    let dragOffset: CGSize
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    let viewMode: ViewMode

    private var textBounds: CGRect {
        guard let textPosition = shape.textPosition,
              let areaSize = shape.areaSize else {
            return .zero
        }
        return CGRect(x: textPosition.x, y: textPosition.y, width: areaSize.width, height: areaSize.height)
    }

    var body: some View {
        Group {
            ProfessionalTextContentView(
                viewModel: viewModel,
                shape: shape,
                textBoxState: textBoxState,
                viewMode: viewMode
            )
            .position(
                x: textBounds.minX + dragOffset.width + textBounds.width / 2,
                y: textBounds.minY + dragOffset.height + textBounds.height / 2
            )
        }
    }
}

struct ProfessionalTextContentView: View {
    @ObservedObject var viewModel: ProfessionalTextViewModel
    let shape: VectorShape
    let textBoxState: ProfessionalTextCanvas.TextBoxState
    var viewMode: ViewMode = .color

    private var textBounds: CGRect {
        guard let textPosition = shape.textPosition,
              let areaSize = shape.areaSize else {
            return .zero
        }
        return CGRect(x: textPosition.x, y: textPosition.y, width: areaSize.width, height: areaSize.height)
    }

    var body: some View {
        let shouldAllowHitTesting = textBoxState == .blue
        ProfessionalUniversalTextView(viewModel: viewModel, textBoxState: textBoxState, viewMode: viewMode)
            .allowsHitTesting(shouldAllowHitTesting)
            .frame(
                width: textBounds.width,
                height: textBounds.height,
                alignment: .topLeading
            )
            .onAppear {
            }
    }
}
