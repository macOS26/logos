import SwiftUI
import AppKit

struct StableGradientHUDContent: View, Equatable {
    let hudManager: PersistentGradientHUDManager

    static func == (lhs: StableGradientHUDContent, rhs: StableGradientHUDContent) -> Bool {
        return lhs.hudManager.editingStopId == rhs.hudManager.editingStopId &&
               lhs.hudManager.editingStopColor == rhs.hudManager.editingStopColor &&
               lhs.hudManager.isVisible == rhs.hudManager.isVisible
    }

    var body: some View {
        VStack(spacing: 0) {
            StableColorPanelWrapper(hudManager: hudManager)
                .frame(maxWidth: 350, maxHeight: 500)

            HStack {
                Spacer()

                Button("Close") {
                    hudManager.hide()
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
    }
}

struct StableColorPanelWrapper: View, Equatable {
    let hudManager: PersistentGradientHUDManager
    @State private var colorDeltaColor: VectorColor?
    @State private var colorDeltaOpacity: Double?

    static func == (lhs: StableColorPanelWrapper, rhs: StableColorPanelWrapper) -> Bool {
        return lhs.hudManager.editingStopId == rhs.hudManager.editingStopId
    }

    var body: some View {
        let document = hudManager.getStableDocument()
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
            onSetActiveColor: { color in
                if let stopId = hudManager.editingStopId {
                    hudManager.updateStopColor(stopId, color)
                }
            },
            colorDeltaColor: $colorDeltaColor,
            colorDeltaOpacity: $colorDeltaOpacity
        )
        .fixedSize()
    }
}
