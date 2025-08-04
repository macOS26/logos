import SwiftUI

// MARK: - Gradient Editing State

struct GradientEditingState {
    let gradientId: UUID // ID to track which gradient is being edited
    let stopIndex: Int   // Which color stop is being edited
    let onColorSelected: (VectorColor) -> Void // Callback when color is selected
    
    init(gradientId: UUID, stopIndex: Int, onColorSelected: @escaping (VectorColor) -> Void) {
        self.gradientId = gradientId
        self.stopIndex = stopIndex
        self.onColorSelected = onColorSelected
    }
}

struct GradientHUDData {
    let document: VectorDocument
    let editingGradientStopId: UUID?
    let editingGradientStopColor: VectorColor
    let currentGradient: VectorGradient?
    let updateStopColor: (UUID, VectorColor) -> Void
    let turnOffEditingState: () -> Void
}

@Observable
class AppState {
    var selectedPanelTab: PanelTab = .layers
    
    // MARK: - Pressure Sensitivity Toggle
    var pressureSensitivityEnabled: Bool {
        get { PressureManager.shared.pressureSensitivityEnabled }
        set { PressureManager.shared.pressureSensitivityEnabled = newValue }
    }
    
    // MARK: - Gradient Editing State
    var gradientEditingState: GradientEditingState? = nil
    
    // MARK: - Gradient HUD State
    var showingGradientHUD = false
    var gradientHUDData: GradientHUDData? = nil
    
    // MARK: - Panel Actions
    func showLayersPanel() {
        selectedPanelTab = .layers
        print("🎨 AppState: Switched to layers panel")
    }
    
    func showColorPanel() {
        selectedPanelTab = .color
        print("🎨 AppState: Switched to color panel")
    }
    
    func showStrokeFillPanel() {
        selectedPanelTab = .properties
        print("🎨 AppState: Switched to stroke/fill panel")
    }
    
    func showPathOpsPanel() {
        selectedPanelTab = .pathOps
        print("🎨 AppState: Switched to path ops panel")
    }
    
    func showFontPanel() {
        selectedPanelTab = .font
        print("🎨 AppState: Switched to font panel")
    }
    
    // MARK: - Gradient Editing Actions
    
    func startGradientStopEditing(gradientId: UUID, stopIndex: Int, onColorSelected: @escaping (VectorColor) -> Void) {
        gradientEditingState = GradientEditingState(
            gradientId: gradientId,
            stopIndex: stopIndex,
            onColorSelected: onColorSelected
        )
        selectedPanelTab = .color
    }
    
    func finishGradientStopEditing() {
        gradientEditingState = nil
    }
    
    // MARK: - Gradient HUD Actions
    
    func showGradientHUD(data: GradientHUDData) {
        gradientHUDData = data
        showingGradientHUD = true
        print("🎨 AppState: Showing gradient HUD - showingGradientHUD: \(showingGradientHUD), gradientHUDData: \(gradientHUDData != nil)")
        print("🎨 AppState: editingGradientStopId: \(data.editingGradientStopId), currentGradient: \(data.currentGradient != nil)")
    }
    
    func hideGradientHUD() {
        showingGradientHUD = false
        gradientHUDData = nil
        print("🎨 AppState: Hiding gradient HUD")
    }
    
    // MARK: - Development Actions
    var showingCoreGraphicsTest = false
    
    func showCoreGraphicsTest() {
        showingCoreGraphicsTest = true
        print("🧪 AppState: Showing CoreGraphics test")
    }
    
    func runPathOperationsBenchmark() {
        print("⚡ AppState: Running path operations benchmark")
        // TODO: Move benchmark logic to a utility class
        // For now, just print a message
        print("🚀 RUNNING PATH OPERATIONS BENCHMARK")
        print("📊 Benchmark functionality to be implemented in utility class")
        print("✅ BENCHMARK PLACEHOLDER COMPLETE")
    }
} 