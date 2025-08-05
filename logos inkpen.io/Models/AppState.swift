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
    // MARK: - Shared Instance
    static let shared = AppState()
    
    var selectedPanelTab: PanelTab = .layers
    
    // MARK: - Default Tool Setting (Persistent across app launches)
    var defaultTool: DrawingTool = .selection {
        didSet {
            UserDefaults.standard.set(defaultTool.rawValue, forKey: "defaultTool")
            print("🛠️ Default tool changed to: \(defaultTool.rawValue)")
        }
    }
    
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
    private var _persistentGradientHUD: PersistentGradientHUDManager?
    var persistentGradientHUD: PersistentGradientHUDManager {
        if _persistentGradientHUD == nil {
            _persistentGradientHUD = PersistentGradientHUDManager(appState: self)
        }
        return _persistentGradientHUD!
    }
    
    // 🔥 WINDOW MANAGEMENT - For opening gradient HUD window
    var openWindowAction: ((String) -> Void)?
    var dismissWindowAction: ((String) -> Void)?
    
    // MARK: - Initializer
    private init() {
        // Load saved default tool from UserDefaults
        if let toolRawValue = UserDefaults.standard.string(forKey: "defaultTool"),
           let tool = DrawingTool(rawValue: toolRawValue) {
            self.defaultTool = tool
            print("🛠️ Loaded saved default tool: \(tool.rawValue)")
        } else {
            print("🛠️ Using default tool: selection")
        }
    }
    
    func setWindowActions(openWindow: @escaping (String) -> Void, dismissWindow: @escaping (String) -> Void) {
        self.openWindowAction = { id in
            // Prevent multiple gradient HUD windows
            if id == "gradient-hud" {
                // Close any existing gradient HUD windows first
                NSApplication.shared.windows.forEach { window in
                    if window.title.contains("Gradient Color Picker") {
                        window.close()
                    }
                }
            }
            openWindow(id)
        }
        self.dismissWindowAction = dismissWindow
    }
    
    // MARK: - Panel Actions
    func showLayersPanel() {
        selectedPanelTab = .layers
    }
    
    func showColorPanel() {
        selectedPanelTab = .color
    }
    
    func showStrokeFillPanel() {
        selectedPanelTab = .properties
    }
    
    func showPathOpsPanel() {
        selectedPanelTab = .pathOps
    }
    
    func showFontPanel() {
        selectedPanelTab = .font
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
    }
    
    func hideGradientHUD() {
        showingGradientHUD = false
        gradientHUDData = nil
    }
    
    // MARK: - Development Actions
    var showingCoreGraphicsTest = false
    
    func showCoreGraphicsTest() {
        showingCoreGraphicsTest = true
    }
    
    func runPathOperationsBenchmark() {
        // TODO: Move benchmark logic to a utility class
        // For now, silent execution
    }
}

// MARK: - Persistent Gradient HUD Manager

@Observable
class PersistentGradientHUDManager {
    // 🔥 PERSISTENT STATE - Never recreated
    var isVisible = false
    var isDragging = false
    
    // Reference to AppState for window management
    private weak var appState: AppState?
    
    // 🔥 POSITION HANDLED BY NSWindow - No manual tracking needed
    
    // Current gradient stop data - updates WITHOUT recreating the HUD
    var editingStopId: UUID? = nil
    var editingStopColor: VectorColor = .black
    var currentDocument: VectorDocument? = nil
    var currentGradient: VectorGradient? = nil
    var onColorSelected: ((UUID, VectorColor) -> Void)? = nil
    var onClose: (() -> Void)? = nil
    
    // Single stable document for ColorPanel - NEVER recreated
    private var stableColorDocument = VectorDocument()
    
    init(appState: AppState) {
        self.appState = appState
        stableColorDocument.defaultFillColor = .black
    }
    
    func show(stopId: UUID, color: VectorColor, document: VectorDocument, gradient: VectorGradient?, 
              onColorSelected: @escaping (UUID, VectorColor) -> Void, onClose: @escaping () -> Void) {
        // Remember if window was already visible to avoid reopening
        let wasAlreadyVisible = isVisible
        
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
        
        // 🔥 ALWAYS set visible, but only trigger window opening once
        isVisible = true
        
        // Only open window if it wasn't already visible
        if !wasAlreadyVisible {
            appState?.openWindowAction?("gradient-hud")
        }
        // If already visible, the WindowGroup will automatically update the content
    }
    
    func hide() {
        isVisible = false
        appState?.dismissWindowAction?("gradient-hud")
        // Call the close callback to turn off gradient editing state
        onClose?()
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