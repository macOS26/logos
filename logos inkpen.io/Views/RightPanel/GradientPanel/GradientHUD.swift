//
//  GradientHUD.swift
//  logos inkpen.io
//
//  Created by Todd Bruss on 9/1/25.
//

import SwiftUI
import AppKit

// MARK: - SwiftUI HUD Window for Gradient Color Picker

// 🔥 PERSISTENT GRADIENT HUD VIEW: Never recreated, only state updates
struct PersistentGradientHUDView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        let hudManager = appState.persistentGradientHUD
        
        if hudManager.isVisible {
            StableGradientHUDContent(hudManager: hudManager)
                // 🔥 POSITION NOT NEEDED - NSWindow handles positioning
                .animation(.none, value: hudManager.isDragging)
        }
    }
}

// 🔥 STABLE HUD CONTENT - Prevents recreation during dragging
struct StableGradientHUDContent: View, Equatable {
    let hudManager: PersistentGradientHUDManager
    
    // Make this view stable by implementing Equatable
    static func == (lhs: StableGradientHUDContent, rhs: StableGradientHUDContent) -> Bool {
        // Only recreate if the essential content changes, not position/dragging
        return lhs.hudManager.editingStopId == rhs.hudManager.editingStopId &&
               lhs.hudManager.editingStopColor == rhs.hudManager.editingStopColor &&
               lhs.hudManager.isVisible == rhs.hudManager.isVisible
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 🔥 STABLE COLOR PANEL - Only recreated when editingStopId changes
            StableColorPanelWrapper(hudManager: hudManager)
                .frame(maxWidth: 350, maxHeight: 500)
            
            // 🔥 CLOSE BUTTON in lower right corner
            HStack {
                Spacer()
                
                // Close button in lower right
                Button("Close") {
                    hudManager.hide()
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
        //.cornerRadius(12)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
    }
}

// 🔥 STABLE COLOR PANEL WRAPPER - Prevents ColorPanel recreation
struct StableColorPanelWrapper: View, Equatable {
    let hudManager: PersistentGradientHUDManager
    
    static func == (lhs: StableColorPanelWrapper, rhs: StableColorPanelWrapper) -> Bool {
        // Only recreate ColorPanel when the editing stop changes
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
    let currentGradient: VectorGradient? // Add current gradient reference
    @Binding var showingColorPicker: Bool
    let updateStopColor: (UUID, VectorColor) -> Void
    let turnOffEditingState: () -> Void
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    // Create a local document wrapper with the correct initial color
    @State private var localDocument: VectorDocument
    
    // Add close callback for the window
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
        
        // Create a copy of the document with the correct initial color but preserve important properties
        let localDoc = VectorDocument()
        localDoc.defaultFillColor = editingGradientStopColor
        
        // Copy essential properties from the original document
        localDoc.settings = document.settings  // Includes colorMode, etc.
        
        // Copy color swatches based on current mode
        localDoc.rgbSwatches = document.rgbSwatches
        localDoc.cmykSwatches = document.cmykSwatches
        localDoc.hsbSwatches = document.hsbSwatches
        
        self._localDocument = State(initialValue: localDoc)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ColorPanel(document: localDocument, onColorSelected: { newColor in
                // When a color is selected, update the stop but DON'T close the window
                if let stopId = editingGradientStopId {
                    updateStopColor(stopId, newColor)
                }
                // Window stays open - user controls when to close
            }, showGradientEditing: true)
            .frame(width: 300, height: 500)  // Reduced height to make room for close button
            
            // Close button in lower right corner
            HStack {
                Spacer()
                Button("Close!") {
                    // Turn off editing state
                    turnOffEditingState()
                    // Hide the window
                    if let window = NSApplication.shared.windows.first(where: { $0.title == "Select Gradient Color" }) {
                        window.orderOut(nil)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .frame(height: 50)
        }
        .background(
            Rectangle()
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .clipShape(Rectangle()) // Force sharp square corners
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5) // Professional shadow
        .task {
            // Set up gradient editing state
            if let stopId = editingGradientStopId, let gradient = currentGradient {
                // Find the correct stop and its current color
                let stops: [GradientStop]
                switch gradient {
                case .linear(let linear):
                    stops = linear.stops
                case .radial(let radial):
                    stops = radial.stops
                }
                
                let stopIndex = stops.firstIndex { $0.id == stopId } ?? 0
                
                // CRITICAL: Use the captured stopId to avoid closure issues
                let capturedStopId = stopId
                appState.gradientEditingState = GradientEditingState(
                    gradientId: capturedStopId,
                    stopIndex: stopIndex,
                    onColorSelected: { color in
                        updateStopColor(capturedStopId, color)
                        // Window stays open - user controls when to close
                    }
                )
            }
        }
        .onDisappear {
            // DON'T clean up gradient editing state to prevent SwiftUI crashes
        }
    }
}