import SwiftUI

struct StableInkHUDContent: View {
    @Environment(AppState.self) private var appState
    @State private var colorPanelKey = UUID()
    @State private var colorDeltaColor: VectorColor?
    @State private var colorDeltaOpacity: Double?

    var body: some View {
        if let document = appState.persistentInkHUD.currentDocument {
            VStack(spacing: 0) {
                ColorPanel(
                    snapshot: Binding(
                        get: { document.snapshot },
                        set: { document.snapshot = $0 }
                    ),
                    selectedObjectIDs: document.viewState.selectedObjectIDs,
                    activeColorTarget: Binding(
                        get: { document.viewState.activeColorTarget },
                        set: { document.viewState.activeColorTarget = $0 }
                    ),
                    colorMode: Binding(
                        get: { document.settings.colorMode },
                        set: { document.settings.colorMode = $0 }
                    ),
                    defaultFillColor: Binding(
                        get: { document.defaultFillColor },
                        set: { document.defaultFillColor = $0 }
                    ),
                    defaultStrokeColor: Binding(
                        get: { document.defaultStrokeColor },
                        set: { document.defaultStrokeColor = $0 }
                    ),
                    defaultFillOpacity: document.defaultFillOpacity,
                    defaultStrokeOpacity: document.defaultStrokeOpacity,
                    currentSwatches: document.currentSwatches,
                    onTriggerLayerUpdates: { indices in document.triggerLayerUpdates(for: indices) },
                    onAddColorSwatch: { color in document.addColorSwatch(color) },
                    onRemoveColorSwatch: { color in document.removeColorSwatch(color) },
                    onSetActiveColor: { color in document.setActiveColor(color) },
                    colorDeltaColor: $colorDeltaColor,
                    colorDeltaOpacity: $colorDeltaOpacity
                )
                .frame(maxWidth: 350, maxHeight: 520)
                .id(colorPanelKey)

                HStack {
                    Spacer()
                    Button("Close") {
                        appState.persistentInkHUD.hide()
                    }
                    .buttonStyle(ProfessionalPrimaryButtonStyle())
                    .controlSize(.small)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
            .fixedSize()
            .background(Color(NSColor.windowBackgroundColor))
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            .onChange(of: document.viewState.selectedObjectIDs) { _, _ in
                if document.getSelectedObjectColor() != nil {
                    colorPanelKey = UUID()
                }
            }
        } else {
            EmptyView()
        }
    }
}
