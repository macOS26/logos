import SwiftUI

struct RightPanel: View {
    @ObservedObject var document: VectorDocument
    @Binding var layerPreviewOpacities: [UUID: Double]
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
                    LayersPanel(document: document, layerPreviewOpacities: $layerPreviewOpacities)
                case .properties:
                    StrokeFillPanel(
                        snapshot: document.snapshot,
                        selectedObjectIDs: document.viewState.selectedObjectIDs,
                        document: document
                    )
                case .gradient:
                    GradientPanel(
                        snapshot: document.snapshot,
                        selectedObjectIDs: document.viewState.selectedObjectIDs,
                        document: document
                    )
                case .color:
                    ColorPanel(
                        snapshot: document.snapshot,
                        selectedObjectIDs: document.viewState.selectedObjectIDs,
                        document: document
                    )
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
    RightPanel(document: VectorDocument(), layerPreviewOpacities: .constant([:]))
        .frame(height: 600)
}
