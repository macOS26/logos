import SwiftUI

struct ProfessionalToggle: View {
    let title: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle())
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
