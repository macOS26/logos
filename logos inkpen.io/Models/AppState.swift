import SwiftUI


@Observable
class AppState {
    // MARK: - Shared Instance
    static let shared = AppState()
    
    var selectedPanelTab: PanelTab = .layers

    // MARK: - Logging Preferences
    /// Master switch for verbose console logging
    var enableVerboseLogging: Bool = false {
        didSet { UserDefaults.standard.set(enableVerboseLogging, forKey: "enableVerboseLogging") }
    }
    /// Separate control for extremely noisy pressure-related logs
    var enablePressureLogging: Bool = false {
        didSet { UserDefaults.standard.set(enablePressureLogging, forKey: "enablePressureLogging") }
    }
    
    // MARK: - Default Tool Setting (Persistent across app launches)
    var defaultTool: DrawingTool = .brush {
        didSet {
            UserDefaults.standard.set(defaultTool.rawValue, forKey: "defaultTool")
            Log.info("🛠️ Default tool changed to: \(defaultTool.rawValue)")
        }
    }
    
    // MARK: - Pressure Sensitivity Toggle
    var pressureSensitivityEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(pressureSensitivityEnabled, forKey: "pressureSensitivityEnabled")
            Log.info("🎨 PRESSURE: Sensitivity toggled to: \(pressureSensitivityEnabled)", category: .pressure)
        }
    }
    
    // MARK: - Clipping Mask Selection Mode
    /// When true, allows selection of individual shapes within clipping masks
    /// When false, clipping mask contents cannot be individually selected
    var enableClippingMaskContentSelection: Bool = false {
        didSet {
            UserDefaults.standard.set(enableClippingMaskContentSelection, forKey: "enableClippingMaskContentSelection")
            Log.info("🎭 CLIPPING MASK: Content selection mode \(enableClippingMaskContentSelection ? "enabled" : "disabled")", category: .general)
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
    
    // 🔥 PERSISTENT INK HUD MANAGER
    private var _persistentInkHUD: PersistentInkHUDManager?
    var persistentInkHUD: PersistentInkHUDManager {
        if _persistentInkHUD == nil {
            _persistentInkHUD = PersistentInkHUDManager(appState: self)
        }
        return _persistentInkHUD!
    }
    
    // 🔥 WINDOW MANAGEMENT - For opening gradient HUD window
    var openWindowAction: ((String) -> Void)?
    var dismissWindowAction: ((String) -> Void)?
    
    // MARK: - New Document Pipeline (WindowGroup-based)
    /// When user completes New Document Setup in its own window, we store the
    /// configured VectorDocument here. The next created DocumentGroup window
    /// will detect this and load these settings, then clear the value.
    var pendingNewDocument: VectorDocument? = nil

    // MARK: - New Document Flow
    /// When true, the next opened document will present the New Document Setup sheet on appear
    var showSetupOnNewDoc: Bool = false
    
    /// Controls whether the New Document Setup window should be available for opening
    var shouldShowDocumentSetup: Bool = false
    
    // MARK: - Preferences: Brush Preview
    enum BrushPreviewStyle: String, CaseIterable { case outline, fill }
    var brushPreviewStyle: BrushPreviewStyle = .outline {
        didSet { UserDefaults.standard.set(brushPreviewStyle.rawValue, forKey: "brushPreviewStyle") }
    }
    /// If true, the live preview is treated as final; we bake exactly that path on mouse up
    var brushPreviewIsFinal: Bool = false {
        didSet { UserDefaults.standard.set(brushPreviewIsFinal, forKey: "brushPreviewIsFinal") }
    }
    
    // MARK: - System Metal Performance HUD Preference
    /// Controls Apple Metal system Performance HUD visibility (live toggle)
    var enableSystemMetalHUD: Bool = false {
        didSet {
            UserDefaults.standard.set(enableSystemMetalHUD, forKey: "enableSystemMetalHUD")
            // Apply immediately for any newly created Metal views
            if enableSystemMetalHUD {
                setenv("MTL_HUD_ENABLED", "1", 1)
            } else {
                setenv("MTL_HUD_ENABLED", "0", 1)
            }
        }
    }

	// MARK: - In-App Performance HUD (draggable, moveable)
	/// Show a lightweight in-app performance HUD that can be dragged
	var showInAppPerformanceHUD: Bool = true {
		didSet { UserDefaults.standard.set(showInAppPerformanceHUD, forKey: "showInAppPerformanceHUD") }
	}
	/// Persistent position for the in-app HUD (top-left origin)
	var inAppHUDOffsetX: CGFloat = 24 {
		didSet { UserDefaults.standard.set(Double(inAppHUDOffsetX), forKey: "inAppHUDOffsetX") }
	}
	var inAppHUDOffsetY: CGFloat = 12 {
		didSet { UserDefaults.standard.set(Double(inAppHUDOffsetY), forKey: "inAppHUDOffsetY") }
	}

    // Position and size controls for Apple's HUD carrier view
    var metalHUDOffsetX: CGFloat = 0 {
        didSet { UserDefaults.standard.set(Double(metalHUDOffsetX), forKey: "metalHUDOffsetX") }
    }
    var metalHUDOffsetY: CGFloat = 24 {
        didSet { UserDefaults.standard.set(Double(metalHUDOffsetY), forKey: "metalHUDOffsetY") }
    }
    var metalHUDWidth: CGFloat = 420 {
        didSet { UserDefaults.standard.set(Double(metalHUDWidth), forKey: "metalHUDWidth") }
    }
    var metalHUDHeight: CGFloat = 280 {
        didSet { UserDefaults.standard.set(Double(metalHUDHeight), forKey: "metalHUDHeight") }
    }
    
    // MARK: - Initializer
    private init() {
        // Load saved default tool from UserDefaults
        if let toolRawValue = UserDefaults.standard.string(forKey: "defaultTool"),
           let tool = DrawingTool(rawValue: toolRawValue) {
            self.defaultTool = tool
            Log.info("🛠️ Loaded saved default tool: \(tool.rawValue)")
        } else {
            self.defaultTool = .brush
            Log.info("🛠️ Using default tool: brush")
        }
        
        // Load saved pressure sensitivity setting
        self.pressureSensitivityEnabled = UserDefaults.standard.object(forKey: "pressureSensitivityEnabled") as? Bool ?? true
        Log.info("🎨 PRESSURE: Loaded sensitivity setting: \(pressureSensitivityEnabled)", category: .pressure)
        
        // Load brush preview preferences
        if let styleRaw = UserDefaults.standard.string(forKey: "brushPreviewStyle"),
           let style = BrushPreviewStyle(rawValue: styleRaw) {
            self.brushPreviewStyle = style
        }
        self.brushPreviewIsFinal = UserDefaults.standard.object(forKey: "brushPreviewIsFinal") as? Bool ?? false

        // Load Apple system HUD preference and layout
        self.enableSystemMetalHUD = UserDefaults.standard.object(forKey: "enableSystemMetalHUD") as? Bool ?? false
		// Load in-app HUD preferences
		self.showInAppPerformanceHUD = UserDefaults.standard.object(forKey: "showInAppPerformanceHUD") as? Bool ?? true
		self.inAppHUDOffsetX = CGFloat(UserDefaults.standard.object(forKey: "inAppHUDOffsetX") as? Double ?? 24)
		self.inAppHUDOffsetY = CGFloat(UserDefaults.standard.object(forKey: "inAppHUDOffsetY") as? Double ?? 12)
        self.metalHUDOffsetX = CGFloat(UserDefaults.standard.object(forKey: "metalHUDOffsetX") as? Double ?? 0)
        self.metalHUDOffsetY = CGFloat(UserDefaults.standard.object(forKey: "metalHUDOffsetY") as? Double ?? 24)
        self.metalHUDWidth = CGFloat(UserDefaults.standard.object(forKey: "metalHUDWidth") as? Double ?? 420)
        self.metalHUDHeight = CGFloat(UserDefaults.standard.object(forKey: "metalHUDHeight") as? Double ?? 280)

        // Load logging preferences
        self.enableVerboseLogging = UserDefaults.standard.object(forKey: "enableVerboseLogging") as? Bool ?? false
        self.enablePressureLogging = UserDefaults.standard.object(forKey: "enablePressureLogging") as? Bool ?? false
    }


    
    func setWindowActions(openWindow: @escaping (String) -> Void, dismissWindow: @escaping (String) -> Void) {
        self.openWindowAction = { id in
            openWindow(id)
        }
        
        self.dismissWindowAction = { id in
            if id.contains("gradient-hud") {
                Log.fileOperation("🎨 GRADIENT HUD: dismissWindowAction called - closing window", level: .info)
                
                // 🔥 NEW: Stop editing state when window is closed
                self.persistentGradientHUD.stopEditing()
                
                // 🔥 PRESERVE WINDOW POSITION - Use orderOut instead of close
                NSApplication.shared.windows.forEach { window in
                    if window.title.contains("Select Gradient Color") && window.isVisible {
                        Log.fileOperation("🎨 GRADIENT HUD: Hiding window to preserve position: \(window.title)", level: .info)
                        // Use orderOut to hide without destroying, preserving position
                        window.orderOut(nil)
                    }
                }
                Log.fileOperation("🎨 GRADIENT HUD: dismissWindowAction completed", level: .info)
            } else if id.contains("ink-hud") {
                Log.info("🖌️ INK HUD: dismissWindowAction called - hiding window", category: .general)
                self.persistentInkHUD.hide()
                NSApplication.shared.windows.forEach { window in
                    if window.title.contains("Ink Color Mixer") && window.isVisible {
                        window.orderOut(nil)
                    }
                }
                Log.info("🖌️ INK HUD: dismissWindowAction completed", category: .general)
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
        Log.fileOperation("🎨 GRADIENT HUD: Force resetting all gradient editing state", level: .info)
        gradientEditingState = nil
        persistentGradientHUD.forceResetHidingFlag()
        persistentGradientHUD.hide()
        
        // 🔥 HIDE ALL GRADIENT WINDOWS (preserve position)
        NSApplication.shared.windows.forEach { window in
            if window.title.contains("Gradient Color Picker") {
                Log.fileOperation("🎨 GRADIENT HUD: Hiding window in emergency reset: \(window.title)", level: .info)
                // Use orderOut to hide without destroying, preserving position
                window.orderOut(nil)
            }
        }
        
        Log.fileOperation("🎨 GRADIENT HUD: Force reset completed", level: .info)
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

    // Removed: System Metal HUD control utilities and shell runner
}

// MARK: - Persistent Gradient HUD Manager

