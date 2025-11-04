import SwiftUI

struct AnchorPointTypeSection: View {
    let selectedPointType: AnchorPointType?
    let onUpdatePointType: (AnchorPointType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Anchor Point")
                .font(.caption)
                .foregroundColor(Color.ui.secondaryText)

            HStack(spacing: 6) {
                ForEach([AnchorPointType.corner, .cusp, .smooth], id: \.self) { pointType in
                    Button {
                        onUpdatePointType(pointType)
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: pointType.iconName)
                                .font(.system(size: 12))

                            Text(pointType.displayName)
                                .font(.caption2)
                        }
                        .foregroundColor(selectedPointType == pointType ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedPointType == pointType ? Color.accentColor.opacity(0.1) : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(selectedPointType == pointType ? Color.accentColor.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 0.5)
                                )
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .help(pointType.description)
                }
            }
        }
    }
}

// MARK: - AnchorPointType UI Extensions
extension AnchorPointType {
    var iconName: String {
        switch self {
        case .corner:
            return "square"
        case .cusp:
            return "diamond"
        case .smooth:
            return "circle"
        }
    }

    var displayName: String {
        switch self {
        case .corner:
            return "Corner"
        case .cusp:
            return "Cusp"
        case .smooth:
            return "Smooth"
        }
    }

    var description: String {
        switch self {
        case .corner:
            return "Sharp corner with no handles or independent angles"
        case .cusp:
            return "Independent curve handles with no tangency constraint"
        case .smooth:
            return "Smooth curve with 180° tangent handles"
        }
    }
}
