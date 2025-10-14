import SwiftUI

struct FillPropertiesSection: View {
    let fillOpacity: Double
    let onApplyFill: () -> Void
    let onUpdateFillOpacity: (Double) -> Void
    let onFillOpacityEditingChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fill")
                .font(.headline)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int(fillOpacity * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }

                Slider(value: Binding(
                    get: { fillOpacity },
                    set: { onUpdateFillOpacity($0) }
                ), in: 0...1, onEditingChanged: onFillOpacityEditingChanged)
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}
