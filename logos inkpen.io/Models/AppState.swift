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
    var pressureSensitivityEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(pressureSensitivityEnabled, forKey: "pressureSensitivityEnabled")
            print("🎨 PRESSURE: Sensitivity toggled to: \(pressureSensitivityEnabled)")
        }
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
        
        // Load saved pressure sensitivity setting
        self.pressureSensitivityEnabled = UserDefaults.standard.object(forKey: "pressureSensitivityEnabled") as? Bool ?? true
        print("🎨 PRESSURE: Loaded sensitivity setting: \(pressureSensitivityEnabled)")
    }


    
    func setWindowActions(openWindow: @escaping (String) -> Void, dismissWindow: @escaping (String) -> Void) {
        self.openWindowAction = { id in
            openWindow(id)
        }
        
        self.dismissWindowAction = { id in
            if id.contains("gradient-hud") {
                print("🎨 GRADIENT HUD: dismissWindowAction called - closing window")
                
                // 🔥 NEW: Stop editing state when window is closed
                self.persistentGradientHUD.stopEditing()
                
                // 🔥 FIXED: Force close and destroy the gradient HUD window
                NSApplication.shared.windows.forEach { window in
                    if window.title.contains("Select Gradient Color") && window.isVisible {
                        print("🎨 GRADIENT HUD: Force closing window: \(window.title)")
                        window.delegate = nil // Remove delegate to prevent callbacks
                        window.close()
                        // Force the window to be destroyed
                        window.orderOut(nil)
                    }
                }
                print("🎨 GRADIENT HUD: dismissWindowAction completed")
            }
            dismissWindow(id)
        }
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
    
    // 🔥 EMERGENCY RESET: Force clear all gradient editing state
    func forceResetGradientEditingState() {
        print("🎨 GRADIENT HUD: Force resetting all gradient editing state")
        gradientEditingState = nil
        persistentGradientHUD.forceResetHidingFlag()
        persistentGradientHUD.hide()
        
        // 🔥 FORCE CLOSE ALL GRADIENT WINDOWS
        NSApplication.shared.windows.forEach { window in
            if window.title.contains("Gradient Color Picker") {
                print("🎨 GRADIENT HUD: Force closing window in emergency reset: \(window.title)")
                window.delegate = nil
                window.close()
                window.orderOut(nil)
            }
        }
        
        print("🎨 GRADIENT HUD: Force reset completed")
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
    private var isHiding = false // 🔥 NEW: Prevent multiple hide calls
    
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
        // 🔥 FIXED: Reset hiding flag when showing
        isHiding = false
        
        // Remember if window was already visible to avoid reopening
        let wasAlreadyVisible = isVisible
        print("🎨 GRADIENT HUD: show() called - wasAlreadyVisible: \(wasAlreadyVisible)")
        print("🎨 GRADIENT HUD: stopId = \(stopId.uuidString.prefix(8))")
        print("🎨 GRADIENT HUD: current isVisible = \(isVisible)")
        
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
        
        var foundExistingWindow = false
        
        for window in NSApplication.shared.windows {
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "gradient-hud") {
                print("🎨 GRADIENT HUD: Found existing window: \(identifier)")
                
                if !window.isVisible {
                    window.tabbingMode = .disallowed
                    window.makeKeyAndOrderFront(nil) // Show the window
                }
                foundExistingWindow = true
                break // Exit the loop once we find the gradient window
            }
        }
        
        // Only open a new window if we didn't find an existing one
        if !foundExistingWindow {
            print("🎨 GRADIENT HUD: No existing window found, opening new one")
            appState?.openWindowAction?("gradient-hud")
        }
        
        print("🎨 GRADIENT HUD: show() completed - isVisible = \(isVisible)")
        // If already visible, the WindowGroup will automatically update the content
    }
    
    func hide() {
        NSApplication.shared.windows.forEach { window in
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "gradient-hud"), window.isVisible {
                window.hidesOnDeactivate = true
            }
        }
    }
    
    // 🔥 NEW: Stop editing when window is closed with X button
    func stopEditing() {
        print("🎨 GRADIENT HUD: Stopping editing state")
        isVisible = false
        editingStopId = nil
        editingStopColor = .black
        currentDocument = nil
        currentGradient = nil
        onColorSelected = nil
        onClose = nil
        
        // Clear the stable document color
        stableColorDocument.defaultFillColor = .black
        stableColorDocument.objectWillChange.send()
        
        // Call the onClose callback if it exists
        onClose?()
        
        print("🎨 GRADIENT HUD: Editing state cleared")
    }
    
    // 🔥 EMERGENCY RESET: Force reset hiding flag
    func forceResetHidingFlag() {
        isHiding = false
        print("🎨 GRADIENT HUD: Force reset hiding flag")
    }
    
    // 🔥 DEBUG: Count gradient windows
    func countGradientWindows() -> Int {
        let count = NSApplication.shared.windows.filter { window in
            window.title.contains("Gradient Color Picker")
        }.count
        print("🎨 GRADIENT HUD: Found \(count) gradient windows")
        return count
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
