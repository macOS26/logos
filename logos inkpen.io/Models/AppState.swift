import SwiftUI

@Observable
class AppState {
    static let shared = AppState()

    var selectedPanelTab: PanelTab = .layers

    var enableVerboseLogging: Bool = false {
        didSet { UserDefaults.standard.set(enableVerboseLogging, forKey: "enableVerboseLogging") }
    }
    var enablePressureLogging: Bool = false {
        didSet { UserDefaults.standard.set(enablePressureLogging, forKey: "enablePressureLogging") }
    }

    var defaultTool: DrawingTool = .brush {
        didSet {
            UserDefaults.standard.set(defaultTool.rawValue, forKey: "defaultTool")
        }
    }

    var pressureSensitivityEnabled: Bool = false {
        didSet {
            UserDefaults.standard.set(pressureSensitivityEnabled, forKey: "pressureSensitivityEnabled")
        }
    }

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
                _pressureCurve = loadedCurve
            }
        }
    }

    var enableClippingMaskContentSelection: Bool = false {
        didSet {
            UserDefaults.standard.set(enableClippingMaskContentSelection, forKey: "enableClippingMaskContentSelection")
        }
    }

    var gradientEditingState: GradientEditingState? = nil

    var showingGradientHUD = false
    var gradientHUDData: GradientHUDData? = nil

    private var _persistentGradientHUD: PersistentGradientHUDManager?
    var persistentGradientHUD: PersistentGradientHUDManager {
        if _persistentGradientHUD == nil {
            _persistentGradientHUD = PersistentGradientHUDManager(appState: self)
        }
        return _persistentGradientHUD!
    }

    private var _persistentInkHUD: PersistentInkHUDManager?
    var persistentInkHUD: PersistentInkHUDManager {
        if _persistentInkHUD == nil {
            _persistentInkHUD = PersistentInkHUDManager(appState: self)
        }
        return _persistentInkHUD!
    }

    var openWindowAction: ((String) -> Void)?
    var dismissWindowAction: ((String) -> Void)?

    var pendingNewDocument: VectorDocument? = nil

    var showSetupOnNewDoc: Bool = false

    var shouldShowDocumentSetup: Bool = false

    enum BrushPreviewStyle: String, CaseIterable { case outline, fill }
    var brushPreviewStyle: BrushPreviewStyle = .fill {
        didSet { UserDefaults.standard.set(brushPreviewStyle.rawValue, forKey: "brushPreviewStyle") }
    }
    var brushPreviewIsFinal: Bool = false {
        didSet { UserDefaults.standard.set(brushPreviewIsFinal, forKey: "brushPreviewIsFinal") }
    }

    enum PDFGradientMethod: String, CaseIterable {
        case cgGradient = "cgGradient"
        case cgShading = "cgShading"
        case cmyk = "cmyk"
        case blend = "blend"
        case mesh = "mesh"
    }

    var pdfGradientMethod: PDFGradientMethod = .cgGradient {
        didSet {
            UserDefaults.standard.set(pdfGradientMethod.rawValue, forKey: "pdfGradientMethod")
        }
    }

    enum PDFTextRenderingMode: String, CaseIterable {
        case glyphs = "glyphs"
        case lines = "lines"
    }

    var pdfTextRenderingMode: PDFTextRenderingMode = .glyphs {
        didSet {
            UserDefaults.standard.set(pdfTextRenderingMode.rawValue, forKey: "pdfTextRenderingMode")
        }
    }

    typealias SVGTextRenderingMode = PDFTextRenderingMode

    var svgTextRenderingMode: SVGTextRenderingMode = .glyphs {
        didSet {
            UserDefaults.standard.set(svgTextRenderingMode.rawValue, forKey: "svgTextRenderingMode")
        }
    }

    enum ExportColorSpace: String, CaseIterable {
        case displayP3 = "displayP3"
        case sRGB = "sRGB"
    }

    var exportColorSpace: ExportColorSpace = .displayP3 {
        didSet {
            UserDefaults.standard.set(exportColorSpace.rawValue, forKey: "exportColorSpace")
        }
    }

    var pdfBlendSteps: Int = 20 {
        didSet {
            let clampedValue = min(max(pdfBlendSteps, 10), 255)
            if pdfBlendSteps != clampedValue {
                pdfBlendSteps = clampedValue
            }
            UserDefaults.standard.set(pdfBlendSteps, forKey: "pdfBlendSteps")
        }
    }

    var pdfMeshGridX: Int = 8 {
        didSet {
            let clampedValue = min(max(pdfMeshGridX, 4), 50)
            if pdfMeshGridX != clampedValue {
                pdfMeshGridX = clampedValue
            }
            UserDefaults.standard.set(pdfMeshGridX, forKey: "pdfMeshGridX")
        }
    }

    var pdfMeshGridY: Int = 8 {
        didSet {
            let clampedValue = min(max(pdfMeshGridY, 4), 50)
            if pdfMeshGridY != clampedValue {
                pdfMeshGridY = clampedValue
            }
            UserDefaults.standard.set(pdfMeshGridY, forKey: "pdfMeshGridY")
        }
    }

    var enableSystemMetalHUD: Bool = false {
        didSet {
            UserDefaults.standard.set(enableSystemMetalHUD, forKey: "enableSystemMetalHUD")
            if enableSystemMetalHUD {
                setenv("MTL_HUD_ENABLED", "1", 1)
            } else {
                setenv("MTL_HUD_ENABLED", "0", 1)
            }
        }
    }

	var showInAppPerformanceHUD: Bool = true {
		didSet { UserDefaults.standard.set(showInAppPerformanceHUD, forKey: "showInAppPerformanceHUD") }
	}
	var inAppHUDOffsetX: CGFloat = 24 {
		didSet { UserDefaults.standard.set(Double(inAppHUDOffsetX), forKey: "inAppHUDOffsetX") }
	}
	var inAppHUDOffsetY: CGFloat = 12 {
		didSet { UserDefaults.standard.set(Double(inAppHUDOffsetY), forKey: "inAppHUDOffsetY") }
	}

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

    private init() {
        if let toolRawValue = UserDefaults.standard.string(forKey: "defaultTool"),
           let tool = DrawingTool(rawValue: toolRawValue) {
            self.defaultTool = tool
        } else {
            self.defaultTool = .brush
        }

        self.pressureSensitivityEnabled = UserDefaults.standard.object(forKey: "pressureSensitivityEnabled") as? Bool ?? false

        loadPressureCurve()

        if let styleRaw = UserDefaults.standard.string(forKey: "brushPreviewStyle"),
           let style = BrushPreviewStyle(rawValue: styleRaw) {
            self.brushPreviewStyle = style
        }
        self.brushPreviewIsFinal = UserDefaults.standard.object(forKey: "brushPreviewIsFinal") as? Bool ?? false

        self.enableSystemMetalHUD = UserDefaults.standard.object(forKey: "enableSystemMetalHUD") as? Bool ?? false
		self.showInAppPerformanceHUD = UserDefaults.standard.object(forKey: "showInAppPerformanceHUD") as? Bool ?? true
		self.inAppHUDOffsetX = CGFloat(UserDefaults.standard.object(forKey: "inAppHUDOffsetX") as? Double ?? 24)
		self.inAppHUDOffsetY = CGFloat(UserDefaults.standard.object(forKey: "inAppHUDOffsetY") as? Double ?? 12)
        self.metalHUDOffsetX = CGFloat(UserDefaults.standard.object(forKey: "metalHUDOffsetX") as? Double ?? 0)
        self.metalHUDOffsetY = CGFloat(UserDefaults.standard.object(forKey: "metalHUDOffsetY") as? Double ?? 24)
        self.metalHUDWidth = CGFloat(UserDefaults.standard.object(forKey: "metalHUDWidth") as? Double ?? 420)
        self.metalHUDHeight = CGFloat(UserDefaults.standard.object(forKey: "metalHUDHeight") as? Double ?? 280)

        self.enableVerboseLogging = UserDefaults.standard.object(forKey: "enableVerboseLogging") as? Bool ?? false
        self.enablePressureLogging = UserDefaults.standard.object(forKey: "enablePressureLogging") as? Bool ?? false

        if let methodRaw = UserDefaults.standard.string(forKey: "pdfGradientMethod") {
            let actualRaw = (methodRaw == "deviceN") ? "cmyk" : methodRaw
            if let method = PDFGradientMethod(rawValue: actualRaw) {
                self.pdfGradientMethod = method
            }
        }

        let savedSteps = UserDefaults.standard.object(forKey: "pdfBlendSteps") as? Int
        self.pdfBlendSteps = savedSteps ?? 20

        let savedGridX = UserDefaults.standard.object(forKey: "pdfMeshGridX") as? Int
        self.pdfMeshGridX = savedGridX ?? 8
        let savedGridY = UserDefaults.standard.object(forKey: "pdfMeshGridY") as? Int
        self.pdfMeshGridY = savedGridY ?? 8

        if let modeRaw = UserDefaults.standard.string(forKey: "pdfTextRenderingMode"),
           let mode = PDFTextRenderingMode(rawValue: modeRaw) {
            self.pdfTextRenderingMode = mode
        }

        if let modeRaw = UserDefaults.standard.string(forKey: "svgTextRenderingMode"),
           let mode = SVGTextRenderingMode(rawValue: modeRaw) {
            self.svgTextRenderingMode = mode
        }

        if let colorSpaceRaw = UserDefaults.standard.string(forKey: "exportColorSpace"),
           let colorSpace = ExportColorSpace(rawValue: colorSpaceRaw) {
            self.exportColorSpace = colorSpace
        }
    }


    func setWindowActions(openWindow: @escaping (String) -> Void, dismissWindow: @escaping (String) -> Void) {
        self.openWindowAction = { id in
            openWindow(id)
        }

        self.dismissWindowAction = { id in
            if id.contains("gradient-hud") {
                self.persistentGradientHUD.stopEditing()

                NSApplication.shared.windows.forEach { window in
                    if window.title.contains("Select Gradient Color") && window.isVisible {
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


}

