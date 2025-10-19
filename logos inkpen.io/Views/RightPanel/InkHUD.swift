import SwiftUI

struct StableInkHUDContent: View {
    @Environment(AppState.self) private var appState
    @State private var colorPanelKey = UUID()

    var body: some View {
        if let document = appState.persistentInkHUD.currentDocument {
            VStack(spacing: 0) {
                ColorPanel(document: document, onColorSelected: { color in
                    document.setActiveColor(color)
                }, showGradientEditing: false)
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
