import SwiftUI

struct FillPropertiesSection: View {
    let fillOpacity: Double
    let previewFillOpacity: Double?
    let onApplyFill: () -> Void
    let onOpacityChange: (Double, Bool) -> Void  // value, isPreview
    let onClearPreview: () -> Void

    @State private var isDragging = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fill Properties")
                .font(.headline)
                .fontWeight(.medium)

            VStack(spacing: 8) {
                HStack {
                    Text("Opacity")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                    Spacer()
                    Text("\(Int((previewFillOpacity ?? fillOpacity) * 100))%")
                        .font(.caption)
                        .foregroundColor(Color.ui.secondaryText)
                }

                Slider(
                    value: Binding(
                        get: { previewFillOpacity ?? fillOpacity },
                        set: { newValue in
                            onOpacityChange(newValue, isDragging) // ALWAYS call with current isDragging state
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        isDragging = editing
                        if !editing {
                            // When released, call again with isPreview: false
                            if let preview = previewFillOpacity {
                                onOpacityChange(preview, false)
                            }
                            onClearPreview()
                        }
                    }
                )
                .controlSize(.regular)
            }

            Button("Apply Fill") {
                onApplyFill()
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .frame(minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            .buttonStyle(BorderlessButtonStyle())
            .contentShape(Rectangle())
        }
        .padding()
        .background(Color.ui.semiTransparentControlBackground)
        .cornerRadius(12)
    }
}
