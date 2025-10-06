import SwiftUI

@Observable
class AppState {
    // MARK: - Shared Instance
    static let shared = AppState()
    
    var selectedPanelTab: PanelTab = .layers

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
        }
    }
    
    // MARK: - Pressure Sensitivity Toggle
    var pressureSensitivityEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(pressureSensitivityEnabled, forKey: "pressureSensitivityEnabled")
        }
    }

    // MARK: - Global Pressure Curve
    /// Maps input pressure (0-1) to output thickness (0-1) using interpolation
    internal var _pressureCurve: [CGPoint] = [
        CGPoint(x: 0.0, y: 0.0),
        CGPoint(x: 0.25, y: 0.25),
        CGPoint(x: 0.5, y: 0.5),
        CGPoint(x: 0.75, y: 0.75),
        CGPoint(x: 1.0, y: 1.0)
    ]

    var pressureCurve: [CGPoint] {
        get { _pressureCurve }
        set {
            _pressureCurve = newValue
            savePressureCurve()
        }
    }

    private func savePressureCurve() {
        let data = pressureCurve.map { ["x": $0.x, "y": $0.y] }
        UserDefaults.standard.set(data, forKey: "pressureCurve")
        UserDefaults.standard.synchronize()
    }

    private func loadPressureCurve() {
        if let data = UserDefaults.standard.array(forKey: "pressureCurve") as? [[String: Double]] {
            let loadedCurve = data.compactMap { dict -> CGPoint? in
                guard let x = dict["x"], let y = dict["y"] else { return nil }
                return CGPoint(x: x, y: y)
            }
            if loadedCurve.count >= 2 {
                _pressureCurve = loadedCurve  // Set backing storage directly to avoid triggering save
            }
        }
    }
    
    // MARK: - Clipping Mask Selection Mode
    /// When true, allows selection of individual shapes within clipping masks
    /// When false, clipping mask contents cannot be individually selected
    var enableClippingMaskContentSelection: Bool = false {
        didSet {
            UserDefaults.standard.set(enableClippingMaskContentSelection, forKey: "enableClippingMaskContentSelection")
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
    var brushPreviewStyle: BrushPreviewStyle = .fill {
        didSet { UserDefaults.standard.set(brushPreviewStyle.rawValue, forKey: "brushPreviewStyle") }
    }
    /// If true, the live preview is treated as final; we bake exactly that path on mouse up
    var brushPreviewIsFinal: Bool = false {
        didSet { UserDefaults.standard.set(brushPreviewIsFinal, forKey: "brushPreviewIsFinal") }
    }
    
    // MARK: - PDF Export Preferences
    /// Controls whether to use CGGradient or CGShading for PDF gradient rendering
    enum PDFGradientMethod: String, CaseIterable {
        case cgGradient = "cgGradient"  // Smooth gradients, may rasterize in Illustrator
        case cgShading = "cgShading"    // Baked opacity to avoid transparency flattening
        case cmyk = "cmyk"              // CMYK color space (was deviceN)
        case blend = "blend"            // Blend mode with discrete steps (Illustrator-style)
        case mesh = "mesh"              // Gradient mesh (future implementation)

        var displayName: String {
            switch self {
            case .cgGradient: return "Gradient"
            case .cgShading: return "Shading"
            case .cmyk: return "CMYK"
            case .blend: return "Blend"
            case .mesh: return "Grid"
            }
        }

        static var availableCases: [PDFGradientMethod] {
            #if DEBUG
            return allCases
            #else
            return [.cgGradient, .cgShading]
            #endif
        }
    }

    var pdfGradientMethod: PDFGradientMethod = .cgGradient {
        didSet {
            UserDefaults.standard.set(pdfGradientMethod.rawValue, forKey: "pdfGradientMethod")
        }
    }

    /// Controls how text is rendered in PDF exports
    enum PDFTextRenderingMode: String, CaseIterable {
        case glyphs = "glyphs"      // Individual glyphs (most accurate)
        case lines = "lines"         // By lines (CTLine)

        var displayName: String {
            switch self {
            case .glyphs: return "Individual Glyphs (most accurate)"
            case .lines: return "By Lines (faster)"
            }
        }

        var description: String {
            switch self {
            case .glyphs: return "Render each glyph individually for maximum precision"
            case .lines: return "Render text line-by-line for better performance"
            }
        }
    }

    var pdfTextRenderingMode: PDFTextRenderingMode = .glyphs {
        didSet {
            UserDefaults.standard.set(pdfTextRenderingMode.rawValue, forKey: "pdfTextRenderingMode")
        }
    }

    /// Controls how text is rendered in SVG exports (reuse same enum as PDF)
    typealias SVGTextRenderingMode = PDFTextRenderingMode

    var svgTextRenderingMode: SVGTextRenderingMode = .glyphs {
        didSet {
            UserDefaults.standard.set(svgTextRenderingMode.rawValue, forKey: "svgTextRenderingMode")
        }
    }

    /// Number of steps for blend mode (10-255)
    var pdfBlendSteps: Int = 20 {
        didSet {
            let clampedValue = min(max(pdfBlendSteps, 10), 255)
            if pdfBlendSteps != clampedValue {
                pdfBlendSteps = clampedValue
            }
            UserDefaults.standard.set(pdfBlendSteps, forKey: "pdfBlendSteps")
        }
    }

    /// Grid size for mesh mode (X dimension, 4-50)
    var pdfMeshGridX: Int = 8 {
        didSet {
            let clampedValue = min(max(pdfMeshGridX, 4), 50)
            if pdfMeshGridX != clampedValue {
                pdfMeshGridX = clampedValue
            }
            UserDefaults.standard.set(pdfMeshGridX, forKey: "pdfMeshGridX")
        }
    }

    /// Grid size for mesh mode (Y dimension, 4-50)
    var pdfMeshGridY: Int = 8 {
        didSet {
            let clampedValue = min(max(pdfMeshGridY, 4), 50)
            if pdfMeshGridY != clampedValue {
                pdfMeshGridY = clampedValue
            }
            UserDefaults.standard.set(pdfMeshGridY, forKey: "pdfMeshGridY")
        }
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
        } else {
            self.defaultTool = .brush
        }
        
        // Load saved pressure sensitivity setting - default to false (OFF) for mouse/trackpad
        self.pressureSensitivityEnabled = UserDefaults.standard.object(forKey: "pressureSensitivityEnabled") as? Bool ?? false

        // Load saved pressure curve
        loadPressureCurve()
        
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

        // Load PDF gradient method preference
        if let methodRaw = UserDefaults.standard.string(forKey: "pdfGradientMethod") {
            // Handle migration from old "deviceN" to new "cmyk"
            let actualRaw = (methodRaw == "deviceN") ? "cmyk" : methodRaw
            if let method = PDFGradientMethod(rawValue: actualRaw) {
                self.pdfGradientMethod = method
            }
        }

        // Load PDF blend steps
        let savedSteps = UserDefaults.standard.object(forKey: "pdfBlendSteps") as? Int
        self.pdfBlendSteps = savedSteps ?? 20

        // Load PDF mesh grid settings
        let savedGridX = UserDefaults.standard.object(forKey: "pdfMeshGridX") as? Int
        self.pdfMeshGridX = savedGridX ?? 8
        let savedGridY = UserDefaults.standard.object(forKey: "pdfMeshGridY") as? Int
        self.pdfMeshGridY = savedGridY ?? 8

        // Load PDF text rendering mode
        if let modeRaw = UserDefaults.standard.string(forKey: "pdfTextRenderingMode"),
           let mode = PDFTextRenderingMode(rawValue: modeRaw) {
            self.pdfTextRenderingMode = mode
        }
    }


    
    func setWindowActions(openWindow: @escaping (String) -> Void, dismissWindow: @escaping (String) -> Void) {
        self.openWindowAction = { id in
            openWindow(id)
        }
        
        self.dismissWindowAction = { id in
            if id.contains("gradient-hud") {
                // 🔥 NEW: Stop editing state when window is closed
                self.persistentGradientHUD.stopEditing()

                // 🔥 PRESERVE WINDOW POSITION - Use orderOut instead of close
                NSApplication.shared.windows.forEach { window in
                    if window.title.contains("Select Gradient Color") && window.isVisible {
                        // Use orderOut to hide without destroying, preserving position
                        window.orderOut(nil)
                    }
                }
            } else if id.contains("ink-hud") {
                self.persistentInkHUD.hide()
                NSApplication.shared.windows.forEach { window in
                    if window.title.contains("Ink Color Mixer") && window.isVisible {
                        window.orderOut(nil)
                    }
                }
            }
            dismissWindow(id)
        }
    }
    
    // MARK: - Panel Actions
    
    // MARK: - Gradient Editing Actions

    // Removed: System Metal HUD control utilities and shell runner
}

// MARK: - Persistent Gradient HUD Manager

