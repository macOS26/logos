import SwiftUI

// MARK: - Stable Ink HUD Content
struct StableInkHUDContent: View {
    @Environment(AppState.self) private var appState
    @State private var colorPanelKey = UUID() // Force ColorPanel refresh

    var body: some View {
        if let document = appState.persistentInkHUD.currentDocument {
            VStack(spacing: 0) {
                // Reuse ColorPanel logic exactly like the right panel (no gradient editing)
                ColorPanel(document: document, onColorSelected: { color in
                    // Apply to active target (both default AND selected objects, like Right Panel)
                    if document.activeColorTarget == .stroke {
                        document.defaultStrokeColor = color
                        // CRITICAL FIX: Also apply to selected objects like Right Panel does
                        document.setActiveColor(color)
                    } else {
                        document.defaultFillColor = color
                        // CRITICAL FIX: Also apply to selected objects like Right Panel does
                        document.setActiveColor(color)
                    }
                }, showGradientEditing: false)
                .frame(maxWidth: 350, maxHeight: 520)
                .id(colorPanelKey) // Force refresh when key changes
                
                HStack {
                    Spacer()
                    Button("Close") {
                        appState.persistentInkHUD.hide()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
            .fixedSize()
            .background(Color(NSColor.windowBackgroundColor))
            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            // Listen for selection changes to update the Ink Panel color
            .onChange(of: document.selectedObjectIDs) { _, _ in
                // When selection changes, update the default colors to match selected object
                if let selectedColor = document.getSelectedObjectColor() {
                    if document.activeColorTarget == .stroke {
                        document.defaultStrokeColor = selectedColor
                    } else {
                        document.defaultFillColor = selectedColor
                    }
                    // Force ColorPanel refresh to show new color
                    colorPanelKey = UUID()
                }
            }
        } else {
            // No document yet; empty view
            EmptyView()
        }
    }
}


