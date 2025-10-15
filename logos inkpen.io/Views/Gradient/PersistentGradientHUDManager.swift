import SwiftUI
import Combine

@Observable
class PersistentGradientHUDManager {
    var isVisible = false
    var isDragging = false
    private var isHiding = false

    private weak var appState: AppState?

    var editingStopId: UUID? = nil
    var editingStopColor: VectorColor = .black
    var currentDocument: VectorDocument? = nil
    var currentGradient: VectorGradient? = nil
    var onColorSelected: ((UUID, VectorColor) -> Void)? = nil
    var onClose: (() -> Void)? = nil

    private var stableColorDocument = VectorDocument()

    init(appState: AppState) {
        self.appState = appState
    }

    func show(stopId: UUID, color: VectorColor, document: VectorDocument, gradient: VectorGradient?,
              onColorSelected: @escaping (UUID, VectorColor) -> Void, onClose: @escaping () -> Void) {
        isHiding = false

        self.editingStopId = stopId
        self.editingStopColor = color
        self.currentDocument = document
        self.currentGradient = gradient
        self.onColorSelected = onColorSelected
        self.onClose = onClose

        stableColorDocument.defaultFillColor = color

        isVisible = true

        var foundExistingWindow = false

        for window in NSApplication.shared.windows {
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "gradient-hud") {

                if !window.isVisible {
                    safeShowWindow(window)
                }
                foundExistingWindow = true
                break
            }
        }

        if !foundExistingWindow {
            appState?.openWindowAction?("gradient-hud")
        }

    }

    func hide() {
        NSApplication.shared.windows.forEach { window in
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "gradient-hud"), window.isVisible {
                window.orderOut(nil)
            }
        }
    }

    func stopEditing() {
        isVisible = false
        editingStopId = nil
        editingStopColor = .black
        currentDocument = nil
        currentGradient = nil
        onColorSelected = nil
        onClose = nil

        onClose?()

    }

    func forceResetHidingFlag() {
        isHiding = false
    }

    func countGradientWindows() -> Int {
        let count = NSApplication.shared.windows.filter { window in
            window.title.contains("Gradient Color Picker")
        }.count
        return count
    }

    func updateStopColor(_ stopId: UUID, _ color: VectorColor) {
        if stopId == editingStopId {
            editingStopColor = color
            stableColorDocument.defaultFillColor = color
        }

        onColorSelected?(stopId, color)
    }

    func getStableDocument() -> VectorDocument {
        return stableColorDocument
    }

    private func validateDisplayForWindow() -> Bool {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            Log.warning("🎨 GRADIENT HUD: No displays available", category: .general)
            return false
        }

        guard let mainScreen = NSScreen.main else {
            Log.warning("🎨 GRADIENT HUD: Main display is invalid", category: .general)
            return false
        }

        let frame = mainScreen.frame
        guard frame.width > 0 && frame.height > 0 &&
              !frame.origin.x.isNaN && !frame.origin.y.isNaN &&
              !frame.width.isNaN && !frame.height.isNaN else {
            Log.warning("🎨 GRADIENT HUD: Invalid display frame: \(frame)", category: .general)
            return false
        }

        return true
    }

    private func safeShowWindow(_ window: NSWindow) {
        window.tabbingMode = .disallowed

        let currentFrame = window.frame
        let mainScreen = NSScreen.main ?? NSScreen.screens.first

        if let screen = mainScreen {
            let screenFrame = screen.visibleFrame
            var newFrame = currentFrame
            if newFrame.maxX > screenFrame.maxX {
                newFrame.origin.x = screenFrame.maxX - newFrame.width
            }
            if newFrame.maxY > screenFrame.maxY {
                newFrame.origin.y = screenFrame.maxY - newFrame.height
            }
            if newFrame.minX < screenFrame.minX {
                newFrame.origin.x = screenFrame.minX
            }
            if newFrame.minY < screenFrame.minY {
                newFrame.origin.y = screenFrame.minY
            }

            if newFrame != currentFrame {
                window.setFrame(newFrame, display: false)
            }
        }

        window.makeKeyAndOrderFront(nil)
    }
}

@Observable
class PersistentInkHUDManager {
    var isVisible = false
    private weak var appState: AppState?

    var currentDocument: VectorDocument? = nil

    init(appState: AppState) {
        self.appState = appState
    }

    func show(document: VectorDocument) {
        currentDocument = document
        isVisible = true

        if !validateDisplayForInkHUD() {
            Log.warning("🖌️ INK HUD: Invalid display detected - using fallback positioning", category: .general)
        }

        var foundExistingWindow = false
        for window in NSApplication.shared.windows {
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "ink-hud") {
                if !window.isVisible {
                    safeShowInkHUDWindow(window)
                }
                foundExistingWindow = true
                break
            }
        }

        if !foundExistingWindow {
            appState?.openWindowAction?("ink-hud")
        }
    }

    func hide() {
        NSApplication.shared.windows.forEach { window in
            if let identifier = window.identifier?.rawValue, identifier.starts(with: "ink-hud"), window.isVisible {
                window.orderOut(nil)
            }
        }
        isVisible = false
    }

    private func validateDisplayForInkHUD() -> Bool {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            Log.warning("🖌️ INK HUD: No displays available", category: .general)
            return false
        }

        guard let mainScreen = NSScreen.main else {
            Log.warning("🖌️ INK HUD: Main display is invalid", category: .general)
            return false
        }

        let frame = mainScreen.frame
        guard frame.width > 0 && frame.height > 0 &&
              !frame.origin.x.isNaN && !frame.origin.y.isNaN &&
              !frame.width.isNaN && !frame.height.isNaN else {
            Log.warning("🖌️ INK HUD: Invalid display frame: \(frame)", category: .general)
            return false
        }

        return true
    }

    private func safeShowInkHUDWindow(_ window: NSWindow) {
        window.tabbingMode = .disallowed

        let currentFrame = window.frame
        let mainScreen = NSScreen.main ?? NSScreen.screens.first

        if let screen = mainScreen {
            let screenFrame = screen.visibleFrame
            var newFrame = currentFrame
            if newFrame.maxX > screenFrame.maxX {
                newFrame.origin.x = screenFrame.maxX - newFrame.width
            }
            if newFrame.maxY > screenFrame.maxY {
                newFrame.origin.y = screenFrame.maxY - newFrame.height
            }
            if newFrame.minX < screenFrame.minX {
                newFrame.origin.x = screenFrame.minX
            }
            if newFrame.minY < screenFrame.minY {
                newFrame.origin.y = screenFrame.minY
            }

            if newFrame != currentFrame {
                window.setFrame(newFrame, display: false)
            }
        }

        window.makeKeyAndOrderFront(nil)
    }
}

struct GradientEditingState {
    let gradientId: UUID
    let stopIndex: Int
    let onColorSelected: (VectorColor) -> Void

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
