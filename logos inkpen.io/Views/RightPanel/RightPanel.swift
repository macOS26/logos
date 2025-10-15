import SwiftUI

struct RightPanel: View {
    @ObservedObject var document: VectorDocument
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            PanelTabBar(selectedTab: Binding(
                get: { appState.selectedPanelTab },
                set: { appState.selectedPanelTab = $0 }
            ))

            Group {
                switch appState.selectedPanelTab {
                case .layers:
                    LayersPanel(document: document)
                case .properties:
                    StrokeFillPanel(document: document)
                case .gradient:
                    GradientPanel(document: document)
                case .color:
                    ColorPanel(document: document)
                case .pathOps:
                    PathOperationsPanel(document: document)
                case .font:
                    FontPanel(document: document)
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5),
            alignment: .leading
        )

    }
}

#Preview {
    RightPanel(document: VectorDocument())
        .frame(height: 600)
}
