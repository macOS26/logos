import SwiftUI
import AppKit


struct PersistentGradientHUDView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        let hudManager = appState.persistentGradientHUD

        if hudManager.isVisible {
            StableGradientHUDContent(hudManager: hudManager)
                .animation(.none, value: hudManager.isDragging)
        }
    }
}

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

    static func == (lhs: StableColorPanelWrapper, rhs: StableColorPanelWrapper) -> Bool {
        return lhs.hudManager.editingStopId == rhs.hudManager.editingStopId
    }

    var body: some View {
                                ColorPanel(
            document: hudManager.getStableDocument(),
            onColorSelected: { newColor in
                if let stopId = hudManager.editingStopId {
                    hudManager.updateStopColor(stopId, newColor)
                }
            },
            showGradientEditing: true
        )
        .fixedSize()
    }
}

struct GradientColorPickerSheet: View {
    let document: VectorDocument
    let editingGradientStopId: UUID?
    let editingGradientStopColor: VectorColor
    let currentGradient: VectorGradient?
    @Binding var showingColorPicker: Bool
    let updateStopColor: (UUID, VectorColor) -> Void
    let turnOffEditingState: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var localDocument: VectorDocument

    var onClose: (() -> Void)?

    init(document: VectorDocument, editingGradientStopId: UUID?, editingGradientStopColor: VectorColor, currentGradient: VectorGradient?, showingColorPicker: Binding<Bool>, updateStopColor: @escaping (UUID, VectorColor) -> Void, turnOffEditingState: @escaping () -> Void, onClose: (() -> Void)? = nil) {
        self.document = document
        self.editingGradientStopId = editingGradientStopId
        self.editingGradientStopColor = editingGradientStopColor
        self.currentGradient = currentGradient
        self._showingColorPicker = showingColorPicker
        self.updateStopColor = updateStopColor
        self.turnOffEditingState = turnOffEditingState
        self.onClose = onClose

        let localDoc = VectorDocument()
        localDoc.defaultFillColor = editingGradientStopColor

        localDoc.settings = document.settings

        localDoc.customRgbSwatches = document.customRgbSwatches
        localDoc.customCmykSwatches = document.customCmykSwatches
        localDoc.customHsbSwatches = document.customHsbSwatches
        localDoc.documentColorDefaults = document.documentColorDefaults

        self._localDocument = State(initialValue: localDoc)
    }

    var body: some View {
        VStack(spacing: 0) {
            ColorPanel(document: localDocument, onColorSelected: { newColor in
                if let stopId = editingGradientStopId {
                    updateStopColor(stopId, newColor)
                }
            }, showGradientEditing: true)
            .frame(width: 300, height: 500)

            HStack {
                Spacer()
                Button("Close!") {
                    turnOffEditingState()
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Select Gradient Color" }) {
                        window.orderOut(nil)
                    }
                }
                .buttonStyle(ProfessionalPrimaryButtonStyle())
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .frame(height: 50)
        }
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .clipShape(Rectangle())
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .task {
            if let stopId = editingGradientStopId, let gradient = currentGradient {
                let stops: [GradientStop]
                switch gradient {
                case .linear(let linear):
                    stops = linear.stops
                case .radial(let radial):
                    stops = radial.stops
                }

                let stopIndex = stops.firstIndex { $0.id == stopId } ?? 0

                let capturedStopId = stopId
                appState.gradientEditingState = GradientEditingState(
                    gradientId: capturedStopId,
                    stopIndex: stopIndex,
                    onColorSelected: { color in
                        updateStopColor(capturedStopId, color)
                    }
                )
            }
        }
        .onDisappear {
        }
    }
}
