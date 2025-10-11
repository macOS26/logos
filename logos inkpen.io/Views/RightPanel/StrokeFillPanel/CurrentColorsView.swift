import SwiftUI

struct ColorLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2)
            .foregroundColor(Color.ui.secondaryText)
    }
}

struct ColorSwatchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension View {
    func colorLabelStyle() -> some View {
        modifier(ColorLabelStyle())
    }
}

struct CurrentColorsView: View {
    let strokeColor: VectorColor
    let fillColor: VectorColor
    let strokeOpacity: Double
    let fillOpacity: Double
    let onStrokeColorTap: () -> Void
    let onFillColorTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ColorSwatchView(
                color: fillColor,
                opacity: fillOpacity,
                label: "Fill",
                action: onFillColorTap
            )
            
            ColorSwatchView(
                color: strokeColor,
                opacity: strokeOpacity,
                label: "Stroke",
                action: onStrokeColorTap
            )
        }
        .padding(12)
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(8)
    }
}

private struct ColorSwatchView: View {
    let color: VectorColor
    let opacity: Double
    let label: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 4) {
            Button(action: action) {
                renderColorSwatchRightPanel(
                    color,
                    width: 30,
                    height: 30,
                    cornerRadius: 0,
                    borderWidth: 1,
                    opacity: opacity
                )
            }
            .buttonStyle(ColorSwatchButtonStyle())
            
            Text(label)
                .colorLabelStyle()
        }
    }
}
