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
    
    // 🔥 PERSISTENT HUD MANAGER - Prevents recreation spam
    let persistentGradientHUD = PersistentGradientHUDManager()
    
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

// MARK: - Persistent Gradient HUD Manager

@Observable
class PersistentGradientHUDManager {
    // 🔥 PERSISTENT STATE - Never recreated
    var isVisible = false
    var isDragging = false
    
    // 🔥 REMEMBERS LAST POSITION - Persistent across app sessions
    var windowPosition: CGPoint {
        get {
            let x = UserDefaults.standard.double(forKey: "GradientHUD_WindowX")
            let y = UserDefaults.standard.double(forKey: "GradientHUD_WindowY")
            
            // If no saved position, use center of screen as default
            if x == 0 && y == 0 {
                return CGPoint(x: 683, y: 384) // Center of 1366x768 screen
            }
            return CGPoint(x: x, y: y)
        }
        set {
            UserDefaults.standard.set(newValue.x, forKey: "GradientHUD_WindowX")
            UserDefaults.standard.set(newValue.y, forKey: "GradientHUD_WindowY")
        }
    }
    
    // 🔥 PROFESSIONAL MOUSE TRACKING (Based on hand tool implementation)
    var initialWindowPosition = CGPoint.zero  // Reference window position when drag started
    var hudDragStart = CGPoint.zero           // Reference cursor position when drag started
    
    // Current gradient stop data - updates WITHOUT recreating the HUD
    var editingStopId: UUID? = nil
    var editingStopColor: VectorColor = .black
    var currentDocument: VectorDocument? = nil
    var currentGradient: VectorGradient? = nil
    var onColorSelected: ((UUID, VectorColor) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    
    // Single stable document for ColorPanel - NEVER recreated
    private var stableColorDocument = VectorDocument()
    
    init() {
        stableColorDocument.defaultFillColor = .black
    }
    
    func show(stopId: UUID, color: VectorColor, document: VectorDocument, gradient: VectorGradient?, 
              onColorSelected: @escaping (UUID, VectorColor) -> Void, onClose: @escaping () -> Void) {
        // Update state WITHOUT recreating anything
        self.editingStopId = stopId
        self.editingStopColor = color
        self.currentDocument = document
        self.currentGradient = gradient
        self.onColorSelected = onColorSelected
        self.onClose = onClose
        
        // Update the stable document color - this triggers ColorPanel refresh
        stableColorDocument.defaultFillColor = color
        
        // 🔥 CRITICAL: Force the ColorPanel to refresh when switching gradient stops
        stableColorDocument.objectWillChange.send()
        
        // 🔥 windowPosition is now a computed property that remembers last position
        // No manual positioning needed - it automatically centers on first use
        
        isVisible = true
    }
    
    func hide() {
        isVisible = false
        // DON'T call onClose - it creates infinite loop
        // onClose?()
    }
    
    func updateStopColor(_ stopId: UUID, _ color: VectorColor) {
        // Update our tracking
        if stopId == editingStopId {
            editingStopColor = color
            stableColorDocument.defaultFillColor = color
            
            // 🔥 CRITICAL: Force the ColorPanel to refresh with the new color
            stableColorDocument.objectWillChange.send()
        }
        
        // Call the callback to update the actual gradient
        onColorSelected?(stopId, color)
    }
    
    func getStableDocument() -> VectorDocument {
        return stableColorDocument
    }
} 